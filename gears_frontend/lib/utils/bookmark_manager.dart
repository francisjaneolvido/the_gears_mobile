import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkManager {
  static const String _key = 'bookmarkedArticles';

  /// Save or update bookmarks
  static Future<void> toggleBookmark(Map<String, dynamic> article) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key) ?? [];
    final existing = saved
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .toList();

    final alreadyBookmarked =
        existing.any((a) => a['id'] == article['id'] || a['title'] == article['title']);

    if (alreadyBookmarked) {
      // Remove bookmark
      existing.removeWhere((a) => a['id'] == article['id'] || a['title'] == article['title']);
    } else {
      // Add new bookmark
      existing.add(article);
    }

    final updated = existing.map((a) => jsonEncode(a)).toList();
    await prefs.setStringList(_key, updated);
  }

  /// Get all saved bookmarks
  static Future<List<Map<String, dynamic>>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key);
    if (saved == null) return [];
    return saved.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  /// Check if an article is bookmarked
  static Future<bool> isBookmarked(Map<String, dynamic> article) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key);
    if (saved == null) return false;
    final existing = saved
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .toList();
    return existing.any(
        (a) => a['id'] == article['id'] || a['title'] == article['title']);
  }
}
