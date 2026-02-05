import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vizora/helper/app_info_cache.dart';
import 'package:vizora/helper/usage_stats.dart';

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
