import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';

/// RN `scenes/referredScreen` — Under credit manager review.
class ReferredScreen extends StatelessWidget {
  const ReferredScreen({super.key, this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'Under credit\nmanager review',
      subtitle: 'We try to give you a decision within 24 hours',
      showBack: false,
      bottom: ZapSubmitButton(
        title: 'Back Home',
        onPressed: () => context.go(AppRoutes.home),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top, size: 72, color: AppColors.accentMint),
              const SizedBox(height: 20),
              Text(
                status == 'WIP'
                    ? 'Your application is still being reviewed.'
                    : 'We are viewing your application and will update you shortly.',
                textAlign: TextAlign.center,
                style: AppTypography.body(size: 14, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
