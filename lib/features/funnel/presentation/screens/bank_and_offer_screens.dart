import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/services/finarkein_ingest_service.dart';
import '../../../../core/services/screen_status_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../dashboard/data/home_repository.dart';

/// RN bankDetails / bankStatement title: Student → Bank Details, else Salary Account.
String _bankAccountDetailsTitle(String userType) {
  return userType.toLowerCase() == 'student'
      ? 'Bank\nDetails'
      : 'Salary\nAccount\nDetails';
}

/// RN `scenes/bankDetails` — name (read-only), IFSC lookup → bank/branch, account.
class BankDetailsScreen extends ConsumerStatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  ConsumerState<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends ConsumerState<BankDetailsScreen> {
  final _customerName = TextEditingController();
  final _ifsc = TextEditingController();
  final _account = TextEditingController();
  final _bankName = TextEditingController();
  final _branch = TextEditingController();

  bool _lookingUpIfsc = false;
  String? _finbitCode;

  String _userType = 'Salaried';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadCustomerName();
      final type = await ref
          .read(sessionStorageProvider)
          .read(StorageKeys.userType);
      if (mounted) {
        setState(() {
          _userType = (type ?? 'Salaried').replaceAll('"', '');
        });
      }
    });
  }

  @override
  void dispose() {
    _customerName.dispose();
    _ifsc.dispose();
    _account.dispose();
    _bankName.dispose();
    _branch.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _customerName.text.trim().isNotEmpty &&
        _ifsc.text.trim().length == 11 &&
        _account.text.trim().length >= 8 &&
        _bankName.text.trim().isNotEmpty &&
        _branch.text.trim().isNotEmpty;
  }

  Future<void> _loadCustomerName() async {
    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId = (await storage.read(
        StorageKeys.customerId,
      ))?.replaceAll('"', '');
      if (customerId == null || customerId.isEmpty) return;

      final response = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.getCustomerInfo,
            data: {'customer_id': customerId},
            options: Options(contentType: Headers.jsonContentType),
          );
      final root = response.data;
      // RN: response.data[0].first_name / last_name
      Map<String, dynamic>? row;
      if (root is List && root.isNotEmpty && root.first is Map) {
        row = Map<String, dynamic>.from(root.first as Map);
      } else if (root is Map) {
        final data = root['data'];
        if (data is List && data.isNotEmpty && data.first is Map) {
          row = Map<String, dynamic>.from(data.first as Map);
        } else if (data is Map) {
          row = Map<String, dynamic>.from(data);
        } else {
          row = Map<String, dynamic>.from(root);
        }
      }
      if (row == null) return;
      final first =
          row['first_name']?.toString() ?? row['firstName']?.toString() ?? '';
      final last =
          row['last_name']?.toString() ?? row['lastName']?.toString() ?? '';
      final name = '$first $last'.trim();
      if (name.isNotEmpty && mounted) {
        setState(() => _customerName.text = name.toUpperCase());
      }
    } catch (_) {
      // Name stays empty; user still sees the field.
    }
  }

  Future<void> _onIfscChanged(String raw) async {
    final value = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (value != _ifsc.text) {
      _ifsc.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    setState(() {});

    if (value.length != 11) {
      setState(() {
        _bankName.clear();
        _branch.clear();
        _finbitCode = null;
      });
      return;
    }

    setState(() => _lookingUpIfsc = true);
    try {
      final response = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.getIfscInfo,
            data: {'ifsc': value},
            options: Options(contentType: Headers.jsonContentType),
          );
      final data = response.data;
      final list = data is Map ? data['ResponseData'] : null;
      if (list is List && list.isNotEmpty && list.first is Map) {
        final row = Map<String, dynamic>.from(list.first as Map);
        setState(() {
          _bankName.text = row['bankname']?.toString() ?? '';
          _branch.text = row['branch']?.toString() ?? '';
          _finbitCode = row['FINBITCODE']?.toString();
        });
      } else {
        setState(() {
          _bankName.clear();
          _branch.clear();
          _finbitCode = null;
        });
        _toast('Invalid IFSC code');
      }
    } catch (_) {
      setState(() {
        _bankName.clear();
        _branch.clear();
      });
      _toast('Could not look up IFSC');
    } finally {
      if (mounted) setState(() => _lookingUpIfsc = false);
    }
  }

  Future<void> _submit() async {
    final ifsc = _ifsc.text.trim().toUpperCase();
    final account = _account.text.trim();
    final bank = _bankName.text.trim();
    final branch = _branch.text.trim();
    final name = _customerName.text.trim();

    if (ifsc.length < 11) {
      _toast('Please enter ifsc code');
      return;
    }
    if (account.length < 9) {
      _toast('Please enter account number');
      return;
    }
    if (bank.isEmpty) {
      _toast('Please enter bank name');
      return;
    }
    if (branch.isEmpty) {
      _toast('Please enter branch');
      return;
    }
    if (name.isEmpty) {
      _toast('Customer name missing');
      return;
    }

    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId = (await storage.read(
        StorageKeys.customerId,
      ))?.replaceAll('"', '');
      final deviceId = (await storage.read(
        StorageKeys.deviceId,
      ))?.replaceAll('"', '');

      // StoreBankInfo overwrites Enach_Amount with request value (null if
      // omitted) — preserve any amount already set after offer origination.
      String? existingEnachAmount;
      try {
        final bankRes = await ref
            .read(dioClientProvider)
            .dio
            .post(
              ApiEndpoints.getBankAccountInformation,
              data: {
                'customer_id': int.tryParse(customerId ?? '') ?? customerId,
              },
              options: Options(contentType: Headers.jsonContentType),
            );
        final bankData = bankRes.data;
        Map? row;
        if (bankData is List && bankData.isNotEmpty && bankData.first is Map) {
          row = bankData.first as Map;
        }
        final rawAmt = row?['enach_amount'];
        final parsed = rawAmt == null
            ? null
            : double.tryParse(rawAmt.toString());
        if (parsed != null && parsed > 0) {
          existingEnachAmount = parsed.toString();
        }
      } catch (_) {}

      // RN getBankDetails → StoreBankInfo (Bearer via useBearer)
      final response = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.storeBankInfo,
            data: {
              'deviceId': deviceId,
              'customer_name': name,
              'customer_id': int.tryParse(customerId ?? '') ?? customerId,
              'sf_record_id': '',
              'ifsc_code': ifsc,
              'bank_account_number': account,
              'bank_name': bank,
              'branch_name': branch,
              if (existingEnachAmount != null)
                'enach_amount': existingEnachAmount,
            },
            options: Options(
              contentType: Headers.jsonContentType,
              extra: {'useBearer': true},
            ),
          );

      final data = response.data;
      final status = data is Map ? data['status'] : null;
      if (status != 200 && status != '200') {
        final msg = data is Map
            ? (data['msg'] ?? data['message'])?.toString()
            : null;
        _toast(msg ?? 'Could not save bank details');
        return;
      }

      await ref.read(screenStatusServiceProvider).completeBank();
      if (!mounted) return;
      // RN → ScreenName.bankStatement (title depends on Student vs Salaried)
      context.go(
        AppRoutes.bankStatement,
        extra: {'bankcode': _finbitCode, 'bankName': bank},
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map
          ? (data['msg'] ?? data['message'])?.toString()
          : null;
      _toast(msg ?? 'Bank account could not be verified. Please try again.');
    } catch (_) {
      _toast('Could not save bank details');
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(globalLoadingProvider);

    return FunnelScaffold(
      title: _bankAccountDetailsTitle(_userType),
      totalSteps: 3,
      activeStep: 2,
      heroAsset: 'assets/images/bankdoc.png',
      heroHeight: 110,
      bottom: ZapSubmitButton(
        title: 'Submit',
        disabled: !_canSubmit || loading || _lookingUpIfsc,
        onPressed: _submit,
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _label('Name as per Bank Account*'),
          _field(_customerName, 'Enter Name', readOnly: true, muted: true),
          const SizedBox(height: 16),
          _label('Bank IFSC Code*'),
          _field(
            _ifsc,
            'Enter IFSC Code',
            maxLength: 11,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(11),
            ],
            onChanged: _onIfscChanged,
            suffix: _lookingUpIfsc
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          _label('Account Number*'),
          _field(
            _account,
            'Enter Account Number',
            keyboard: TextInputType.number,
            maxLength: 30,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _label('Bank Name*'),
          _field(_bankName, 'Enter Bank Name', readOnly: true, muted: true),
          const SizedBox(height: 16),
          _label('Bank Branch*'),
          _field(_branch, 'Enter Branch', readOnly: true, muted: true),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTypography.body(size: 12, color: AppColors.muted),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint, {
    TextInputType keyboard = TextInputType.text,
    bool readOnly = false,
    bool muted = false,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    return TextField(
      controller: c,
      readOnly: readOnly,
      enableInteractiveSelection: !readOnly,
      keyboardType: keyboard,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      cursorColor: Colors.white,
      style: AppTypography.body(
        size: 16,
        color: muted ? AppColors.muted : AppColors.white,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: AppTypography.body(size: 16, color: AppColors.muted),
        filled: true,
        fillColor: const Color(0xFF2A0A5C),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}


class BankStatementScreen extends ConsumerStatefulWidget {
  const BankStatementScreen({super.key, this.args});

  final Map<String, dynamic>? args;

  @override
  ConsumerState<BankStatementScreen> createState() =>
      _BankStatementScreenState();
}

class _BankStatementScreenState extends ConsumerState<BankStatementScreen> {
  String? get _bankName {
    final args = widget.args;
    if (args == null) return null;
    return args['bankName']?.toString() ??
        (args['bankDetails'] is Map
            ? (args['bankDetails'] as Map)['bankName']?.toString()
            : null);
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'Account\nAggregator',
      totalSteps: 3,
      activeStep: 2,
      heroAsset: 'assets/images/bankdoc.png',
      heroHeight: 110,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (_bankName != null && _bankName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _bankName!,
                style: AppTypography.body(size: 13, color: AppColors.muted),
              ),
            ),
          Text(
            'Validate your bank account via Account Aggregator',
            style: AppTypography.body(size: 13),
          ),
          const SizedBox(height: 16),
          ZapSubmitButton(
            title: 'Continue with Account Aggregator',
            onPressed: () {
              context.push(
                AppRoutes.finbit,
                extra: {
                  'bankDetails': {
                    'bankName': _bankName,
                  },
                  'bankName': _bankName,
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Finarkein AA consent journey (replaces Finbit WebView accountUID bridge).
class FinbitScreen extends ConsumerStatefulWidget {
  const FinbitScreen({super.key, this.args});

  final Map<String, dynamic>? args;

  @override
  ConsumerState<FinbitScreen> createState() => _FinbitScreenState();
}

class _FinbitScreenState extends ConsumerState<FinbitScreen> {
  bool _webviewVisible = false;
  String? _requestId;
  WebViewController? _controller;
  var _consentReturnHandled = false;
  var _sawConsentReturn = false;

  /// Finarkein post-consent landing (thank-you) or our custom return URL.
  bool _isConsentReturnUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('thank-you') ||
        lower.contains('/o/thank') ||
        lower.contains('finarkein-return') ||
        lower.contains('thankyou') ||
        // Local Finarkein mock — no real AA WebView journey.
        lower.contains('mock=1') ||
        lower.contains('/mock/') ||
        // Finarkein UAT thank-you host paths
        (lower.contains('fnrk.in') && lower.contains('thank'));
  }

  bool _isMockFinarkeinRun(String? requestId, String? redirectUrl) {
    final id = (requestId ?? '').toLowerCase();
    if (id.startsWith('mock-')) return true;
    final lower = (redirectUrl ?? '').toLowerCase();
    return lower.contains('mock=1') || lower.contains('/mock/');
  }

  void _handleConsentReturnUrl(String? url) {
    if (!_isConsentReturnUrl(url)) return;
    _sawConsentReturn = true;
    unawaited(_onConsentReturned());
  }

  /// Advance to Residence only after Finarkein reports consent approved.
  /// Thank-you URL / “I finished” are hints — never sufficient alone.
  Future<void> _onConsentReturned() async {
    if (_consentReturnHandled) return;
    _consentReturnHandled = true;
    final requestId = _requestId;
    if (!mounted) return;
    setState(() => _webviewVisible = false);

    if (requestId == null || requestId.isEmpty) {
      _consentReturnHandled = false;
      _toast('Bank validation is not complete. Please try again.');
      return;
    }

    final ingest = ref.read(finarkeinIngestServiceProvider);
    ref.read(globalLoadingProvider.notifier).state = true;
    var approved = false;
    try {
      approved = await ingest.waitUntilConsentApproved(requestId: requestId);
    } finally {
      if (mounted) {
        ref.read(globalLoadingProvider.notifier).state = false;
      }
    }

    if (!approved) {
      // Allow retry — user may still be on OTP or abandoned mid-journey.
      _consentReturnHandled = false;
      _sawConsentReturn = false;
      if (!mounted) return;
      _toast(
        'Consent not completed yet. Open bank validation again after approving.',
      );
      return;
    }

    _sawConsentReturn = true;
    // Consent approved — ingest continues in background while user fills residence.
    try {
      await ref.read(screenStatusServiceProvider).completeBank();
    } catch (_) {}
    ingest.startBackground(requestId);
    if (!mounted) return;
    context.go(AppRoutes.residenceAddress);
  }

  /// AppBar / system back: if thank-you already hit, verify consent then
  /// continue; otherwise only close the WebView (no Residence advance).
  Future<void> _onWebViewBack() async {
    if (_consentReturnHandled) return;
    if (_sawConsentReturn) {
      await _onConsentReturned();
      return;
    }
    try {
      final current = await _controller?.currentUrl();
      if (_isConsentReturnUrl(current)) {
        await _onConsentReturned();
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _webviewVisible = false);
  }

  Future<void> _openFinarkein() async {
    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId = (await storage.read(
        StorageKeys.customerId,
      ))?.replaceAll('"', '');
      final response = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.finarkeinConsentInitiate,
            data: {
              if (customerId != null && customerId.isNotEmpty)
                'customer_id': int.tryParse(customerId) ?? customerId,
            },
            options: Options(
              contentType: Headers.jsonContentType,
              extra: {'useBearer': true},
            ),
          );
      final root = response.data;
      Map? payload;
      if (root is Map) {
        final resp = root['response'];
        payload = resp is Map ? resp : root;
      }
      final requestId = payload?['request_id']?.toString();
      final redirectUrl = payload?['redirect_url']?.toString();
      if (requestId == null ||
          requestId.isEmpty ||
          redirectUrl == null ||
          redirectUrl.isEmpty) {
        _toast('Could not start bank validation. Please try again.');
        return;
      }
      _consentReturnHandled = false;
      _sawConsentReturn = false;
      _requestId = requestId;
      unawaited(
        ref.read(finarkeinIngestServiceProvider).persistRequestId(requestId),
      );

      // Mock / already-on-return URL: skip blank WebView and continue funnel.
      if (_isMockFinarkeinRun(requestId, redirectUrl)) {
        await _onConsentReturned();
        return;
      }

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              if (_isConsentReturnUrl(request.url)) {
                _sawConsentReturn = true;
                unawaited(_onConsentReturned());
                // Stay in-app; no need to render Finarkein thank-you.
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
            onUrlChange: (change) {
              _handleConsentReturnUrl(change.url);
            },
            onPageStarted: _handleConsentReturnUrl,
            onPageFinished: _handleConsentReturnUrl,
          ),
        )
        ..loadRequest(Uri.parse(redirectUrl));
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _webviewVisible = true;
      });
      return;
    } on DioException catch (e) {
      final data = e.response?.data;
      final err = data is Map
          ? (data['message'] ?? data['msg'] ?? data['error'])?.toString()
          : null;
      _toast(err ?? 'Could not start bank validation. Please try again.');
    } catch (_) {
      _toast('Could not start bank validation. Please try again.');
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final verifyingConsent = ref.watch(globalLoadingProvider);

    if (_webviewVisible && _controller != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_onWebViewBack());
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => unawaited(_onWebViewBack()),
            ),
            title: Text(
              'Bank validation',
              style: AppTypography.headline(
                size: 16,
              ).copyWith(color: Colors.black),
            ),
          ),
          body: WebViewWidget(controller: _controller!),
        ),
      );
    }

    final hasStartedAa = _requestId != null && _requestId!.isNotEmpty;

    return FunnelScaffold(
      title: 'Bank account\nValidation',
      showBack: true,
      totalSteps: 3,
      activeStep: 3,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              Text(
                'Use Account Aggregator',
                style: AppTypography.headline(size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                'Securely share your bank statement data\nto validate your account',
                style: AppTypography.body(size: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 260,
                  child: ZapSubmitButton(
                    title: hasStartedAa
                        ? 'Open bank validation again'
                        : 'Continue',
                    disabled: verifyingConsent,
                    onPressed: _openFinarkein,
                  ),
                ),
              ),
              if (hasStartedAa) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 260,
                    child: OutlinedButton(
                      onPressed: verifyingConsent
                          ? null
                          : () => unawaited(_onConsentReturned()),
                      child: const Text('I finished — continue'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'After you approve consent in the bank screen, you move to address automatically. If the screen stays here, finish consent first, then tap “I finished — continue”.',
                  style: AppTypography.body(size: 11, color: AppColors.muted),
                ),
              ],
            ],
          ),
          if (verifyingConsent)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class ResidenceAddressScreen extends ConsumerStatefulWidget {
  const ResidenceAddressScreen({super.key});

  @override
  ConsumerState<ResidenceAddressScreen> createState() =>
      _ResidenceAddressScreenState();
}

class _ResidenceAddressScreenState
    extends ConsumerState<ResidenceAddressScreen> {
  final _address = TextEditingController();
  final _postal = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _locality = TextEditingController();
  final _sublocality = TextEditingController();
  bool _lookingUpPin = false;

  @override
  void dispose() {
    _address.dispose();
    _postal.dispose();
    _city.dispose();
    _state.dispose();
    _locality.dispose();
    _sublocality.dispose();
    super.dispose();
  }

  Future<void> _onPostalChanged(String raw) async {
    final pin = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (pin != _postal.text) {
      _postal.value = TextEditingValue(
        text: pin,
        selection: TextSelection.collapsed(offset: pin.length),
      );
    }
    if (pin.length != 6) return;
    setState(() => _lookingUpPin = true);
    try {
      // RN getAutoFillAddress → monexo addressAutofill/getCity
      final cityRes = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.fetchCity,
            data: FormData.fromMap({'pincode': pin}),
          );
      final cityRoot = cityRes.data;
      if (cityRoot is Map && cityRoot['status_code'] == 200) {
        final result = cityRoot['result'];
        final data = result is Map ? result['data'] : null;
        if (data is Map) {
          final city = data['city']?.toString() ?? '';
          if (city.isNotEmpty) _city.text = city;
        }
      }

      // RN getLocality → first locality as default
      final locRes = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.getLocalities,
            data: {'pincode': pin},
            options: Options(contentType: Headers.jsonContentType),
          );
      final locRoot = locRes.data;
      if (locRoot is Map && locRoot['status_code'] == 200) {
        final result = locRoot['result'];
        final list = result is Map ? result['locality'] : null;
        if (list is List && list.isNotEmpty) {
          final first = list.first.toString();
          if (first.isNotEmpty) {
            _locality.text = first;
            final subRes = await ref
                .read(dioClientProvider)
                .dio
                .post(
                  ApiEndpoints.getSubLocalities,
                  data: {'pincode': pin, 'locality': first},
                  options: Options(contentType: Headers.jsonContentType),
                );
            final subRoot = subRes.data;
            if (subRoot is Map && subRoot['status_code'] == 200) {
              final subResult = subRoot['result'];
              final subs = subResult is Map ? subResult['sublocality'] : null;
              if (subs is List && subs.isNotEmpty) {
                _sublocality.text = subs.first.toString();
              }
            }
          }
        }
      }

      // data.gov postal → state (same source RN verifyPostalCode uses)
      try {
        final gov = await ref
            .read(dioClientProvider)
            .dio
            .get(
              'https://api.data.gov.in/resource/0a076478-3fd3-4e2c-b2d2-581876f56d77',
              queryParameters: {
                'format': 'json',
                'api-key':
                    '579b464db66ec23bdd000001be9925f848ef448249d6231c74b87637',
                'filters[pincode]': pin,
              },
              options: Options(
                extra: {'clearHeader': true},
                contentType: Headers.jsonContentType,
              ),
            );
        final govRoot = gov.data;
        if (govRoot is Map && govRoot['status']?.toString() == 'ok') {
          final records = govRoot['records'];
          if (records is Map && records.isNotEmpty) {
            final first = records.values.first;
            if (first is Map) {
              final stateName = first['statename']?.toString() ?? '';
              final region = first['regionname']?.toString() ?? '';
              if (stateName.isNotEmpty) _state.text = stateName;
              if (_city.text.trim().isEmpty && region.isNotEmpty) {
                _city.text = region;
              }
            }
          } else if (records is List &&
              records.isNotEmpty &&
              records.first is Map) {
            final first = Map<String, dynamic>.from(records.first as Map);
            final stateName = first['statename']?.toString() ?? '';
            final region = first['regionname']?.toString() ?? '';
            if (stateName.isNotEmpty) _state.text = stateName;
            if (_city.text.trim().isEmpty && region.isNotEmpty) {
              _city.text = region;
            }
          }
        }
      } catch (_) {
        // Optional enrichment — city/locality from Django is enough to submit.
      }
    } catch (_) {
      // User can still fill city/state manually.
    } finally {
      if (mounted) setState(() => _lookingUpPin = false);
    }
  }

  Future<void> _submit() async {
    final address = _address.text.trim();
    final postal = _postal.text.trim();
    final city = _city.text.trim();
    final state = _state.text.trim();
    final locality = _locality.text.trim();
    final sublocality = _sublocality.text.trim();

    if (address.isEmpty || postal.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter address and 6-digit pincode')),
      );
      return;
    }
    if (city.isEmpty || state.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter city and state')));
      return;
    }

    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId = (await storage.read(
        StorageKeys.customerId,
      ))?.replaceAll('"', '');
      if (customerId == null || customerId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing customer id — please re-login'),
          ),
        );
        return;
      }

      // RN StoreAddressInfo payload (postal, not pincode).
      final response = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.storeAddressInfo,
            data: {
              'city': city,
              'state': state,
              'address': address,
              'localities': locality.isEmpty ? city : locality,
              'sublocalitie': sublocality.isEmpty ? locality : sublocality,
              'customer_id': customerId,
              'postal': postal,
            },
            options: Options(contentType: Headers.jsonContentType),
          );

      final data = response.data;
      final status = data is Map ? data['status'] : null;
      final msg = data is Map ? data['msg']?.toString() : null;
      // 200 = saved; 403 + "already exist" = ok to continue funnel.
      final already =
          msg != null && msg.toLowerCase().contains('already exist');
      if (status != 200 && status != '200' && !already) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg ?? 'Could not save address')),
        );
        return;
      }

      await ref.read(screenStatusServiceProvider).completeAddress();
      // RN ResidenceAddress focus marks bankdetails_verified.
      await ref.read(screenStatusServiceProvider).completeBankVerified();
      // First-time: employer after residence, then Waiting.
      // Repeat loan already collected employer before bank/AA — skip the
      // second Employer details prompt and go straight to credit decision.
      var employerDone = false;
      try {
        final bundle = await ref
            .read(homeRepositoryProvider)
            .fetchHomeBundle();
        employerDone = bundle.flags.employerDetails;
      } catch (_) {
        // Fall through to employer when flags cannot be loaded.
      }
      if (mounted) {
        if (employerDone) {
          context.go(AppRoutes.waiting);
        } else {
          context.go(
            AppRoutes.employerDetails,
            extra: const {'isFrom': 'postResidence'},
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not save address')));
      }
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTypography.body(size: 12, color: AppColors.muted),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboard,
    int? maxLength,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboard,
      onChanged: onChanged,
      cursorColor: Colors.white,
      style: AppTypography.body(size: 16),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: AppTypography.body(size: 16, color: AppColors.muted),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'Residence Address',
      bottom: ZapSubmitButton(
        title: 'Continue',
        disabled: _lookingUpPin,
        onPressed: _submit,
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _label('Full Address*'),
          _field(controller: _address, hint: 'Enter full address', maxLines: 3),
          const SizedBox(height: 16),
          _label('Pincode*'),
          _field(
            controller: _postal,
            hint: 'Enter pincode',
            keyboard: TextInputType.number,
            maxLength: 6,
            onChanged: _onPostalChanged,
            suffix: _lookingUpPin
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          _label('City*'),
          _field(controller: _city, hint: 'Enter city'),
          const SizedBox(height: 16),
          _label('State*'),
          _field(controller: _state, hint: 'Enter state'),
          const SizedBox(height: 16),
          _label('Locality'),
          _field(controller: _locality, hint: 'Enter locality'),
          const SizedBox(height: 16),
          _label('Sublocality'),
          _field(controller: _sublocality, hint: 'Enter sublocality'),
        ],
      ),
    );
  }
}

