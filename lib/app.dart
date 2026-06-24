import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/routes.dart';
import 'config/theme.dart';

class SacoStayApp extends ConsumerWidget {
  const SacoStayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SacoStay',
      debugShowCheckedModeBanner: false,
      theme: SacoTheme.light(),
      routerConfig: router,
    );
  }
}
