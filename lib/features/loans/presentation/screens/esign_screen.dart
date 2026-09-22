import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/esign_repository.dart';
import '../../data/references_repository.dart';

/// Opens Cashfree e-sign [signing_link] and refreshes status on return/resume.
class EsignScreen extends ConsumerStatefulWidget {
  const EsignScreen({super.key});

  @override
  ConsumerState<EsignScreen> createState() => _EsignScreenState();
}

class _EsignScreenState extends ConsumerState<EsignScreen>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  String? _error;
  bool _loading = true;
  EsignStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus(openWebViewIfNeeded: false);
    }
  }

  Future<void> _bootstrap() async {
    // References must be completed before e-sign.
    try {
      final refs = await ref.read(referencesRepositoryProvider).fetchStatus();
      if (!mounted) return;
      if (!refs.complete) {
        context.go(AppRoutes.references);
        return;
      }
    } catch (_) {
      // If status check fails, still attempt e-sign; disbursement gate remains.
    }
    await _refreshStatus(openWebViewIfNeeded: true);
  }

  Future<void> _refreshStatus({required bool openWebViewIfNeeded}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await ref
          .read(esignRepositoryProvider)
          .fetchStatus(refresh: true);
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
      if (status.isSigned) {
        return;
      }
      final link = status.signingLink?.trim() ?? '';
      if (openWebViewIfNeeded && link.isNotEmpty) {
        _controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (_) {
                // Soft refresh after Cashfree page settles.
                Future<void>.delayed(const Duration(seconds: 2), () {
                  if (mounted) _refreshStatus(openWebViewIfNeeded: false);
                });
              },
            ),
          )
          ..loadRequest(Uri.parse(link));
        setState(() {});
      } else if (!status.exists || link.isEmpty) {
        setState(() {
          _error =
              'No e-sign agreement is ready yet. Please wait for LOS to send it.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final signed = _status?.isSigned == true;
    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      appBar: AppBar(
        backgroundColor: AppColors.deepPurple,
        foregroundColor: Colors.white,
        title: Text('Loan agreement', style: AppTypography.headline(size: 18)),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshStatus(openWebViewIfNeeded: true),
          ),
        ],
      ),
      body: signed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.accentMint, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      'Agreement signed successfully',
                      style: AppTypography.headline(size: 20),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.go(AppRoutes.home),
                      child: const Text('Back to home'),
                    ),
                  ],
                ),
              ),
            )
          : _loading && _controller == null
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _controller == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, style: AppTypography.body(), textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () =>
                                  _refreshStatus(openWebViewIfNeeded: true),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _controller == null
                      ? Center(
                          child: Text(
                            'Waiting for signing link…',
                            style: AppTypography.body(),
                          ),
                        )
                      : WebViewWidget(controller: _controller!),
    );
  }
}
