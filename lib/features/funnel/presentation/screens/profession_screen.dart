import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

class ProfessionScreen extends ConsumerStatefulWidget {
  const ProfessionScreen({super.key});

  @override
  ConsumerState<ProfessionScreen> createState() => _ProfessionScreenState();
}

class _ProfessionScreenState extends ConsumerState<ProfessionScreen> {
  String? _selected;

  Future<void> _select(String type) async {
    setState(() => _selected = type);
    if (type == 'Business') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Currently not offering to business users!')),
      );
      return;
    }
    await ref.read(sessionStorageProvider).write(StorageKeys.userType, type);
    if (!mounted) return;
    context.push(AppRoutes.document, extra: type);
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'Tell us about\nyourself',
      subtitle: 'Choose your current profession',
      showBack: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        child: SizedBox(
          // RN professionTypeMainView height ~180
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ProfessionCard(
                  label: 'Student',
                  asset: 'assets/images/Profession/student.png',
                  selected: _selected == 'Student',
                  onTap: () => _select('Student'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProfessionCard(
                  label: 'Salaried',
                  asset: 'assets/images/Profession/salaried.png',
                  selected: _selected == 'Salaried',
                  onTap: () => _select('Salaried'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProfessionCard(
                  label: 'Business',
                  asset: 'assets/images/Profession/business.png',
                  selected: _selected == 'Business',
                  onTap: () => _select('Business'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfessionCard extends StatelessWidget {
  const _ProfessionCard({
    required this.label,
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: const Color(0xFF3E1982),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accentMint : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: Opacity(
                      opacity: selected ? 1 : 0.5,
                      child: Image.asset(
                        asset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 18,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 12,
                    color: Colors.white.withValues(alpha: selected ? 1 : 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
