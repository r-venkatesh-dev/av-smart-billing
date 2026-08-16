import 'package:flutter/services.dart';

final mobileNumberInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(10),
];

String? validateOptionalMobileNumber(String? value) {
  final phone = (value ?? '').trim();
  return phone.isEmpty || RegExp(r'^\d{10}$').hasMatch(phone)
      ? null
      : 'Enter a valid 10-digit mobile number.';
}

String? validateRequiredMobileNumber(String? value) {
  final phone = (value ?? '').trim();
  return RegExp(r'^\d{10}$').hasMatch(phone)
      ? null
      : 'Enter a valid 10-digit mobile number.';
}

class LicenseKeyInputFormatter extends TextInputFormatter {
  const LicenseKeyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var characters = newValue.text.toUpperCase().replaceAll(
      RegExp('[^A-Z0-9]'),
      '',
    );
    final deletedAutomaticHyphen =
        oldValue.text.endsWith('-') &&
        newValue.text == oldValue.text.substring(0, oldValue.text.length - 1);
    if (deletedAutomaticHyphen && characters.isNotEmpty) {
      characters = characters.substring(0, characters.length - 1);
    }
    final limited = characters.substring(0, characters.length.clamp(0, 16));
    final groups = <String>[];
    for (var index = 0; index < limited.length; index += 4) {
      groups.add(
        limited.substring(index, (index + 4).clamp(0, limited.length)),
      );
    }
    var formatted = groups.join('-');
    if (limited.isNotEmpty && limited.length < 16 && limited.length % 4 == 0) {
      formatted = '$formatted-';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
