import 'package:flutter/services.dart';

/// Service providing native retail POS scanner audio and haptic feedback.
class SoundService {
  static const MethodChannel _channel =
      MethodChannel('in.avsmartbilling.mobile/sound');

  /// Crisp high-frequency POS barcode scanner beep.
  static Future<void> beepSuccess() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}

    try {
      await _channel.invokeMethod('beepSuccess');
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Low-frequency warning buzz tone for unknown barcodes or errors.
  static Future<void> beepError() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}

    try {
      await _channel.invokeMethod('beepError');
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }
}
