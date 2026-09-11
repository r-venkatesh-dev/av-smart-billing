import 'package:av_smartbilling_mobile/src/app.dart';
import 'package:av_smartbilling_mobile/src/screens/activation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders ActivationScreen with free trial button', (tester) async {
    final widget = MaterialApp(
      home: ActivationScreen(controller: FakeAppController()),
    );

    await tester.pumpWidget(widget);

    expect(find.text('AV Smartbilling'), findsOneWidget);
    expect(find.text('Activate this device'), findsOneWidget);
    expect(find.text("Don't have a key?"), findsOneWidget);
    expect(find.text('Start Free Trial'), findsOneWidget);
  });
}

class FakeAppController extends ChangeNotifier implements AppController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
