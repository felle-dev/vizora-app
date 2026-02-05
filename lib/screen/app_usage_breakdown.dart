import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:vizora/helper/app_info_cache.dart';
import 'package:vizora/helper/time_tools.dart';
import 'package:vizora/model.dart';
import 'package:vizora/helper/usage_stats.dart';

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
  bool _isLoadingAppInfo = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    _loadUsageToday();
  }

  Future<void> _loadAppInfo() async {
    final info = await AppInfoCache.getAppInfo(widget.stat.packageName);
    if (mounted) {
      setState(() {
        _appInfo = info;
        _isLoadingAppInfo = false;
      });
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
                  const SizedBox(width: 4),
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
        padding: const EdgeInsets.all(0),
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

    // Show consistent placeholder while loading
    if (_isLoadingAppInfo || _appInfo == null) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(64),
        ),
        child: Icon(
          Icons.apps,
          size: 32,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      );
    }

    final iconBytes = _appInfo!['icon'] as List<int>?;
    if (iconBytes != null && iconBytes.isNotEmpty) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(64)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(64),
          child: Image.memory(
            Uint8List.fromList(iconBytes),
            fit: BoxFit.cover,
            gaplessPlayback: true, // Add this
          ),
        ),
      );
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(64),
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
        padding: const EdgeInsets.all(0),
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
