import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../../utils/config.dart';
import '../../utils/time_ago.dart';
import '../../models/comment_model.dart';
import '../../utils/comment_thread.dart';

import 'magazine_layout_page.dart';
import '../../widgets/video_player_widget.dart';

class ArticleDetailPage extends StatefulWidget {
  final Map<String, dynamic> article;
  final int? userId;
  final String? userStatus;

  const ArticleDetailPage({
    super.key,
    required this.article,
    this.userId,
    this.userStatus,
  });

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  bool _bookmarked = false;

  List<CommentModel> threaded = [];
  List<CommentModel> flatComments = [];
  bool loadingComments = true;

  List<Map<String, dynamic>> relatedArticles = [];

  final TextEditingController commentController = TextEditingController();
  final TextEditingController replyController = TextEditingController();

  int? replyParentId;
  String? replyToName;

  int _currentIndex = 0;
  String? _latestStatus;

  @override
  void initState() {
    super.initState();
    _checkBookmarkStatus();
    _latestStatus = null;
    if (widget.userId != null && widget.userId != 0) {
      _fetchUserStatus();
    }
    _fetchComments();
    _fetchRelatedArticles();
  }

  @override
  void dispose() {
    commentController.dispose();
    replyController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // MEDIA HELPERS
  // ===========================================================================

  /// Rewrites any stale IP in a URL to the current baseUrl's host.
  /// This fixes the problem when WiFi changes and the backend baked the old IP
  /// into media URLs (e.g. http://172.16.9.121:5001/static/uploads/photo.jpg).
  String _fixUrl(String url) {
    if (url.isEmpty) return url;
    // If it's a Supabase URL, leave it alone
    if (url.contains("supabase.co")) return url;

    try {
      final currentHost = Uri.parse(baseUrl).host;
      final currentPort = Uri.parse(baseUrl).port;
      final parsed = Uri.parse(url);

      // Only rewrite local/LAN URLs (not supabase, not external)
      if (parsed.scheme == "http" || parsed.scheme == "https") {
        final isLanIp = RegExp(
          r'^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.)',
        ).hasMatch(parsed.host);

        if (isLanIp && parsed.host != currentHost) {
          // Determine the correct port: mobile backend is 5001, web is 5000
          int targetPort = parsed.port;
          // If the old URL pointed to port 5000 (web), keep 5000
          // If it pointed to 5001 (mobile), keep 5001
          // Just swap the host
          return parsed.replace(host: currentHost).toString();
        }
      }
    } catch (_) {}
    return url;
  }

  /// Parses any media format from the backend into a clean list of maps.
  /// Backend's resolve_media_url() always returns List<Map> with url/thumbnail/type.
  /// Also rewrites stale IPs.
  List<Map<String, dynamic>> _parseMedia(dynamic raw) {
    if (raw == null) return [];

    List items = [];

    if (raw is List) {
      items = raw;
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) items = decoded;
      } catch (_) {}
    } else if (raw is Map) {
      // Tkinter dict fallback: {"file_paths": ["photo.jpg"]}
      final fps = raw["file_paths"];
      if (fps is List) {
        return fps
            .map((f) => f.toString().trim())
            .where((f) => f.isNotEmpty)
            .map((f) => {
                  "url": _fixUrl(f),
                  "thumbnail": _fixUrl(f),
                  "type": "image",
                })
            .toList();
      }
      return [];
    }

    return items
        .whereType<Map>()
        .map((e) {
          final url = _fixUrl((e["url"] ?? "").toString());
          final thumb = _fixUrl((e["thumbnail"] ?? e["url"] ?? "").toString());
          return {
            "url": url,
            "thumbnail": thumb.isNotEmpty ? thumb : url,
            "type": (e["type"] ?? "image").toString(),
          };
        })
        .where((e) => (e["url"] as String).isNotEmpty)
        .toList();
  }

  bool _isVideo(Map<String, dynamic> item) {
    final type = (item["type"] ?? "").toString().toLowerCase();
    if (type == "video") return true;
    final url = (item["url"] ?? "").toString().toLowerCase().split("?").first;
    return url.endsWith(".mp4") ||
        url.endsWith(".mov") ||
        url.endsWith(".avi") ||
        url.endsWith(".mkv") ||
        url.endsWith(".webm");
  }

  // Replace your existing _thumbUrl() with this
