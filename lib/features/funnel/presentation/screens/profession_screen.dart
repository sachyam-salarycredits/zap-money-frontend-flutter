import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

/// Profession step — product is Salaried-only; auto-select and continue.
class ProfessionScreen extends ConsumerStatefulWidget {
  const ProfessionScreen({super.key});

  @override
  ConsumerState<ProfessionScreen> createState() => _ProfessionScreenState();
}

class _ProfessionScreenState extends ConsumerState<ProfessionScreen> {
  static const _salaried = 'Salaried';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSelectSalaried());
  }

  Future<void> _autoSelectSalaried() async {
    await ref.read(sessionStorageProvider).write(StorageKeys.userType, _salaried);
    if (!mounted) return;
    context.go(AppRoutes.document, extra: _salaried);
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'Tell us about\nyourself',
      showBack: false,
      showHelp: false,
      heroAsset: 'assets/images/Profession/target.png',
      heroHeight: 150,
      useSheet: true,
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppColors.accentMint),
        ),
      ),
    );
  }
}
