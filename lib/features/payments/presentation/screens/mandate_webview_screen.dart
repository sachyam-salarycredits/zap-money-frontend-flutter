import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/theme/app_theme.dart';

/// Detects Cashfree / LotusPay eNACH return URLs (RN enach WebView heuristics).
bool isEnachReturnUrl(String url) {
  final navUrl = url.toLowerCase();
  return navUrl.contains('app.lotuspay.com/npci_onmags_response') ||
      navUrl.contains('status=success') ||
      navUrl.contains('subscription_status=active') ||
      (navUrl.contains('cashfreeenachcheckout') &&
          navUrl.contains('source_id=') &&
          !navUrl.contains('subssessionid=')) ||
      (navUrl.contains('source_id=') && !navUrl.contains('subssessionid='));
}

class MandateWebViewScreen extends StatefulWidget {
  const MandateWebViewScreen({
    super.key,
    required this.initialUrl,
    required this.onSuccess,
    this.onClose,
  });

  final String initialUrl;
  final VoidCallback onSuccess;
  final VoidCallback? onClose;

  @override
  State<MandateWebViewScreen> createState() => _MandateWebViewScreenState();
}

class _MandateWebViewScreenState extends State<MandateWebViewScreen> {
  late final WebViewController _controller;
  var _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            _maybeComplete(request.url);
            return NavigationDecision.navigate;
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) _maybeComplete(url);
          },
          onPageFinished: _maybeComplete,
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  void _maybeComplete(String url) {
    if (_finished) return;
    if (!isEnachReturnUrl(url)) return;
    _finished = true;
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      appBar: AppBar(
        backgroundColor: AppColors.deepPurple,
        title: Text('eNACH', style: AppTypography.headline(size: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            widget.onClose?.call();
            Navigator.of(context).maybePop();
          },
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
