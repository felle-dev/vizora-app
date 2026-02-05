import 'package:flutter/services.dart';
import 'package:vizora/model.dart';

class UsageStatsHelper {
  static const MethodChannel _channel = MethodChannel('usage_stats');

  // Usage Stats Permission
  static Future<bool> hasPermission() async {
    try {
      final bool result = await _channel.invokeMethod('hasPermission');
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (e) {
      // Handle error
    }
  }

  // Accessibility Permission
  static Future<bool> hasAccessibilityPermission() async {
    try {
      final bool result = await _channel.invokeMethod(
        'hasAccessibilityPermission',
      );
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<void> requestAccessibilityPermission() async {
    try {
      await _channel.invokeMethod('requestAccessibilityPermission');
    } catch (e) {
      // Handle error
    }
  }

  // Overlay Permission
  static Future<bool> hasOverlayPermission() async {
    try {
      final bool result = await _channel.invokeMethod('hasOverlayPermission');
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      // Handle error
    }
  }

  // Device Admin Permission
  static Future<bool> hasDeviceAdminPermission() async {
    try {
      final bool result = await _channel.invokeMethod(
        'hasDeviceAdminPermission',
      );
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<void> requestDeviceAdminPermission() async {
    try {
      await _channel.invokeMethod('requestDeviceAdminPermission');
    } catch (e) {
      // Handle error
    }
  }

  static Future<List<AppUsageStat>> getStatsByTimestamps(
    int start,
    int end,
  ) async {
    try {
      final List<dynamic> result = await _channel.invokeMethod(
        'getStatsByTimestamps',
        {'start': start, 'end': end},
      );
      return result
          .map((item) => AppUsageStat.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<AppUsageStat>> getStatsByDate(DateTime date) async {
    final start = DateTime(
      date.year,
      date.month,
      date.day,
    ).millisecondsSinceEpoch;
    final end = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;
    return getStatsByTimestamps(start, end);
  }

  static Future<int?> getEarliestDataTimestamp() async {
    try {
      final int? result = await _channel.invokeMethod(
        'getEarliestDataTimestamp',
      );
      return result;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getAppInfo(String packageName) async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'getAppInfo',
        {'packageName': packageName},
      );
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return null;
    }
  }

  static Future<void> setIgnoredPackages(List<String> packages) async {
    try {
      await _channel.invokeMethod('setIgnoredPackages', {'packages': packages});
    } catch (e) {
      print('Error setting ignored packages: $e');
    }
  }

  // App Timer Methods
  static Future<void> setAppTimer(String packageName, int limitMinutes) async {
    try {
      await _channel.invokeMethod('setAppTimer', {
        'packageName': packageName,
        'limitMinutes': limitMinutes,
      });
    } catch (e) {
      print('Error setting app timer: $e');
    }
  }

  static Future<Map<String, int>> getAppTimers() async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'getAppTimers',
      );
      return result.map((key, value) => MapEntry(key.toString(), value as int));
    } catch (e) {
      print('Error getting app timers: $e');
      return {};
    }
  }

  static Future<void> removeAppTimer(String packageName) async {
    try {
      await _channel.invokeMethod('removeAppTimer', {
        'packageName': packageName,
      });
    } catch (e) {
      print('Error removing app timer: $e');
    }
  }

  static Future<int?> getAppUsageToday(String packageName) async {
    try {
      final int? result = await _channel.invokeMethod('getAppUsageToday', {
        'packageName': packageName,
      });
      return result;
    } catch (e) {
      print('Error getting app usage today: $e');
      return null;
    }
  }
}
