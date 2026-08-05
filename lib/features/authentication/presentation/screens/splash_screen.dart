import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(authRepositoryProvider);
    final storage = ref.read(sessionStorageProvider);

    // Run I/O in parallel; don't block UI on a fixed 3s sleep.
    final sessionFuture = repo.hasStoredSession();
    final versionFuture = _checkVersionUpdate(repo);
    await Future.wait<void>([
      storage.delete(StorageKeys.sfCustomerId),
      versionFuture,
      Future<void>.delayed(const Duration(milliseconds: 900)),
    ]);

    final isLogin = await sessionFuture;
    if (!mounted) return;
    context.go(isLogin ? AppRoutes.login : AppRoutes.onboarding);
  }

  Future<void> _checkVersionUpdate(AuthRepository repo) async {
    try {
      final remote = await repo.checkAppVersion();
      final info = await PackageInfo.fromPlatform();
      if (remote != null && remote != info.version && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(AppConfig.appName),
            content: const Text(
              'A new version of application is available. Please update your application',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final uri = Uri.parse(AppConfig.playStoreUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      body: Center(
        child: RepaintBoundary(
          child: Lottie.asset(
            'assets/lottie/splash_screen.json',
            width: 220,
            height: 220,
            fit: BoxFit.contain,
            repeat: true,
            frameRate: FrameRate(30),
            options: LottieOptions(enableMergePaths: false),
          ),
        ),
      ),
    );
  }
}
