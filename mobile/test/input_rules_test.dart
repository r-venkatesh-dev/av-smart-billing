import 'package:av_smartbilling_mobile/src/input_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile number validation allows only blank or exactly 10 digits', () {
    expect(validateOptionalMobileNumber(''), isNull);
    expect(validateOptionalMobileNumber('9876543210'), isNull);
    expect(validateOptionalMobileNumber('987654321'), isNotNull);
    expect(validateOptionalMobileNumber('98765432101'), isNotNull);
    expect(validateOptionalMobileNumber('98765abc10'), isNotNull);
    expect(validateRequiredMobileNumber(''), isNotNull);
  });

  test(
    'license formatter uppercases and inserts hyphens every four characters',
    () {
      const formatter = LicenseKeyInputFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: 'ab12cd34-ef56 gh78extra'),
      );

      expect(result.text, 'AB12-CD34-EF56-GH78');
      expect(result.selection.baseOffset, result.text.length);
    },
  );

  test('license formatter adds a hyphen as soon as a group is complete', () {
    const formatter = LicenseKeyInputFormatter();
    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: 'ABC'),
      const TextEditingValue(text: 'ABCD'),
    );

    expect(result.text, 'ABCD-');
  });

  test('backspace over an automatic license hyphen removes a character', () {
    const formatter = LicenseKeyInputFormatter();
    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: 'ABCD-'),
      const TextEditingValue(text: 'ABCD'),
    );

    expect(result.text, 'ABC');
  });

  test('mobile input formatters remove non-digits and stop at 10 digits', () {
    var value = const TextEditingValue(text: '98a7654321012');
    for (final formatter in mobileNumberInputFormatters) {
      value = formatter.formatEditUpdate(TextEditingValue.empty, value);
    }
    expect(value.text, '9876543210');
  });
}
