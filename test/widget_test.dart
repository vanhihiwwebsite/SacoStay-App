import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sacostay/config/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('SacoStay theme smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SacoTheme.light(),
        home: const Scaffold(
          body: Center(child: Text('SacoStay')),
        ),
      ),
    );

    expect(find.text('SacoStay'), findsOneWidget);
  });
}
