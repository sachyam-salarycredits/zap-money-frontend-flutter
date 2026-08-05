import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../router/app_router.dart';

class ZapMoneyApp extends ConsumerWidget {
  const ZapMoneyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Zap Money',
      debugShowCheckedModeBanner: false,
      theme: buildZapTheme(),
      routerConfig: router,
    );
  }
}
