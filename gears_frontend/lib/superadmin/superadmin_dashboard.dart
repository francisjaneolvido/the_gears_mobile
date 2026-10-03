// -----------------------------------------------------------------------------
// SUPERADMIN DASHBOARD - FINAL FULL FIXED VERSION
// -----------------------------------------------------------------------------

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gears_frontend/superadmin/superadmin_profile_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';

// NAV PAGES
import 'package:gears_frontend/superadmin/superadmin_users_page.dart';
import 'package:gears_frontend/superadmin/superadmin_articles_page.dart';
import 'package:gears_frontend/superadmin/activity_log.dart';
import 'package:gears_frontend/widgets/superadmin_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SuperAdminDashboard extends StatefulWidget {
  final String email;
  final String role;

  const SuperAdminDashboard({
    super.key,
    required this.email,
    required this.role,
  });





  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  bool isLoading = true;
  int currentIndex = 0;

  int totalUsers = 0;
  int approvedUsers = 0;
  int pendingUsers = 0;
  int totalArticles = 0;
  int pendingReviews = 0;
  int totalAdmins = 0;


  String? superadminEmail;


  List<dynamic> users = [];
  List<dynamic> recentArticles = [];
  List<dynamic> activityLogs = [];

  @override
void initState() {
  super.initState();
  _initialize();
}

