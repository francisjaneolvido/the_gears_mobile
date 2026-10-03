// =============================================================
// SUPERADMIN USERS PAGE — MODERNIZED UI (D1 + S2 Shadow)
// Gradient AppBar • Filled Buttons • Clean Spacing • Premium UX
// =============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:gears_frontend/widgets/superadmin_nav.dart';
import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';

// Navigation
import 'package:gears_frontend/superadmin/superadmin_dashboard.dart';
import 'package:gears_frontend/superadmin/superadmin_articles_page.dart';
import 'package:gears_frontend/superadmin/superadmin_profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SuperAdminUsersPage extends StatefulWidget {
  final String email;

  const SuperAdminUsersPage({super.key, required this.email});

  @override
  State<SuperAdminUsersPage> createState() => _SuperAdminUsersPageState();
}

class _SuperAdminUsersPageState extends State<SuperAdminUsersPage>
    with TickerProviderStateMixin {
  bool loading = true;
  bool isEIC = false;

  late TabController tabController;

  List<dynamic> allUsers = [];
  List<dynamic> filteredUsers = [];

  String searchQuery = "";
  String sortOption = "Name (A–Z)";
  String filterStatus = "All";

  int currentIndex = 2;
  
  // ------------------------------------------------------------
  // INIT
  // ------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    tabController = TabController(length: 4, vsync: this);

    tabController.addListener(() {
      _applyFilters();
      setState(() {});
    });

    _fetchUsers();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }
  Future<String?> _getLoggedInEmail() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString("user_email");
}

  // ------------------------------------------------------------
  // FETCH USERS
  // ------------------------------------------------------------
  Future<void> _fetchUsers() async {
  setState(() => loading = true);

  try {
    final loggedEmail = await _getLoggedInEmail();

    final res = await http.get(Uri.parse("$baseUrl/get-users"));

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;

      final me = list.firstWhere(
        (u) => u["email"] == loggedEmail,
        orElse: () => null,
      );

      isEIC = (me != null && me["is_eic"] == 1);

      allUsers = list;
      _applyFilters();
    }
  } catch (e) {
    _showSnack("Error loading users: $e", true);
  }

  setState(() => loading = false);
}


  // ------------------------------------------------------------
  // FILTER + SORT
  // ------------------------------------------------------------
  void _applyFilters() {
    int tab = tabController.index;

    List<dynamic> subset = allUsers.where((u) {
      // TAB FILTERS
      if (tab == 0 && u["role"] != "admin") return false;
      if (tab == 1 && !(u["role"] == "superadmin" && (u["is_eic"] ?? 0) == 0)) {
        return false;
      }
      if (tab == 2 && !(u["role"] == "superadmin" && (u["is_eic"] ?? 0) == 1)) {
        return false;
      }
      if (tab == 3 && u["role"] != "user") return false;

      // STATUS FILTER (Users tab only)
      if (tab == 3 && filterStatus != "All") {
        if (u["status"] != filterStatus.toLowerCase()) return false;
      }

      final name =
          "${u['first_name']} ${u['last_name']}".toLowerCase().trim();
      final email = (u["email"] ?? "").toLowerCase();
      final q = searchQuery.toLowerCase();

      return name.contains(q) || email.contains(q);
    }).toList();

    // SORT
    switch (sortOption) {
      case "Name (A–Z)":
        subset.sort((a, b) => ("${a['first_name']} ${a['last_name']}")
            .compareTo("${b['first_name']} ${b['last_name']}"));
        break;

      case "Name (Z–A)":
        subset.sort((a, b) => ("${b['first_name']} ${b['last_name']}")
            .compareTo("${a['first_name']} ${a['last_name']}"));
        break;

      case "Status":
        subset.sort((a, b) => a["status"].compareTo(b["status"]));
        break;
    }

    setState(() => filteredUsers = subset);
  }

  // ------------------------------------------------------------
  // SNACKBAR
  // ------------------------------------------------------------
  void _showSnack(String msg, bool error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? Colors.red : Colors.green,
        content: Text(msg),
      ),
    );
  }

  // ------------------------------------------------------------
  // MAIN BUILD
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(),
      floatingActionButton: tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryOrange,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                "Add Admin",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _showAddAdminDialog,
            )
          : null,
      bottomNavigationBar: _buildBottomNav(),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 6),
                _buildToolbar(),
                const SizedBox(height: 6),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => _fetchUsers(),
                    child: _buildUserList(),
                  ),
                ),
              ],
            ),
    );
  }

  // ------------------------------------------------------------
  // APP BAR WITH NEW GRADIENT
  // ------------------------------------------------------------
  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryOrange,
              AppTheme.primaryRed,
            ],
          ),
        ),
      ),
      title: Text(
        "Manage Users",
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          
        ),
      ),

      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(45),
        child: Container(
          height: 45,
          color: Colors.white,
          child: TabBar(
            controller: tabController,
            isScrollable: true,
            labelColor: AppTheme.primaryOrange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryOrange,
            indicatorWeight: 3,
            labelPadding: const EdgeInsets.symmetric(horizontal: 22),
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: "Admins"),
              Tab(text: "Editorial Board"),
              Tab(text: "EIC"),
              Tab(text: "Users"),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // TOOLBAR
  // ------------------------------------------------------------
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      child: Column(
        children: [
          // SEARCH BOX
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.lightCardShadow,
            ),
            child: TextField(
              onChanged: (v) {
                searchQuery = v;
                _applyFilters();
              },
              decoration: InputDecoration(
                icon: const Icon(Icons.search, color: Colors.grey),
                hintText: "Search users...",
                border: InputBorder.none,
                hintStyle: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(child: _sortDropdown()),
              const SizedBox(width: 8),
              Expanded(child: _filterDropdown()),
              const SizedBox(width: 8),
              _resetButton(),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SORT DROPDOWN
  // ------------------------------------------------------------
  Widget _sortDropdown() {
    return _dropdownContainer(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: sortOption,
          isExpanded: true,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
          items: [
            "Name (A–Z)",
            "Name (Z–A)",
            "Status",
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            sortOption = v!;
            _applyFilters();
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // FILTER DROPDOWN
  // ------------------------------------------------------------
  Widget _filterDropdown() {
    bool isUsersTab = (tabController.index == 3);

    return Opacity(
      opacity: isUsersTab ? 1.0 : 0.35,
      child: IgnorePointer(
        ignoring: !isUsersTab,
        child: _dropdownContainer(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: filterStatus,
              isExpanded: true,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[800]),
              items: [
                "All",
                "pending",
                "approved",
                "rejected",
                "disapproved",
              ]
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (v) {
                filterStatus = v!;
                _applyFilters();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdownContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.lightCardShadow,
      ),
      child: child,
    );
  }

  // ------------------------------------------------------------
  // RESET BUTTON (FILLED + SHADOW)
  // ------------------------------------------------------------
  Widget _resetButton() {
    return InkWell(
      onTap: () {
        searchQuery = "";
        filterStatus = "All";
        sortOption = "Name (A–Z)";
        _applyFilters();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.30),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 20),
      ),
    );
  }

  // ------------------------------------------------------------
  // USER LIST
  // ------------------------------------------------------------
  Widget _buildUserList() {
    if (filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined,
                size: 60, color: Colors.grey.withOpacity(0.35)),
            const SizedBox(height: 12),
            Text("No users found", style: AppTheme.subtitleText),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: filteredUsers.length,
      itemBuilder: (_, i) => _userCard(filteredUsers[i]),
    );
  }
  // ------------------------------------------------------------
  // USER CARD (Modern Rounded Surface)
  // ------------------------------------------------------------
  Widget _userCard(dynamic user) {
    final name =
        "${user['first_name'] ?? ''} ${user['last_name'] ?? ''}".trim();

    final pic = user["profile_picture"];

    return InkWell(
      onTap: () => _openQuickView(user),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.cardRadius,
          boxShadow: AppTheme.lightCardShadow,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _openUserProfileDialog(user),
              child: CircleAvatar(
                radius: 30,
                backgroundImage: pic != null ? NetworkImage(pic) : null,
                backgroundColor: AppTheme.primaryOrange,
                child: pic == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : "?",
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTheme.cardTitleText),
                  const SizedBox(height: 2),
                  Text(
                    user["email"] ?? "",
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.smallLabel,
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _roleBadge(user["role"]),
                      _statusBadge(user["status"]),
                      if (user["is_eic"] == 1) _eicBadge(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BADGES
  // ------------------------------------------------------------
  Widget _roleBadge(String role) {
    Color c = Colors.blue;

    if (role == "admin") c = Colors.orange;
    if (role == "superadmin") c = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        role.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color c = Colors.grey;

    if (status == "approved") c = Colors.green;
    if (status == "pending") c = AppTheme.primaryOrange;
    if (status == "rejected" || status == "disapproved") c = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
    );
  }

  Widget _eicBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium, size: 14, color: Colors.black),
          const SizedBox(width: 4),
          Text(
            "EIC",
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // QUICK VIEW BOTTOM SHEET (Modern)
  // ------------------------------------------------------------
  void _openQuickView(dynamic user) {
    final pic = user["profile_picture"];
    final name = "${user['first_name']} ${user['last_name']}".trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.60,
        minChildSize: 0.45,
        maxChildSize: 0.90,
        builder: (_, controller) {
          return Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: ListView(
              controller: controller,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Profile Avatar
                GestureDetector(
                  onTap: () => _openUserProfileDialog(user),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: pic != null ? NetworkImage(pic) : null,
                    backgroundColor: AppTheme.primaryOrange,
                    child: pic == null
                        ? Text(
                            name[0].toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 16),

                // Name + Email
                Center(
                  child: Column(
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user["email"],
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Badges
                Center(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _roleBadge(user["role"]),
                      _statusBadge(user["status"]),
                      if (user["is_eic"] == 1) _eicBadge(),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Action Buttons (Floating Grid)
                _quickViewActions(user),
              ],
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // QuickView Action Buttons (D1 FILLED + S2 SHADOW)
  // ------------------------------------------------------------
  Widget _quickViewActions(dynamic user) {
    final email = user["email"];
    final role = user["role"];
    final status = user["status"];

    List<Widget> list = [];

    // ADMIN ACTIONS
    if (role == "admin") {
      bool active = status == "approved";

      list.add(_actionBtn(
        active ? "Disable" : "Enable",
        active ? Colors.red : AppTheme.primaryOrange,
        active ? Icons.block : Icons.check,
        () => _toggleAdminStatus(email, !active),
      ));
    }

    // USER ACTIONS
    if (role == "user") {
      if (status == "pending") {
        list.add(_actionBtn(
          "Approve",
          Colors.green,
          Icons.check,
          () => _toggleUserStatus(email, true),
        ));

        list.add(_actionBtn(
          "Disapprove",
          Colors.red,
          Icons.close,
          () => _toggleUserStatus(email, false),
        ));
      } else if (status == "approved") {
        list.add(_actionBtn(
          "Disapprove",
          Colors.red,
          Icons.close,
          () => _toggleUserStatus(email, false),
        ));
      } else {
        list.add(_actionBtn(
          "Approve",
          Colors.green,
          Icons.check,
          () => _toggleUserStatus(email, true),
        ));
      }
    }

    // EIC PROMOTION
    if (isEIC && role != "superadmin") {
      list.add(
        _actionBtn(
          "Promote to Editorial Board",
          AppTheme.primaryOrange,
          Icons.upgrade,
          () => _promoteToSuperAdmin(email),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: list,
      ),
    );
  }

  // ------------------------------------------------------------
  // ACTION BUTTON (HARD-FILL + MEDIUM SHADOW S2)
  // ------------------------------------------------------------
  Widget _actionBtn(
    String label,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.30),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 5), // S2 shadow
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // UNIVERSAL CONFIRMATION DIALOG (Modern Filled Buttons)
  // ------------------------------------------------------------
  Future<bool> _confirmAction(String title, String message) async {
    return await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              title,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            content: Text(
              message,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            actionsPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            actions: [
              // CANCEL (grey fill)
              _dialogFilledBtn(
                label: "Cancel",
                color: Colors.grey.shade600,
                onTap: () => Navigator.pop(context, false),
              ),

              // CONFIRM (orange fill)
              _dialogFilledBtn(
                label: "Confirm",
                color: AppTheme.primaryOrange,
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ------------------------------------------------------------
  // FILLED BUTTON USED IN CONFIRMATION DIALOGS (D1 STYLE)
  // ------------------------------------------------------------
  Widget _dialogFilledBtn({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.30),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 5), // S2 Shadow
            )
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BACKEND ACTIONS (WITH CONFIRMATION)
  // ------------------------------------------------------------
  Future<void> _toggleAdminStatus(String email, bool enable) async {
    if (!await _confirmAction(
      enable ? "Enable Admin?" : "Disable Admin?",
      "Are you sure you want to ${enable ? 'enable' : 'disable'} this admin?",
    )) return;

    final endpoint = enable ? "/approve-user" : "/disapprove-user";

    try {
      await http.post(
        Uri.parse("$baseUrl$endpoint"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "target_email": email,
          "approver_email": await _getLoggedInEmail(),

        }),
      );

      _showSnack(enable ? "Admin Enabled" : "Admin Disabled", false);
      _fetchUsers();
    } catch (e) {
      _showSnack("Error updating admin: $e", true);
    }
  }

  Future<void> _toggleUserStatus(String email, bool approve) async {
    if (!await _confirmAction(
      approve ? "Approve User?" : "Disapprove User?",
      "Are you sure you want to continue?",
    )) return;

    final endpoint = approve ? "/approve-user" : "/disapprove-user";

    try {
      await http.post(
        Uri.parse("$baseUrl$endpoint"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "target_email": email,
          "approver_email": await _getLoggedInEmail(),

        }),
      );

      _showSnack(
          approve ? "User Approved" : "User Disapproved", false);
      _fetchUsers();
    } catch (e) {
      _showSnack("Error updating user: $e", true);
    }
  }

  Future<void> _promoteToSuperAdmin(String email) async {
    if (!await _confirmAction(
      "Promote to Editorial Board?",
      "This user will be added to the Editorial Board.",
    )) return;

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/make-superadmin"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "approver_email": await _getLoggedInEmail(),

          "target_email": email,
        }),
      );

      if (res.statusCode == 200) {
        _showSnack("User Promoted Successfully", false);
        _fetchUsers();
      } else {
        _showSnack("Failed: ${res.body}", true);
      }
    } catch (e) {
      _showSnack("Error: $e", true);
    }
  }

  // ------------------------------------------------------------
  // PROFILE VIEW DIALOG (CLEAN MODERN LOOK)
  // ------------------------------------------------------------
  void _openUserProfileDialog(dynamic user) {
    final name =
        "${user['first_name']} ${user['last_name']}".trim();
    final email = user["email"];
    final role = user["role"];
    final status = user["status"];
    final pic = user["profile_picture"];

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: pic != null ? NetworkImage(pic) : null,
                  backgroundColor: AppTheme.primaryOrange,
                  child: pic == null
                      ? Text(
                          name[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),

                const SizedBox(height: 16),

                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 18),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _roleBadge(role),
                    _statusBadge(status),
                    if (user["is_eic"] == 1) _eicBadge(),
                  ],
                ),

                const SizedBox(height: 24),

                _dialogFilledBtn(
                  label: "Close",
                  color: Colors.grey.shade600,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // ADD ADMIN DIALOG (FULLY MODERNIZED)
  // ------------------------------------------------------------
  Future<void> _showAddAdminDialog() async {
    final firstController = TextEditingController();
    final middleController = TextEditingController();
    final lastController = TextEditingController();
    final emailController = TextEditingController();

    bool submitting = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              final f = firstController.text.trim();
              final l = lastController.text.trim();
              final e = emailController.text.trim();

              if (f.isEmpty || l.isEmpty || e.isEmpty) {
                setState(() =>
                    errorMessage = "First name, last name, and email required.");
                return;
              }

              setState(() {
                submitting = true;
                errorMessage = null;
              });

              try {
                final res = await http.post(
                  Uri.parse("$baseUrl/create-admin"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "creator_email": widget.email,
                    "first_name": f,
                    "middle_name": middleController.text.trim(),
                    "last_name": l,
                    "email": e,
                  }),
                );

                if (res.statusCode == 200) {
                  Navigator.pop(context);
                  _showSnack("Admin Created Successfully", false);
                  _fetchUsers();
                } else {
                  errorMessage = res.body;
                }
              } catch (err) {
                errorMessage = "Error: $err";
              }

              setState(() => submitting = false);
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // HEADER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryOrange,
                          AppTheme.primaryRed,
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "Add New Admin",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // FORM
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _dialogField(firstController, "First Name"),
                        const SizedBox(height: 10),
                        _dialogField(middleController, "Middle Name"),
                        const SizedBox(height: 10),
                        _dialogField(lastController, "Last Name"),
                        const SizedBox(height: 10),
                        _dialogField(emailController, "Email",
                            type: TextInputType.emailAddress),

                        if (errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            errorMessage!,
                            style: GoogleFonts.poppins(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          )
                        ],

                        const SizedBox(height: 20),

                        // SUBMIT BUTTON (Orange Filled)
                        InkWell(
                          onTap: submitting ? null : submit,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryOrange
                                      .withOpacity(0.30),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 5),
                                )
                              ],
                            ),
                            child: Center(
                              child: submitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      "Create Admin",
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // CANCEL BUTTON (Grey Filled)
                        InkWell(
                          onTap: submitting ? null : () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade600,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade600.withOpacity(0.30),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 5),
                                )
                              ],
                            ),
                            child: Center(
                              child: Text(
                                "Cancel",
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _dialogField(TextEditingController controller, String label,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BOTTOM NAVIGATION
  // ------------------------------------------------------------
  Widget _buildBottomNav() {
    return SuperAdminNav(
      currentIndex: currentIndex,
      role: "superadmin",
      onTap: (index) {
        if (index == currentIndex) return;

        setState(() => currentIndex = index);

        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SuperAdminDashboard(
                email: widget.email,
                role: "superadmin",
              ),
            ),
          );
        }

        if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SuperAdminArticlesPage(email: widget.email),
            ),
          );
        }

        if (index == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SuperAdminUsersPage(email: widget.email),
            ),
          );
        }

        if (index == 3) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SuperAdminProfilePage(
                email: widget.email,
              ),
            ),
          );
        }
      },
    );
  }
}
