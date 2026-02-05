import 'package:vizora/helper/usage_stats.dart';

class AppInfoCache {
  static final Map<String, Map<String, dynamic>> _cache = {};

  static Future<Map<String, dynamic>?> getAppInfo(String packageName) async {
    if (_cache.containsKey(packageName)) {
      return _cache[packageName];
    }

    final info = await UsageStatsHelper.getAppInfo(packageName);
    if (info != null) {
      _cache[packageName] = info;
    }
    return info;
  }

  static void clear() {
    _cache.clear();
  }
}
