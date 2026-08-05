import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = NavigationBarThemeData(
      backgroundColor: AppColors.tabBar,
      indicatorColor: Colors.white.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return AppTypography.body(
          size: 11,
          weight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? Colors.white : AppColors.muted,
        );
      }),
    );

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBarTheme(
        data: theme,
        child: NavigationBar(
          height: 68,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onTap,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: _TabIcon('assets/images/tabs/homeinactive.png'),
              selectedIcon: _TabIcon('assets/images/tabs/homeactive.png'),
              label: 'Home',
            ),
            NavigationDestination(
              icon: _TabIcon('assets/images/tabs/creditscoreinactive.png'),
              selectedIcon: _TabIcon('assets/images/tabs/creditScoreActive.png'),
              label: 'Credit',
            ),
            NavigationDestination(
              icon: _TabIcon('assets/images/tabs/discount.png', height: 18),
              selectedIcon: _TabIcon('assets/images/tabs/discountsactive.png'),
              label: 'Discount',
            ),
            NavigationDestination(
              icon: _TabIcon('assets/images/tabs/rewardsinactive.png'),
              selectedIcon: _TabIcon('assets/images/tabs/rewardsactive.png'),
              label: 'Reward',
            ),
            NavigationDestination(
              icon: _TabIcon('assets/images/tabs/learninactive.png'),
              selectedIcon: _TabIcon('assets/images/tabs/learnactive.png'),
              label: 'Learn',
            ),
          ],
        ),
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon(this.asset, {this.height = 22});

  final String asset;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      height: height,
      errorBuilder: (_, __, ___) => Icon(
        Icons.circle,
        size: height,
        color: Colors.white54,
      ),
    );
  }
}

void goHome(BuildContext context) => context.go(AppRoutes.home);