class WaitingScreen extends ConsumerStatefulWidget {
  const WaitingScreen({super.key, this.isTopUp = false});

  /// Re-apply after a repaid loan: an approved decision leads to the offer
  /// screen, not back to Home where the customer started.
  final bool isTopUp;

  @override
  ConsumerState<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends ConsumerState<WaitingScreen> {
  String? _error;
  bool _running = false;
  bool _repeatLoan = false;
  /// Shown under the title while polling / running CD.
  String _statusMessage = 'We are preparing your credit decision…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Map<String, dynamic>? _offerRow(dynamic root) {
    if (root is List && root.isNotEmpty && root.first is Map) {
      return Map<String, dynamic>.from(root.first as Map);
    }
    if (root is Map) {
      // CD error body: {error, msg, status: 403} — not an offer row.
      final status = root['status'];
      if (status == 403 || status == '403' || root.containsKey('error')) {
        return Map<String, dynamic>.from(root);
      }
      final data = root['data'];
      if (data is List && data.isNotEmpty && data.first is Map) {
        return Map<String, dynamic>.from(data.first as Map);
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return Map<String, dynamic>.from(root);
    }
    return null;
  }

  bool _navigateForStatus(String? status) {
    final s = status?.toUpperCase();
    if (s == 'APP') {
      ref.read(homeRefreshTickProvider.notifier).state++;
      context.go(_repeatLoan ? AppRoutes.offer : AppRoutes.home);
      return true;
    }
    if (s == 'REJ') {
      context.go(AppRoutes.rejected);
      return true;
    }
    if (s == 'REF' || s == 'WIP') {
      context.go(AppRoutes.referred, extra: {'status': s});
      return true;
    }
    return false;
  }

  Future<String?> _fetchExistingOfferStatus(String customerId) async {
    try {
      final response = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.getCreditDecisionInformation,
            data: {'customer_id': customerId},
            options: Options(contentType: Headers.jsonContentType),
          );
      final row = _offerRow(response.data);
      final status = row?['status']?.toString();
      if (status == '403' || status == null) return null;
      return status;
    } catch (_) {
      return null;
    }
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
      _statusMessage = 'We are preparing your credit decision…';
    });

    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId = (await storage.read(
        StorageKeys.customerId,
      ))?.replaceAll('"', '');
      if (customerId == null || customerId.isEmpty) {
        setState(() => _error = 'Missing customer id — please re-login');
        return;
      }

      _repeatLoan = widget.isTopUp;
      if (!_repeatLoan) {
        try {
          final bundle = await ref
              .read(homeRepositoryProvider)
              .fetchHomeBundle();
          _repeatLoan = bundle.home.topUpEligible && bundle.home.loanCompleted;
        } catch (_) {
          // Continue with the explicit route flag when Home is unavailable.
        }
      }

      // AA consent may finish before Finarkein ingest. If we have a run id,
      // do not call CD until READY — otherwise CD creates REF (manager review).
      // Keep the wait short for UX; Retry if still processing (background sync
      // already ran during residence + employer).
      final ingest = ref.read(finarkeinIngestServiceProvider);
      final finarkeinRequestId = await ingest.readRequestId();
      if (finarkeinRequestId != null && finarkeinRequestId.isNotEmpty) {
        if (mounted) {
          setState(
            () => _statusMessage = 'Confirming your bank data…',
          );
        }
        bool ready = false;
        try {
          ready = await ingest.waitUntilReady(
            requestId: finarkeinRequestId,
            maxWait: const Duration(seconds: 60),
            interval: const Duration(seconds: 5),
          );
        } catch (_) {
          ready = false;
        }
        if (!ready) {
          if (!mounted) return;
          setState(
            () => _error =
                'Your bank data is still processing. Tap Retry in a moment — we will not run a decision until it is ready.',
          );
          return;
        }
      }

      if (mounted) {
        setState(
          () => _statusMessage = 'We are running your credit decision…',
        );
      }

      // CD can sleep ~30s waiting for Finbit name-match; allow retries.
      const attempts = 5;
      String? lastDetail;

      for (var i = 0; i < attempts; i++) {
        try {
          final response = await ref
              .read(dioClientProvider)
              .dio
              .post(
                ApiEndpoints.creditDecision,
                data: {'cust_id': customerId},
                options: Options(
                  contentType: Headers.jsonContentType,
                  sendTimeout: const Duration(minutes: 2),
                  receiveTimeout: const Duration(minutes: 2),
                ),
              );
          if (!mounted) return;

          final row = _offerRow(response.data);
          final statusRaw = row?['status'];
          final status = statusRaw?.toString().toUpperCase();

          // Backend exception path returns JSON status 403 (often HTTP 200).
          if (status == '403' || row?['error'] != null) {
            final msg = row?['msg']?.toString();
            lastDetail = msg ?? 'Credit decision failed on server';
            // Offer may already exist from a prior run — check before giving up.
            final existing = await _fetchExistingOfferStatus(customerId);
            if (!mounted) return;
            if (existing != null && _navigateForStatus(existing)) return;
            if (i < attempts - 1) {
              await Future<void>.delayed(const Duration(seconds: 8));
              continue;
            }
            setState(() => _error = lastDetail);
            return;
          }

          if (_navigateForStatus(status)) return;

          // Unknown / empty — Finbit may still be processing.
          lastDetail = status == null || status.isEmpty
              ? 'Decision not ready yet'
              : 'Decision pending ($status)';
          final existing = await _fetchExistingOfferStatus(customerId);
          if (!mounted) return;
          if (existing != null && _navigateForStatus(existing)) return;

          if (i < attempts - 1) {
            await Future<void>.delayed(const Duration(seconds: 8));
            continue;
          }
          setState(
            () => _error =
                '$lastDetail. Finbit/bureau data may still be processing — retry shortly.',
          );
        } on DioException catch (e) {
          lastDetail = e.message ?? 'Network error';
          final existing = await _fetchExistingOfferStatus(customerId);
          if (!mounted) return;
          if (existing != null && _navigateForStatus(existing)) return;
          if (i < attempts - 1) {
            await Future<void>.delayed(const Duration(seconds: 8));
            continue;
          }
          setState(
            () => _error =
                'Could not run credit decision (${e.response?.statusCode ?? e.type}). Try again.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not run credit decision. Try again.');
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'Hang tight',
      subtitle: _error == null
          ? _statusMessage
          : 'Credit decision needs another try',
      showBack: false,
      bottom: _error == null
          ? null
          : ZapSubmitButton(
              title: 'Retry',
              disabled: _running,
              onPressed: _run,
            ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _error == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.accentMint,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                        size: 14,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                )
              : Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(size: 14, color: AppColors.muted),
                ),
        ),
      ),
    );
  }
}

class RejectedScreen extends StatelessWidget {
  const RejectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'Application update',
      showBack: false,
      bottom: ZapSubmitButton(
        title: 'Back to home',
        onPressed: () => context.go(AppRoutes.home),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'We are unable to offer a loan at this time. You can re-apply later.',
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 15),
          ),
        ),
      ),
    );
  }
}
