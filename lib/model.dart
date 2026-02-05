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
