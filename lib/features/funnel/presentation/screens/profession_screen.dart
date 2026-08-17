import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

/// RN `scenes/profession` — Student / Salaried / Business picker.
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
        const SnackBar(
          content: Text('Currently not offering to business users!'),
        ),
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
      showBack: false,
      showHelp: false,
      heroAsset: 'assets/images/Profession/target.png',
      heroHeight: 150,
      useSheet: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  SizedBox(height: constraints.maxHeight * 0.28),
                  Text(
                    'Choose your current profession',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                      size: 18,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _ProfessionCard(
                            label: 'Student',
                            asset: 'assets/images/Profession/student.png',
                            imageSize: 90,
                            selected: _selected == 'Student',
                            onTap: () => _select('Student'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ProfessionCard(
                            label: 'Salaried',
                            asset: 'assets/images/Profession/salaried.png',
                            imageSize: 114,
                            selected: _selected == 'Salaried',
                            onTap: () => _select('Salaried'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ProfessionCard(
                            label: 'Business',
                            asset: 'assets/images/Profession/business.png',
                            imageSize: 70,
                            selected: _selected == 'Business',
                            onTap: () => _select('Business'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfessionCard extends StatelessWidget {
  const _ProfessionCard({
    required this.label,
    required this.asset,
    required this.imageSize,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String asset;
  final double imageSize;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // RN: selected height 100%, unselected 85% of the 180 row.
    final height = selected ? 180.0 : 180.0 * 0.85;
    final opacity = selected ? 1.0 : 0.5;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF3E1982),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? const Color.fromRGBO(128, 255, 219, 1)
                    : Colors.transparent,
                width: selected ? 1 : 0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: Opacity(
                      opacity: opacity,
                      child: Image.asset(
                        asset,
                        width: imageSize,
                        height: imageSize,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person,
                          color: Colors.white.withValues(alpha: opacity),
                          size: imageSize * 0.55,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Opacity(
                  opacity: opacity,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 12,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
