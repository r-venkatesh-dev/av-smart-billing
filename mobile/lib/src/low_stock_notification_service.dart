import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

class LowStockNotificationService {
  static const _signatureKey = 'avsb_low_stock_notification_signature_v1';
  static const _notificationId = 2401;
  static const _storage = FlutterSecureStorage();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  bool initialized = false;

  Future<void> initialize() async {
    if (!Platform.isAndroid || initialized) return;
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher'),
      ),
    );
    initialized = true;
  }

  Future<void> update(List<Product> products) async {
    if (!Platform.isAndroid) return;
    await initialize();
    if (products.isEmpty) {
      await _storage.delete(key: _signatureKey);
      await plugin.cancel(id: _notificationId);
      return;
    }
    final signature = products
        .map((product) => '${product.id}:${product.stockQuantity}')
        .join('|');
    if (await _storage.read(key: _signatureKey) == signature) return;
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final allowed = await android?.requestNotificationsPermission();
    if (allowed == false) return;
    final names = products.take(3).map((product) => product.name).join(', ');
    final extra = products.length > 3 ? ' and ${products.length - 3} more' : '';
    await plugin.show(
      id: _notificationId,
      title:
          '${products.length} low-stock product${products.length == 1 ? '' : 's'}',
      body: '$names$extra need attention.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'avsb_low_stock',
          'Low stock alerts',
          channelDescription: 'Alerts when active products reach low stock',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: 'low-stock',
    );
    await _storage.write(key: _signatureKey, value: signature);
  }
}
