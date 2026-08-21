import 'package:av_smartbilling_mobile/src/security_service.dart';
import 'package:av_smartbilling_mobile/src/screens/security_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new app PIN must contain exactly six digits', () {
    expect(validateNewAppPin('123456'), isNull);
    expect(validateNewAppPin('12345'), isNotNull);
    expect(validateNewAppPin('1234567'), isNotNull);
    expect(validateNewAppPin('12a456'), isNotNull);
    expect(validateNewAppPin(''), isNotNull);
  });

  testWidgets('PIN setup dialog closes cleanly after confirmation', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => const AppPinDialog(
                    title: 'Create App PIN',
                    confirm: true,
                    allowLegacy: false,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New 6-digit PIN'),
      '123456',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm 6-digit PIN'),
      '123456',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(result, '123456');
    expect(find.text('Create App PIN'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