Future<void> _initialize() async {
  await _loadEmail();     // wait until email is loaded
  _loadDashboard();       // now safe to load dashboard
}

  Future<void> _loadEmail() async {
  final prefs = await SharedPreferences.getInstance();

  final saved1 = prefs.getString("email");       // Remember Me email
  final saved2 = prefs.getString("user_email");  // Always saved login email

  setState(() {
    superadminEmail = saved1 ?? saved2 ?? widget.email;
  });

  print("Loaded approver (superadmin) email: $superadminEmail");
}


  // ===========================================================================
  // DASHBOARD LOADER (SAFE WITH mounted CHECK)
  // ===========================================================================
  Future<void> _loadDashboard() async {
  if (!mounted) return;
  setState(() => isLoading = true);

  await Future.wait([
    _fetchDashboardStats(),
    _fetchUsers(),
    _fetchRecentArticles(),
    _fetchActivityLogs(),
  ]);

  if (mounted) setState(() => isLoading = false);
}

  // ===========================================================================
  // FETCH DASHBOARD STATS
  // ===========================================================================
  Future<void> _fetchDashboardStats() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/dashboard-stats'));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (!mounted) return;
        setState(() {
          totalUsers = data['total_users'] ?? 0;
          approvedUsers = data['approved_users'] ?? 0;
          pendingUsers = data['pending_users'] ?? 0;
          totalArticles = data['articles'] ?? 0;
          pendingReviews = data['pending_reviews'] ?? 0;
          totalAdmins = data['total_admins'] ?? 0;


        });
      }
    } catch (e) {
      print('[DEBUG] Dashboard stats error: $e');
    }
  }

  // ===========================================================================
  // FETCH USERS
  // ===========================================================================
  Future<void> _fetchUsers() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/get-users'));

      if (res.statusCode == 200) {
        users = (jsonDecode(res.body) as List).take(5).toList();
      }
    } catch (e) {
      print('[DEBUG] Fetch users error: $e');
    }
  }

  // ===========================================================================
  // FETCH RECENT ARTICLES
  // ===========================================================================
  Future<void> _fetchRecentArticles() async {
  try {
    final res = await http.get(Uri.parse('$baseUrl/get-published-articles'));

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;

      list.sort((a, b) =>
          _parseDate(b["created_at"]).compareTo(_parseDate(a["created_at"])));

      if (mounted) {
        setState(() {
          recentArticles = list.take(5).toList();
        });
      }
    }
  } catch (e) {
    print('[DEBUG] Fetch articles error: $e');
  }
}

  // ===========================================================================
  // FETCH ACTIVITY LOGS
  // ===========================================================================
  Future<void> _fetchActivityLogs() async {
  try {
    final email = superadminEmail ?? widget.email;

    final res = await http.get(
      Uri.parse('$baseUrl/get-activity-logs?viewer_email=$email'),
    );

    print("[DEBUG] Using email for logs: $email");
    print("[DEBUG] Raw Logs: ${res.body}");

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      activityLogs = (body["logs"] as List).take(5).toList();
    }
  } catch (e) {
    print('[DEBUG] Fetch activity logs error: $e');
  }
}


  // ===========================================================================
  // DATE PARSING (100% SAFE)
  // ===========================================================================
  DateTime _parseDate(dynamic raw) {
  if (raw == null) return DateTime.now();

  String value = raw.toString().trim();

  // Standardize spacing → ISO8601
  value = value.replaceAll(" ", "T");

  // Remove microseconds
  if (value.contains(".")) {
    value = value.split(".").first;
  }

  // Ensure timezone
  if (!value.endsWith("Z") &&
      !RegExp(r'(\+|-)\d\d:\d\d$').hasMatch(value)) {
    value += "Z";
  }

  try {
    return DateTime.parse(value).toLocal();
  } catch (e) {
    print("[DEBUG] Date parse failed: $raw → $e");
    return DateTime.now();
  }
}


  // ===========================================================================
  // HUMAN-READABLE TIME FORMATTER
  // ===========================================================================
  String _formatDateSmart(dynamic raw) {
    final date = _parseDate(raw);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays == 1) {
      return "Yesterday • ${DateFormat('hh:mm a').format(date)}";
    }
    if (diff.inDays < 7) return "${diff.inDays}d ago";

    return DateFormat("MMM dd, yyyy • hh:mm a").format(date);
  }

  // ===========================================================================
  // BOTTOM NAVIGATION
  // ===========================================================================
  void _onNavTap(int index) {
    if (index == currentIndex) return;

    Widget page;

    switch (index) {
      case 0:
        page = SuperAdminDashboard(
  email: superadminEmail ?? widget.email,
  role: "superadmin",
);

        break;
      case 1:
  page = SuperAdminArticlesPage(
    email: superadminEmail ?? widget.email, // ✅ hindi dapat null
  );
  break;
      case 2:
      page = SuperAdminUsersPage(
  email: superadminEmail ?? widget.email,
);

        break;
      case 3:
        page = SuperAdminProfilePage(
  email: superadminEmail ?? widget.email,
);

        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

    setState(() => currentIndex = index);
  }

  // ===========================================================================
  // SUMMARY CARDS
  // ===========================================================================
  Widget _buildSummaryCards() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                "Total Admins",
                totalAdmins,
                Icons.supervisor_account


              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                "Total Users",
                totalUsers,
                Icons.people,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _summaryCard(
                "Total Articles",
                totalArticles,
                Icons.article_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                "Pending Reviews",
                pendingReviews,
                Icons.pending_actions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _summaryCard(
                "Pending Users",
                pendingUsers,
                Icons.person_add_alt_1,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}


  Widget _summaryCard(String title, int number, IconData icon) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: AppTheme.cardRadius,
      boxShadow: AppTheme.lightCardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ------ GRADIENT ICON WRAPPER ------
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppTheme.primaryOrange, AppTheme.primaryRed],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Icon(icon, size: 28, color: Colors.white),
        ),

        const SizedBox(height: 14),

        Text(
          "$number",
          style: AppTheme.headingText.copyWith(fontSize: 26),
        ),
        Text(
          title,
          style: AppTheme.subtitleText,
        ),
      ],
    ),
  );
}


  // ===========================================================================
  // QUICK ACTIONS
  // ===========================================================================
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Quick Actions"),
        
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _actionButton(
                    "Review Articles",
                    Icons.rate_review,
                    AppTheme.primaryOrange,
                    () => _onNavTap(1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionButton(
                    "Manage Users", Icons.manage_accounts, Colors.blue,
                    () => _onNavTap(2)),
              ),
            ],
          ),
        ),
      ],
    );
  }

 Widget _actionButton(
    String text, IconData icon, Color color, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: AppTheme.cardRadius,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.35), width: 1.2),
        boxShadow: AppTheme.lightCardShadow,
      ),
      child: Column(
        children: [
          // ⭐ GRADIENT ICON
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppTheme.primaryOrange, AppTheme.primaryRed],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds),
            child: Icon(icon, size: 30, color: Colors.white),
          ),

          const SizedBox(height: 8),
          Text(
            text,
            style: AppTheme.cardTitleText.copyWith(fontSize: 13),
          ),
        ],
      ),
    ),
  );
}


  // ===========================================================================
  // RECENT ARTICLES
  // ===========================================================================
  Widget _buildRecentArticles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Recent Articles", () => _onNavTap(1)),
        if (recentArticles.isEmpty)
          _emptyMessage("No recent articles")
        else
          ListView.builder(
            itemCount: recentArticles.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (_, i) => _articleTile(recentArticles[i]),
          ),
      ],
    );
  }

  Widget _articleTile(dynamic a) {
  Color color;
  IconData icon;

  switch (a["status"]) {
  case "approved":
  case "published":
    color = Colors.green;
    icon = Icons.check_circle;
    break;
  case "pending":       // ✅ hindi "submitted"
    color = Colors.blue;
    icon = Icons.hourglass_bottom;
    break;
  case "needs_revision":
    color = Colors.orange;
    icon = Icons.edit_note;
    break;
  case "draft":
    color = Colors.grey;
    icon = Icons.edit_note_outlined;
    break;
  default:
    color = Colors.grey;
    icon = Icons.circle;
}

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: AppTheme.cardRadius,
      boxShadow: AppTheme.lightCardShadow,
    ),
    child: Row(
      children: [
        // Left Icon Badge
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),

        const SizedBox(width: 14),

        // Title + Author
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a["headline"] ?? "Untitled",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "By ${a["author_name"] ?? "Unknown"}",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textGrey,
                ),
              ),
            ],
          ),
        ),

        // Timestamp
        Text(
          _formatDateSmart(a["created_at"]),
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppTheme.textGrey,
          ),
        ),
      ],
    ),
  );
}


  // ===========================================================================
  // RECENT USERS
  // ===========================================================================
  Widget _buildRecentUsers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Recent Users", () => _onNavTap(2)),
        if (users.isEmpty)
          _emptyMessage("No recent users")
        else
          ListView.builder(
            itemCount: users.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (_, i) => _userTile(users[i]),
          ),
      ],
    );
  }

  Widget _userTile(dynamic u) {
  final first = u["first_name"]?.trim() ?? "";
  final last = u["last_name"]?.trim() ?? "";

  final status = u["status"] ?? "pending";
  final statusColor = status == "approved"
      ? Colors.green
      : (status == "rejected" ? Colors.red : Colors.orange);

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: AppTheme.cardRadius,
      boxShadow: AppTheme.lightCardShadow,
    ),
    child: Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 24,
          backgroundColor: statusColor.withOpacity(0.15),
          child: Text(
            "${first.isNotEmpty ? first[0] : ""}${last.isNotEmpty ? last[0] : ""}",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),

        const SizedBox(width: 14),

        // User Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$first $last",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                u["email"],
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textGrey,
                ),
              ),
            ],
          ),
        ),

        // Role Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            u["role"] ?? "user",
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
      ],
    ),
  );
}


  // ===========================================================================
  // RECENT ACTIVITY LOGS
  // ===========================================================================
  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Activity Logs", () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActivityLogPage(viewerEmail: superadminEmail ?? widget.email),

            ),
          );
        }),

        if (activityLogs.isEmpty)
          _emptyMessage("No activity yet")
        else
          ListView.builder(
            itemCount: activityLogs.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (_, i) => _activityTile(activityLogs[i]),
          ),
      ],
    );
  }

  Widget _activityTile(dynamic log) {
  final action = (log["action"] ?? "").toString().toLowerCase();
  final desc = log["description"] ?? "No description";

  // Select color & icon
  Color color;
  IconData icon;

  if (action.contains("approved")) {
    color = Colors.green;
    icon = Icons.check_circle_outline;
  } else if (action.contains("rejected") || action.contains("deleted")) {
    color = Colors.red;
    icon = Icons.cancel_outlined;
  } else if (action.contains("submitted")) {
    color = Colors.orange;
    icon = Icons.upload_file;
  } else if (action.contains("updated") || action.contains("edited")) {
    color = Colors.blue;
    icon = Icons.edit_note;
  } else {
    color = Colors.grey;
    icon = Icons.info_outline;
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: AppTheme.cardRadius,
      boxShadow: AppTheme.lightCardShadow,
    ),
    child: Row(
      children: [
        // Icon badge
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),

        const SizedBox(width: 14),

        // Description text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                desc,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                log["action"] ?? "",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textGrey,
                ),
              ),
            ],
          ),
        ),

        // Timestamp
        Text(
          _formatDateSmart(log["created_at"]),
          textAlign: TextAlign.right,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppTheme.textGrey,
          ),
        ),
      ],
    ),
  );
}


  // ===========================================================================
  // SECTION HELPERS
  // ===========================================================================
  Widget _sectionHeader(String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTheme.headingText.copyWith(fontSize: 18)),
          InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Text(
                  "Show More",
                  style: AppTheme.subtitleText.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppTheme.textDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(title, style: AppTheme.headingText.copyWith(fontSize: 18)),
    );
  }

  Widget _emptyMessage(String message) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message, style: AppTheme.subtitleText),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
     print("DASHBOARD EMAIL (final) = '${superadminEmail ?? widget.email}'");

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,

      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryOrange, AppTheme.primaryRed],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: Text(
          "Dashboard",
          style:
              AppTheme.headingText.copyWith(color: Colors.white, fontSize: 22),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        color: AppTheme.textDark,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      _buildSummaryCards(),
                      const SizedBox(height: 28),

                      _buildQuickActions(),
                      const SizedBox(height: 28),

                      _buildRecentArticles(),
                      const SizedBox(height: 28),

                      _buildRecentUsers(),
                      const SizedBox(height: 28),

                      _buildRecentActivity(),
                    ],
                  ),
                ),
              ),
      ),

      bottomNavigationBar: SuperAdminNav(
        currentIndex: currentIndex,
        onTap: _onNavTap,
        role: "superadmin",
      ),
    );
  }
}
