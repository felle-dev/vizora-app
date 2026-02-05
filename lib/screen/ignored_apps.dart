import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vizora/helper/app_info_cache.dart';

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
                                  // border: Border.all(
                                  //   color: theme.colorScheme.outlineVariant,
                                  //   width: 1,
                                  // ),
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
