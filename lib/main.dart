import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:dynamic_color/dynamic_color.dart';

void main() {
  runApp(const UsageStatsApp());
}

// ============================================================================
// MAIN APP
// ============================================================================

class UsageStatsApp extends StatelessWidget {
  const UsageStatsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'Vizora',
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(lightDynamic),
          darkTheme: _buildDarkTheme(darkDynamic),
          themeMode: ThemeMode.system,
          home: const UsageStatsHome(),
        );
      },
    );
  }

  ThemeData _buildLightTheme(ColorScheme? lightDynamic) {
    final colorScheme =
        lightDynamic ??
        ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Outfit',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'NoyhR'),
        displayMedium: TextStyle(fontFamily: 'NoyhR'),
        displaySmall: TextStyle(fontFamily: 'NoyhR'),
        headlineLarge: TextStyle(fontFamily: 'NoyhR'),
        headlineMedium: TextStyle(fontFamily: 'NoyhR'),
        headlineSmall: TextStyle(fontFamily: 'NoyhR'),
        titleLarge: TextStyle(fontFamily: 'NoyhR'),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme(ColorScheme? darkDynamic) {
    final colorScheme =
        darkDynamic ??
        ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Outfit',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'NoyhR'),
        displayMedium: TextStyle(fontFamily: 'NoyhR'),
        displaySmall: TextStyle(fontFamily: 'NoyhR'),
        headlineLarge: TextStyle(fontFamily: 'NoyhR'),
        headlineMedium: TextStyle(fontFamily: 'NoyhR'),
        headlineSmall: TextStyle(fontFamily: 'NoyhR'),
        titleLarge: TextStyle(fontFamily: 'NoyhR'),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }
}

// ============================================================================
// MODELS
// ============================================================================

class AppUsageStat {
  final String packageName;
  final int totalTime;
  final List<DateTime> startTimes;

  AppUsageStat({
    required this.packageName,
    required this.totalTime,
    required this.startTimes,
  });

  int get totalMinutes => totalTime ~/ (1000 * 60);
  int get sessionCount => startTimes.length;

  Map<int, int> getHourlyBreakdown() {
    final hourlyUsage = <int, int>{};
    for (int i = 0; i < 24; i++) {
      hourlyUsage[i] = 0;
    }
    for (var startTime in startTimes) {
      final hour = startTime.hour;
      hourlyUsage[hour] = (hourlyUsage[hour] ?? 0) + totalMinutes;
    }
    return hourlyUsage;
  }

  factory AppUsageStat.fromJson(Map<String, dynamic> json) => AppUsageStat(
    packageName: json['packageName'],
    totalTime: json['totalTime'],
    startTimes: (json['startTimes'] as List)
        .map((e) => DateTime.fromMillisecondsSinceEpoch(e as int))
        .toList(),
  );
}

// ============================================================================
// APP INFO CACHE - Prevents flickering
// ============================================================================

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

// ============================================================================
// PLATFORM CHANNEL HELPER
// ============================================================================

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

// ============================================================================
// TIME TOOLS
// ============================================================================

class TimeTools {
  static String formatTime(int milliseconds, {bool showSeconds = false}) {
    if (milliseconds <= 0) return '0m';

    final hours = milliseconds ~/ (1000 * 60 * 60);
    final minutes = (milliseconds % (1000 * 60 * 60)) ~/ (1000 * 60);
    final seconds = (milliseconds % (1000 * 60)) ~/ 1000;

    final parts = <String>[];

    if (hours > 0) {
      parts.add('${hours}h');
    }

    if (minutes > 0) {
      parts.add('${minutes}m');
    } else if (hours > 0) {
      parts.add('0m');
    }

    if (showSeconds && seconds > 0) {
      parts.add('${seconds}s');
    }

    return parts.isEmpty ? '0m' : parts.join(' ');
  }

  static String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  static String getDateLabel(DateTime date) {
    if (isToday(date)) return 'Today';
    if (isYesterday(date)) return 'Yesterday';
    return formatDate(date);
  }

  static String formatHour(int hour) {
    return '${hour.toString().padLeft(2, '0')}:00';
  }
}

// ============================================================================
// MAIN HOME SCREEN
// ============================================================================

