import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/screen_status_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../dashboard/data/home_repository.dart';
import '../../../loans/data/loans_prefetch.dart';
import '../../data/profile_repository.dart';

class ProfileHubScreen extends ConsumerStatefulWidget {
  const ProfileHubScreen({super.key});

  @override
  ConsumerState<ProfileHubScreen> createState() => _ProfileHubScreenState();
}

class _ProfileHubScreenState extends ConsumerState<ProfileHubScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _plOrDc = false;
  bool _dcCompleted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(profileRepositoryProvider);
      final results = await Future.wait([
        repo.fetchProfile(),
        repo.fetchFlags(),
      ]);
      final profile = results[0] as Map<String, dynamic>;
      final flags = results[1] as ScreenCompletionFlags;
      if (mounted) {
        setState(() {
          _profile = profile;
          _plOrDc = flags.pl || flags.dc;
          _dcCompleted = flags.dc;
          _loading = false;
        });
      }
      // RN: Profile warms Loan-Contract-PDF before My Loans opens.
      // ignore: unawaited_futures
      _warmLoansCache();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load profile';
        });
      }
    }
  }

  Future<void> _warmLoansCache() async {
    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final homeRepo = ref.read(homeRepositoryProvider);
      final results = await Future.wait([
        profileRepo.fetchFlags(),
        profileRepo.fetchLoanContractPdfs().catchError(
          (_) => <Map<String, dynamic>>[],
        ),
        homeRepo.fetchContractHint(),
      ]);
      final flags = results[0] as ScreenCompletionFlags;
      final contracts = results[1] as List<Map<String, dynamic>>;
      final hint =
          results[2] as ({String? contractId, Map<String, dynamic>? loanAccount});

      var contractId = hint.contractId;
      if (contractId == null || contractId.isEmpty) {
        for (final c in contracts) {
          final lai = c['lai']?.toString();
          if (lai != null && lai.isNotEmpty) {
            contractId = lai;
            break;
          }
        }
      }

      if (!mounted) return;
      ref.read(loansPrefetchProvider.notifier).state = LoansPrefetchState(
        contracts: contracts,
        flags: flags,
        contractId: contractId,
        loanAccount: hint.loanAccount,
        ready: true,
      );
    } catch (_) {
      // Prefetch is best-effort; My Loans will fetch on open.
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A0A5C),
        title: Text('Log out?', style: AppTypography.headline(size: 18)),
        content: Text(
          'You will need to verify OTP again to sign back in.',
          style: AppTypography.body(size: 14, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Log out',
              style: AppTypography.body(size: 14, color: AppColors.accentMint),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(profileRepositoryProvider).logoutLocal();
    if (mounted) context.go(AppRoutes.login);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = [
      _profile?['firstName'],
      _profile?['lastName'],
    ].whereType<String>().where((e) => e.trim().isNotEmpty).join(' ');
    final mobile = _profile?['mobileNumber']?.toString() ?? '';
    final photo = _profile?['profile_photo_link']?.toString();
    final userType = _profile?['userType']?.toString() ?? '';
    final hasBank = (_profile?['IFSCCode']?.toString().isNotEmpty ?? false) &&
        (_profile?['accountNumber']?.toString().isNotEmpty ?? false) &&
        (_profile?['bankName']?.toString().isNotEmpty ?? false);

    return FunnelScaffold(
      title: 'Profile',
      showBack: true,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentMint),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_error != null)
                  Text(_error!, style: AppTypography.body(size: 14)),
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final updated = await context.push<bool>(
                              AppRoutes.profileImageSelect,
                            );
                            if (updated == true && mounted) {
                              await _load();
                            }
                          },
                          customBorder: const CircleBorder(),
                          child: CircleAvatar(
                            radius: 56,
                            backgroundColor: const Color(0xFF3E1982),
                            backgroundImage: photo != null && photo.isNotEmpty
                                ? NetworkImage(photo)
                                : null,
                            child: photo == null || photo.isEmpty
                                ? Text(
                                    (name.isNotEmpty ? name[0] : '?')
                                        .toUpperCase(),
                                    style: AppTypography.headline(size: 32),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF80FFDB),
                                Color(0xFF4747E7),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/images/profile/editProfile.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name.isEmpty ? 'Zap Money user' : name,
                  textAlign: TextAlign.center,
                  style: AppTypography.headline(size: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  mobile.isEmpty ? '' : (mobile.startsWith('+91') ? mobile : '+91 $mobile'),
                  textAlign: TextAlign.center,
                  style: AppTypography.body(size: 14, color: AppColors.muted),
                ),
                if (userType.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    userType,
                    textAlign: TextAlign.center,
                    style: AppTypography.body(size: 13, color: AppColors.accentMint),
                  ),
                ],
                const SizedBox(height: 28),
                _ProfileTile(
                  asset: 'assets/images/profile/profilepersonaldetail.png',
                  label: 'Personal Details',
                  onTap: () => context.push(
                    AppRoutes.profilePersonal,
                    extra: {
                      'profile': _profile,
                      'locked': _plOrDc,
                    },
                  ),
                ),
                if (hasBank)
                  _ProfileTile(
                    asset: 'assets/images/profile/profilebank.png',
                    label: 'Bank Details',
                    onTap: () => context.push(
                      AppRoutes.profileBank,
                      extra: {
                        'profile': _profile,
                        'locked': _plOrDc,
                      },
                    ),
                  ),
                _ProfileTile(
                  asset: 'assets/images/profile/profileEmployee.png',
                  label: userType.toLowerCase() == 'student'
                      ? 'College Details'
                      : 'Employer Details',
                  onTap: () => context.push(
                    AppRoutes.profileEmployer,
                    extra: {
                      'profile': _profile,
                      'locked': _plOrDc,
                    },
                  ),
                ),
                if (userType.toLowerCase() == 'salaried')
                  _ProfileTile(
                    asset: 'assets/images/profile/profileSalary.png',
                    label: 'Salary Details',
                    onTap: () => context.push(
                      AppRoutes.profileSalary,
                      extra: {
                        'profile': _profile,
                        'locked': _dcCompleted,
                      },
                    ),
                  ),
                _ProfileTile(
                  asset: 'assets/images/profile/address.png',
                  label: 'Address',
                  onTap: () => context.push(AppRoutes.profileAddress),
                ),
                _ProfileTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'My Loans',
                  onTap: () {
                    final warm = ref.read(loansPrefetchProvider);
                    context.push(
                      AppRoutes.myLoans,
                      extra: warm.contractId,
                    );
                  },
                ),
                _ProfileTile(
                  asset: 'assets/images/profile/help.png',
                  label: 'Help & Support',
                  onTap: () => _openUrl('mailto:contact@monexo.co'),
                ),
                _ProfileTile(
                  asset: 'assets/images/profile/faq.png',
                  label: 'FAQs',
                  onTap: () => _openUrl('https://zapmoney.in/support-and-faqs/'),
                ),
                _ProfileTile(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Terms & Privacy',
                  onTap: () => _openUrl('https://zapmoney.in/privacy-policy/'),
                ),
                _ProfileTile(
                  asset: 'assets/images/profile/logoutbtn.png',
                  label: 'Log out',
                  onTap: _logout,
                ),
              ],
            ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.label,
    required this.onTap,
    this.asset,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final String? asset;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF2A0A5C),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                if (asset != null)
                  Image.asset(
                    asset!,
                    height: 24,
                    width: 24,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.circle, color: Colors.white54, size: 22),
                  )
                else
                  Icon(icon ?? Icons.circle, color: Colors.white70, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(label, style: AppTypography.body(size: 15)),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
