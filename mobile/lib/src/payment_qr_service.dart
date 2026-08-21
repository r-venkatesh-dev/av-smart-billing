import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class PaymentQrService {
  PaymentQrService({ImagePicker? picker}) : picker = picker ?? ImagePicker();

  final ImagePicker picker;

  Future<String?> pickAndStore() async {
    try {
      final selected = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
        requestFullMetadata: false,
      );
      if (selected == null) return null;
      final directory = await getApplicationDocumentsDirectory();
      final destination = File(
        path.join(directory.path, 'av-smartbilling-payment-qr.img'),
      );
      await destination.writeAsBytes(await selected.readAsBytes(), flush: true);
      return destination.path;
    } on PlatformException catch (error) {
      if (error.code == 'channel-error') {
        throw Exception(
          'Could not open your photos. Please fully close and reopen the app, then try again.',
        );
      }
      throw Exception('Could not select that image. Please try another image.');
    }
  }

  Future<void> remove(String filePath) async {
    if (filePath.isEmpty) return;
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }
}
