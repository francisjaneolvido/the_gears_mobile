import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gears_frontend/pages/home_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:gears_frontend/admin/admin_dashboard.dart';


// Correct Admin Pages

// Account Settings
import 'package:gears_frontend/superadmin/account_settings/change_password.dart';
import 'package:gears_frontend/superadmin/account_settings/update_email.dart';

import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';
import 'package:gears_frontend/pages/login_page.dart';

class AdminProfileSettings extends StatefulWidget {
  final String email;

  const AdminProfileSettings({super.key, required this.email});

  @override
  State<AdminProfileSettings> createState() => _AdminProfileSettingsState();
}

class _AdminProfileSettingsState extends State<AdminProfileSettings> {
  String fullName = "";
  String email = "";
  int userId = 0;
  String role = "admin";
  String status = "";

  String? profilePictureUrl;
  File? localImage;

  bool isLoading = true;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    email = widget.email;
    _loadAdminData();
  }

  // --------------------------------------------------
  // LOAD ADMIN PROFILE
  // --------------------------------------------------
  Future<void> _loadAdminData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      final res = await http.get(Uri.parse("$baseUrl/get-users"));

      if (res.statusCode == 200) {
        List<dynamic> list = jsonDecode(res.body);

        final admin = list.firstWhere(
          (u) => u["email"] == widget.email,
          orElse: () => null,
        );

        if (admin != null) {
          setState(() {
            fullName = admin["full_name"] ?? "Admin User";
            email = admin["email"];
            userId = admin["id"];
            role = admin["role"] ?? "admin";
            status = admin["status"] ?? "";

            String? pic = admin["profile_picture"];
            if (pic != null && pic.isNotEmpty) {
              profilePictureUrl =
                  pic.startsWith("http") ? pic : "$baseUrl/uploads/$pic";
            } else {
              profilePictureUrl = null;
            }

            isLoading = false;
          });

          // Save to prefs
          prefs.setString("admin_name", fullName);
          prefs.setString("admin_email", email);
          prefs.setInt("admin_id", userId);
          prefs.setString("admin_role", role);
          prefs.setString("admin_status", status);
          if (profilePictureUrl != null) {
            prefs.setString("admin_picture", profilePictureUrl!);
          }
        }
      }
    } catch (e) {
      debugPrint("Admin load error: $e");
    }

    setState(() => isLoading = false);
  }

  // --------------------------------------------------
  // PROFILE IMAGE PICKER
  // --------------------------------------------------
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

      final streamed = await req.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String? url = data["profile_picture_url"];
        if (url == null && data["filename"] != null) {
          url = "$baseUrl/uploads/${data["filename"]}";
        }

        setState(() {
          profilePictureUrl = url;
          localImage = null;
        });

        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString("admin_picture", profilePictureUrl!);
      }
    } catch (e) {
      debugPrint("Upload failed: $e");
    }
  }

  // --------------------------------------------------
  // SWITCH TO USER MODE
  // --------------------------------------------------
 Future<void> _switchToUserMode() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // DO NOT REMOVE ADMIN SESSION DATA
  await prefs.setString("current_view", "user");

  final userEmail = prefs.getString("user_email") ?? "";
  final userId = prefs.getInt("id") ?? 0;
  final userStatus = prefs.getString("user_status") ?? "";

  if (!mounted) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => HomePage(
        email: userEmail,
        userId: userId,
        userStatus: userStatus,
      ),
    ),
  );
}






  // --------------------------------------------------
  // LOGOUT
  // --------------------------------------------------
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

  // --------------------------------------------------
  // UI HELPERS
  // --------------------------------------------------
  ImageProvider _avatar() {
    if (localImage != null) return FileImage(localImage!);
    if (profilePictureUrl != null) return NetworkImage(profilePictureUrl!);
    return const AssetImage("assets/images/profile_placeholder.png");
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  // --------------------------------------------------
  // BUILD UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -----------------------------------------
                  // HEADER WITH GRADIENT
                  // -----------------------------------------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryOrange, AppTheme.primaryRed],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 47,
                                backgroundImage: _avatar(),
                              ),
                            ),
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
                                  child: const Icon(Icons.camera_alt,
                                      size: 20, color: AppTheme.primaryOrange),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Text(
                          fullName,
                          style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          email,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _badge(role, Colors.deepPurple),
                            const SizedBox(width: 8),
                            if (status.isNotEmpty)
                              _badge(
                                  status,
                                  status == "approved"
                                      ? Colors.green
                                      : Colors.orange),
                          ],
                        ),

                        const SizedBox(height: 16),

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
                                width: 1.5,
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
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // -----------------------------------------
                  // CONTENT AREA
                  // -----------------------------------------
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),

                        Text(
                          "Account Settings",
                          style: GoogleFonts.poppins(
                              fontSize: 17, fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(height: 14),

                        _option(Icons.lock, "Change Password", () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChangePasswordPage(email: email),
                            ),
                          );
                        }),

                        _option(Icons.email, "Update Email", () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UpdateEmailPage(email: email),
                            ),
                          );
                        }),

                        const SizedBox(height: 26),

                        Text(
                          "Admin Tools",
                          style: GoogleFonts.poppins(
                              fontSize: 17, fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(height: 14),

                        // Manage Articles
                        _option(Icons.article, "Manage Articles", () {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => AdminDashboard(
        email: email,
        role: role,
        initialIndex: 1,   // <<< Opens "My Articles"
      ),
    ),
  );
}),


                        // Manage Users
                        _option(Icons.people, "Manage Users", () {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => AdminDashboard(
        email: email,
        role: role,
        initialIndex: 2,   // <<< Opens "Manage Users"
      ),
    ),
  );
}),


                        // Moderation Logs
                        _option(Icons.report_gmailerrorred, "Moderation Logs",
                            () {}),

                        const SizedBox(height: 26),

                        Text(
                          "More",
                          style: GoogleFonts.poppins(
                              fontSize: 17, fontWeight: FontWeight.w600),
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

  // -----------------------------------------
  // OPTION TILE
  // -----------------------------------------
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
        trailing:
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
      ),
    );
  }

  // -----------------------------------------
  // LOGOUT BUTTON
  // -----------------------------------------
  Widget _logoutButton() {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text("Logout",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                )),
            content: Text(
              "Are you sure you want to log out?",
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.poppins(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _logout();
                },
                child: Text(
                  "Logout",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
