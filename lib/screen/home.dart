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

  final Map<String, Map<String, dynamic>?> _appInfoCache = {};

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

      // Preload app info for all stats
      for (final stat in filteredStats) {
        if (!_appInfoCache.containsKey(stat.packageName)) {
          _appInfoCache[stat.packageName] = await AppInfoCache.getAppInfo(
            stat.packageName,
          );
        }
      }

      setState(() {
        _stats = filteredStats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildAppUsageItem(AppUsageStat stat) {
    final theme = Theme.of(context);
    final hasTimer = _appTimers.containsKey(stat.packageName);
    final timerLimit = _appTimers[stat.packageName];

    // Get cached app info
    final appInfo = _appInfoCache[stat.packageName];
    final iconBytes = appInfo?['icon'] as List<int>?;
    final appName = appInfo?['appName'] as String?;

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
          onLongPress: () => _showAppOptionsBottomSheet(stat),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  children: [
                    // Remove FutureBuilder, use cached data directly
                    iconBytes != null && iconBytes.isNotEmpty
                        ? Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(48),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(48),
                              child: Image.memory(
                                Uint8List.fromList(iconBytes),
                                fit: BoxFit.cover,
                                gaplessPlayback: true, // Add this
                              ),
                            ),
                          )
                        : Container(
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
                      Text(
                        appName ?? stat.packageName.split('.').last,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (context) => PopScope(
        canPop: false,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(
                        0.4,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: theme.colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Required Permissions',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                          color: theme.colorScheme.primaryContainer.withOpacity(
                            0.3,
                          ),
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
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                _isRequestingPermissions = true;
                                await _requestAllPermissions();
                              },
                              child: const Text('Grant All'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
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
                  applicationLegalese: '© 2026 Vizora\nGPL v3.0 License',
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

    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
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
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Permissions Status',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildPermissionRow('Usage Stats', usageStats),
                  _buildPermissionRow('Accessibility', accessibility),
                  _buildPermissionRow('Display Overlay', overlay),
                  _buildPermissionRow('Device Admin', deviceAdmin),
                  const SizedBox(height: 24),
                  if (!usageStats || !accessibility || !overlay || !deviceAdmin)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _isRequestingPermissions = true;
                          _requestAllPermissions();
                        },
                        child: const Text('Grant All'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.coffee_outlined,
                          color: theme.colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'About Vizora',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                        color: theme.colorScheme.primaryContainer.withOpacity(
                          0.3,
                        ),
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
                      '© 2026 Vizora\nLicensed under GPL v3.0',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showPermissionHelpDialog() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Permission Help',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How to enable permissions manually:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPermissionHelpItem(
                        theme,
                        Icons.bar_chart,
                        'Usage Stats',
                        'Settings → Apps → Special app access → Usage access → Vizora',
                      ),
                      const SizedBox(height: 12),
                      _buildPermissionHelpItem(
                        theme,
                        Icons.accessibility,
                        'Accessibility Service',
                        'Settings → Accessibility → Downloaded apps → Vizora',
                      ),
                      const SizedBox(height: 12),
                      _buildPermissionHelpItem(
                        theme,
                        Icons.layers,
                        'Display Overlay',
                        'Settings → Apps → Special app access → Display over other apps → Vizora',
                      ),
                      const SizedBox(height: 12),
                      _buildPermissionHelpItem(
                        theme,
                        Icons.admin_panel_settings,
                        'Device Admin',
                        'Settings → Security → Device admin apps → Vizora',
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withOpacity(
                            0.3,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.error.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 20,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Can\'t enable Accessibility?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Some devices require removing restrictions first:\n\n'
                              '1. Go to Settings → Apps → Vizora\n'
                              '2. Tap the menu (⋮) in the top right\n'
                              '3. Select "Allow restricted settings"\n'
                              '4. Authenticate with PIN/biometric\n'
                              '5. Now try enabling Accessibility again',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.secondary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Note: Menu paths may vary slightly depending on your Android version and device manufacturer.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _isRequestingPermissions = true;
                            _requestAllPermissions();
                          },
                          child: const Text('Try Again'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionHelpItem(
    ThemeData theme,
    IconData icon,
    String title,
    String path,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Text(
            path,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
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
            OutlinedButton.icon(
              onPressed: () => _showPermissionHelpDialog(),
              icon: Icon(
                Icons.help_outline,
                size: 18,
                color: theme.colorScheme.onErrorContainer,
              ),
              label: Text(
                'Need Help?',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.onErrorContainer),
                minimumSize: const Size(double.infinity, 36),
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

  void _showAppOptionsBottomSheet(AppUsageStat stat) {
    final theme = Theme.of(context);
    final hasTimer = _appTimers.containsKey(stat.packageName);
    final timerLimit = _appTimers[stat.packageName];

    // Get cached app info
    final appInfo = _appInfoCache[stat.packageName];
    final appName =
        appInfo?['appName'] as String? ?? stat.packageName.split('.').last;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
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
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                appName,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                hasTimer ? Icons.timer : Icons.timer_outlined,
                color: theme.colorScheme.primary,
              ),
              title: Text(hasTimer ? 'Edit Timer' : 'Set Timer'),
              subtitle: hasTimer
                  ? Text('Current limit: $timerLimit minutes')
                  : null,
              onTap: () {
                Navigator.pop(context);
                _showTimerBottomSheet(stat);
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: theme.colorScheme.error),
              title: const Text('Ignore App'),
              subtitle: const Text('Hide from usage stats'),
              onTap: () {
                Navigator.pop(context);
                _showIgnoreAppBottomSheet(stat.packageName, appName);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showTimerBottomSheet(AppUsageStat stat) {
    final theme = Theme.of(context);
    final hasTimer = _appTimers.containsKey(stat.packageName);
    int selectedMinutes = _appTimers[stat.packageName] ?? 30;

    final appInfo = _appInfoCache[stat.packageName];
    final appName =
        appInfo?['appName'] as String? ?? stat.packageName.split('.').last;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
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
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set Timer for $appName',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Limit usage to ${selectedMinutes} minutes per day',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: selectedMinutes.toDouble(),
                      min: 5,
                      max: 300,
                      divisions: 59,
                      label: '$selectedMinutes min',
                      onChanged: (value) {
                        setSheetState(() {
                          selectedMinutes = value.toInt();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Used today: ${TimeTools.formatTime(stat.totalTime)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (hasTimer)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await UsageStatsHelper.removeAppTimer(
                                  stat.packageName,
                                );
                                await _loadAppTimers();
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Timer removed'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Remove'),
                            ),
                          ),
                        if (hasTimer) const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              await UsageStatsHelper.setAppTimer(
                                stat.packageName,
                                selectedMinutes,
                              );
                              await _loadAppTimers();
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Timer set to $selectedMinutes minutes',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            child: const Text('Set Timer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showIgnoreAppBottomSheet(String packageName, String appName) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
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
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.block,
                        color: theme.colorScheme.error,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ignore App',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hide "$appName" from usage stats and widgets?',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
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
                                  content: const Text(
                                    'App added to ignored list',
                                  ),
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
