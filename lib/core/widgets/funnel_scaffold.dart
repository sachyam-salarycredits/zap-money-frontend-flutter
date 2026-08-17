import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// Shared onboarding layout aligned to ZapMoney new-flow designs.
class FunnelScaffold extends StatelessWidget {
  const FunnelScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.onBack,
    this.bottom,
    this.showBack = true,
    this.showHelp = true,
    this.totalSteps,
    this.activeStep,
    this.heroAsset,
    this.heroHeight = 110,
    this.useSheet = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? bottom;
  final VoidCallback? onBack;
  final bool showBack;
  final bool showHelp;

  /// 1-based. When set with [totalSteps], shows top progress bars.
  final int? totalSteps;
  final int? activeStep;

  final String? heroAsset;
  final double heroHeight;

  /// When true, wraps [child] in the rounded dark sheet used by older screens.
  final bool useSheet;

  @override
  Widget build(BuildContext context) {
    final showTopBar =
        showBack || showHelp || (totalSteps != null && activeStep != null);

    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTopBar)
              _TopBar(
                showBack: showBack,
                showHelp: showHelp,
                onBack: onBack,
                totalSteps: totalSteps,
                activeStep: activeStep,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTypography.headline(size: 28)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            subtitle!,
                            style: AppTypography.body(
                              size: 14,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (heroAsset != null)
                    Image.asset(
                      heroAsset!,
                      height: heroHeight,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
            Expanded(
              child: useSheet
                  ? Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        // RN profession sheet: rgba(35, 2, 97, 0.8)
                        color: Color(0xCC230261),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(25)),
                      ),
                      child: child,
                    )
                  : child,
            ),
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.showBack,
    required this.showHelp,
    required this.onBack,
    required this.totalSteps,
    required this.activeStep,
  });

  final bool showBack;
  final bool showHelp;
  final VoidCallback? onBack;
  final int? totalSteps;
  final int? activeStep;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: Image.asset(
                'assets/images/backicon.png',
                width: 16,
                height: 16,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.arrow_back, color: Colors.white),
              ),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: totalSteps != null && activeStep != null
                ? Center(
                    child: FunnelStepIndicator(
                      total: totalSteps!,
                      active: activeStep!,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (showHelp)
            const NeedHelpChip()
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class FunnelStepIndicator extends StatelessWidget {
  const FunnelStepIndicator({
    super.key,
    required this.total,
    required this.active,
  });

  final int total;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final on = i < active;
        return Container(
          width: 28,
          height: 4,
          margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class NeedHelpChip extends StatelessWidget {
  const NeedHelpChip({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => showNeedHelpSheet(context),
      style: TextButton.styleFrom(
        backgroundColor: AppColors.accentMint,
        foregroundColor: AppColors.deepPurple,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(
        'Need help?',
        style: AppTypography.body(
          size: 12,
          weight: FontWeight.w600,
          color: AppColors.deepPurple,
        ),
      ),
    );
  }
}

Future<void> showNeedHelpSheet(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) {
      return Dialog(
        backgroundColor: const Color(0xFF4A2B8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Spacer(),
                  Text(
                    'Need Help?',
                    style: AppTypography.body(
                      size: 18,
                      weight: FontWeight.w600,
                      color: AppColors.accentMint,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _HelpAction(
                icon: Icons.phone_outlined,
                label: 'Talk to Us',
                onTap: () => _launch(Uri.parse('tel:18005729191')),
              ),
              const SizedBox(height: 12),
              _HelpAction(
                icon: Icons.mail_outline,
                label: 'Write to Us',
                onTap: () => _launch(Uri.parse('mailto:support@zapmoney.in')),
              ),
              const SizedBox(height: 12),
              _HelpAction(
                icon: Icons.chat_bubble_outline,
                label: 'Chat on WhatsApp',
                onTap: () => _launch(
                  Uri.parse('https://wa.me/918047123456'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _HelpAction extends StatelessWidget {
  const _HelpAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.deepPurple),
        label: Text(
          label,
          style: AppTypography.body(
            size: 16,
            weight: FontWeight.w600,
            color: AppColors.deepPurple,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.deepPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

Future<void> _launch(Uri uri) async {
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
