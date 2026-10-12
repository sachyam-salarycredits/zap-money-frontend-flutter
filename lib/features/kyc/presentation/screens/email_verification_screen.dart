import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../dashboard/data/home_repository.dart';
import '../../data/kyc_repository.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen>
    with WidgetsBindingObserver {
  final _email = TextEditingController();
  String _savedEmail = '';
  String? _message;
  var _editing = false;
  var _linkSent = false;
  var _checking = false;

  final _emailRegex = RegExp(r'^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w\w+)+$');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final seeded = widget.initialEmail?.trim() ?? '';
    if (seeded.isNotEmpty) {
      _savedEmail = seeded;
      _email.text = seeded;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_savedEmail.isEmpty) {
        _loadSavedEmail();
      }
      _continue(silent: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _email.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _linkSent && !_editing) {
      _continue(silent: true);
    }
  }

  Future<void> _loadSavedEmail() async {
    try {
      final profile = await ref.read(kycRepositoryProvider).getCustomerInfo();
      final fromProfile = profile?['email']?.toString().trim() ?? '';
      if (!mounted) return;
      if (fromProfile.isEmpty) {
        setState(() => _editing = true);
        return;
      }
      setState(() {
        _savedEmail = fromProfile;
        _email.text = fromProfile;
      });
    } catch (_) {
      if (mounted) setState(() => _editing = true);
    }
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _email.text = _savedEmail;
      _message = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editing = false;
      _email.text = _savedEmail;
    });
  }

  Future<void> _send() async {
    final value = (_editing ? _email.text : _savedEmail).trim();
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
          _savedEmail = value;
          _email.text = value;
          _editing = false;
          _linkSent = true;
          _message =
              'Verification link sent to $value. Open it, then tap Continue.';
        });
      }
    } on EmailVerificationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
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

  Future<void> _continue({bool silent = false}) async {
    if (_checking || _editing) return;
    _checking = true;
    if (!silent) {
      ref.read(globalLoadingProvider.notifier).state = true;
    }
    try {
      final bundle = await ref.read(homeRepositoryProvider).fetchHomeBundle();
      if (!mounted) return;
      if (!bundle.home.emailVerified) {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Open the verification link in your email, then tap Continue.',
              ),
            ),
          );
        }
        return;
      }
      final kycDone = bundle.flags.ocr || bundle.flags.vkyc;
      if (!kycDone) {
        context.go(AppRoutes.dkyc);
      } else if (!bundle.flags.equifax) {
        context.go(AppRoutes.equifax);
      } else {
        context.go(AppRoutes.home);
      }
    } catch (_) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not confirm email verification')),
        );
      }
    } finally {
      _checking = false;
      if (!silent) {
        ref.read(globalLoadingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'Activate email',
      subtitle: _editing
          ? 'Enter the correct email. We will send the verification link there.'
          : 'We send a verification link to the email you already entered.',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ZapSubmitButton(
            title: _editing
                ? 'Save and send link'
                : (_linkSent ? 'Resend verification link' : 'Send verification link'),
            onPressed: _savedEmail.isEmpty && !_editing ? null : _send,
          ),
          if (_editing)
            TextButton(
              onPressed: _savedEmail.isEmpty ? null : _cancelEditing,
              child: Text(
                'Cancel',
                style: AppTypography.body(size: 14, color: AppColors.accentMint),
              ),
            )
          else
            ZapSubmitButton(
              title: 'Continue',
              onPressed: () => _continue(),
            ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_editing)
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
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
            )
          else ...[
            Text(
              "We'll send a verification link to",
              style: AppTypography.body(size: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Text(
              _savedEmail.isEmpty ? 'Loading your email…' : _savedEmail,
              style: AppTypography.headline(size: 18, color: AppColors.accentMint),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _savedEmail.isEmpty ? null : _startEditing,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                ),
                child: Text(
                  'Change email',
                  style: AppTypography.body(size: 14, color: AppColors.accentMint),
                ),
              ),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: AppTypography.body(size: 14, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
