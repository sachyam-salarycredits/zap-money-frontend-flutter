import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    _OnboardData(
      image: 'assets/images/Onboard/onboard1.png',
      title: 'Get Instant Loan\nApprovals',
    ),
    _OnboardData(
      image: 'assets/images/Onboard/onboard2.png',
      title: 'Track Credit Score\nEasily',
    ),
  ];

  void _next() {
    if (_index >= _pages.length - 1) {
      context.go(AppRoutes.login);
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return _OnboardPage(
                    imageAsset: page.image,
                    title: page.title,
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: active ? 20 : 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.accentMint : Colors.white38,
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            ZapSubmitButton(
              title: _index == _pages.length - 1 ? 'Get Started' : 'Next',
              onPressed: _next,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardData {
  const _OnboardData({required this.image, required this.title});
  final String image;
  final String title;
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({required this.imageAsset, required this.title});

  final String imageAsset;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Expanded(
            child: Center(
              child: Image.asset(
                imageAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                cacheWidth: 600,
              ),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.headline(size: 25),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
