import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:vizora/helper/app_info_cache.dart';
import 'package:vizora/helper/time_tools.dart';
import 'package:vizora/model.dart';
import 'package:vizora/helper/usage_stats.dart';
import 'package:vizora/screen/app_timers.dart';
import 'package:vizora/screen/app_usage_breakdown.dart';
import 'package:vizora/screen/ignored_apps.dart';

class UsageStatsHome extends StatefulWidget {
  const UsageStatsHome({super.key});

  @override
  State<UsageStatsHome> createState() => _UsageStatsHomeState();
}

class _UsageStatsHomeState extends State<UsageStatsHome>
    with WidgetsBindingObserver {
  DateTime _selectedDate = DateTime.now();
  DateTime? _earliestDate;
  DateTime? _currentDate;
  List<AppUsageStat> _stats = [];
  Set<String> _ignoredPackages = {};
  Map<String, int> _appTimers = {}; // packageName -> limit in minutes
  bool _isLoading = false;
  bool _hasPermission = false;

  // Permission status tracking
  bool _hasUsageStats = false;
  bool _hasAccessibility = false;
  bool _hasOverlay = false;
  bool _hasDeviceAdmin = false;

  // Track if we're in the middle of permission flow
  bool _isRequestingPermissions = false;

  static const int _minUsageTime = 180000; // 3 minutes

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
    _loadAppTimers();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isRequestingPermissions) {
      // App came back to foreground, recheck permissions and continue flow
      _continuePermissionFlow();
    }
  }

  Future<void> _continuePermissionFlow() async {
    await _checkAllPermissions();

    // If still requesting permissions and not all granted, continue to next
    if (_isRequestingPermissions) {
      if (!_hasUsageStats ||
          !_hasAccessibility ||
          !_hasOverlay ||
          !_hasDeviceAdmin) {
        await _requestAllPermissions();
      } else {
        // All permissions granted
        _isRequestingPermissions = false;
      }
    }
  }

  Future<void> _checkAllPermissions() async {
    final usageStats = await UsageStatsHelper.hasPermission();
    final accessibility = await UsageStatsHelper.hasAccessibilityPermission();
    final overlay = await UsageStatsHelper.hasOverlayPermission();
    final deviceAdmin = await UsageStatsHelper.hasDeviceAdminPermission();

    setState(() {
      _hasUsageStats = usageStats;
      _hasAccessibility = accessibility;
      _hasOverlay = overlay;
      _hasDeviceAdmin = deviceAdmin;
      _hasPermission = usageStats;
    });

    if (!usageStats) {
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
          _isRequestingPermissions = true;
          await _requestAllPermissions();
        },
        onReject: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _requestAllPermissions() async {
    // Request Usage Stats first
    if (!_hasUsageStats) {
      await UsageStatsHelper.requestPermission();
      return; // Wait for app resume to continue
    }

    // Request Accessibility
    if (!_hasAccessibility) {
      await UsageStatsHelper.requestAccessibilityPermission();
      return; // Wait for app resume to continue
    }

    // Request Overlay
    if (!_hasOverlay) {
      await UsageStatsHelper.requestOverlayPermission();
      return; // Wait for app resume to continue
    }

    // Request Device Admin
    if (!_hasDeviceAdmin) {
      await UsageStatsHelper.requestDeviceAdminPermission();
      return; // Wait for app resume to continue
    }

    // All permissions granted
    await _checkAllPermissions();
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
                _isRequestingPermissions = true;
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

  bool get _hasMissingPermissions {
    return !_hasUsageStats ||
        !_hasAccessibility ||
        !_hasOverlay ||
        !_hasDeviceAdmin;
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
                    icon: const Icon(Icons.calendar_today),
                    tooltip: TimeTools.getDateLabel(_selectedDate),
                    onPressed: _selectDate,
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: _showMenu,
                  ),
                ],
              ),
            ];
          },
          body: RefreshIndicator(
            onRefresh: () async {
              await _checkAllPermissions();
              await _loadUsageStats();
            },
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
                if (_hasMissingPermissions) _buildMissingPermissionsCard(),
                // _buildPieChart(),
                _buildTotalUsageCard(),
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

  Widget _buildMissingPermissionsCard() {
    final theme = Theme.of(context);
    final missingPermissions = <Map<String, dynamic>>[];

    if (!_hasUsageStats)
      missingPermissions.add({'name': 'Usage Stats', 'icon': Icons.bar_chart});
    if (!_hasAccessibility)
      missingPermissions.add({
        'name': 'Accessibility',
        'icon': Icons.accessibility,
      });
    if (!_hasOverlay)
      missingPermissions.add({'name': 'Display Overlay', 'icon': Icons.layers});
    if (!_hasDeviceAdmin)
      missingPermissions.add({
        'name': 'Device Admin',
        'icon': Icons.admin_panel_settings,
      });

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.onErrorContainer,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Missing Permissions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...missingPermissions.map(
              (perm) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      perm['icon'] as IconData,
                      size: 18,
                      color: theme.colorScheme.onErrorContainer.withOpacity(
                        0.8,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      perm['name'] as String,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () {
                  _isRequestingPermissions = true;
                  _requestAllPermissions();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.onErrorContainer,
                  foregroundColor: theme.colorScheme.errorContainer,
                ),
                child: const Text('Grant Missing Permissions'),
              ),
            ),
          ],
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

  // ignore: unused_element
  Widget _buildPieChart() {
    if (_stats.isEmpty) return const SizedBox();

    final theme = Theme.of(context);
    final topApps = _stats.take(3).toList();
    final othersTime = _stats
        .skip(3)
        .fold<int>(0, (sum, stat) => sum + stat.totalTime);

    final colors = [Colors.blue, Colors.red, Colors.green, Colors.purple];

    int touchedIndex = -1;

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
            const SizedBox(height: 16),
            Text(
              'Tap a section to view details',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              height: 200,
              child: StatefulBuilder(
                builder: (context, setChartState) {
                  final sections = <PieChartSectionData>[];

                  // Build sections for top apps
                  for (int i = 0; i < topApps.length; i++) {
                    final stat = topApps[i];
                    final isTouched = i == touchedIndex;
                    final radius = isTouched ? 85.0 : 70.0;

                    sections.add(
                      PieChartSectionData(
                        value: stat.totalTime.toDouble(),
                        title: isTouched
                            ? TimeTools.formatTime(stat.totalTime)
                            : '',
                        titleStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        color: colors[i],
                        radius: radius,
                        badgePositionPercentageOffset: 1.3,
                      ),
                    );
                  }

                  // Add "Others" section if exists
                  if (othersTime > 0) {
                    final isTouched = topApps.length == touchedIndex;
                    final radius = isTouched ? 85.0 : 70.0;

                    sections.add(
                      PieChartSectionData(
                        value: othersTime.toDouble(),
                        title: isTouched
                            ? TimeTools.formatTime(othersTime)
                            : '',
                        titleStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        color: colors[3],
                        radius: radius,
                      ),
                    );
                  }

                  return PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 50,
                      sectionsSpace: 2,
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setChartState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              touchedIndex = -1;
                              return;
                            }
                            touchedIndex = pieTouchResponse
                                .touchedSection!
                                .touchedSectionIndex;
                          });

                          // Navigate on tap
                          if (event is FlTapUpEvent && touchedIndex >= 0) {
                            if (touchedIndex < topApps.length) {
                              final stat = topApps[touchedIndex];
                              final hasTimer = _appTimers.containsKey(
                                stat.packageName,
                              );
                              final timerLimit = _appTimers[stat.packageName];

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
                                        await UsageStatsHelper.removeAppTimer(
                                          stat.packageName,
                                        );
                                      }
                                      await _loadAppTimers();
                                    },
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    swapAnimationDuration: const Duration(milliseconds: 300),
                    swapAnimationCurve: Curves.easeOutCubic,
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ...topApps.asMap().entries.map((entry) {
                  return InkWell(
                    onTap: () {
                      final stat = topApps[entry.key];
                      final hasTimer = _appTimers.containsKey(stat.packageName);
                      final timerLimit = _appTimers[stat.packageName];

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
                                await UsageStatsHelper.removeAppTimer(
                                  stat.packageName,
                                );
                              }
                              await _loadAppTimers();
                            },
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: _buildLegendItem(
                        colors[entry.key],
                        entry.value.packageName.split('.').last,
                        TimeTools.formatTime(entry.value.totalTime),
                      ),
                    ),
                  );
                }),
                if (othersTime > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: _buildLegendItem(
                      colors[3],
                      'Others',
                      TimeTools.formatTime(othersTime),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, [String? time]) {
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
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (time != null) ...[
          const SizedBox(width: 4),
          Text(
            '($time)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
                                // border: Border.all(
                                //   color: theme.colorScheme.outlineVariant,
                                //   width: 1,
                                // ),
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
