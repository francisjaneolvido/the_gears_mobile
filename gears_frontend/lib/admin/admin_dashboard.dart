import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gears_frontend/widgets/gradient_icon.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';

// NAVIGATION
import 'package:gears_frontend/widgets/superadmin_nav.dart';
import 'package:gears_frontend/widgets/admin_nav.dart';

// PAGES
import 'package:gears_frontend/admin/articles/admin_manage_articles_page.dart';
import 'package:gears_frontend/admin/admin_users_page.dart';
import 'package:gears_frontend/admin/admin_profile_settings.dart';
import 'package:gears_frontend/superadmin/activity_log.dart';


class AdminDashboard extends StatefulWidget {
  final String email;
  final String role;
  final int initialIndex; // <-- ADD THIS

  const AdminDashboard({
    super.key,
    required this.email,
    required this.role,
    this.initialIndex = 0, // <-- DEFAULT
  });


  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  bool isLoading = true;

  Map<String, dynamic> stats = {
    "my_drafts": 0,
    "my_pending": 0,
    "my_published": 0,
    "my_revisions": 0,
    "my_commented_articles": 0,
  };

  List<Map<String, dynamic>> topAuthors = [];
  int activeUsers = 0;
  List<dynamic> activityLogs = [];

@override
void initState() {
  super.initState();
  _currentIndex = widget.initialIndex;  // <-- APPLY INITIAL INDEX

  fetchPersonalStats();
  fetchAnalyticsData();
  fetchActivityLogs();
}

