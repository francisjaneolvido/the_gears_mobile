import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gears_frontend/utils/config.dart';
import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/models/notification_model.dart';

class NotificationPage extends StatefulWidget {
  final int userId;

  const NotificationPage({super.key, required this.userId});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<NotificationModel> notifications = [];
  bool isLoading = true;

  late RealtimeChannel notifChannel;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
    setupRealtime();
  }

  @override
  void dispose() {
    notifChannel.unsubscribe();
    super.dispose();
  }

  // --------------------------------------------------------
  // 🔥 SUPABASE REAL-TIME STREAM
  // --------------------------------------------------------
  void setupRealtime() {
    final supabase = Supabase.instance.client;

    notifChannel = supabase
        .channel("public:notifications")
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: "public",
          table: "notifications",
          callback: (payload) {
            final data = payload.newRecord;

            // Only push notifications meant for this user
            if (data["user_id"] == widget.userId) {
              final newNotif = NotificationModel.fromJson(data);

              setState(() {
                notifications.insert(0, newNotif);
              });

              print("📌 NEW REALTIME NOTIFICATION: $data");
            }
          },
        )
        .subscribe();
  }

  // --------------------------------------------------------
  // FETCH
  // --------------------------------------------------------
  Future<void> fetchNotifications() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/notifications/${widget.userId}"),
      );

      if (res.statusCode == 200) {
        final List raw = jsonDecode(res.body);

        setState(() {
          notifications =
              raw.map((json) => NotificationModel.fromJson(json)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print("ERROR loading notifications: $e");
      setState(() => isLoading = false);
    }
  }

  // --------------------------------------------------------
  // MARK AS READ
  // --------------------------------------------------------
  Future<void> markAsRead(int id) async {
    try {
      await http.post(Uri.parse("$baseUrl/notifications/read/$id"));

      setState(() {
        notifications = notifications.map((n) {
          if (n.id == id) {
            return NotificationModel(
              id: n.id,
              type: n.type,
              title: n.title,
              message: n.message,
              createdAt: n.createdAt,
              isRead: true,
              articleId: n.articleId,
              commentId: n.commentId,
            );
          }
          return n;
        }).toList();
      });
    } catch (e) {
      print("Mark as read error: $e");
    }
  }

  // --------------------------------------------------------
  // CLEAR ALL
  // --------------------------------------------------------
  Future<void> clearAll() async {
    await http.post(Uri.parse("$baseUrl/notifications/clear/${widget.userId}"));
    setState(() => notifications = []);
  }

  // --------------------------------------------------------
  // ICONS
  // --------------------------------------------------------
  IconData getIcon(String type) {
    switch (type) {
      case "comment":
        return Icons.chat_bubble;
      case "reply":
        return Icons.reply;
      case "admin":
        return Icons.admin_panel_settings;
      case "system":
        return Icons.info_outline;
      case "article":
        return Icons.article_outlined; // NEW
      case "status":
        return Icons.verified_user; // NEW
      default:
        return Icons.notifications;
    }
  }

  // --------------------------------------------------------
  // COLORS
  // --------------------------------------------------------
  Color getColor(String type) {
    switch (type) {
      case "comment":
        return AppTheme.primaryOrange;
      case "reply":
        return Colors.blue;
      case "admin":
        return AppTheme.primaryRed;
      case "system":
        return Colors.red.shade700;
      case "article":
        return Colors.green; // NEW
      case "status":
        return Colors.purple; // NEW
      default:
        return Colors.grey;
    }
  }

  // --------------------------------------------------------
  // DATE FORMAT
  // --------------------------------------------------------
  String formatDate(String raw) {
    try {
      final date = DateTime.parse(raw);
      final diff = DateTime.now().difference(date);

      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      if (diff.inDays < 7) return "${diff.inDays}d ago";

      return "${date.day}/${date.month}/${date.year}";
    } catch (_) {
      return "";
    }
  }

  // --------------------------------------------------------
  // GROUPING
  // --------------------------------------------------------
  Map<String, List<NotificationModel>> groupNotifications(
      List<NotificationModel> list) {
    final now = DateTime.now();
    final Map<String, List<NotificationModel>> grouped = {
      "Today": [],
      "This Week": [],
      "Older": [],
    };

    for (var n in list) {
      final d = DateTime.tryParse(n.createdAt) ?? now;
      final diff = now.difference(d);

      if (diff.inDays == 0) {
        grouped["Today"]!.add(n);
      } else if (diff.inDays <= 7) {
        grouped["This Week"]!.add(n);
      } else {
        grouped["Older"]!.add(n);
      }
    }
    return grouped;
  }

  // --------------------------------------------------------
  // TAP HANDLER
  // --------------------------------------------------------
  void openNotification(NotificationModel n) {
    markAsRead(n.id);

    // Article navigation
    if (n.articleId != null) {
      Navigator.pushNamed(
        context,
        "/article",
        arguments: n.articleId,
      );
      return;
    }

    // Status change → go to profile
    if (n.type == "status") {
      Navigator.pushNamed(context, "/profile");
      return;
    }
  }

  // --------------------------------------------------------
  // UI START
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,

      body: Column(
        children: [
          // ---------------------------------------------------------
          // HEADER
          // ---------------------------------------------------------
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.only(top: 55, bottom: 20, left: 20, right: 20),
            decoration: const BoxDecoration(
              gradient: AppTheme.homeAppBarGradient,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        "assets/icons/back.svg",
                        color: Colors.white,
                        height: 20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Text(
                  "Notifications",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const Spacer(),

                if (notifications.isNotEmpty)
                  GestureDetector(
                    onTap: clearAll,
                    child: Text(
                      "Clear All",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ---------------------------------------------------------
          // BODY
          // ---------------------------------------------------------
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : notifications.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: fetchNotifications,
                        child: _buildGroupedList(),
                      ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------
  // GROUPED LIST
  // --------------------------------------------------------
  Widget _buildGroupedList() {
    final groups = groupNotifications(notifications);

    final sections = [
      {"title": "Today", "items": groups["Today"]!},
      {"title": "This Week", "items": groups["This Week"]!},
      {"title": "Older", "items": groups["Older"]!},
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      itemCount: sections.length,
      itemBuilder: (_, index) {
        final sec = sections[index];
        final List<NotificationModel> items =
            sec["items"] as List<NotificationModel>;

        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sec["title"] as String,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),

            const SizedBox(height: 10),

            ...items.map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _notifCard(n),
                )),
          ],
        );
      },
    );
  }

  // --------------------------------------------------------
  // NOTIFICATION CARD
  // --------------------------------------------------------
  Widget _notifCard(NotificationModel n) {
    final bool unread = !n.isRead;

    return GestureDetector(
      onTap: () => openNotification(n),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: unread ? Colors.white : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: getColor(n.type).withOpacity(0.15),
                  ),
                  child:
                      Icon(getIcon(n.type), color: getColor(n.type), size: 20),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    n.type.toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: getColor(n.type),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                if (unread)
                  Container(
                    height: 10,
                    width: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryRed,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              n.title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              n.message,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textGrey,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              formatDate(n.createdAt),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------
  // EMPTY STATE
  // --------------------------------------------------------
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 90, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            "No notifications yet",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "We'll let you know when something arrives.",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textGrey,
            ),
          ),
        ],
      ),
    );
  }
}
