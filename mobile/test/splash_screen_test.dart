import 'package:av_smartbilling_mobile/src/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows branded splash while the app initializes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AnimatedSplashScreen()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('AV Smartbilling'), findsOneWidget);
    expect(find.text('Fast, simple billing for your business'), findsOneWidget);
    expect(find.text('Preparing your billing workspace…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('offers retry when initialization fails', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedSplashScreen(error: true, onRetry: () => retried = true),
      ),
    );

    expect(
      find.text('AV Smartbilling could not start. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });
}
