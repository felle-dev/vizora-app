import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

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
    return MaterialApp(
      title: 'Usage Stats',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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
          backgroundColor: ColorScheme.fromSeed(seedColor: Colors.blue).surface,
          foregroundColor: ColorScheme.fromSeed(
            seedColor: Colors.blue,
          ).onSurface,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: ColorScheme.fromSeed(
            seedColor: Colors.blue,
          ).surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
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
          backgroundColor: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ).surface,
          foregroundColor: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ).onSurface,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ).surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const UsageStatsHome(),
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
      final bool result = await _channel.invokeMethod('hasAccessibilityPermission');
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
      final bool result = await _channel.invokeMethod('hasDeviceAdminPermission');
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

  static Future<String?> exportData(DateTime startDate, DateTime endDate) async {
    try {
      final String? result = await _channel.invokeMethod(
        'exportData',
        {
          'startDate': startDate.millisecondsSinceEpoch,
          'endDate': endDate.millisecondsSinceEpoch,
        },
      );
      return result;
    } catch (e) {
      print('Error exporting data: $e');
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
  bool _isLoading = false;
  bool _hasPermission = false;
  static const int _minUsageTime = 180000; // 3 minutes

  @override
  void initState() {
    super.initState();
    _checkAllPermissions();
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
              leading: const Icon(Icons.security),
              title: const Text('Check Permissions'),
              onTap: () {
                Navigator.pop(context);
                _showPermissionsStatus();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export Data'),
              onTap: () {
                Navigator.pop(context);
                _showExportDialog();
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
                    'Usage Stats',
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
                _buildDateSelector(),
                const SizedBox(height: 20),
                _buildTotalUsageCard(),
                const SizedBox(height: 20),
                _buildPieChart(),
                const SizedBox(height: 32),
                Text(
                  'App Usage',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
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
                color: theme.colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.phone_android,
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
            const SizedBox(height: 60),
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
            const SizedBox(height: 60),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppUsageBreakdownScreen(stat: stat),
              ),
            );
          },
          onLongPress: () => _showIgnoreAppDialog(stat.packageName),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                FutureBuilder<Map<String, dynamic>?>(
                  future: AppInfoCache.getAppInfo(stat.packageName),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      final iconBytes = snapshot.data!['icon'] as List<int>?;
                      if (iconBytes != null && iconBytes.isNotEmpty) {
                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(48), // Fully rounded
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(48), // Fully rounded
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
                        borderRadius: BorderRadius.circular(48), // Fully rounded
                      ),
                      child: Icon(
                        Icons.apps,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    );
                  },
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

  Future<void> _showExportDialog() async {
    DateTime? startDate = _earliestDate ?? DateTime.now().subtract(const Duration(days: 30));
    DateTime? endDate = DateTime.now();

    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) => _ExportDialog(
        initialStartDate: startDate!,
        initialEndDate: endDate!,
        earliestDate: _earliestDate ?? DateTime.now().subtract(const Duration(days: 365)),
      ),
    );

    if (result != null) {
      startDate = result['start'];
      endDate = result['end'];

      if (startDate != null && endDate != null) {
        // Show loading
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Exporting data...'),
                  ],
                ),
              ),
            ),
          ),
        );

        final filePath = await UsageStatsHelper.exportData(startDate!, endDate!);

        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog

        if (filePath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Data exported to: $filePath'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {},
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to export data'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
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
                                  borderRadius: BorderRadius.circular(48), // Fully rounded
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                    width: 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(48), // Fully rounded
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
                              borderRadius: BorderRadius.circular(48), // Fully rounded
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
// APP USAGE BREAKDOWN SCREEN
// ============================================================================

class AppUsageBreakdownScreen extends StatefulWidget {
  final AppUsageStat stat;

  const AppUsageBreakdownScreen({Key? key, required this.stat})
    : super(key: key);

  @override
  State<AppUsageBreakdownScreen> createState() =>
      _AppUsageBreakdownScreenState();
}

class _AppUsageBreakdownScreenState extends State<AppUsageBreakdownScreen> {
  Map<String, dynamic>? _appInfo;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final info = await AppInfoCache.getAppInfo(widget.stat.packageName);
    if (mounted) {
      setState(() => _appInfo = info);
    }
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
// EXPORT DIALOG
// ============================================================================

class _ExportDialog extends StatefulWidget {
  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final DateTime earliestDate;

  const _ExportDialog({
    required this.initialStartDate,
    required this.initialEndDate,
    required this.earliestDate,
  });

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: widget.earliestDate,
      lastDate: _endDate,
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Export Usage Data'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select date range to export:'),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: const Text('Start Date'),
            subtitle: Text(TimeTools.formatDate(_startDate)),
            onTap: _selectStartDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('End Date'),
            subtitle: Text(TimeTools.formatDate(_endDate)),
            onTap: _selectEndDate,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Data will be exported as CSV file to Downloads folder',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'start': _startDate,
              'end': _endDate,
            });
          },
          child: const Text('Export'),
        ),
      ],
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
          const Text(
            'This app requires 4 permissions to function properly:',
          ),
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
                Icon(
                  Icons.lock,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
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
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
