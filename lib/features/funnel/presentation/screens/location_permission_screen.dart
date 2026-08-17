import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../dashboard/data/home_repository.dart';
import '../../../device_sync/device_sync_service.dart';

/// RN `scenes/locationPermission` — after credit score, before bank/college.
class LocationPermissionScreen extends ConsumerStatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  ConsumerState<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState
    extends ConsumerState<LocationPermissionScreen> {
  bool _busy = false;

  Future<void> _goNext() async {
    final storage = ref.read(sessionStorageProvider);
    final userType =
        (await storage.read(StorageKeys.userType))?.replaceAll('"', '') ?? '';
    if (!mounted) return;
    if (userType.toLowerCase() == 'student') {
      context.go(AppRoutes.collegeDetails);
    } else {
      var repeatLoan = false;
      try {
        final bundle = await ref.read(homeRepositoryProvider).fetchHomeBundle();
        repeatLoan = bundle.home.topUpEligible && bundle.home.loanCompleted;
      } catch (_) {
        // The bank refresh remains safe if Home cannot be loaded.
      }
      if (!mounted) return;
      context.go(
        repeatLoan ? AppRoutes.employerDetails : AppRoutes.bankDetails,
        extra: repeatLoan ? const {'isFrom': 'repeatLoan'} : null,
      );
    }
  }

  Future<void> _allow() async {
    setState(() => _busy = true);
    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      await Permission.location.request();
      // Fire-and-forget location sync (same idea as RN after grant).
      ref.read(deviceSyncServiceProvider).syncAfterPermissionGrant();
    } catch (_) {
      // RN continues even if permission is denied.
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        ref.read(globalLoadingProvider.notifier).state = false;
      }
    }
    if (mounted) await _goNext();
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'Location\nPermission\nNeeded',
      subtitle:
          'With your location, we are able to provide better service and prevent fraud. We serve only in certain areas.',
      showBack: false,
      bottom: ZapSubmitButton(
        title: 'Allow & Continue',
        disabled: _busy,
        onPressed: _allow,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 72,
            color: AppColors.accentMint,
          ),
          const SizedBox(height: 24),
          Text('Location', style: AppTypography.headline(size: 18)),
          const SizedBox(height: 8),
          Text(
            'We use location for serviceability checks and fraud prevention. Your information is safe with us.',
            style: AppTypography.body(size: 14, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
