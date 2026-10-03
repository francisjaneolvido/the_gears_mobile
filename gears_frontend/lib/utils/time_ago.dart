import 'package:intl/intl.dart';

String timeAgo(DateTime date) {
  final now = DateTime.now();
  final dt = date.toLocal();
  final diff = now.difference(dt);

  if (diff.inSeconds < 60) return "just now";
  if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
  if (diff.inHours < 24) return "${diff.inHours}h ago";
  if (diff.inDays < 7) return "${diff.inDays}d ago";

  return DateFormat("MMMM dd, yyyy • HH:mm").format(dt);
}
