import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

class _DocItem {
  const _DocItem(this.title, {this.subtitle, this.asset});

  final String title;
  final String? subtitle;
  final String? asset;
}

/// RN `scenes/document` checklist → PAN screen.
class DocumentScreen extends ConsumerWidget {
  const DocumentScreen({super.key, this.userType});

  final String? userType;

  static const _salariedDocs = [
    _DocItem('Pan Card', asset: 'assets/images/pan.png'),
    _DocItem('Aadhaar Card Number'),
    _DocItem('Bank Details', asset: 'assets/images/bankdoc.png'),
    _DocItem('3 Months Salary Slip'),
    _DocItem('3 Months Bank Statements'),
    _DocItem('Employee ID'),
  ];

  static const _studentDocs = [
    _DocItem(
      'Government Issued ID',
      subtitle: 'PanCard or Driving License or Voter ID',
      asset: 'assets/images/pan.png',
    ),
    _DocItem('Aadhaar Card Number'),
    _DocItem('College ID'),
    _DocItem('Bank Details', asset: 'assets/images/bankdoc.png'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = (userType ?? 'Salaried').replaceAll('"', '');
    final items = type.toLowerCase() == 'student' ? _studentDocs : _salariedDocs;

    return FunnelScaffold(
      title: 'Documents\nrequired',
      subtitle:
          'Please keep the following documents handy for quicker account opening',
      bottom: ZapSubmitButton(
        title: 'Continue',
        onPressed: () async {
          final stored =
              await ref.read(sessionStorageProvider).read(StorageKeys.userType);
          if (!context.mounted) return;
          context.push(
            AppRoutes.pancard,
            extra: (stored ?? type).replaceAll('"', ''),
          );
        },
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Image.asset(
            'assets/images/Profession/Document.png',
            height: 120,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          for (final item in items) ...[
            _DocRow(item: item),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.item});

  final _DocItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          height: 22,
          child: item.asset != null
              ? Image.asset(
                  item.asset!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.description_outlined,
                    color: AppColors.accentMint,
                    size: 20,
                  ),
                )
              : const Icon(
                  Icons.check_circle,
                  color: AppColors.accentMint,
                  size: 20,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: AppTypography.body(size: 15)),
              if (item.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  item.subtitle!,
                  style: AppTypography.body(size: 12, color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
