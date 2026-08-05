import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/services/screen_status_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

/// RN `scenes/equifaxReport` — calls `/validatescore` with `{ cust_id }`.
class EquifaxScreen extends ConsumerStatefulWidget {
  const EquifaxScreen({super.key});

  @override
  ConsumerState<EquifaxScreen> createState() => _EquifaxScreenState();
}

class _EquifaxScreenState extends ConsumerState<EquifaxScreen> {
  bool _loading = true;
  String? _error;
  int? _score;
  String? _userName;
  String? _loanAmount;
  String? _message;
  String _userType = 'Salaried';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
      _score = null;
    });
    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId =
          (await storage.read(StorageKeys.customerId))?.replaceAll('"', '');
      final deviceId =
          (await storage.read(StorageKeys.deviceId))?.replaceAll('"', '');
      _userType =
          (await storage.read(StorageKeys.userType))?.replaceAll('"', '') ??
              'Salaried';

      if (customerId == null || customerId.isEmpty) {
        setState(() {
          _loading = false;
          _error =
              'Missing customer id. Go back and complete personal information.';
        });
        return;
      }

      final dio = ref.read(dioClientProvider).dio;

      // RN fires PRFIL enrichment fire-and-forget; never blocks PCRLT.
      // ignore: unawaited_futures
      dio
          .post(
            ApiEndpoints.pullEquifaxProfile,
            data: {
              'custid': customerId,
              'deviceId': deviceId,
            },
            options: Options(
              contentType: Headers.jsonContentType,
              extra: {'useBearer': true},
            ),
          )
          .then((_) {}, onError: (_) {});

      // RN equifax screen uses validatescore({ cust_id }), not pullCreditBureau.
      final response = await dio.post(
        ApiEndpoints.validatescore,
        data: {'cust_id': customerId},
        options: Options(contentType: Headers.jsonContentType),
      );

      final data = response.data;
      if (kDebugMode) {
        debugPrint('validatescore → $data');
      }

      if (data is! Map) {
        throw StateError('Unexpected validatescore response');
      }

      final status = data['status'];
      if (status != 200 && status != '200') {
        final msg = data['msg']?.toString() ??
            data['message']?.toString() ??
            'Could not fetch credit report';
        setState(() {
          _loading = false;
          _error = msg;
        });
        return;
      }

      final payload = data['data'];
      final responseBlock = data['response'];
      int? score;
      String? first;
      String? last;
      String? loan;
      String? message;

      if (payload is Map) {
        score = _asInt(payload['score']);
        first = payload['first_name']?.toString();
        last = payload['last_name']?.toString();
        loan = payload['loan_amouunt']?.toString() ??
            payload['loan_amount']?.toString();
      }
      if (responseBlock is Map) {
        score ??= _asInt(responseBlock['score']);
        message = responseBlock['message']?.toString();
      }

      await ref.read(screenStatusServiceProvider).completeEquifax();

      if (!mounted) return;
      setState(() {
        _loading = false;
        _score = score ?? 0;
        _userName = '${first ?? ''} ${last ?? ''}'.trim();
        _loanAmount = loan;
        _message = message;
      });
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'validatescore DioException http=${e.response?.statusCode} '
          'data=${e.response?.data}',
        );
      }
      if (!mounted) return;
      final data = e.response?.data;
      final msg = data is Map
          ? (data['msg'] ?? data['message'])?.toString()
          : null;
      setState(() {
        _loading = false;
        _error = msg ??
            (e.response?.statusCode != null
                ? 'Credit check failed (HTTP ${e.response!.statusCode})'
                : 'Could not fetch credit report. Tap retry.');
      });
    } catch (e) {
      if (kDebugMode) debugPrint('validatescore error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not fetch credit report. Tap retry.';
      });
    }
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  void _continue() {
    // RN: credit score → location permission → bank (salaried) / college (student).
    context.go(AppRoutes.locationPermission);
  }

  Color get _scoreColor {
    final s = _score ?? 0;
    if (s <= 299) return AppColors.accentMint;
    if (s <= 599) return const Color(0xFFDA1717);
    return const Color(0xFF2A9134);
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'Your Credit\nScore',
      showBack: false,
      showHelp: true,
      totalSteps: 3,
      activeStep: 3,
      bottom: _score != null && !_loading
          ? ZapSubmitButton(title: 'Continue', onPressed: _continue)
          : null,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.accentMint),
                    SizedBox(height: 16),
                    Text(
                      'Pulling your bureau report…',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                )
              : _error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: AppTypography.body(size: 14),
                        ),
                        const SizedBox(height: 16),
                        ZapSubmitButton(title: 'Retry', onPressed: _run),
                      ],
                    )
                  : _ScoreResult(
                      score: _score ?? 0,
                      name: _userName,
                      loanAmount: _loanAmount,
                      message: _message,
                      accent: _scoreColor,
                    ),
        ),
      ),
    );
  }
}

class _ScoreResult extends StatelessWidget {
  const _ScoreResult({
    required this.score,
    required this.accent,
    this.name,
    this.loanAmount,
    this.message,
  });

  final int score;
  final Color accent;
  final String? name;
  final String? loanAmount;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final ntc = score <= 299;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (name != null && name!.isNotEmpty) ...[
          Text(name!, style: AppTypography.body(size: 16)),
          const SizedBox(height: 16),
        ],
        Container(
          width: 160,
          height: 160,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: 8),
          ),
          child: Text(
            '$score',
            style: AppTypography.headline(size: 42),
          ),
        ),
        const SizedBox(height: 24),
        if (ntc) ...[
          Text(
            'No Credit History\nNo Problem',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              size: 18,
              weight: FontWeight.w600,
              color: AppColors.accentMint,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We also help you build\nyour Credit Score',
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 14),
          ),
        ] else if (message != null && message!.isNotEmpty) ...[
          Text(
            message!,
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 14),
          ),
        ],
        if (loanAmount != null && loanAmount!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Eligible up to ₹$loanAmount',
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 16, weight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}