class UsageStatsHome extends StatefulWidget {
  const UsageStatsHome({super.key});

  @override
  State<UsageStatsHome> createState() => _UsageStatsHomeState();
}

class _UsageStatsHomeState extends State<UsageStatsHome> {
  DateTime _selectedDate = DateTime.now();
  DateTime? _earliestDate;
  DateTime? _currentDate;
  List<AppUsageStat> _stats = [];
  Set<String> _ignoredPackages = {};
  Map<String, int> _appTimers = {}; // packageName -> limit in minutes
  bool _isLoading = false;
  bool _hasPermission = false;
  static const int _minUsageTime = 180000; // 3 minutes

  @override
  void initState() {
    super.initState();
    _checkAllPermissions();
    _loadAppTimers();
  }

  Future<void> _checkAllPermissions() async {
    final hasUsageStats = await UsageStatsHelper.hasPermission();
    setState(() => _hasPermission = hasUsageStats);

    if (!hasUsageStats) {
      _showAllPermissionsDialog();
      return;
    }

    await _findDataAvailabilityRange();
    await _loadUsageStats();
  }

  void _showAllPermissionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AllPermissionsDialog(
        onAccept: () async {
          Navigator.pop(context);
          await _requestAllPermissions();
        },
        onReject: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _requestAllPermissions() async {
    // Request Usage Stats
    await UsageStatsHelper.requestPermission();
    await Future.delayed(const Duration(seconds: 2));

    // Request Accessibility
    await UsageStatsHelper.requestAccessibilityPermission();
    await Future.delayed(const Duration(seconds: 2));

    // Request Overlay
    await UsageStatsHelper.requestOverlayPermission();
    await Future.delayed(const Duration(seconds: 2));

    // Request Device Admin
    await UsageStatsHelper.requestDeviceAdminPermission();

    // Wait and recheck
    await Future.delayed(const Duration(seconds: 3));
    _checkAllPermissions();
  }

  Future<void> _findDataAvailabilityRange() async {
    final earliest = await UsageStatsHelper.getEarliestDataTimestamp();
    if (earliest != null) {
      setState(() {
        _earliestDate = DateTime.fromMillisecondsSinceEpoch(earliest);
        _currentDate = DateTime.now();
      });
    }
  }

  Future<void> _loadUsageStats() async {
    setState(() => _isLoading = true);

    try {
      final stats = await UsageStatsHelper.getStatsByDate(_selectedDate);
      final filteredStats = stats
          .where(
            (stat) =>
                stat.totalTime >= _minUsageTime &&
                !_ignoredPackages.contains(stat.packageName),
          )
          .toList();
      filteredStats.sort((a, b) => b.totalTime.compareTo(a.totalTime));

      setState(() {
        _stats = filteredStats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncIgnoredPackages() async {
    await UsageStatsHelper.setIgnoredPackages(_ignoredPackages.toList());
  }

  Future<void> _loadAppTimers() async {
    final timers = await UsageStatsHelper.getAppTimers();
    setState(() => _appTimers = timers);
  }

  String _getTotalUsageTime() {
    final totalMs = _stats.fold<int>(0, (sum, stat) => sum + stat.totalTime);
    return TimeTools.formatTime(totalMs);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate:
          _earliestDate ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: _currentDate ?? DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadUsageStats();
    }
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Manage Ignored Apps'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IgnoredAppsScreen(
                      ignoredPackages: _ignoredPackages,
                      onChanged: (updatedPackages) async {
                        setState(() {
                          _ignoredPackages = updatedPackages;
                        });
                        await _syncIgnoredPackages();
                        await _loadUsageStats();
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('App Timers'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppTimersScreen(
                      appTimers: _appTimers,
                      onChanged: (updatedTimers) async {
                        setState(() {
                          _appTimers = updatedTimers;
                        });
                        await _loadAppTimers();
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Check Permissions'),
              onTap: () {
                Navigator.pop(context);
                _showPermissionsStatus();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Licenses'),
              onTap: () {
                Navigator.pop(context);
                showLicensePage(
                  context: context,
                  applicationName: 'Vizora',
                  applicationVersion: '1.0.0',
                  applicationIcon: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.coffee_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  applicationLegalese: '© 2024 Vizora\nGPL v3.0 License',
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showPermissionsStatus() async {
    final usageStats = await UsageStatsHelper.hasPermission();
    final accessibility = await UsageStatsHelper.hasAccessibilityPermission();
    final overlay = await UsageStatsHelper.hasOverlayPermission();
    final deviceAdmin = await UsageStatsHelper.hasDeviceAdminPermission();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPermissionRow('Usage Stats', usageStats),
            _buildPermissionRow('Accessibility', accessibility),
            _buildPermissionRow('Display Overlay', overlay),
            _buildPermissionRow('Device Admin', deviceAdmin),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!usageStats || !accessibility || !overlay || !deviceAdmin)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _requestAllPermissions();
              },
              child: const Text('Grant All'),
            ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.coffee_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            const Text('About Vizora'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vizora',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 1.0.0',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'A comprehensive screen time management app that helps you understand and control your digital habits.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'All data stays on your device',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '© 2024 Vizora\nLicensed under GPL v3.0',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(String name, bool granted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            color: granted ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Text(name),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: NotificationListener<ScrollNotification>(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 120.0,
                floating: false,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'Vizora',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  expandedTitleScale: 1.5,
                ),
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: theme.colorScheme.onSurface,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: _showMenu,
                  ),
                ],
              ),
            ];
          },
          body: RefreshIndicator(
            onRefresh: _loadUsageStats,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.security,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Permissions Required',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please grant all required permissions to use this app',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _showAllPermissionsDialog,
                icon: const Icon(Icons.settings),
                label: const Text('Grant Permissions'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_stats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No usage data available',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Try selecting a different date',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTotalUsageCard(),
                _buildDateSelector(),
                _buildPieChart(),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildAppUsageItem(_stats[index]),
            childCount: _stats.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildDateSelector() {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: _selectDate,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_today,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Date',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      TimeTools.getDateLabel(_selectedDate),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalUsageCard() {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Screen Time',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getTotalUsageTime(),
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_stats.length} apps used',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withOpacity(
                        0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.coffee_outlined,
                size: 48,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    if (_stats.isEmpty) return const SizedBox();

    final theme = Theme.of(context);
    final topApps = _stats.take(3).toList();
    final othersTime = _stats
        .skip(3)
        .fold<int>(0, (sum, stat) => sum + stat.totalTime);

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      theme.colorScheme.surfaceContainerHighest,
    ];

    final sections = topApps.asMap().entries.map((entry) {
      final index = entry.key;
      final stat = entry.value;

      return PieChartSectionData(
        value: stat.totalTime.toDouble(),
        title: '',
        color: colors[index],
        radius: 70,
      );
    }).toList();

    if (othersTime > 0) {
      sections.add(
        PieChartSectionData(
          value: othersTime.toDouble(),
          title: '',
          color: colors[3],
          radius: 70,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Distribution',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 70),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 60,
                  sectionsSpace: 3,
                  startDegreeOffset: -90,
                ),
              ),
            ),
            const SizedBox(height: 70),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ...topApps.asMap().entries.map((entry) {
                  return _buildLegendItem(
                    colors[entry.key],
                    entry.value.packageName.split('.').last,
                  );
                }),
                if (othersTime > 0) _buildLegendItem(colors[3], 'Others'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildAppUsageItem(AppUsageStat stat) {
    final theme = Theme.of(context);
    final hasTimer = _appTimers.containsKey(stat.packageName);
    final timerLimit = _appTimers[stat.packageName];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppUsageBreakdownScreen(
                  stat: stat,
                  hasTimer: hasTimer,
                  timerLimit: timerLimit,
                  onTimerSet: (limit) async {
                    if (limit != null) {
                      await UsageStatsHelper.setAppTimer(
                        stat.packageName,
                        limit,
                      );
                    } else {
                      await UsageStatsHelper.removeAppTimer(stat.packageName);
                    }
                    await _loadAppTimers();
                  },
                ),
              ),
            );
          },
          onLongPress: () => _showIgnoreAppDialog(stat.packageName),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  children: [
                    FutureBuilder<Map<String, dynamic>?>(
                      future: AppInfoCache.getAppInfo(stat.packageName),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          final iconBytes =
                              snapshot.data!['icon'] as List<int>?;
                          if (iconBytes != null && iconBytes.isNotEmpty) {
                            return Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(48),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(48),
                                child: Image.memory(
                                  Uint8List.fromList(iconBytes),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          }
                        }
                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(48),
                          ),
                          child: Icon(
                            Icons.apps,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        );
                      },
                    ),
                    if (hasTimer)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.timer,
                            color: theme.colorScheme.onPrimary,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<Map<String, dynamic>?>(
                        future: AppInfoCache.getAppInfo(stat.packageName),
                        builder: (context, snapshot) {
                          final appName = snapshot.data?['appName'] as String?;
                          return Text(
                            appName ?? stat.packageName.split('.').last,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            TimeTools.formatTime(stat.totalTime),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.refresh,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${stat.sessionCount} sessions',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showIgnoreAppDialog(String packageName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ignore App'),
        content: const Text(
          'Add this app to ignored packages? It will no longer appear in usage stats or the widget.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              setState(() {
                _ignoredPackages.add(packageName);
              });
              await _syncIgnoredPackages();
              Navigator.pop(context);
              await _loadUsageStats();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('App added to ignored list'),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () async {
                        setState(() {
                          _ignoredPackages.remove(packageName);
                        });
                        await _syncIgnoredPackages();
                        await _loadUsageStats();
                      },
                    ),
                  ),
                );
              }
            },
            child: const Text('Ignore'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// IGNORED APPS SCREEN
// ============================================================================

class IgnoredAppsScreen extends StatefulWidget {
  final Set<String> ignoredPackages;
  final Function(Set<String>) onChanged;

  const IgnoredAppsScreen({
    Key? key,
    required this.ignoredPackages,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<IgnoredAppsScreen> createState() => _IgnoredAppsScreenState();
}

class _IgnoredAppsScreenState extends State<IgnoredAppsScreen> {
  late Set<String> _localIgnoredPackages;

  @override
  void initState() {
    super.initState();
    _localIgnoredPackages = Set.from(widget.ignoredPackages);
  }

  void _removePackage(String packageName) {
    setState(() {
      _localIgnoredPackages.remove(packageName);
    });
    widget.onChanged(_localIgnoredPackages);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Ignored Apps'), elevation: 0),
      body: _localIgnoredPackages.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Ignored Apps',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Apps you ignore will appear here. Long press any app in the main list to ignore it.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _localIgnoredPackages.length,
              itemBuilder: (context, index) {
                final packageName = _localIgnoredPackages.elementAt(index);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: FutureBuilder<Map<String, dynamic>?>(
                        future: AppInfoCache.getAppInfo(packageName),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            final iconBytes =
                                snapshot.data!['icon'] as List<int>?;
                            if (iconBytes != null && iconBytes.isNotEmpty) {
                              return Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    48,
                                  ), // Fully rounded
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                    width: 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    48,
                                  ), // Fully rounded
                                  child: Image.memory(
                                    Uint8List.fromList(iconBytes),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            }
                          }
                          return Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                48,
                              ), // Fully rounded
                            ),
                            child: Icon(
                              Icons.apps,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          );
                        },
                      ),
                      title: FutureBuilder<Map<String, dynamic>?>(
                        future: AppInfoCache.getAppInfo(packageName),
                        builder: (context, snapshot) {
                          final appName = snapshot.data?['appName'] as String?;
                          return Text(
                            appName ?? packageName.split('.').last,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      subtitle: Text(
                        packageName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Remove from ignored list'),
                              content: const Text(
                                'This app will appear in your usage stats again.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    _removePackage(packageName);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'App removed from ignored list',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================================
// APP TIMERS SCREEN
// ============================================================================

class AppTimersScreen extends StatefulWidget {
  final Map<String, int> appTimers;
  final Function(Map<String, int>) onChanged;

  const AppTimersScreen({
    Key? key,
    required this.appTimers,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<AppTimersScreen> createState() => _AppTimersScreenState();
}

class _AppTimersScreenState extends State<AppTimersScreen> {
  late Map<String, int> _localTimers;

  @override
  void initState() {
    super.initState();
    _localTimers = Map.from(widget.appTimers);
  }

  Future<void> _removeTimer(String packageName) async {
    setState(() {
      _localTimers.remove(packageName);
    });
    await UsageStatsHelper.removeAppTimer(packageName);
    widget.onChanged(_localTimers);
  }

  Future<void> _editTimer(String packageName, int currentLimit) async {
    int selectedMinutes = currentLimit;

    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Timer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$selectedMinutes minutes per day',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Slider(
                value: selectedMinutes.toDouble(),
                min: 5,
                max: 300,
                divisions: 59,
                label: '$selectedMinutes min',
                onChanged: (value) {
                  setDialogState(() {
                    selectedMinutes = value.toInt();
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selectedMinutes),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _localTimers[packageName] = result;
      });
      await UsageStatsHelper.setAppTimer(packageName, result);
      widget.onChanged(_localTimers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('App Timers'), elevation: 0),
      body: _localTimers.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_off_outlined,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No App Timers',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Set timers for apps to limit daily usage. Tap any app in the main list to set a timer.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _localTimers.length,
              itemBuilder: (context, index) {
                final entry = _localTimers.entries.elementAt(index);
                final packageName = entry.key;
                final limitMinutes = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: FutureBuilder<Map<String, dynamic>?>(
                        future: AppInfoCache.getAppInfo(packageName),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            final iconBytes =
                                snapshot.data!['icon'] as List<int>?;
                            if (iconBytes != null && iconBytes.isNotEmpty) {
                              return Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(48),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                    width: 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(48),
                                  child: Image.memory(
                                    Uint8List.fromList(iconBytes),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            }
                          }
                          return Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(48),
                            ),
                            child: Icon(
                              Icons.apps,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          );
                        },
                      ),
                      title: FutureBuilder<Map<String, dynamic>?>(
                        future: AppInfoCache.getAppInfo(packageName),
                        builder: (context, snapshot) {
                          final appName = snapshot.data?['appName'] as String?;
                          return Text(
                            appName ?? packageName.split('.').last,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      subtitle: Row(
                        children: [
                          Icon(
                            Icons.timer,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$limitMinutes min/day',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () =>
                                _editTimer(packageName, limitMinutes),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.error,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Remove Timer'),
                                  content: const Text(
                                    'Remove the time limit for this app?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        _removeTimer(packageName);
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Timer removed'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================================
// APP USAGE BREAKDOWN SCREEN
// ============================================================================

class AppUsageBreakdownScreen extends StatefulWidget {
  final AppUsageStat stat;
  final bool hasTimer;
  final int? timerLimit;
  final Function(int?) onTimerSet;

  const AppUsageBreakdownScreen({
    Key? key,
    required this.stat,
    this.hasTimer = false,
    this.timerLimit,
    required this.onTimerSet,
  }) : super(key: key);

  @override
  State<AppUsageBreakdownScreen> createState() =>
      _AppUsageBreakdownScreenState();
}

class _AppUsageBreakdownScreenState extends State<AppUsageBreakdownScreen> {
  Map<String, dynamic>? _appInfo;
  int? _usageToday;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    _loadUsageToday();
  }

  Future<void> _loadAppInfo() async {
    final info = await AppInfoCache.getAppInfo(widget.stat.packageName);
    if (mounted) {
      setState(() => _appInfo = info);
    }
  }

  Future<void> _loadUsageToday() async {
    final usage = await UsageStatsHelper.getAppUsageToday(
      widget.stat.packageName,
    );
    if (mounted) {
      setState(() => _usageToday = usage);
    }
  }

  void _showTimerDialog() {
    int selectedMinutes = widget.timerLimit ?? 30;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set App Timer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Limit usage to ${selectedMinutes} minutes per day',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Slider(
                value: selectedMinutes.toDouble(),
                min: 5,
                max: 300,
                divisions: 59,
                label: '$selectedMinutes min',
                onChanged: (value) {
                  setDialogState(() {
                    selectedMinutes = value.toInt();
                  });
                },
              ),
              const SizedBox(height: 8),
              if (_usageToday != null)
                Text(
                  'Used today: ${TimeTools.formatTime(_usageToday!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          actions: [
            if (widget.hasTimer)
              TextButton(
                onPressed: () {
                  widget.onTimerSet(null);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Timer removed'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('Remove'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                widget.onTimerSet(selectedMinutes);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Timer set to $selectedMinutes minutes'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Set'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Usage Details',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                expandedTitleScale: 1.5,
              ),
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.onSurface,
              actions: [
                IconButton(
                  icon: Icon(
                    widget.hasTimer ? Icons.timer : Icons.timer_outlined,
                  ),
                  onPressed: _showTimerDialog,
                  tooltip: 'Set Timer',
                ),
              ],
            ),
          ];
        },
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAppHeader(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Screen Time',
                      TimeTools.formatTime(widget.stat.totalTime),
                      Icons.access_time,
                      theme.colorScheme.primaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Sessions',
                      '${widget.stat.sessionCount}',
                      Icons.refresh,
                      theme.colorScheme.secondaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildLineChart(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppHeader() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _buildAppIcon(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _appInfo?['appName'] ??
                        widget.stat.packageName.split('.').last,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.stat.packageName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon() {
    final theme = Theme.of(context);
    if (_appInfo != null) {
      final iconBytes = _appInfo!['icon'] as List<int>?;
      if (iconBytes != null && iconBytes.isNotEmpty) {
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(64), // Fully rounded
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(64), // Fully rounded
            child: Image.memory(
              Uint8List.fromList(iconBytes),
              fit: BoxFit.cover,
            ),
          ),
        );
      }
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(64), // Fully rounded
      ),
      child: Icon(
        Icons.apps,
        size: 32,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color bgColor,
  ) {
    final theme = Theme.of(context);
    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.onSecondaryContainer, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    final theme = Theme.of(context);
    final hourlyUsage = widget.stat.getHourlyBreakdown();

    final spots = hourlyUsage.entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.toDouble()))
        .toList();

    final maxValue = hourlyUsage.values.isEmpty
        ? 60.0
        : hourlyUsage.values.reduce((a, b) => a > b ? a : b).toDouble();
    final maxY = maxValue * 1.3;
    final minY = -maxValue * 0.1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hourly Usage',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxValue > 60 ? (maxValue / 5) : 15,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: theme.colorScheme.outlineVariant.withOpacity(
                          0.3,
                        ),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: maxValue > 60 ? (maxValue / 5) : 15,
                        getTitlesWidget: (value, meta) {
                          if (value < 0) return const Text('');
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '${value.toInt()}m',
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.right,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 4,
                        getTitlesWidget: (value, meta) {
                          final hour = value.toInt();
                          if (hour % 4 == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                TimeTools.formatHour(hour),
                                style: theme.textTheme.bodySmall,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 23,
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.2,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        cutOffY: 0,
                        applyCutOffY: true,
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final hour = spot.x.toInt();
                          final minutes = spot.y.toInt();
                          return LineTooltipItem(
                            '${TimeTools.formatHour(hour)}\n${minutes}m',
                            TextStyle(
                              color: theme.colorScheme.onInverseSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 0,
                        color: theme.colorScheme.outline.withOpacity(0.3),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ALL PERMISSIONS DIALOG
// ============================================================================

class _AllPermissionsDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _AllPermissionsDialog({required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.security, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          const Expanded(child: Text('Required Permissions')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This app requires 4 permissions to function properly:'),
          const SizedBox(height: 16),
          _buildPermissionItem(
            context,
            Icons.bar_chart,
            'Usage Stats',
            'Track app usage',
          ),
          _buildPermissionItem(
            context,
            Icons.accessibility,
            'Accessibility',
            'Monitor app activity',
          ),
          _buildPermissionItem(
            context,
            Icons.layers,
            'Display Overlay',
            'Show blocking overlays',
          ),
          _buildPermissionItem(
            context,
            Icons.admin_panel_settings,
            'Device Admin',
            'Prevent uninstallation',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.lock, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'All data stays on your device',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(onPressed: onReject, child: const Text('Reject')),
        FilledButton(onPressed: onAccept, child: const Text('Grant All')),
      ],
    );
  }

  Widget _buildPermissionItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
