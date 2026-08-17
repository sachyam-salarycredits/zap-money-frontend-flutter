import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// RN `scenes/equifaxReport` — consent OTP gate, then `/validatescore`.
class EquifaxScreen extends ConsumerStatefulWidget {
  const EquifaxScreen({super.key});

  @override
  ConsumerState<EquifaxScreen> createState() => _EquifaxScreenState();
}

class _EquifaxScreenState extends ConsumerState<EquifaxScreen> {
  static const _consentHeadline =
      'I authorize Zap Money / Monexo to access my credit bureau report.';
  static const _consentBody =
      'We will fetch your credit report to assess your loan eligibility. '
      'This will be recorded as a soft inquiry and will not impact your credit score.';

  bool _booting = true;
  bool _fetching = false;
  bool _consentChecked = false;
  bool _otpSent = false;
  bool _submitting = false;
  String? _error;
  String? _consentHeadlineText;
  String? _consentBodyText;
  String? _mobileMasked;
  String? _customerId;
  String? _deviceId;
  int _cooldownSeconds = 0;
  int? _score;
  String? _userName;
  String? _loanAmount;
  String? _message;
  String _userType = 'Salaried';

  final List<TextEditingController> _digits =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  String get _otp => _digits.map((c) => c.text).join();

  bool get _needsConsent => _score == null && !_fetching && !_booting;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    for (final c in _digits) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startCooldown(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    setState(() => _cooldownSeconds = s);
    if (s <= 0) return;
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || _cooldownSeconds <= 0) return false;
      setState(() => _cooldownSeconds--);
      return _cooldownSeconds > 0;
    });
  }

  void _applyConsentCopy(Map? payload) {
    if (payload == null) return;
    final headline = payload['consent_headline']?.toString();
    final body = payload['consent_body']?.toString();
    if (headline != null && headline.isNotEmpty) {
      _consentHeadlineText = headline;
    }
    if (body != null && body.isNotEmpty) {
      _consentBodyText = body;
    }
    final retry = payload['otp_send_retry_after_seconds'];
    final retryInt = retry is int ? retry : int.tryParse('$retry');
    if (retryInt != null && retryInt > 0) {
      _startCooldown(retryInt);
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _booting = true;
      _error = null;
    });
    try {
      final storage = ref.read(sessionStorageProvider);
      _customerId =
          (await storage.read(StorageKeys.customerId))?.replaceAll('"', '');
      _deviceId =
          (await storage.read(StorageKeys.deviceId))?.replaceAll('"', '');
      _userType =
          (await storage.read(StorageKeys.userType))?.replaceAll('"', '') ??
              'Salaried';

      if (_customerId == null || _customerId!.isEmpty) {
        setState(() {
          _booting = false;
          _error =
              'Missing customer id. Go back and complete personal information.';
        });
        return;
      }

      final dio = ref.read(dioClientProvider).dio;
      final statusRes = await dio.post(
        ApiEndpoints.getBureauConsentStatus,
        data: {
          'custid': _customerId,
          'deviceId': _deviceId,
        },
        options: Options(
          contentType: Headers.jsonContentType,
          extra: {'useBearer': true},
        ),
      );

      final statusData = statusRes.data;
      final payload =
          statusData is Map ? statusData['data'] : null;
      final required = payload is Map
          ? payload['required'] != false && payload['required'] != 'false'
          : true;
      final hasConsent = payload is Map &&
          (payload['has_consent'] == true || payload['has_consent'] == 1);
      if (payload is Map) {
        _applyConsentCopy(payload);
        _mobileMasked = payload['mobile_masked']?.toString();
      }

      if (!mounted) return;
      if (!required || hasConsent) {
        setState(() => _booting = false);
        await _fetchReport();
        return;
      }

      setState(() {
        _booting = false;
        _consentHeadlineText ??= _consentHeadline;
        _consentBodyText ??= _consentBody;
      });
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('bureau consent status failed: ${e.response?.data}');
      }
      if (!mounted) return;
      setState(() {
        _booting = false;
        _consentHeadlineText = _consentHeadline;
        _consentBodyText = _consentBody;
        final data = e.response?.data;
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          _error = data is Map
              ? (data['msg'] ?? data['message'])?.toString()
              : 'Session expired. Please login again.';
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('bureau consent bootstrap: $e');
      if (!mounted) return;
      setState(() {
        _booting = false;
        _consentHeadlineText = _consentHeadline;
        _consentBodyText = _consentBody;
      });
    }
  }

  Future<void> _sendOtp({bool resend = false}) async {
    if (!_consentChecked) {
      setState(() => _error = 'Please authorize credit bureau access to continue.');
      return;
    }
    if (_cooldownSeconds > 0) {
      setState(() =>
          _error = 'Too many OTP requests. Try again in $_cooldownSeconds seconds.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioClientProvider).dio;
      final res = await dio.post(
        ApiEndpoints.sendBureauConsentOtp,
        data: {
          'custid': _customerId,
          'deviceId': _deviceId,
          'consent_given': true,
        },
        options: Options(
          contentType: Headers.jsonContentType,
          extra: {'useBearer': true},
        ),
      );
      final data = res.data;
      final payload = data is Map ? data['data'] : null;
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _submitting = false;
        if (payload is Map) {
          _mobileMasked = payload['mobile_masked']?.toString() ?? _mobileMasked;
          final remaining = payload['sends_remaining'];
          final remInt =
              remaining is int ? remaining : int.tryParse('$remaining');
          if (remInt != null && remInt <= 0) {
            final retry = payload['retry_after_seconds'];
            final retryInt = retry is int ? retry : int.tryParse('$retry');
            if (retryInt != null && retryInt > 0) {
              _startCooldown(retryInt);
            }
          }
        }
      });
      if (resend && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent')),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final code = data is Map ? data['code']?.toString() : null;
      final retry = data is Map ? data['retry_after_seconds'] : null;
      final retryInt = retry is int ? retry : int.tryParse('$retry');
      if (code == 'otp_send_cooldown' && retryInt != null && retryInt > 0) {
        _startCooldown(retryInt);
      }
      setState(() {
        _submitting = false;
        _error = data is Map
            ? (data['msg'] ?? data['message'])?.toString()
            : 'Unable to send OTP. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Unable to send OTP. Please try again.';
      });
    }
  }

  Future<void> _verifyAndFetch() async {
    if (!_consentChecked) {
      setState(() => _error = 'Please authorize credit bureau access to continue.');
      return;
    }
    if (_otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP sent to your mobile.');
      return;
    }
    if (!_otpSent) {
      await _sendOtp();
      if (!_otpSent) return;
      setState(() =>
          _error = 'OTP sent. Enter the code, then tap Verify OTP & Fetch Report.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioClientProvider).dio;
      await dio.post(
        ApiEndpoints.verifyBureauConsentOtp,
        data: {
          'custid': _customerId,
          'deviceId': _deviceId,
          'otp': _otp,
        },
        options: Options(
          contentType: Headers.jsonContentType,
          extra: {'useBearer': true},
        ),
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await _fetchReport();
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      setState(() {
        _submitting = false;
        _error = data is Map
            ? (data['msg'] ?? data['message'])?.toString()
            : 'OTP verification failed. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'OTP verification failed. Please try again.';
      });
    }
  }

  Future<void> _fetchReport() async {
    setState(() {
      _fetching = true;
      _error = null;
      _score = null;
    });
    try {
      final customerId = _customerId;
      final deviceId = _deviceId;
      if (customerId == null || customerId.isEmpty) {
        setState(() {
          _fetching = false;
          _error =
              'Missing customer id. Go back and complete personal information.';
        });
        return;
      }

      final dio = ref.read(dioClientProvider).dio;

      // PRFIL enrichment: fire-and-forget; never blocks PCRLT.
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
          _fetching = false;
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
        _fetching = false;
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
      final code = data is Map ? data['code']?.toString() : null;
      final msg = data is Map
          ? (data['msg'] ?? data['message'])?.toString()
          : null;
      setState(() {
        _fetching = false;
        if (code == 'consent_required') {
          _error = null;
          _consentHeadlineText ??= _consentHeadline;
          _consentBodyText ??= _consentBody;
        } else {
          _error = msg ??
              (e.response?.statusCode != null
                  ? 'Credit check failed (HTTP ${e.response!.statusCode})'
                  : 'Could not fetch credit report. Tap retry.');
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('validatescore error: $e');
      if (!mounted) return;
      setState(() {
        _fetching = false;
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
    context.go(AppRoutes.locationPermission);
  }

  Color get _scoreColor {
    final s = _score ?? 0;
    if (s <= 299) return AppColors.accentMint;
    if (s <= 599) return const Color(0xFFDA1717);
    return const Color(0xFF2A9134);
  }

  void _onDigit(int index, String value) {
    if (value.isEmpty) {
      if (index > 0) _nodes[index - 1].requestFocus();
    } else {
      final digit = value[value.length - 1];
      _digits[index].text = digit;
      _digits[index].selection =
          TextSelection.collapsed(offset: _digits[index].text.length);
      if (index < 5) {
        _nodes[index + 1].requestFocus();
      } else {
        _nodes[index].unfocus();
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final showScore = _score != null && !_fetching && !_booting;
    final showConsent = _needsConsent && _score == null;

    return FunnelScaffold(
      title: showConsent ? 'Credit Bureau\nVerification' : 'Your Credit\nScore',
      showBack: false,
      showHelp: true,
      totalSteps: 3,
      activeStep: 3,
      bottom: showScore
          ? ZapSubmitButton(title: 'Continue', onPressed: _continue)
          : showConsent
              ? ZapSubmitButton(
                  title: 'Verify OTP & Fetch Report',
                  disabled: _submitting || !_consentChecked || _otp.length < 6,
                  onPressed: _verifyAndFetch,
                )
              : null,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _booting || _fetching
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.accentMint),
                    const SizedBox(height: 16),
                    Text(
                      _fetching
                          ? 'Pulling your bureau report…'
                          : 'Checking consent…',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                )
              : showScore
                  ? _ScoreResult(
                      score: _score ?? 0,
                      name: _userName,
                      loanAmount: _loanAmount,
                      message: _message,
                      accent: _scoreColor,
                    )
                  : _ConsentCard(
                      consentHeadline:
                          _consentHeadlineText ?? _consentHeadline,
                      consentBody: _consentBodyText ?? _consentBody,
                      consentChecked: _consentChecked,
                      otpSent: _otpSent,
                      mobileMasked: _mobileMasked,
                      error: _error,
                      submitting: _submitting,
                      cooldownSeconds: _cooldownSeconds,
                      digits: _digits,
                      nodes: _nodes,
                      onConsentChanged: (v) {
                        setState(() {
                          _consentChecked = v;
                          _error = null;
                        });
                        if (v && !_otpSent && _cooldownSeconds <= 0) {
                          _sendOtp();
                        }
                      },
                      onDigit: _onDigit,
                      onResend: () => _sendOtp(resend: true),
                      onRetryFetch: _error != null &&
                              _error!.contains('Could not fetch')
                          ? _fetchReport
                          : null,
                    ),
        ),
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.consentHeadline,
    required this.consentBody,
    required this.consentChecked,
    required this.otpSent,
    required this.digits,
    required this.nodes,
    required this.onConsentChanged,
    required this.onDigit,
    required this.onResend,
    this.mobileMasked,
    this.error,
    this.submitting = false,
    this.cooldownSeconds = 0,
    this.onRetryFetch,
  });

  final String consentHeadline;
  final String consentBody;
  final bool consentChecked;
  final bool otpSent;
  final String? mobileMasked;
  final String? error;
  final bool submitting;
  final int cooldownSeconds;
  final List<TextEditingController> digits;
  final List<FocusNode> nodes;
  final ValueChanged<bool> onConsentChanged;
  final void Function(int, String) onDigit;
  final VoidCallback onResend;
  final VoidCallback? onRetryFetch;

  @override
  Widget build(BuildContext context) {
    final coolingDown = cooldownSeconds > 0;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Authorize a soft credit inquiry to check your loan eligibility.',
            style: AppTypography.body(size: 14, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3E1982),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: consentChecked,
                    activeColor: AppColors.accentMint,
                    checkColor: AppColors.deepPurple,
                    side: const BorderSide(color: Colors.white70),
                    onChanged: submitting
                        ? null
                        : (v) => onConsentChanged(v ?? false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: consentHeadline,
                          style: AppTypography.body(
                            size: 13,
                            weight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '\n$consentBody',
                          style: AppTypography.body(size: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            otpSent && mobileMasked != null && mobileMasked!.isNotEmpty
                ? 'Enter OTP sent to $mobileMasked'
                : 'Enter 6-digit OTP',
            style: AppTypography.body(size: 14, weight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              return SizedBox(
                width: 44,
                child: TextField(
                  controller: digits[i],
                  focusNode: nodes[i],
                  enabled: !submitting,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: AppTypography.headline(size: 20),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFF3E1982),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => onDigit(i, v),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: submitting || !consentChecked || coolingDown
                  ? null
                  : onResend,
              child: Text(
                coolingDown
                    ? 'Resend in ${cooldownSeconds}s'
                    : (otpSent ? 'Resend OTP' : 'Send OTP'),
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.accentMint,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (error != null && error!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 13, color: const Color(0xFFFFAE00)),
            ),
            if (onRetryFetch != null) ...[
              const SizedBox(height: 12),
              ZapSubmitButton(title: 'Retry', onPressed: onRetryFetch),
            ],
          ],
        ],
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
