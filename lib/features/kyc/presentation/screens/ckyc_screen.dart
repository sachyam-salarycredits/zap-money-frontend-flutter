import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../data/ckyc_repository.dart';

class CkycScreen extends ConsumerStatefulWidget {
  const CkycScreen({super.key});

  @override
  ConsumerState<CkycScreen> createState() => _CkycScreenState();
}

class _CkycScreenState extends ConsumerState<CkycScreen> {
  bool _loading = false;
  String? _error;
  int? _sessionId;
  List<Map<String, dynamic>> _hits = [];
  String? _otpMessage;
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(ckycRepositoryProvider);
      final data = await repo.search();
      final hits = (data['hits'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      setState(() {
        _sessionId = data['sessionId'] as int?;
        _hits = hits;
        _loading = false;
      });
      if (hits.length == 1) {
        await _generateOtp();
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _selectAndContinue(String referenceId) async {
    if (_sessionId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(ckycRepositoryProvider).selectHit(
            sessionId: _sessionId!,
            referenceId: referenceId,
          );
      await _generateOtp();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _generateOtp() async {
    if (_sessionId == null) return;
    try {
      final data = await ref.read(ckycRepositoryProvider).generateOtp(
            sessionId: _sessionId!,
          );
      setState(() {
        _loading = false;
        _otpMessage = data['message'] as String?;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _validateOtp() async {
    if (_sessionId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(ckycRepositoryProvider).validateOtp(
            sessionId: _sessionId!,
            otp: _otpController.text.trim(),
          );
      if (!mounted) return;
      context.go(AppRoutes.dkyc);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showOtp = _otpMessage != null && _otpMessage!.isNotEmpty;
    final showPicker = _hits.length > 1 && !showOtp;

    return FunnelScaffold(
      title: 'CKYC',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Retrieve your KYC from the central registry using OTP on your registered mobile.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.warning)),
            if (showPicker) ...[
              const Text('Multiple CKYC records found. Select yours:'),
              const SizedBox(height: 8),
              ..._hits.map(
                (hit) => Card(
                  child: ListTile(
                    title: Text('${hit['fullName'] ?? ''}'),
                    subtitle: Text('Ref: ${hit['referenceId'] ?? ''}'),
                    onTap: _loading
                        ? null
                        : () => _selectAndContinue('${hit['referenceId']}'),
                  ),
                ),
              ),
            ],
            if (showOtp) ...[
              Text(_otpMessage!),
              const SizedBox(height: 12),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'CKYC OTP'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loading ? null : _validateOtp,
                child: const Text('Submit OTP'),
              ),
            ],
            if (!showOtp && !showPicker) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _runSearch,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Search CKYC'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
