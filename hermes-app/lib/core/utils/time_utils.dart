String formatRelativeTime(int? timestamp) {
  if (timestamp == null) return '';
  // Support both second-level (old) and millisecond-level (new) timestamps
  final isMs = timestamp > 1e12;
  final tsSec = isMs ? timestamp ~/ 1000 : timestamp;
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final diff = now - tsSec;

  if (diff < 60) return '刚刚';
  if (diff < 3600) return '${diff ~/ 60}分钟前';
  if (diff < 86400) return '${diff ~/ 3600}小时前';
  if (diff < 172800) return '昨天';

  final ms = isMs ? timestamp : timestamp * 1000;
  final date = DateTime.fromMillisecondsSinceEpoch(ms);
  final thisYear = DateTime.now().year;
  if (date.year == thisYear) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}
