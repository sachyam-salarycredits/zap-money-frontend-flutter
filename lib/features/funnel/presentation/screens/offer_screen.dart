import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/services/screen_status_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../dashboard/data/home_repository.dart';
import '../widgets/legal_agreement_sheet.dart';

/// RN `scenes/offerScreen/salaried` — Request Money + legal agreements + Apply.
class OfferScreen extends ConsumerStatefulWidget {
  const OfferScreen({super.key});

  @override
  ConsumerState<OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends ConsumerState<OfferScreen> {
  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  bool _loadingOffer = true;
  bool _busy = false;
  bool _agreed = false;
  String? _error;

  double _minAmount = 1000;
  double _maxAmount = 50000;
  double _amount = 50000;
  int _minTerm = 1;
  int _maxTerm = 12;
  int _term = 12;
  double _interestRate = 0;
  String? _offerId;
  double _emi = 0;
  double _interestAmount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOffer());
  }

  Future<void> _loadOffer() async {
    setState(() {
      _loadingOffer = true;
      _error = null;
    });
    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId = (await storage.read(
        StorageKeys.customerId,
      ))?.replaceAll('"', '');
      if (customerId == null || customerId.isEmpty) {
        setState(() {
          _loadingOffer = false;
          _error = 'Missing customer id — please re-login';
        });
        return;
      }

      final response = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.getCreditDecisionInformation,
            data: {'customer_id': customerId},
            options: Options(contentType: Headers.jsonContentType),
          );

      final row = _offerRow(response.data);
      final status = row?['status']?.toString().toUpperCase();
      if (row == null || status == '403' || status == null) {
        setState(() {
          _loadingOffer = false;
          _error = 'No approved offer found. Pull to retry from Home.';
        });
        return;
      }

      double asDouble(dynamic v, [double fallback = 0]) {
        if (v is num) return v.toDouble();
        return double.tryParse(v?.toString() ?? '') ?? fallback;
      }

      final minAmt = asDouble(row['min_loan_amount'], 1000);
      final maxAmt = asDouble(row['max_loan_amount'], minAmt);
      var minTerm = asDouble(row['min_term'], 1).round().clamp(1, 60);
      var maxTerm = asDouble(
        row['max_term'],
        minTerm.toDouble(),
      ).round().clamp(minTerm, 60);
      // Unlocked offers historically shipped with max_term=3 (NTC default).
      // Product tenure for larger / unlocked amounts is up to 12 months.
      if (maxAmt > 3000 && maxTerm < 12) {
        maxTerm = 12;
        if (minTerm > maxTerm) minTerm = 1;
      }
      final rate = asDouble(row['interest_rate']);
      final pricingId =
          row['customer_pricing_id']?.toString() ??
          row['record_id']?.toString() ??
          '';

      setState(() {
        _minAmount = minAmt;
        _maxAmount = maxAmt < minAmt ? minAmt : maxAmt;
        _amount = _maxAmount;
        _minTerm = minTerm;
        _maxTerm = maxTerm;
        _term = maxTerm;
        _interestRate = rate;
        _offerId = pricingId;
        _loadingOffer = false;
      });
      await _recalcEmi();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingOffer = false;
          _error = 'Could not load offer. Try again.';
        });
      }
    }
  }

  Map<String, dynamic>? _offerRow(dynamic root) {
    if (root is List && root.isNotEmpty && root.first is Map) {
      return Map<String, dynamic>.from(root.first as Map);
    }
    if (root is Map) {
      final data = root['data'];
      if (data is List && data.isNotEmpty && data.first is Map) {
        return Map<String, dynamic>.from(data.first as Map);
      }
      return Map<String, dynamic>.from(root);
    }
    return null;
  }

  Future<void> _recalcEmi() async {
    final amount = _amount.round();
    final term = _term;
    final roi = _interestRate.round();
    if (amount <= 0 || term <= 0) return;

    try {
      final response = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.calculateEmi,
            data: {'tenor': term, 'loan_amount': amount, 'roi': roi},
            options: Options(contentType: Headers.jsonContentType),
          );
      final data = response.data;
      if (data is Map && (data['Status'] == 200 || data['Status'] == '200')) {
        final emi = data['emi_amount'];
        final emiVal = emi is num
            ? emi.toDouble()
            : double.tryParse(emi?.toString() ?? '') ?? 0;
        if (mounted) {
          setState(() {
            _emi = emiVal;
            _interestAmount = (emiVal * term) - amount;
            if (_interestAmount < 0) _interestAmount = 0;
          });
        }
        return;
      }
    } catch (_) {
      // Fall through to local amortization.
    }

    final local = _localEmi(amount.toDouble(), term, _interestRate);
    if (mounted) {
      setState(() {
        _emi = local;
        _interestAmount = (local * term) - amount;
        if (_interestAmount < 0) _interestAmount = 0;
      });
    }
  }

  double _localEmi(double principal, int tenure, double annualRate) {
    if (tenure <= 0) return 0;
    if (annualRate <= 0) return (principal / tenure).roundToDouble();
    final r = annualRate / (12 * 100);
    final pow = (1 + r);
    var stepTwo = 1.0;
    for (var i = 0; i < tenure; i++) {
      stepTwo *= pow;
    }
    final emi = (principal * r * stepTwo) / (stepTwo - 1);
    return emi.roundToDouble();
  }

  Future<({double lat, double lng})> _location() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (lat: 0.0, lng: 0.0);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return (lat: 0.0, lng: 0.0);
    }
  }

  Future<void> _apply() async {
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept legal agreements')),
      );
      return;
    }
    if (_offerId == null || _offerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing offer id — reload offer')),
      );
      return;
    }

    setState(() => _busy = true);
    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId = (await storage.read(
        StorageKeys.customerId,
      ))?.replaceAll('"', '');
      final userType =
          (await storage.read(StorageKeys.userType))?.replaceAll('"', '') ?? '';
      final deviceImei = await ref
          .read(deviceIdServiceProvider)
          .getHardwareImei();
      final loc = await _location();

      // RN newOfferDetailsPl → StoreFinalOfferSelection
      final response = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.storeFinalOfferSelection,
            data: {
              'offer_id': _offerId,
              'sf_app_record_id': null,
              'loan_amount': _amount.round(),
              'interest_rate': _interestRate,
              'term': _term,
              'customer_id': customerId,
              'latitude': loc.lat,
              'longitude': loc.lng,
              'partner_id': '',
              'device_imei': deviceImei,
            },
            options: Options(contentType: Headers.jsonContentType),
          );

      // API rejects with HTTP 200 + {status: 403, msg: ...}. Marking the offer
      // stage complete here would strand the customer on a loan that was never
      // created, so surface the message and stay put.
      final body = response.data;
      final status = body is Map ? body['status'] : null;
      if (status == 403 ||
          status == '403' ||
          (body is Map && body['error'] != null)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                (body is Map ? body['msg']?.toString() : null) ??
                    'Could not accept offer',
              ),
            ),
          );
        }
        return;
      }

      if (userType.toLowerCase() == 'student') {
        await ref.read(screenStatusServiceProvider).completePl();
      } else {
        await ref.read(screenStatusServiceProvider).completeDc();
      }

      if (!mounted) return;
      ref.read(homeRefreshTickProvider.notifier).state++;

      // A new contract always needs a mandate sized for its selected EMI.
      // Reuse KYC only when the closure reset retained a still-valid KYC flag.
      var kycValid = false;
      try {
        final bundle = await ref.read(homeRepositoryProvider).fetchHomeBundle();
        kycValid = bundle.flags.ocr || bundle.flags.vkyc;
      } catch (_) {
        // Fail closed: KYC can be completed again if freshness is unknown.
      }
      if (!mounted) return;
      context.go(kycValid ? AppRoutes.enach : AppRoutes.dkyc);
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map
          ? (data['msg'] ?? data['message'])?.toString()
          : null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg ?? 'Could not accept offer')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not accept offer')));
      }
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  List<int> get _tenures {
    if (_maxTerm < _minTerm) return [_minTerm];
    return [for (var t = _minTerm; t <= _maxTerm; t++) t];
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(globalLoadingProvider) || _busy;

    return FunnelScaffold(
      title: 'Request\nMoney',
      subtitle: _loadingOffer
          ? 'Loading your offer…'
          : 'Choose amount & tenure, then accept legal agreements.',
      showBack: true,
      onBack: () => context.go(AppRoutes.home),
      bottom: ZapSubmitButton(
        title: 'Apply Now',
        disabled: loading || _loadingOffer || _error != null || !_agreed,
        onPressed: _apply,
      ),
      child: _loadingOffer
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(color: AppColors.accentMint),
              ),
            )
          : _error != null
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: AppTypography.body(size: 14, color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  ZapSubmitButton(title: 'Retry', onPressed: _loadOffer),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  'Loan amount',
                  style: AppTypography.body(size: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Text(
                  _currency.format(_amount),
                  style: AppTypography.headline(size: 32),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.accentMint,
                    inactiveTrackColor: const Color(0xFF633AB1),
                    thumbColor: AppColors.accentMint,
                    overlayColor: AppColors.accentMint.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _amount.clamp(_minAmount, _maxAmount),
                    min: _minAmount,
                    max: _maxAmount <= _minAmount ? _minAmount + 1 : _maxAmount,
                    divisions: _maxAmount <= _minAmount
                        ? 1
                        : ((_maxAmount - _minAmount) / 1000).round().clamp(
                            1,
                            100,
                          ),
                    onChanged: (v) {
                      setState(() => _amount = v);
                    },
                    onChangeEnd: (_) => _recalcEmi(),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _currency.format(_minAmount),
                      style: AppTypography.body(
                        size: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    Text(
                      _currency.format(_maxAmount),
                      style: AppTypography.body(
                        size: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // RN `chooseDurationText` + horizontal `durationViewStyle` chips
                Text(
                  'Choose loan duration',
                  style: AppTypography.body(size: 15, color: Colors.white),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 75,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tenures.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final t = _tenures[index];
                      final selected = _term == t;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() => _term = t);
                            _recalcEmi();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 115,
                            height: 75,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3E1982),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? AppColors.accentMint
                                    : Colors.transparent,
                                width: selected ? 1 : 0,
                              ),
                            ),
                            child: Text(
                              t == 1 ? '1 Month' : '$t Months',
                              style: AppTypography.body(
                                size: 15,
                                color: AppColors.accentMint,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                _metricRow(
                  'Interest rate',
                  '${_interestRate.toStringAsFixed(0)}% p.a.',
                ),
                _metricRow('Monthly EMI', _currency.format(_emi)),
                _metricRow('Total interest', _currency.format(_interestAmount)),
                const SizedBox(height: 24),
                InkWell(
                  onTap: () => setState(() => _agreed = !_agreed),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _agreed
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: _agreed ? AppColors.accentMint : Colors.white70,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'I agree with the ',
                              style: AppTypography.body(size: 13),
                            ),
                            GestureDetector(
                              onTap: () => showLegalAgreementSheet(context),
                              child: Text(
                                'Legal agreements',
                                style:
                                    AppTypography.body(
                                      size: 13,
                                      color: AppColors.accentMint,
                                    ).copyWith(
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.accentMint,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.body(size: 14, color: AppColors.muted),
          ),
          Text(
            value,
            style: AppTypography.body(size: 15, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
