// -----------------------------------------------------------------------------
// SUPERADMIN PROFILE PAGE — FINAL FIX WITH SAFE isEIC BOOL HANDLING
// -----------------------------------------------------------------------------

import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gears_frontend/pages/home_page.dart';
import 'package:gears_frontend/superadmin/account_settings/update_email.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';
import 'package:gears_frontend/pages/login_page.dart';

// NAVIGATION
import 'package:gears_frontend/widgets/superadmin_nav.dart';
import 'package:gears_frontend/superadmin/superadmin_dashboard.dart';
import 'package:gears_frontend/superadmin/superadmin_articles_page.dart';
import 'package:gears_frontend/superadmin/superadmin_users_page.dart';
import 'package:gears_frontend/superadmin/account_settings/change_password.dart';


class SuperAdminProfilePage extends StatefulWidget {
  final String email;

  const SuperAdminProfilePage({super.key, required this.email});

  @override
  State<SuperAdminProfilePage> createState() => _SuperAdminProfilePageState();
}

class _SuperAdminProfilePageState extends State<SuperAdminProfilePage> {
  String fullName = "";
  String email = "";
  int userId = 0;

  String role = "superadmin";
  String status = "";
  bool isEIC = false; // FIXED SAFE BOOL

  String? profilePictureUrl;
  File? localImage;

  bool isLoading = true;
  final _picker = ImagePicker();

  int currentIndex = 3; // PROFILE TAB

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  // ---------------------------------------------------------------------------
  // LOAD PROFILE DATA
  // ---------------------------------------------------------------------------
  Future<void> _loadAdminData() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/get-users"));