String _thumbUrl(Map<String, dynamic> item) {
  final thumb = (item["thumbnail"] ?? "").toString().trim();
  final url = (item["url"] ?? "").toString().trim();
  final candidate = thumb.isNotEmpty ? thumb : url;

  // If the "thumbnail" is actually a video file, it can't be decoded as image
  final lc = candidate.toLowerCase().split("?").first;
  final isVideoFile = lc.endsWith(".mp4") || lc.endsWith(".mov") ||
      lc.endsWith(".avi") || lc.endsWith(".mkv") || lc.endsWith(".webm");

  if (isVideoFile) return ""; // caller must show a placeholder
  return candidate;
}

  List<String> extractThumbnails(dynamic mediaRaw) {
    final media = _parseMedia(mediaRaw);
    return media
        .map((m) => _thumbUrl(m))
        .where((u) => u.isNotEmpty)
        .toList();
  }

  // ===========================================================================
  // DATA FETCHING
  // ===========================================================================

  Future<void> _fetchUserStatus() async {
    if (widget.userId == null || widget.userId == 0) return;
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/get-user-status/${widget.userId}"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() => _latestStatus = data["status"]);
      }
    } catch (_) {}
  }

  Future<void> _fetchComments() async {
    if (mounted) setState(() => loadingComments = true);
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/get-comments/${widget.article["id"]}"));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List<CommentModel> flat = [];

        if (decoded is List) {
          flat = decoded
              .map<CommentModel>((json) => CommentModel.fromJson(json))
              .toList();
        } else if (decoded is Map && decoded["comments"] is List) {
          flat = (decoded["comments"] as List)
              .map<CommentModel>((json) => CommentModel.fromJson(json))
              .toList();
        }

        flatComments = flat;
        threaded = buildThreadedComments(flatComments);
      } else {
        threaded = [];
      }
    } catch (e) {
      print("COMMENT FETCH ERROR: $e");
      threaded = [];
    }
    if (mounted) setState(() => loadingComments = false);
  }

  Future<void> _fetchRelatedArticles() async {
    try {
      final a = widget.article;
      final res = await http.get(Uri.parse(
          "$baseUrl/get-related-articles/${a["category"]}/${a["id"]}"));
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            relatedArticles =
                List<Map<String, dynamic>>.from(jsonDecode(res.body));
          });
        }
      }
    } catch (_) {}
  }

  // ===========================================================================
  // BOOKMARK
  // ===========================================================================

  Future<void> _checkBookmarkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList("bookmarkedArticles");
    if (saved != null) {
      final bookmarks =
          saved.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
      if (mounted) {
        setState(() {
          _bookmarked =
              bookmarks.any((b) => b["id"] == widget.article["id"]);
        });
      }
    }
  }

  Future<void> _toggleBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList('bookmarkedArticles') ?? [];
    List<Map<String, dynamic>> bookmarks =
        saved.map((s) => jsonDecode(s)).cast<Map<String, dynamic>>().toList();

    if (_bookmarked) {
      bookmarks.removeWhere((b) => b["id"] == widget.article["id"]);
      setState(() => _bookmarked = false);
    } else {
      bookmarks.add(widget.article);
      setState(() => _bookmarked = true);
    }

    await prefs.setStringList(
      'bookmarkedArticles',
      bookmarks.map((e) => jsonEncode(e)).toList(),
    );
  }

  // ===========================================================================
  // SHARE & DOWNLOAD
  // ===========================================================================

  Future<void> _shareArticle() async {
    final a = widget.article;
    final preview = (a["content"] ?? "").toString();
    await Share.share(
      "${a["headline"]}\n\nBy ${a["author_name"]}\n\n"
      "${preview.length > 200 ? preview.substring(0, 200) + "..." : preview}"
      "\n\nRead more in The Gears App.",
      subject: a["headline"],
    );
  }

  Future<void> _downloadImage(String url) async {
    try {
      var status = await Permission.storage.request();
      if (!status.isGranted) status = await Permission.photos.request();
      if (!status.isGranted) return;
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return;
      await Gal.putImageBytes(res.bodyBytes);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Saved to gallery")));
      }
    } catch (_) {}
  }

  void _showImageFullscreen(String url, int index, List<String> allImages) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (context) => Stack(
        children: [
          Center(
            child: InteractiveViewer(
              maxScale: 5,
              minScale: 0.5,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white, size: 60),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 22),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            right: 20,
            child: GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                await _downloadImage(url);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.download, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // COMMENTS
  // ===========================================================================

  Future<void> _addComment({int? parentId}) async {
    final ctrl = parentId != null ? replyController : commentController;
    final text = ctrl.text.trim();
    if (text.isEmpty) return;

    await http.post(
      Uri.parse("$baseUrl/add-comment"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "article_id": widget.article["id"],
        "user_id": widget.userId,
        "content": text,
        "parent_id": parentId ?? replyParentId,
      }),
    );

    ctrl.clear();
    if (parentId == null) {
      replyParentId = null;
      replyToName = null;
    }

    await _fetchComments();
  }

  // ===========================================================================
  // UTILITY
  // ===========================================================================

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return "";
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat("MMMM dd, yyyy • hh:mm a").format(dt);
    } catch (e) {
      return raw;
    }
  }

  bool get _isViewOnly =>
      _latestStatus == "view_only" || widget.userStatus == "view_only";

  // ===========================================================================
  // COMMENT UI
  // ===========================================================================

  Widget _viewOnlyBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.red, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "You are in View-Only Mode.\nCommenting and replying are disabled.",
              style: GoogleFonts.poppins(
                color: Colors.red.shade800,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showViewOnlySnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("You are in View-Only Mode."),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _parentCommentTile(CommentModel c) {
    bool showReplies = false;
    bool showReplyBox = false;

    return StatefulBuilder(
      builder: (context, setSB) {
        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: c.userAvatar != null
                    ? NetworkImage(c.userAvatar!)
                    : null,
                child: c.userAvatar == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.userName,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(c.content,
                              style: GoogleFonts.poppins(fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_isViewOnly) {
                              _showViewOnlySnack();
                              return;
                            }
                            setSB(() => showReplyBox = !showReplyBox);
                            setState(() {
                              replyParentId = c.id;
                              replyToName = c.userName;
                            });
                          },
                          child: Text(
                            "Reply",
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          timeAgo(c.createdAt ?? DateTime.now()),
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                    if (c.replies.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () =>
                            setSB(() => showReplies = !showReplies),
                        child: Text(
                          showReplies
                              ? "Hide replies"
                              : "View replies (${c.replies.length})",
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (showReplies)
                        Column(
                          children: c.replies
                              .map((r) => _replyCommentTile(r))
                              .toList(),
                        ),
                    ],
                    if (showReplyBox) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commentController,
                              decoration: InputDecoration(
                                hintText: "Reply to ${c.userName}...",
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send,
                                color: AppTheme.primaryOrange),
                            onPressed: () async {
                              await _addComment();
                              setSB(() => showReplyBox = false);
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _replyCommentTile(CommentModel c) {
    bool showReplyBox = false;
    bool showNestedReplies = false;

    return StatefulBuilder(
      builder: (context, setSB) {
        return Container(
          margin: const EdgeInsets.only(left: 30, top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 2, height: 50, color: Colors.grey.shade300),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 15,
                backgroundImage: c.userAvatar != null
                    ? NetworkImage(c.userAvatar!)
                    : null,
                child: c.userAvatar == null
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.userName,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(c.content,
                              style: GoogleFonts.poppins(fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_isViewOnly) {
                              _showViewOnlySnack();
                              return;
                            }
                            setSB(() => showReplyBox = !showReplyBox);
                            setState(() {
                              replyParentId = c.id;
                              replyToName = c.userName;
                            });
                          },
                          child: Text("Reply",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700)),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          timeAgo(c.createdAt ?? DateTime.now()),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    if (showReplyBox)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: replyController,
                                decoration: InputDecoration(
                                  hintText: "Reply to ${c.userName}...",
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send,
                                  color: AppTheme.primaryOrange),
                              onPressed: () async {
                                await _addComment(parentId: c.id);
                                setSB(() => showReplyBox = false);
                              },
                            ),
                          ],
                        ),
                      ),
                    if (c.replies.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => setSB(
                            () => showNestedReplies = !showNestedReplies),
                        child: Text(
                          showNestedReplies
                              ? "Hide replies"
                              : "View replies (${c.replies.length})",
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (showNestedReplies)
                        Column(
                          children: c.replies
                              .map((child) => _replyCommentTile(child))
                              .toList(),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentGate() {
    if (_latestStatus == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_latestStatus == "approved") {
      return _buildCommentInput();
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        "You must be approved before commenting.",
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryOrange,
        ),
      ),
    );
  }

  Widget _buildCommentsSection() {
    if (loadingComments) {
      return const Center(child: CircularProgressIndicator());
    }
    if (threaded.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          "No comments yet. Be the first!",
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: threaded.length,
      itemBuilder: (_, i) => _parentCommentTile(threaded[i]),
    );
  }

  Widget _buildCommentInput() {
    final replying = replyParentId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (replying)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Replying to $replyToName",
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    replyParentId = null;
                    replyToName = null;
                  }),
                  child: const Icon(Icons.close,
                      size: 18, color: Colors.orange),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: commentController,
                decoration: InputDecoration(
                  hintText: replying
                      ? "Write a reply..."
                      : "Write a comment...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send, color: AppTheme.primaryOrange),
              onPressed: () => _addComment(),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // MEDIA WIDGET — fixed with CachedNetworkImage + play overlay for videos
  // ===========================================================================

  Widget _buildMediaPlaceholder({double height = 260}) {
    return Container(
      height: height,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined,
              size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            "Media unavailable",
            style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget buildMediaWidget(Map<String, dynamic> item) {
  final isVideo = _isVideo(item);
  final thumbUrl = _thumbUrl(item); // now returns "" if thumb is also a video

  // Video with no valid thumbnail → show a styled placeholder with play icon
  if (isVideo && thumbUrl.isEmpty) {
    return Container(
      height: 260,
      width: double.infinity,
      color: Colors.black87,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 2),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              size: 56,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "Tap to play video",
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  if (thumbUrl.isEmpty) return _buildMediaPlaceholder();

  return Stack(
    alignment: Alignment.center,
    children: [
      CachedNetworkImage(
        imageUrl: thumbUrl,   // guaranteed to be an image URL now
        height: 260,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 260,
          color: Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) {
          debugPrint("❌ Media load failed: $url\n   Error: $error");
          return _buildMediaPlaceholder();
        },
      ),
      if (isVideo) ...[
        Container(
          height: 260,
          width: double.infinity,
          color: Colors.black.withOpacity(0.30),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.85), width: 2),
          ),
          child: const Icon(Icons.play_arrow_rounded, size: 48, color: Colors.white),
        ),
      ],
    ],
  );
}
  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final a = widget.article;

    // Parse media using the unified helper (also rewrites stale IPs)
    final List<Map<String, dynamic>> media = _parseMedia(a["media"]);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryOrange, AppTheme.primaryRed],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              IconButton(
                icon: SvgPicture.asset(
                  "assets/icons/back.svg",
                  height: 26,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: _shareArticle,
              ),
              IconButton(
                icon: Icon(
                  _bookmarked ? Icons.bookmark : Icons.bookmark_outline,
                  color: Colors.white,
                ),
                onPressed: _toggleBookmark,
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── MEDIA CAROUSEL ──────────────────────────────────────────
            if (media.isNotEmpty)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: CarouselSlider(
                      options: CarouselOptions(
                        height: 260,
                        viewportFraction: 1,
                        autoPlay: media.length > 1,
                        enableInfiniteScroll: media.length > 1,
                        onPageChanged: (i, _) =>
                            setState(() => _currentIndex = i),
                      ),
                      items: media.map((item) {
                        final isVideo = _isVideo(item);
                        return GestureDetector(
                          onTap: () {
                            if (isVideo) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    backgroundColor: Colors.black,
                                    appBar: AppBar(
                                        backgroundColor: Colors.black),
                                    body: Center(
                                      child: VideoPlayerWidget(
                                          videoUrl: item["url"]),
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              _showImageFullscreen(
                                item["url"],
                                _currentIndex,
                                media
                                    .map((m) => m["url"] as String)
                                    .toList(),
                              );
                            }
                          },
                          child: buildMediaWidget(item),
                        );
                      }).toList(),
                    ),
                  ),

                  // Dot indicators (replaces plain text counter)
                  if (media.length > 1)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          media.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentIndex == i ? 18 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _currentIndex == i
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Magazine button
                  if (a["is_magazine"] == 1)
                    Positioned(
                      bottom: 14,
                      right: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MagazineLayoutPage(article: a),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.menu_book_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  "Magazine",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              )
            // No media placeholder
            else
              Container(
                height: 8,
                color: Colors.transparent,
              ),

            const SizedBox(height: 20),

            // ── HEADLINE ─────────────────────────────────────────────────
            Text(
              a["headline"] ?? "",
              style: GoogleFonts.hedvigLettersSerif(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              "By ${a["author_name"]}",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textDark,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              _formatDate(a["created_at"]),
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 24),

            // ── CONTENT ──────────────────────────────────────────────────
            GestureDetector(
              onLongPress: () => Clipboard.setData(
                  ClipboardData(text: a["content"] ?? "")),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  a["content"] ?? "",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    height: 1.7,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            if (_isViewOnly) _viewOnlyBanner(),

            // ── COMMENTS ─────────────────────────────────────────────────
            Text(
              "Comments",
              style: GoogleFonts.poppins(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 14),

            _buildCommentsSection(),

            const SizedBox(height: 20),

            if (!_isViewOnly) _buildCommentGate(),

            const SizedBox(height: 32),

            // ── RELATED ARTICLES ─────────────────────────────────────────
            if (relatedArticles.isNotEmpty) ...[
              Text(
                "Related Articles",
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 210,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: relatedArticles.length,
                  itemBuilder: (_, i) {
                    final r = relatedArticles[i];
                    final relatedMedia = _parseMedia(r["media"]);
                    final thumbUrl = relatedMedia.isNotEmpty
                        ? _thumbUrl(relatedMedia.first)
                        : "";
                    final isRelatedVideo = relatedMedia.isNotEmpty &&
                        _isVideo(relatedMedia.first);

                    return GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArticleDetailPage(
                            article: r,
                            userId: widget.userId,
                            userStatus: widget.userStatus,
                          ),
                        ),
                      ),
                      child: Container(
                        width: 170,
                        margin: const EdgeInsets.only(right: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: AppTheme.lightCardShadow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14)),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  thumbUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: thumbUrl,
                                          height: 110,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(
                                            height: 110,
                                            color: Colors.grey.shade200,
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2),
                                            ),
                                          ),
                                          errorWidget: (_, __, ___) =>
                                              Container(
                                            height: 110,
                                            color: Colors.grey.shade200,
                                            child: Icon(
                                              Icons.broken_image,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          height: 110,
                                          color: Colors.grey.shade200,
                                          child: Icon(
                                            Icons.article_outlined,
                                            size: 36,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                  // Video badge for related articles
                                  if (isRelatedVideo)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withOpacity(0.55),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white
                                                .withOpacity(0.8),
                                            width: 1.5),
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                r["headline"] ?? "",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}