import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasSession = false;
  bool _biometricInFlight = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(authRepositoryProvider);
    final info = await PackageInfo.fromPlatform();
    final has = await repo.hasStoredSession();
    if (!mounted) return;
    setState(() {
      _hasSession = has;
      _appVersion = info.version;
    });
    // RN `getIds`: token + deviceId → auto Face/Fingerprint prompt.
    // Brief delay so Android FragmentActivity is ready for BiometricPrompt.
    if (has) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await _tryBiometric(autoPrompt: true);
    }
  }

  /// Skip-OTP resume — mirrors RN `useFaceIdAuth` → `isBiometricAvailable`.
  Future<void> _tryBiometric({bool autoPrompt = false}) async {
    if (_biometricInFlight) return;
    _biometricInFlight = true;
    final repo = ref.read(authRepositoryProvider);
    final bio = ref.read(biometricServiceProvider);
    try {
      // RN clears + refreshes SF id before LocalAuth (non-blocking).
      unawaited(repo.refreshSfCustomerIdForBiometricLogin());

      final available = await bio.canCheckBiometrics();
      if (!available) {
        // RN silently no-ops when scanner has no enrolled fingers on auto path.
        if (!autoPrompt && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometrics not available on this device'),
            ),
          );
        }
        return;
      }
      final result = await bio.authenticate();
      if (!result.success || !mounted) {
        if (!result.cancelled &&
            result.errorMessage != null &&
            mounted &&
            !autoPrompt) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.errorMessage!)),
          );
        }
        return;
      }

      ref.read(globalLoadingProvider.notifier).state = true;
      try {
        final session = await repo.readStoredSession();
        if (session == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Session expired. Please login with OTP.'),
              ),
            );
          }
          return;
        }
        final route =
            await ref.read(resolvePostLoginRouteUseCaseProvider).call(session);
        if (mounted) context.go(route);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not resume session. Please try OTP. ($e)'),
            ),
          );
        }
      } finally {
        if (mounted) {
          ref.read(globalLoadingProvider.notifier).state = false;
        }
      }
    } finally {
      _biometricInFlight = false;
    }
  }

  Future<void> _sendOtp() async {
    final mobile = _controller.text.trim();
    final error = Validators.mobileNumber(mobile);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _focusNode.unfocus();
    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final ok = await ref.read(sendOtpUseCaseProvider).call(
            mobile,
            appVersion: _appVersion.isEmpty ? '1.0.0' : _appVersion,
          );
      if (!mounted) return;
      if (ok) {
        context.push(AppRoutes.otp, extra: mobile);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong!!!, Please try again.'),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        final msg = data is Map
            ? (data['msg']?.toString() ?? data['message']?.toString())
            : null;
        final http = e.response?.statusCode;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg ??
                  (http != null
                      ? 'Request failed (HTTP $http). Check Flutter logs.'
                      : 'Something went wrong!!!, Please try again.'),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong!!!, Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        ref.read(globalLoadingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(globalLoadingProvider);

    return Scaffold(
      // Avoid full-scene resize jank/crashes on some Samsung GPUs when IME opens.
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.deepPurple,
      body: Stack(
        children: [
          // Solid theme background — full-bleed PNG + Impeller was killing the
          // process on keyboard open (mali_gralloc / Skipped 100+ frames).
          const Positioned.fill(
            child: ColoredBox(color: AppColors.deepPurple),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 48, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create better\ntogether',
                        style: TextStyle(
                          fontFamily: 'DigretoNeue',
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Join our community',
                        style: TextStyle(
                          fontFamily: 'DigretoNeue',
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2A0A5C),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                      children: [
                        const Text(
                          'Enter your mobile number',
                          style: TextStyle(
                            fontFamily: 'DigretoNeue',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                '+91',
                                style: TextStyle(
                                  fontFamily: 'DigretoNeue',
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  enabled: !loading,
                                  autofocus: false,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.done,
                                  maxLength: 10,
                                  cursorColor: Colors.white,
                                  style: const TextStyle(
                                    fontFamily: 'DigretoNeue',
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    counterText: '',
                                    hintText: '4469006363',
                                    hintStyle: TextStyle(
                                      fontFamily: 'DigretoNeue',
                                      fontSize: 16,
                                      color: AppColors.muted,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  onSubmitted: (_) {
                                    if (_controller.text.trim().length == 10) {
                                      _sendOtp();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Once you click on Get OTP, a 6-digit OTP will\nbe sent to the given mobile number',
                          style: TextStyle(
                            fontFamily: 'DigretoNeue',
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        if (_hasSession) ...[
                          const SizedBox(height: 20),
                          Center(
                            child: Column(
                              children: [
                                IconButton(
                                  onPressed: loading ? null : _tryBiometric,
                                  icon: Image.asset(
                                    'assets/images/face-id.png',
                                    height: 52,
                                    width: 52,
                                    color: Colors.white,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(
                                      Icons.fingerprint,
                                      size: 52,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const Text(
                                  'Login with Fingerprint.',
                                  style: TextStyle(
                                    fontFamily: 'DigretoNeue',
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 48),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, _) {
                            final len = value.text.trim().length;
                            return ZapSubmitButton(
                              title: 'Get OTP',
                              disabled: len < 10 || loading,
                              onPressed: _sendOtp,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
