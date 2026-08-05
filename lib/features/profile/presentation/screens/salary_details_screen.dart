import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../data/profile_repository.dart';

/// RN `SalaryDetailProfile` — 3 PDF slots + password + Upload.
class ProfileSalaryScreen extends ConsumerStatefulWidget {
  const ProfileSalaryScreen({super.key, this.args});

  final Map<String, dynamic>? args;

  @override
  ConsumerState<ProfileSalaryScreen> createState() =>
      _ProfileSalaryScreenState();
}

class _PickedSlip {
  const _PickedSlip({
    required this.path,
    required this.name,
    required this.slot,
  });

  final String path;
  final String name;
  final int slot; // 1..3
}

class _ProfileSalaryScreenState extends ConsumerState<ProfileSalaryScreen> {
  final _password = TextEditingController();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _uploading = false;
  _PickedSlip? _pending;

  bool get _locked => widget.args?['locked'] == true;

  @override
  void initState() {
    super.initState();
    final initial = (widget.args?['profile'] as Map?)?.cast<String, dynamic>();
    _profile = initial;
    _password.text = initial?['Payslip_password']?.toString() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final profile = await ref.read(profileRepositoryProvider).fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile ?? _profile;
        if ((_password.text).isEmpty) {
          _password.text = profile?['Payslip_password']?.toString() ?? '';
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _remoteSlip(int index) {
    final slips = _profile?['salary_slip'];
    if (slips is! List || index >= slips.length) return null;
    final v = slips[index]?.toString().trim();
    if (v == null || v.isEmpty || v == 'null') return null;
    return v;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openSlip(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _toast('Invalid salary slip link');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _toast('Could not open salary slip');
  }

  Future<void> _pick(int slot) async {
    if (_locked) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final path = file.path;
      if (path == null || path.isEmpty) {
        _toast('Could not read selected file');
        return;
      }
      final name = file.name;
      if (!name.toLowerCase().endsWith('.pdf') &&
          file.extension?.toLowerCase() != 'pdf') {
        _toast('Please Select pdf file only');
        return;
      }
      if (file.size > 3000000) {
        _toast('File size exceeds the limit 3MB');
        return;
      }
      setState(() {
        _pending = _PickedSlip(path: path, name: name, slot: slot);
      });
    } catch (_) {
      _toast('Could not open file picker. Please try again.');
    }
  }

  Future<void> _upload() async {
    final pending = _pending;
    if (pending == null) {
      _toast('Please select a salary slip PDF first');
      return;
    }
    setState(() => _uploading = true);
    try {
      final ok = await ref.read(profileRepositoryProvider).uploadSalarySlip(
            documentName: 'salary_slip ${pending.slot}',
            filePath: pending.path,
            fileName: pending.name,
            password: _password.text.trim(),
          );
      if (!mounted) return;
      if (ok) {
        _toast('Uploaded successfully');
        setState(() => _pending = null);
        await _refresh();
      } else {
        _toast('Upload failed. Please try again.');
      }
    } catch (_) {
      _toast('Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'Salary Details',
      bottom: _locked
          ? null
          : ZapSubmitButton(
              title: _uploading ? 'Uploading…' : 'Upload',
              disabled: _uploading,
              onPressed: _upload,
            ),
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentMint),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  'Salary Slips',
                  style: AppTypography.body(size: 12, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 1; i <= 3; i++) ...[
                      if (i > 1) const SizedBox(width: 10),
                      Expanded(child: _slotTile(i)),
                    ],
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'File Password (If Any)',
                  style: AppTypography.body(size: 12, color: Colors.white),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _password,
                  enabled: !_locked && !_uploading,
                  obscureText: true,
                  cursorColor: Colors.white,
                  style: AppTypography.body(size: 16),
                  decoration: InputDecoration(
                    hintText: 'Enter your password ',
                    hintStyle:
                        AppTypography.body(size: 16, color: AppColors.muted),
                    filled: true,
                    fillColor: const Color(0xFF2A0A5C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_locked) ...[
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

  Widget _slotTile(int slot) {
    final remote = _remoteSlip(slot - 1);
    final pendingHere = _pending?.slot == slot;
    final hasFile = pendingHere || (remote != null && remote.isNotEmpty);

    return AspectRatio(
      aspectRatio: 0.85,
      child: Material(
        color: const Color(0xFF2A0A5C),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (!hasFile) {
              _pick(slot);
            } else if (pendingHere) {
              // Local pending — nothing to open yet.
            } else {
              _openSlip(remote);
            }
          },
          child: Stack(
            children: [
              Center(
                child: hasFile
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/profile/pdfupload.png',
                            height: 40,
                            width: 40,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.picture_as_pdf,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          if (pendingHere) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Ready',
                              style: AppTypography.body(
                                size: 9,
                                color: AppColors.accentMint,
                              ),
                            ),
                          ],
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Upload for',
                            style: AppTypography.body(
                              size: 9,
                              color: const Color(0xFFAC9FC6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Image.asset(
                            'assets/images/profile/uploadImage.png',
                            height: 18,
                            width: 18,
                            color: const Color(0xFFAC9FC6),
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.upload_file,
                              size: 18,
                              color: Color(0xFFAC9FC6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Month $slot',
                            style: AppTypography.body(
                              size: 9,
                              color: const Color(0xFFAC9FC6),
                            ),
                          ),
                        ],
                      ),
              ),
              if (hasFile && !_locked)
                Positioned(
                  top: 8,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _pick(slot),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/profile/editicon.png',
                          height: 10,
                          width: 10,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.edit,
                            size: 10,
                            color: AppColors.accentMint,
                          ),
                        ),
                        Text(
                          ' Edit',
                          style: AppTypography.body(
                            size: 9,
                            color: AppColors.accentMint,
                          ),
                        ),
                      ],
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
