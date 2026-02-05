import 'package:intl/intl.dart';

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
