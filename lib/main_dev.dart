import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/zap_money_app.dart';

/// Dev entry — same as main; use dart-defines for env overrides.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ZapMoneyApp()));
}
