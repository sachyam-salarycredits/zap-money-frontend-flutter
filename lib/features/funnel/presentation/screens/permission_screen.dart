import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/screen_status_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../device_sync/device_sync_service.dart';

class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  bool _busy = false;

  Future<void> _allowAll() async {
    setState(() => _busy = true);
    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      await [
        Permission.location,
        Permission.contacts,
        Permission.phone,
      ].request();

      await ref.read(screenStatusServiceProvider).completePermission();
      // Fire-and-forget sync (RN starts background sync after grant).
      ref.read(deviceSyncServiceProvider).syncAfterPermissionGrant();

      if (mounted) context.go(AppRoutes.profession);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save permission status')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        ref.read(globalLoadingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'App Permissions',
      subtitle: 'We need a few permissions to evaluate your profile securely.',
      showBack: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        children: [
          Image.asset(
            'assets/images/Permission/permission.png',
            height: 140,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(height: 24),
          ),
          const SizedBox(height: 20),
          _PermTile(
            icon: Icons.location_on_outlined,
            title: 'Location',
            body:
                'With your location, we provide better service and help prevent fraud.',
          ),
          _PermTile(
            icon: Icons.contacts_outlined,
            title: 'Contacts',
            body: 'Used to evaluate your credit profile.',
          ),
          _PermTile(
            icon: Icons.phone_android,
            title: 'Phone / Device',
            body:
                'We collect device model and hardware details to uniquely identify your device.',
          ),
          const SizedBox(height: 24),
          ZapSubmitButton(
            title: 'Allow',
            disabled: _busy,
            onPressed: _allowAll,
          ),
        ],
      ),
    );
  }
}

class _PermTile extends StatelessWidget {
  const _PermTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accentMint, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.headline(size: 16)),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTypography.body(size: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
