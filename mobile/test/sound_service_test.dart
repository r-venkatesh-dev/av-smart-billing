import 'package:av_smartbilling_mobile/src/sound_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SoundService invokes platform channel methods cleanly without throwing', () async {
    final List<MethodCall> calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('in.avsmartbilling.mobile/sound'),
      (MethodCall methodCall) async {
        calls.add(methodCall);
        return true;
      },
    );

    await SoundService.beepSuccess();
    expect(calls.map((c) => c.method), contains('beepSuccess'));

    await SoundService.beepError();
    expect(calls.map((c) => c.method), contains('beepError'));
  });

  test('SoundService handles platform channel exceptions gracefully', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('in.avsmartbilling.mobile/sound'),
      (MethodCall methodCall) async {
        throw PlatformException(code: 'UNAVAILABLE');
      },
    );

    // Should not throw
    await SoundService.beepSuccess();
    await SoundService.beepError();
  });
}
