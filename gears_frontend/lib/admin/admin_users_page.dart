// PART 1 OF 2  ─────────────────────────────────────────────────────────────
// CLEAN LOGIC + NETWORKING + SEARCH + STATE MANAGEMENT
// ─────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';

class AdminManageUsersPage extends StatefulWidget {
  final String adminEmail;

  const AdminManageUsersPage({super.key, required this.adminEmail});

  @override
  State<AdminManageUsersPage> createState() => _AdminManageUsersPageState();
}

class _AdminManageUsersPageState extends State<AdminManageUsersPage> {
  List<dynamic> users = [];
  List<dynamic> filteredUsers = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  // ─────────────────────────────────────────────────────────────
  // FETCH USERS (Only regular users, exclude admin + superadmin)
  // ─────────────────────────────────────────────────────────────
  Future<void> fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse("$baseUrl/get-users"));

      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);

        // Keep ONLY regular users (NOT admin or superadmin)
        users = data.where((u) => u["role"] == "user").toList();

        filteredUsers = users;
      }
    } catch (e) {
      debugPrint("Error fetching users: $e");
    }

    setState(() => isLoading = false);
  }

  // ─────────────────────────────────────────────────────────────
  // SEARCH FILTER
  // ─────────────────────────────────────────────────────────────
  void filterUsers() {
    setState(() {
      filteredUsers = users.where((user) {
        final q = searchQuery.toLowerCase();

        return user["full_name"].toLowerCase().contains(q) ||
            user["email"].toLowerCase().contains(q);
      }).toList();
    });
  }
void _showUserDetails(Map<String, dynamic> user) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ───────── Header Row ─────────
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 28, color: Colors.black87),
                  const SizedBox(width: 10),
                  Text(
                    "User Details",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ───────── Card-like Info Box ─────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _modernDetail("Full Name", user["full_name"]),
                    _modernDetail("Email", user["email"]),
                    _modernDetail("Role", "User"),
                    _modernDetail("Status", user["status"] ?? "N/A"),
                    _modernDetail("View-Only Mode",
                        user["is_view_only"] == true ? "Enabled" : "Disabled"),
                    _modernDetail("Date Joined", user["created_at"] ?? "Unknown"),
                    _modernDetail("Last Active", user["last_active"] ?? "Unknown"),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ───────── Close Button ─────────
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black87,
                  ),
                  child: Text(
                    "Close",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      );
    },
  );
}
Widget _modernDetail(String label, dynamic value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value?.toString() ?? "N/A",
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
      ],
    ),
  );
}


  // ─────────────────────────────────────────────────────────────
  // TOGGLE VIEW-ONLY MODE
  // ─────────────────────────────────────────────────────────────
  Future<void> toggleViewOnly(String email, bool newValue) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/set-view-only"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "target_email": email,
          "moderator_email": widget.adminEmail,
          "view_only": newValue
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("View-only updated for $email"),
            backgroundColor: Colors.green,
          ),
        );
        fetchUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update view-only"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Toggle error: $e");
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BADGES (CLEANED)
  // ─────────────────────────────────────────────────────────────
  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        "USER",
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF7B1FA2),
        ),
      ),
    );
  }

  Widget _buildViewOnlyBadge(bool viewOnly) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: viewOnly ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        viewOnly ? "VIEW ONLY" : "FULL ACCESS",
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: viewOnly ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
        ),
      ),
    );
  }

// PART 2 OF 2  ─────────────────────────────────────────────────────────────
// USER CARD + FINAL UI BUILD
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────
// USER CARD UI — Clean, Professional, View-Only Toggle
// ─────────────────────────────────────────────────────────────
Widget _buildUserCard(Map<String, dynamic> user) {
  final String name = user["full_name"] ?? "Unknown";
  final String email = user["email"];
  final bool isViewOnly = user["is_view_only"] == true;

  String? pic = user["profile_picture"];
  String? profileUrl;

  // Profile photo logic
  if (pic != null && pic.isNotEmpty) {
    profileUrl =
        pic.startsWith("http") ? pic : "$baseUrl/uploads/$pic";
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black12.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, 3),
        )
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Avatar ───────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: (profileUrl != null)
                  ? Image.network(
                      profileUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF9A825), Color(0xFFF57C00)],
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        name[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),

            const SizedBox(width: 16),

            // ─── Name & Email ───────────────────────────────────────
            Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15.5,
                color: AppTheme.textDark,
              ),
            ),
          ),

          // ─── INFO ICON ──────────────────────────
          InkWell(
            onTap: () => _showUserDetails(user),
            child: const Icon(Icons.info_outline, size: 20, color: Colors.blueGrey),
          ),
        ],
      ),

      const SizedBox(height: 4),

      Text(
        email,
        style: GoogleFonts.poppins(
          fontSize: 12.5,
          color: Colors.grey[600],
        ),
      ),

      const SizedBox(height: 8),

      Row(
        children: [
          _buildRoleBadge("user"),
          const SizedBox(width: 8),
          _buildViewOnlyBadge(isViewOnly),
        ],
      ),
    ],
  ),
),

          ],
        ),

        const SizedBox(height: 18),
        Divider(color: Colors.grey.shade300),
        const SizedBox(height: 18),

        // ─────────────────────────────────────────────────────────
        // VIEW-ONLY TOGGLE SWITCH
        // ─────────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "View-Only Mode",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),

            Switch(
              value: isViewOnly,
              activeColor: Colors.redAccent,
              onChanged: (newValue) {
                toggleViewOnly(email, newValue);
              },
            )
          ],
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// FINAL UI BUILD() METHOD
// ─────────────────────────────────────────────────────────────
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.grey[50],

    body: RefreshIndicator(
      onRefresh: fetchUsers,
      color: AppTheme.primaryOrange,
      child: Column(
        children: [
          // ───────────────────────────────────────────────────────
          // SEARCH BAR AREA (No filters)
          // ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (v) {
                    searchQuery = v;
                    filterUsers();
                  },
                  decoration: InputDecoration(
                    hintText: "Search users...",
                    hintStyle: GoogleFonts.poppins(fontSize: 14),
                    fillColor: Colors.grey.shade100,
                    filled: true,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ───────────────────────────────────────────────────────
          // USER LIST
          // ───────────────────────────────────────────────────────
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredUsers.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.only(top: 120),
                        children: [
                          Column(
                            children: [
                              Icon(Icons.people_outline,
                                  size: 70, color: Colors.grey[400]),
                              const SizedBox(height: 14),
                              Text(
                                "No users found",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              )
                            ],
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 16),
                        itemCount: filteredUsers.length,
                        itemBuilder: (_, index) =>
                            _buildUserCard(filteredUsers[index]),
                      ),
          ),
        ],
      ),
    ),
  );
}
}