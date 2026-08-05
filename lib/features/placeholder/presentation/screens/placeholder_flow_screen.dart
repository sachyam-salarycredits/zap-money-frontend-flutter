import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Temporary destinations for ScreenStatus routes until those features migrate.
class PlaceholderFlowScreen extends StatelessWidget {
  const PlaceholderFlowScreen({
    super.key,
    required this.title,
    this.subtitle =
        'This screen will be implemented in a later migration phase.',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.tabBar,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppTypography.headline(size: 24)),
              const SizedBox(height: 12),
              Text(
                subtitle,
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
