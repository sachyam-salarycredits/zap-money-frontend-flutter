import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';

class UpiMandateIntentScreen extends StatefulWidget {
  const UpiMandateIntentScreen({
    super.key,
    required this.intent,
    required this.onApproved,
    this.mandateUrl,
    this.onWebCheckout,
    this.onClose,
  });

  final Map<String, dynamic> intent;
  final Future<void> Function() onApproved;
  final String? mandateUrl;
  final VoidCallback? onWebCheckout;
  final VoidCallback? onClose;

  @override
  State<UpiMandateIntentScreen> createState() => _UpiMandateIntentScreenState();
}

class _UpiMandateIntentScreenState extends State<UpiMandateIntentScreen> {
  String? _status;
  var _launching = false;

  Map<String, String> get _apps {
    final raw = widget.intent['apps'];
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.value is String && (e.value as String).trim().isNotEmpty)
          e.key.toString().toUpperCase(): (e.value as String).trim(),
    };
  }

  String? get _defaultLink {
    final d = widget.intent['default']?.toString().trim();
    if (d != null && d.isNotEmpty) return d;
    return _apps['DEFAULT'] ?? (_apps.isEmpty ? null : _apps.values.first);
  }

  List<MapEntry<String, String>> get _choices {
    final apps = Map<String, String>.from(_apps);
    apps.remove('DEFAULT');
    if (apps.isEmpty && _defaultLink != null) {
      return [MapEntry('UPI app', _defaultLink!)];
    }
    const order = ['GPAY', 'PHONEPE', 'PAYTM', 'BHIM', 'AMAZONPAY'];
    final ordered = <MapEntry<String, String>>[];
    for (final key in order) {
      final url = apps.remove(key);
      if (url != null) ordered.add(MapEntry(key, url));
    }
    ordered.addAll(apps.entries);
    return ordered;
  }

  String _label(String key) {
    switch (key.toUpperCase()) {
      case 'GPAY':
        return 'Google Pay';
      case 'PHONEPE':
        return 'PhonePe';
      case 'PAYTM':
        return 'Paytm';
      case 'BHIM':
        return 'BHIM';
      case 'AMAZONPAY':
        return 'Amazon Pay';
      default:
        return key;
    }
  }

  Future<void> _launch(String raw) async {
    setState(() {
      _launching = true;
      _status = 'Opening UPI app…';
    });
    try {
      final uri = Uri.parse(raw);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() {
        _status = ok
            ? 'Approve the mandate in your UPI app, then tap I’ve approved.'
            : 'Could not open that UPI app. Try another, or web checkout.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = 'Could not open that UPI app.');
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = _choices;
    final defaultLink = _defaultLink;

    return FunnelScaffold(
      title: 'Approve UPI Autopay',
      subtitle: 'Open your UPI app to authorize EMI collection.',
      onBack: () {
        widget.onClose?.call();
        Navigator.of(context).maybePop();
      },
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ZapSubmitButton(
            title: 'I’ve approved',
            onPressed: () async {
              setState(() => _status = 'Checking mandate status…');
              await widget.onApproved();
            },
          ),
          if (widget.mandateUrl != null && widget.onWebCheckout != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.onWebCheckout,
              child: Text(
                'Use web checkout instead',
                style: AppTypography.body(size: 14, color: AppColors.accentMint),
              ),
            ),
          ],
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            Platform.isIOS
                ? 'Choose an app to authorize the mandate.'
                : 'Choose a UPI app. This opens a mandate intent, not a one-time payment.',
            style: AppTypography.body(size: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (defaultLink != null)
            ZapSubmitButton(
              title: _launching ? 'Opening…' : 'Open UPI app',
              onPressed: _launching ? null : () => _launch(defaultLink),
            ),
          if (choices.length > 1) ...[
            const SizedBox(height: 20),
            Text('Or pick an app', style: AppTypography.headline(size: 16)),
            const SizedBox(height: 8),
            for (final e in choices)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_label(e.key), style: AppTypography.body(size: 15)),
                trailing: const Icon(Icons.open_in_new, color: Colors.white70),
                onTap: _launching ? null : () => _launch(e.value),
              ),
          ],
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(
              _status!,
              style: AppTypography.body(size: 14, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
