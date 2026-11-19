import 'dart:math' as math;

/// "8 s ago", "3 min ago", "2 h ago".
String formatAgo(DateTime time, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(time);
  if (d.inSeconds < 60) return '${math.max(0, d.inSeconds)} s ago';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  return '${d.inHours} h ago';
}

/// "10:42 PM".
String formatClock(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Oct 28".
String formatShortDate(DateTime time) => '${_months[time.month - 1]} ${time.day}';

/// "10 PM".
String formatHour(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  return '$hour ${time.hour < 12 ? 'AM' : 'PM'}';
}

/// "Mon".
String formatWeekday(DateTime time) => _weekdays[time.weekday - 1];

/// Midnight at the start of [time]'s day.
DateTime startOfDay(DateTime time) => DateTime(time.year, time.month, time.day);

/// "Today", "Yesterday", or "Mon, Oct 28" — for grouping lists by day.
String formatDayLabel(DateTime time, {DateTime? now}) {
  final today = startOfDay(now ?? DateTime.now());
  final days = today.difference(startOfDay(time)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return '${formatWeekday(time)}, ${formatShortDate(time)}';
}

/// "yesterday 9:00 AM", "today 3:15 PM", "Oct 28 9:00 AM".
String formatRelativeDay(DateTime time) {
  final label = formatDayLabel(time);
  final day = label == 'Today' || label == 'Yesterday' ? label.toLowerCase() : formatShortDate(time);
  return '$day ${formatClock(time)}';
}
