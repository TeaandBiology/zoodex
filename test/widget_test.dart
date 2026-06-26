import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoodex/widgets/chip.dart';

// A tiny smoke test that needs no device storage, so `flutter test` passes out
// of the box. Add fuller tests as the app grows.
void main() {
  testWidgets('AppChip shows its label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppChip(label: 'Mammals'))),
    );
    expect(find.text('Mammals'), findsOneWidget);
  });
}