  // ---------------- FETCH PERSONAL STATS ----------------
  Future<void> fetchPersonalStats() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/admin-dashboard-stats/${widget.email}"),
      );

      if (response.statusCode == 200) {
        setState(() {
          stats = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error stats: $e");
    }

    setState(() => isLoading = false);
  }

  // ---------------- FETCH ANALYTICS ----------------
  Future<void> fetchAnalyticsData() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/analytics"));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          topAuthors = List<Map<String, dynamic>>.from(data["top_authors"]);
          activeUsers = data["active_users"] ?? 0;
        });
      }
    } catch (e) {
      debugPrint("Analytics Error: $e");
    }
  }

  // ---------------- FETCH ACTIVITY LOGS ----------------
  Future<void> fetchActivityLogs() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/get-activity-logs?viewer_email=${widget.email}"),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);

        setState(() {
          activityLogs = List.from(body["logs"]).take(5).toList();
        });
      }
    } catch (e) {
      debugPrint("Activity Logs Error: $e");
    }
  }

  String formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays == 1) return "Yesterday";
    return "${diff.inDays}d ago";
  }

  // ---------------- SAFE DATE PARSER ----------------
  DateTime safeParseDate(dynamic raw) {
    if (raw == null) return DateTime.now();

    String s = raw.toString().trim();

    try {
      if (s.contains(" ") && !s.contains("T")) {
        s = s.replaceFirst(" ", "T");
      }

      if (RegExp(r'^.+T\d{2}:\d{2}$').hasMatch(s)) {
        s = "${s}:00";
      }

      s = s.replaceAll(RegExp(r'\.\d+'), "");

      if (RegExp(r'(\+|-)\d{2}:\d{2}$').hasMatch(s)) {
        return DateTime.parse(s).toLocal();
      }

      if (!s.endsWith("Z")) {
        s = "${s}Z";
      }

      return DateTime.parse(s).toLocal();
    } catch (e) {
      print("[DATE ERROR] Failed to parse: $raw → $e");
      return DateTime.now();
    }
  }

  // ---------------- PAGE SWITCH ----------------
  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 1:
        return AdminManageArticlesPage(authorEmail: widget.email);
      case 2:
        return AdminManageUsersPage(adminEmail: widget.email);
      case 3:
        return AdminProfileSettings(email: widget.email);
      default:
        return _buildDashboardPage();
    }
  }

  // ---------------- TOP AUTHORS CARD ----------------
  Widget _buildTopAuthorsCard() {
    if (topAuthors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Center(
          child: Text(
            "No top authors this month.",
            style: GoogleFonts.poppins(
              color: AppTheme.textGrey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...topAuthors.asMap().entries.map((entry) {
            final author = entry.value;
            final isLast = entry.key == topAuthors.length - 1;
            final name = "${author["first_name"]} ${author["last_name"]}";
            final count = author["total_articles"] ?? 0;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "$count articles",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ---------------- FULL DASHBOARD PAGE ----------------
  Widget _buildDashboardPage() {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async {
              await fetchPersonalStats();
              await fetchAnalyticsData();
              await fetchActivityLogs();
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeHeader(),
                  const SizedBox(height: 28),

                  _buildPersonalStatsGrid(),
                  const SizedBox(height: 28),

                  _buildActiveUsersCard(),
                  const SizedBox(height: 32),

                  Text(
                    "Top 5 Authors This Month",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTopAuthorsCard(),
                  const SizedBox(height: 32),

                  _buildRecentActivity(),
                  const SizedBox(height: 32),

                  Text(
                    "Quick Actions",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildQuickActions(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
  }

  // ---------------- WELCOME HEADER ----------------
  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.admin_panel_settings,
            size: 36,
            color: AppTheme.primaryOrange,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "Welcome back, ${widget.role.toUpperCase()}!",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  //                       ACTIVITY LOG FEED
  // --------------------------------------------------------------------------
  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Activity Logs",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ActivityLogPage(viewerEmail: widget.email),
                  ),
                );
              },
              child: Row(
                children: [
                  Text(
                    "Show More",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppTheme.textDark,
                  ),
                ],
              ),
            )
          ],
        ),
        const SizedBox(height: 16),

        activityLogs.isEmpty
            ? _emptyActivity()
            : Column(
                children:
                    activityLogs.map((log) => _activityTile(log)).toList(),
              ),
      ],
    );
  }

  // ---------------- ACTIVITY TILE ----------------
  Widget _activityTile(dynamic log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.circle,
                color: AppTheme.primaryOrange.withOpacity(0.6),
                size: 12,
              ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log["description"] ?? "No description",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatTime(log["created_at"]),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Center(
        child: Text(
          "No recent activity",
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textGrey,
          ),
        ),
      ),
    );
  }

  // ---------------- TIME FORMAT ----------------
  String formatTime(dynamic rawDate) {
    final date = safeParseDate(rawDate);
    final diff = DateTime.now().difference(date);

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays == 1) return "Yesterday";
    return "${diff.inDays}d ago";
  }

  // ---------------- PERSONAL STATS GRID ----------------
  Widget _buildPersonalStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      children: [
        _stat("My Drafts", stats["my_drafts"], Icons.edit_note),
        _stat("Pending", stats["my_pending"], Icons.pending_actions),
        _stat("Published", stats["my_published"], Icons.check_circle_outline),
        _stat("Revisions", stats["my_revisions"], Icons.autorenew),
        _stat("With Comments", stats["my_commented_articles"],
            Icons.comment_outlined),
      ],
    );
  }

  Widget _stat(String title, dynamic value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GradientIcon(icon, size: 34),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$value",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textGrey,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveUsersCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Active Users",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          Text(
            "$activeUsers",
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryOrange,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- QUICK ACTIONS ----------------
  Widget _buildQuickActions() {
    return Column(
      children: [
        _quickAction(
          "Manage Articles",
          "Create, edit, or submit articles",
          Icons.article_outlined,
          () => setState(() => _currentIndex = 1),
        ),
        const SizedBox(height: 14),
        _quickAction(
          "Manage Users",
          "Approve, disapprove, or promote users",
          Icons.people_outline,
          () => setState(() => _currentIndex = 2),
        ),
      ],
    );
  }

  Widget _quickAction(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            GradientIcon(icon, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ShaderMask(
              shaderCallback: (rect) => AppTheme.iconGradientShader(rect),
              child: const Icon(Icons.arrow_forward_ios, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _currentIndex == 3
          ? null
          : AppBar(
              elevation: 0,
              flexibleSpace: Container(
                decoration: BoxDecoration(gradient: AppTheme.titleGradient),
              ),
              title: Text(
                _currentIndex == 0
                    ? "Dashboard"
                    : _currentIndex == 1
                        ? "My Articles"
                        : _currentIndex == 2
                            ? "Manage Users"
                            : "",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ),
      body: _getCurrentPage(),
      bottomNavigationBar: widget.role == "superadmin"
          ? SuperAdminNav(
              currentIndex: _currentIndex,
              role: widget.role,
              onTap: (i) => setState(() => _currentIndex = i),
            )
          : AdminNav(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
            ),
    );
  }
}