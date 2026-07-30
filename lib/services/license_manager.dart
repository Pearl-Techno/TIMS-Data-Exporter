import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class LicenseManager {
  static const String _licenseFileName = '.tims_license_info';
  static const String _keyPrefix = 'Quantyx';
  static const int _trialDays = 365;

  /// Retrieves the file used to store license information.
  static Future<File> _getLicenseFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(path.join(directory.path, _licenseFileName));
  }

  /// Checks the current license status.
  /// Returns a map containing expiration info and remaining days.
  static Future<Map<String, dynamic>> checkLicenseStatus() async {
    try {
      final file = await _getLicenseFile();

      if (!await file.exists()) {
        return {
          'isExpired': true,
          'status': 'unactivated',
          'daysLeft': 0,
          'requiredKey': '${_keyPrefix}001',
        };
      }

      final content = await file.readAsString();
      final parts = content.split('|');
      if (parts.length < 2) throw Exception('Invalid license data');

      final activationDate = DateTime.parse(parts[0]);
      final currentKey = parts[1];

      final difference = DateTime.now().difference(activationDate).inDays;
      final isExpired = difference >= _trialDays;

      return {
        'isExpired': isExpired,
        'status': isExpired ? 'expired' : 'activated',
        'daysLeft': isExpired ? 0 : _trialDays - difference,
        'currentKey': currentKey,
      };
    } catch (e) {
      return {'isExpired': true, 'status': 'unactivated', 'daysLeft': 0};
    }
  }

  /// Validates the provided key and updates the license file if correct.
  static Future<bool> activateLicense(String key) async {
    final file = await _getLicenseFile();
    String expectedKey = '${_keyPrefix}001';

    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final currentKey = content.split('|')[1];

        // Extract number from current key (e.g. Quantyx001 -> 1)
        final numPart = currentKey.replaceAll(_keyPrefix, '');
        final currentIdx = int.tryParse(numPart) ?? 0;

        // The next valid key is the current index + 1
        expectedKey =
            '$_keyPrefix${(currentIdx + 1).toString().padLeft(3, '0')}';
      } catch (e) {
        // If file is corrupted, fallback to 001
      }
    }

    if (key == expectedKey) {
      final now = DateTime.now();
      await file.writeAsString('${now.toIso8601String()}|$key');
      return true;
    }
    return false;
  }
}
