import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../data/profile_repository.dart';

class ProfilePersonalScreen extends StatelessWidget {
  const ProfilePersonalScreen({super.key, this.args});

  final Map<String, dynamic>? args;

  @override
  Widget build(BuildContext context) {
    final profile = (args?['profile'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final locked = args?['locked'] == true;
    return FunnelScaffold(
      title: 'Personal Details',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _kv('First name', profile['firstName']),
          _kv('Last name', profile['lastName']),
          _kv('Email', profile['emailId']),
          _kv('Mobile', profile['mobileNumber']),
          _kv('Gender', profile['gender']),
          _kv('Aadhaar', profile['aadhaar_number']),
          if (locked) ...[
            const SizedBox(height: 12),
            Text(
              'Editing is locked after loan offer completion.',
              style: AppTypography.body(size: 13, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class ProfileBankScreen extends StatelessWidget {
  const ProfileBankScreen({super.key, this.args});

  final Map<String, dynamic>? args;

  @override
  Widget build(BuildContext context) {
    final profile = (args?['profile'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final locked = args?['locked'] == true;
    return FunnelScaffold(
      title: 'Bank Details',
      bottom: locked
          ? null
          : ZapSubmitButton(
              title: 'Edit bank details',
              onPressed: () => context.push(AppRoutes.bankDetails),
            ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _kv('Bank name', profile['bankName']),
          _kv('Account number', profile['accountNumber']),
          _kv('IFSC', profile['IFSCCode']),
          _kv('Branch', profile['bank_branch']),
          if (locked) ...[
            const SizedBox(height: 12),
            Text(
              'Bank details are view-only after offer completion.',
              style: AppTypography.body(size: 13, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class ProfileEmployerScreen extends ConsumerStatefulWidget {
  const ProfileEmployerScreen({super.key, this.args});

  final Map<String, dynamic>? args;

  @override
  ConsumerState<ProfileEmployerScreen> createState() =>
      _ProfileEmployerScreenState();
}

class _ProfileEmployerScreenState extends ConsumerState<ProfileEmployerScreen> {
  Map<String, dynamic>? _office;
  bool _loading = true;

  Map<String, dynamic> get _profile =>
      (widget.args?['profile'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};

  bool get _locked => widget.args?['locked'] == true;

  bool get _isStudent =>
      (_profile['userType']?.toString().toLowerCase() ?? '') == 'student';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOffice());
  }

  Future<void> _loadOffice() async {
    if (_isStudent) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final office =
          await ref.read(profileRepositoryProvider).fetchOfficeAddress();
      if (mounted) {
        setState(() {
          _office = office;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: _isStudent ? 'College Details' : 'Employer Details',
      bottom: _locked
          ? null
          : ZapSubmitButton(
              title: 'Edit',
              onPressed: () => context.push(
                _isStudent
                    ? AppRoutes.collegeDetails
                    : AppRoutes.employerDetails,
                extra: _isStudent ? null : {'isFrom': 'editProfile'},
              ),
            ),
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentMint),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: _isStudent
                  ? [
                      _kv('College name', _profile['companyName']),
                      _kv('Parent phone number', _profile['phoneNumber']),
                    ]
                  : [
                      // RN EmployerDetailsProfile: company + office address fields
                      _kv('Company name', _profile['companyName']),
                      _kv('Pin code', _office?['pincode']),
                      _kv('City', _office?['city']),
                      _kv('State', _office?['state']),
                      _kv('Full address', _office?['address']),
                    ],
            ),
    );
  }
}

class ProfileAddressScreen extends ConsumerStatefulWidget {
  const ProfileAddressScreen({super.key});

  @override
  ConsumerState<ProfileAddressScreen> createState() =>
      _ProfileAddressScreenState();
}

class _ProfileAddressScreenState extends ConsumerState<ProfileAddressScreen> {
  Map<String, dynamic>? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final addr = await ref
            .read(profileRepositoryProvider)
            .fetchResidentialAddress();
        if (mounted) {
          setState(() {
            _info = addr;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final addrMap = _info;

    return FunnelScaffold(
      title: 'Address',
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentMint),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (addrMap != null &&
                    (addrMap['address']?.toString().trim().isNotEmpty == true ||
                        addrMap['postal']?.toString().trim().isNotEmpty ==
                            true)) ...[
                  _kv('Address', addrMap['address']),
                  _kv('City', addrMap['city']),
                  _kv('State', addrMap['state']),
                  _kv('Pincode', addrMap['postal']),
                ] else ...[
                  Text(
                    'No address on file yet.',
                    style: AppTypography.body(size: 14, color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  ZapSubmitButton(
                    title: 'Add address',
                    onPressed: () => context.push(AppRoutes.residenceAddress),
                  ),
                ],
              ],
            ),
    );
  }
}

Widget _kv(String label, dynamic value) {
  final text = value?.toString().trim();
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.body(size: 12, color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(
          (text == null || text.isEmpty) ? '—' : text,
          style: AppTypography.body(size: 16),
        ),
      ],
    ),
  );
}
