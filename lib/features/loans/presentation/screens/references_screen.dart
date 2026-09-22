import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/esign_repository.dart';
import '../../data/references_repository.dart';

/// Collect exactly two personal references after funding, before e-sign.
class ReferencesScreen extends ConsumerStatefulWidget {
  const ReferencesScreen({super.key});

  @override
  ConsumerState<ReferencesScreen> createState() => _ReferencesScreenState();
}

class _ReferencesScreenState extends ConsumerState<ReferencesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name1 = TextEditingController();
  final _relation1 = TextEditingController();
  final _mobile1 = TextEditingController();
  final _name2 = TextEditingController();
  final _relation2 = TextEditingController();
  final _mobile2 = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  static final _mobileRe = RegExp(r'^[6-9]\d{9}$');
  static final _nameRe = RegExp(r"^[A-Za-z][A-Za-z\s'.-]{0,126}$");

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _name1.dispose();
    _relation1.dispose();
    _mobile1.dispose();
    _name2.dispose();
    _relation2.dispose();
    _mobile2.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await ref.read(referencesRepositoryProvider).fetchStatus();
      if (!mounted) return;
      if (status.complete) {
        context.go(AppRoutes.home);
        return;
      }
      if (status.references.length >= 1) {
        final r1 = status.references[0];
        _name1.text = '${r1['name'] ?? ''}';
        _relation1.text = '${r1['relation'] ?? ''}';
        _mobile1.text = '${r1['mobile_number'] ?? ''}';
      }
      if (status.references.length >= 2) {
        final r2 = status.references[1];
        _name2.text = '${r2['name'] ?? ''}';
        _relation2.text = '${r2['relation'] ?? ''}';
        _mobile2.text = '${r2['mobile_number'] ?? ''}';
      }
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String? _validateName(String? value, String label) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter $label name';
    if (!_nameRe.hasMatch(v)) return 'Use letters only for $label name';
    return null;
  }

  String? _validateRelation(String? value, String label) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter relation for $label';
    if (!_nameRe.hasMatch(v)) return 'Use letters only for relation';
    return null;
  }

  String? _validateMobile(String? value, String label) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter $label mobile';
    if (!_mobileRe.hasMatch(v)) {
      return 'Enter a valid 10-digit Indian mobile';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final m1 = _mobile1.text.trim();
    final m2 = _mobile2.text.trim();
    if (m1 == m2) {
      setState(() => _error = 'Both references must have different mobile numbers');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(referencesRepositoryProvider).saveReferences(
            name1: _name1.text,
            relation1: _relation1.text,
            mobile1: m1,
            name2: _name2.text,
            relation2: _relation2.text,
            mobile2: m2,
          );
      if (!mounted) return;
      // After references, continue to e-sign when a signing link is available.
      try {
        final esign =
            await ref.read(esignRepositoryProvider).fetchStatus(refresh: false);
        if (!mounted) return;
        if (esign.isSigned) {
          context.go(AppRoutes.home);
          return;
        }
        if ((esign.signingLink ?? '').trim().isNotEmpty) {
          context.go(AppRoutes.esign);
          return;
        }
      } catch (_) {
        // Fall through to home if e-sign status is unavailable.
      }
      if (!mounted) return;
      context.go(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTypography.body(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accentMint),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(text, style: AppTypography.headline(size: 18)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      appBar: AppBar(
        backgroundColor: AppColors.deepPurple,
        foregroundColor: Colors.white,
        title: Text('References', style: AppTypography.headline(size: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Text(
                      'Add 2 personal references before signing your loan agreement.',
                      style: AppTypography.body(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    _sectionTitle('Reference 1'),
                    TextFormField(
                      controller: _name1,
                      style: AppTypography.body(),
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration('Full name'),
                      validator: (v) => _validateName(v, 'reference 1'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _relation1,
                      style: AppTypography.body(),
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration('Relation'),
                      validator: (v) => _validateRelation(v, 'reference 1'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _mobile1,
                      style: AppTypography.body(),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: _decoration('Mobile number'),
                      validator: (v) => _validateMobile(v, 'reference 1'),
                    ),
                    _sectionTitle('Reference 2'),
                    TextFormField(
                      controller: _name2,
                      style: AppTypography.body(),
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration('Full name'),
                      validator: (v) => _validateName(v, 'reference 2'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _relation2,
                      style: AppTypography.body(),
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration('Relation'),
                      validator: (v) => _validateRelation(v, 'reference 2'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _mobile2,
                      style: AppTypography.body(),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: _decoration('Mobile number'),
                      validator: (v) => _validateMobile(v, 'reference 2'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: AppTypography.body(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit references'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
