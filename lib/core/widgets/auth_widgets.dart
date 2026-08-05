import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ZapSubmitButton extends StatelessWidget {
  const ZapSubmitButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.disabled = false,
  });

  final String title;
  final VoidCallback? onPressed;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: disabled ? null : onPressed,
          child: Text(title),
        ),
      ),
    );
  }
}

class AuthHeroHeader extends StatelessWidget {
  const AuthHeroHeader({
    super.key,
    this.title = 'Create better\ntogether',
    this.subtitle = 'Join our community',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.headline(size: 34)),
          const SizedBox(height: 8),
          Text(subtitle, style: AppTypography.body(size: 16)),
        ],
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF2A0A5C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: child,
      ),
    );
  }
}
