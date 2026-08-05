import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/kyc_repository.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  late final TextEditingController _email;
  String? _message;

  final _emailRegex =
      RegExp(r'^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w\w+)+$');

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = _email.text.trim();
    if (!_emailRegex.hasMatch(value)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email')),
      );
      return;
    }
    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      await ref.read(kycRepositoryProvider).sendEmailVerification(value);
      if (mounted) {
        setState(() {
          _message =
              'Verification link sent. Open it from your inbox (or check backend mock logs), then return to Home.';
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send verification email')),
        );
      }
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'Activate email',
      subtitle: 'We send a verification link — not an in-app OTP.',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ZapSubmitButton(title: 'Send verification link', onPressed: _send),
          TextButton(
            onPressed: () => context.go(AppRoutes.home),
            child: Text(
              'Back to Home',
              style: AppTypography.body(size: 14, color: AppColors.accentMint),
            ),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            style: AppTypography.body(size: 16),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: 'you@example.com',
              hintStyle: AppTypography.body(size: 16, color: AppColors.muted),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, style: AppTypography.body(size: 14, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}
