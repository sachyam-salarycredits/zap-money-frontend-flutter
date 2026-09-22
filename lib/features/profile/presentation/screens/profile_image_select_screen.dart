import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/profile_repository.dart';

class ProfileImageSelectScreen extends ConsumerStatefulWidget {
  const ProfileImageSelectScreen({super.key});

  @override
  ConsumerState<ProfileImageSelectScreen> createState() =>
      _ProfileImageSelectScreenState();
}

class _ProfileImageSelectScreenState
    extends ConsumerState<ProfileImageSelectScreen> {
  static const _illustrationPresets = [
    'assets/images/profile/picker/books.png',
    'assets/images/profile/picker/IconBusiness.png',
    'assets/images/profile/picker/spacecraft.png',
  ];

  static const _emojiPresets = [
    'assets/images/profile/picker/owl.png',
    'assets/images/profile/picker/bird.png',
    'assets/images/profile/picker/bunny.png',
  ];

  final _picker = ImagePicker();
  XFile? _pendingPick;
  bool _uploading = false;

  Future<void> _toast(String message) {
    if (!mounted) return Future.value();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    return Future.value();
  }

  Future<void> _uploadPreset(int profileKey) async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final ok = await ref
          .read(profileRepositoryProvider)
          .uploadProfilePhotoFromPreset(profileKey);
      if (!mounted) return;
      if (ok) {
        await _toast('Profile photo updated');
        context.pop(true);
      } else {
        await _toast('Could not update profile photo');
      }
    } catch (_) {
      if (mounted) await _toast('Could not update profile photo');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_uploading) return;
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 500,
      maxHeight: 500,
    );
    if (file == null) return;

    setState(() {
      _pendingPick = file;
      _uploading = true;
    });
    try {
      final ok = await ref.read(profileRepositoryProvider).uploadProfilePhoto(
            filePath: file.path,
            fileName: file.name,
          );
      if (!mounted) return;
      if (ok) {
        await _toast('Profile photo updated');
        context.pop(true);
      } else {
        await _toast('Could not update profile photo');
      }
    } catch (_) {
      if (mounted) await _toast('Could not update profile photo');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _showSourcePicker() async {
    if (_uploading) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF4A2B8C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose photo source',
                  style: AppTypography.body(size: 16, weight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.photo_camera_outlined,
                        label: 'Camera',
                        onTap: () => Navigator.pop(ctx, ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.photo_library_outlined,
                        label: 'Gallery',
                        onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null) return;
    await _pickImage(source);
  }

  Future<void> _uploadPending() async {
    final file = _pendingPick;
    if (file == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      final ok = await ref.read(profileRepositoryProvider).uploadProfilePhoto(
            filePath: file.path,
            fileName: file.name,
          );
      if (!mounted) return;
      if (ok) {
        await _toast('Profile photo updated');
        context.pop(true);
      } else {
        await _toast('Could not update profile photo');
      }
    } catch (_) {
      if (mounted) await _toast('Could not update profile photo');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/profile/picker/Profile_pic_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: _uploading ? null : () => context.pop(),
                  icon: Image.asset(
                    'assets/images/profile/picker/close.png',
                    width: 28,
                    height: 28,
                    color: Colors.white,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    'Select your\nprofile image',
                    style: AppTypography.headline(size: 28),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        _PresetRow(
                          assets: _illustrationPresets,
                          keyOffset: 0,
                          onTap: _uploadPreset,
                          disabled: _uploading,
                        ),
                        _PresetRow(
                          assets: _emojiPresets,
                          keyOffset: 3,
                          onTap: _uploadPreset,
                          disabled: _uploading,
                          rainbowIndex: 2,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ActionCircle(
                              asset: 'assets/images/profile/picker/camera.png',
                              onTap: _showSourcePicker,
                              disabled: _uploading,
                            ),
                            const SizedBox(width: 30),
                            _ActionCircle(
                              asset: 'assets/images/profile/picker/gallery.png',
                              onTap: _showSourcePicker,
                              disabled: _uploading,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_pendingPick != null && !_uploading)
                          ? _uploadPending
                          : null,
                      child: const Text('Set Profile'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_uploading)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accentMint),
              ),
            ),
        ],
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.assets,
    required this.keyOffset,
    required this.onTap,
    required this.disabled,
    this.rainbowIndex,
  });

  final List<String> assets;
  final int keyOffset;
  final Future<void> Function(int profileKey) onTap;
  final bool disabled;
  final int? rainbowIndex;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (var i = 0; i < assets.length; i++)
            Padding(
              padding: const EdgeInsets.all(8),
              child: _PresetCircle(
                asset: assets[i],
                profileKey: keyOffset + i,
                onTap: onTap,
                disabled: disabled,
                showRainbow: rainbowIndex == i,
              ),
            ),
        ],
      ),
    );
  }
}

class _PresetCircle extends StatelessWidget {
  const _PresetCircle({
    required this.asset,
    required this.profileKey,
    required this.onTap,
    required this.disabled,
    this.showRainbow = false,
  });

  final String asset;
  final int profileKey;
  final Future<void> Function(int profileKey) onTap;
  final bool disabled;
  final bool showRainbow;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(asset, width: 70, height: 70, fit: BoxFit.contain);

    if (showRainbow) {
      image = Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(41),
          image: const DecorationImage(
            image: AssetImage('assets/images/profile/picker/renbow.png'),
            fit: BoxFit.cover,
          ),
        ),
        alignment: Alignment.center,
        child: Image.asset(asset, width: 70, height: 70, fit: BoxFit.contain),
      );
    }

    return InkWell(
      onTap: disabled ? null : () => onTap(profileKey),
      borderRadius: BorderRadius.circular(45),
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: const Color(0xFF3E1982),
          borderRadius: BorderRadius.circular(45),
        ),
        alignment: Alignment.center,
        child: image,
      ),
    );
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.asset,
    required this.onTap,
    required this.disabled,
  });

  final String asset;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(45),
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: const Color(0xFF3E1982),
          borderRadius: BorderRadius.circular(45),
        ),
        alignment: Alignment.center,
        child: Image.asset(asset, width: 30, height: 30, fit: BoxFit.contain),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF3E1982),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 8),
            Text(label, style: AppTypography.body(size: 13)),
          ],
        ),
      ),
    );
  }
}