      if (res.statusCode == 200) {
        List<dynamic> list = jsonDecode(res.body);

        final admin = list.firstWhere(
          (u) => u["email"] == widget.email,
          orElse: () => null,
        );

        if (admin != null) {
  setState(() {
    fullName = admin["full_name"] ?? "";
    email = admin["email"] ?? widget.email;
    userId = admin["id"] ?? 0;

    role = admin["role"] ?? "superadmin";
    status = admin["status"] ?? "pending";

    // ⭐ FIX: Convert int (0/1) or bool to a real bool
    isEIC = admin["is_eic"] == true || admin["is_eic"] == 1;

    profilePictureUrl = admin["profile_picture"];
    isLoading = false;
  });
}

      }
    } catch (e) {
      debugPrint("Profile Load Error: $e");
    }

   
  }

  // ---------------------------------------------------------------------------
  // PICK IMAGE & UPLOAD
  // ---------------------------------------------------------------------------
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() => localImage = file);

    await _uploadProfilePicture(file);
  }

  Future<void> _uploadProfilePicture(File file) async {
    try {
      final req = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/upload-profile-picture"),
      );

      req.fields["email"] = email;
      req.files.add(await http.MultipartFile.fromPath(
        "profile_picture",
        file.path,
      ));

      final resp = await req.send();
      final response = await http.Response.fromStream(resp);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          profilePictureUrl = data["profile_picture_url"];
          localImage = null;
        });
      }
    } catch (e) {
      debugPrint("Upload error: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // SWITCH USER MODE
  // ---------------------------------------------------------------------------
 Future<void> _switchToUserMode() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  await prefs.setString("current_view", "user");

  // Save user-view info
  await prefs.setString("user_email", email);
  await prefs.setInt("user_id", userId);
  await prefs.setString("user_status", status);

  // ❌ DO NOT DELETE SUPERADMIN DATA

  if (!mounted) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => HomePage(
        email: email,
        userId: userId,
        userStatus: status,
      ),
    ),
  );
}




  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // ---------------------------------------------------------------------------
  // BADGE UI
  // ---------------------------------------------------------------------------
  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AVATAR IMAGE HANDLER
  // ---------------------------------------------------------------------------
  ImageProvider _avatar() {
  print("PROFILE PIC URL: $profilePictureUrl");

  if (localImage != null) return FileImage(localImage!);
  if (profilePictureUrl != null && profilePictureUrl!.isNotEmpty) {
    return NetworkImage(profilePictureUrl!);
  }

  return const AssetImage("assets/images/profile_placeholder.png");
}

  // ---------------------------------------------------------------------------
  // NAVIGATION ROUTER (same as dashboard)
  // ---------------------------------------------------------------------------
  void _onNavTap(int index) {
    if (index == currentIndex) return;

    Widget page;

    switch (index) {
      case 0:
        page = SuperAdminDashboard(email: widget.email, role: role);
        break;
      case 1:
        page = SuperAdminArticlesPage(email: widget.email);
        break;
      case 2:
        page = SuperAdminUsersPage(email: widget.email);
        break;
      default:
        page = SuperAdminProfilePage(email: widget.email);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

    setState(() => currentIndex = index);
  }

  // ---------------------------------------------------------------------------
  // BUILD UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,

      bottomNavigationBar: SuperAdminNav(
        currentIndex: currentIndex,
        onTap: _onNavTap,
        role: isEIC ? "eic" : "superadmin",
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------------------------------------------------------------------
                  // HEADER
                  // ---------------------------------------------------------------------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryOrange, AppTheme.primaryRed],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        // ---------------- Avatar ----------------
                        Stack(
                          children: [
                            CircleAvatar(
  radius: 47,
  backgroundColor: Colors.white,
  child: ClipOval(
    child: profilePictureUrl != null && profilePictureUrl!.isNotEmpty
        ? Image.network(
            profilePictureUrl!,
            fit: BoxFit.cover,
            width: 94,
            height: 94,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                "assets/images/profile_placeholder.png",
                fit: BoxFit.cover,
                width: 94,
                height: 94,
              );
            },
          )
        : Image.asset(
            "assets/images/profile_placeholder.png",
            fit: BoxFit.cover,
            width: 94,
            height: 94,
          ),
  ),
),


                            // Change Picture Button
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: AppTheme.primaryOrange,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ---------------- Name ----------------
                        Text(
                          fullName,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // ---------------- Email ----------------
                        Text(
                          email,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ---------------- BADGES ----------------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (status.isNotEmpty)
                              _badge(
                                status,
                                status == "approved"
                                    ? Colors.green
                                    : Colors.orange,
                              ),

                            const SizedBox(width: 8),

                            _badge(
                              isEIC ? "EIC" : "SUPERADMIN",
                              isEIC
                                  ? Colors.amber.shade700
                                  : Colors.deepPurple,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ---------------- Switch Mode ----------------
                        GestureDetector(
                          onTap: _switchToUserMode,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.swap_horiz,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "Switch to User Mode",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ---------------------------------------------------------------------
                  // CONTENT SECTION
                  // ---------------------------------------------------------------------
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ACCOUNT SETTINGS
                        Text(
                          "Account Settings",
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),

                        _option(Icons.lock, "Change Password", () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChangePasswordPage(email: widget.email),
    ),
  );
}),

                       _option(Icons.email, "Update Email", () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => UpdateEmailPage(email: widget.email),
    ),
  );
}),


                        const SizedBox(height: 26),

                        // SUPERADMIN TOOLS
                        Text(
                          "SuperAdmin Tools",
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),

                        _option(Icons.article, "Manage Articles", () {
                          Navigator.pushNamed(context, "/admin-articles");
                        }),
                        _option(Icons.people, "Manage Users", () {
                          Navigator.pushNamed(context, "/admin-users");
                        }),
                        _option(Icons.security, "Moderation Logs", () {}),

                        const SizedBox(height: 26),

                        // MORE
                        Text(
                          "More",
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),

                        _option(Icons.help_outline, "Help & Support", () {}),
                        _option(Icons.privacy_tip_outlined, "Privacy Policy",
                            () {}),
                        _option(Icons.info_outline, "About App", () {}),

                        const SizedBox(height: 26),
                        _logoutButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // OPTION TILE
  // ---------------------------------------------------------------------------
  Widget _option(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.lightCardShadow,
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryOrange, AppTheme.primaryRed],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15.5,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios,
            color: Colors.grey, size: 16),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOGOUT BUTTON
  // ---------------------------------------------------------------------------
  Widget _logoutButton() {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.lightCardShadow,
        ),
        child: Center(
          child: Text(
            "Log Out",
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
