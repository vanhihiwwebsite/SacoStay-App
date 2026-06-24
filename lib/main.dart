import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/user_prefs.dart';
import 'features/auth/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final userPrefs = await UserPrefs.create();
  final container = ProviderContainer(
    overrides: [
      userPrefsProvider.overrideWithValue(userPrefs),
    ],
  );

  await container.read(authControllerProvider.notifier).bootstrap();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SacoStayApp(),
    ),
  );
}
