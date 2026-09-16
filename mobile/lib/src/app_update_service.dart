import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ui_helpers.dart';

class AppVersionInfo {
  const AppVersionInfo({
    required this.versionName,
    required this.buildNumber,
  });

  final String versionName;
  final int buildNumber;

  String get display => '$versionName ($buildNumber)';
}

class AppUpdateResult {
  const AppUpdateResult({
    required this.hasUpdate,
    required this.isForceUpdate,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minRequiredBuild,
    required this.releaseNotes,
    required this.updateUrl,
  });

  final bool hasUpdate;
  final bool isForceUpdate;
  final String currentVersion;
  final int currentBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final int minRequiredBuild;
  final String releaseNotes;
  final String updateUrl;
}

class AppUpdateService {
  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _storage = FlutterSecureStorage();
  static const _lastCheckKey = 'avsb_last_version_check_v1';
  static const _apiUrl = String.fromEnvironment(
    'AVSB_API_URL',
    defaultValue: 'https://av-smart-billing.vercel.app',
  );

  /// 12 hours throttling for background automated update checks.
  static const _checkThrottle = Duration(hours: 12);

  /// Reads current version name and build number from package info.
  Future<AppVersionInfo> getCurrentVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final buildNum = int.tryParse(info.buildNumber) ?? 1;
      return AppVersionInfo(
        versionName: info.version.isNotEmpty ? info.version : '1.0.0',
        buildNumber: buildNum,
      );
    } catch (_) {
      return const AppVersionInfo(versionName: '1.0.0', buildNumber: 1);
    }
  }

  Future<String?> _readLastCheck() async {
    try {
      return await _storage.read(key: _lastCheckKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeLastCheck(String value) async {
    try {
      await _storage.write(key: _lastCheckKey, value: value);
    } catch (_) {
      // Storage failure must not prevent version check
    }
  }

  /// Checks whether an update is available.
  /// When [manual] is false (background run on startup):
  /// - Throttled to once every 12 hours.
  /// - Any network or parsing error is silently swallowed (returns null).
  ///
  /// When [manual] is true (user clicked "Check for Updates"):
  /// - Always performs network call.
  /// - Throws exception if network is unreachable so UI can notify user.
  Future<AppUpdateResult?> checkForUpdate({bool manual = false}) async {
    if (!manual) {
      final lastCheckRaw = await _readLastCheck();
      if (lastCheckRaw != null) {
        final lastCheck = DateTime.tryParse(lastCheckRaw);
        if (lastCheck != null &&
            DateTime.now().difference(lastCheck) < _checkThrottle) {
          return null;
        }
      }
    }

    final localInfo = await getCurrentVersionInfo();

    try {
      final uri = Uri.parse('$_apiUrl/api/mobile/version?platform=android');
      final response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'AV-Smartbilling-Mobile',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (manual) {
          throw Exception('Unable to reach update server (status ${response.statusCode}).');
        }
        return null;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (payload['ok'] != true) {
        if (manual) {
          throw Exception(payload['message'] ?? 'Could not check for updates.');
        }
        return null;
      }

      final latestVersion = payload['latestVersion'] as String? ?? localInfo.versionName;
      final latestBuild = payload['latestBuildNumber'] as int? ?? localInfo.buildNumber;
      final minRequired = payload['minRequiredBuild'] as int? ?? 1;
      final releaseNotes = payload['releaseNotes'] as String? ?? '';
      final updateUrl = payload['updateUrl'] as String? ??
          'https://play.google.com/store/apps/details?id=in.avsmartbilling.mobile';

      // Save last check timestamp
      await _writeLastCheck(DateTime.now().toIso8601String());

      final hasUpdate = latestBuild > localInfo.buildNumber;
      final isForceUpdate = localInfo.buildNumber < minRequired;

      return AppUpdateResult(
        hasUpdate: hasUpdate,
        isForceUpdate: isForceUpdate,
        currentVersion: localInfo.versionName,
        currentBuildNumber: localInfo.buildNumber,
        latestVersion: latestVersion,
        latestBuildNumber: latestBuild,
        minRequiredBuild: minRequired,
        releaseNotes: releaseNotes,
        updateUrl: updateUrl,
      );
    } on SocketException catch (_) {
      if (manual) {
        throw Exception('You are offline. Please connect to the internet to check for updates.');
      }
      return null;
    } on TimeoutException catch (_) {
      if (manual) {
        throw Exception('Connection timed out while checking for updates.');
      }
      return null;
    } on http.ClientException catch (_) {
      if (manual) {
        throw Exception('Network connection error. Please check your internet and try again.');
      }
      return null;
    } catch (e) {
      if (manual) {
        throw Exception('Could not check for updates: $e');
      }
      return null;
    }
  }

  /// Opens the Play Store or download link.
  Future<bool> launchUpdateUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Shows the update dialog to the user.
  Future<void> showUpdateDialog(
    BuildContext context,
    AppUpdateResult update,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !update.isForceUpdate,
      builder: (ctx) => PopScope(
        canPop: !update.isForceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: update.isForceUpdate
                      ? const Color(0xfffee2e2)
                      : const Color(0xffd5eeeb),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  update.isForceUpdate
                      ? Icons.warning_amber_rounded
                      : Icons.system_update_rounded,
                  color: update.isForceUpdate
                      ? const Color(0xffdc2626)
                      : const Color(0xff057c73),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  update.isForceUpdate
                      ? 'Update Required'
                      : 'New Update Available',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version ${update.latestVersion} (Build ${update.latestBuildNumber}) is now available.',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Installed: ${update.currentVersion} (Build ${update.currentBuildNumber})',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                if (update.isForceUpdate) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xfffef2f2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xfffecaca)),
                    ),
                    child: const Text(
                      'This update includes critical improvements and is required to continue.',
                      style: TextStyle(
                        color: Color(0xff991b1b),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                if (update.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    "What's New:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfff3f4f6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      update.releaseNotes,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!update.isForceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
            FilledButton.icon(
              onPressed: () async {
                final launched = await launchUpdateUrl(update.updateUrl);
                if (!launched && ctx.mounted) {
                  showMessage(
                    ctx,
                    'Could not open update link automatically. Please visit Google Play Store.',
                    error: true,
                  );
                }
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }
}
