import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../providers/auth_providers.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.mobileNumber});

  final String mobileNumber;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _digits =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  int _seconds = 120;
  bool _invalid = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _tick();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _appVersion = i.version);
    });
  }

  void _tick() {
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || _seconds <= 0) return false;
      setState(() => _seconds--);
      return _seconds > 0;
    });
  }

  String get _otp => _digits.map((c) => c.text).join();

  String get _timerText {
    final dt = DateTime(0, 1, 1, 0, 0, _seconds);
    return DateFormat('mm:ss').format(dt);
  }

  Future<void> _verify(String otp) async {
    if (otp.length != 6) return;
    ref.read(globalLoadingProvider.notifier).state = true;
    setState(() => _invalid = false);
    try {
      final session = await ref.read(verifyOtpUseCaseProvider).call(
            mobileNumber: widget.mobileNumber,
            otp: otp,
          );
      if (!mounted) return;
      if (session == null) {
        setState(() => _invalid = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP is not valid')),
        );
        return;
      }
      // RN waits ~1s then loads flags
      await Future<void>.delayed(const Duration(seconds: 1));
      final route =
          await ref.read(resolvePostLoginRouteUseCaseProvider).call(session);
      if (mounted) context.go(route);
    } catch (e) {
      if (mounted) {
        setState(() => _invalid = true);
        final msg = e is DioException && e.response?.data is Map
            ? (e.response!.data['msg']?.toString())
            : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg ?? 'OTP is not valid')),
        );
      }
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _resend() async {
    final ok = await ref.read(sendOtpUseCaseProvider).call(
          widget.mobileNumber,
          appVersion: _appVersion,
        );
    if (ok && mounted) {
      setState(() => _seconds = 120);
      _tick();
    }
  }

  void _onDigit(int index, String value) {
    if (value.isEmpty) {
      if (index > 0) _nodes[index - 1].requestFocus();
    } else {
      final digit = value.isEmpty ? '' : value[value.length - 1];
      _digits[index].text = digit;
      _digits[index].selection =
          TextSelection.collapsed(offset: _digits[index].text.length);
      if (index < 5) {
        _nodes[index + 1].requestFocus();
      } else {
        _nodes[index].unfocus();
        _verify(_otp);
      }
    }
    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(globalLoadingProvider);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Login/login.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: AppColors.deepPurple,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuthHeroHeader(),
                AuthCard(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                IconButton(
                                  onPressed: () => context.pop(),
                                  icon: Image.asset(
                                    'assets/images/backicon.png',
                                    height: 15,
                                    width: 15,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(
                                      Icons.arrow_back,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Text(
                                  'OTP Verification',
                                  style: AppTypography.headline(size: 22),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'An OTP verification code will be sent to\n+91 ${widget.mobileNumber}',
                                  style: AppTypography.body(
                                    size: 13,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: List.generate(6, (i) {
                                    return SizedBox(
                                      width: 42,
                                      child: TextField(
                                        controller: _digits[i],
                                        focusNode: _nodes[i],
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        maxLength: 1,
                                        style:
                                            AppTypography.headline(size: 20),
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        decoration: InputDecoration(
                                          counterText: '',
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: _invalid
                                                  ? Colors.redAccent
                                                  : Colors.white54,
                                            ),
                                          ),
                                        ),
                                        onChanged: (v) => _onDigit(i, v),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: Text(
                                    _timerText,
                                    style: AppTypography.body(size: 14),
                                  ),
                                ),
                                if (_seconds == 0)
                                  TextButton(
                                    onPressed: _resend,
                                    child: Text(
                                      'Resend OTP',
                                      style: AppTypography.body(
                                        size: 14,
                                        color: AppColors.accentMint,
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                ZapSubmitButton(
                                  title: 'Verify',
                                  disabled: _otp.length < 6 || loading,
                                  onPressed: () => _verify(_otp),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
