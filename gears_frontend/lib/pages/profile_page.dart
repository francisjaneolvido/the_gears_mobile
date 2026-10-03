import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:gears_frontend/admin/admin_dashboard.dart';

import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';
import 'package:gears_frontend/widgets/bottom_nav.dart';
import 'package:gears_frontend/pages/login_page.dart';
import 'profile_details_page.dart';

class ProfilePage extends StatefulWidget {
  final String email;
  final int userId;
  

  const ProfilePage({
    super.key,
    required this.email,
    required this.userId,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String fullName = "User Name";
  String email = "";
  int userId = 0;
  String currentView = "user"; // default


  String userStatus = "";
  String? _profileImageUrl;

  File? _localProfileImage;
  bool _isLoading = true;

  final ImagePicker _picker = ImagePicker();

 @override
void initState() {
  super.initState();
  _loadUserData();
  _loadCurrentView();
}

Future<void> _loadCurrentView() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    currentView = prefs.getString("current_view") ?? "user";
  });
}

  // ----------------------------------------------------
  // LOAD USER PROFILE + PROFILE PICTURE
  // ----------------------------------------------------
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    fullName = prefs.getString("name") ?? "User Name";
    email = prefs.getString("email") ?? widget.email;
    userId = prefs.getInt("id") ?? widget.userId;
    _profileImageUrl = prefs.getString("profile_picture_url");

    setState(() {});

    try {
      final res = await http.get(Uri.parse("$baseUrl/get-users"));

      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);

        final found = list.firstWhere(
          (u) => u["id"] == userId,
          orElse: () => null,
        );

        if (found != null) {
          fullName = found["full_name"] ??
              "${found["first_name"] ?? ""} ${found["last_name"] ?? ""}".trim();

          email = found["email"] ?? email;
          userStatus = found["status"] ?? "";

          // Backend stores a full public URL
          _profileImageUrl = found["profile_picture"] ?? _profileImageUrl;

          // Save locally
          prefs.setString("name", fullName);
          prefs.setString("email", email);
          prefs.setInt("id", userId);
          prefs.setString("user_status", userStatus);
          if (_profileImageUrl != null) {
            prefs.setString("profile_picture_url", _profileImageUrl!);
          }
        }
      }
    } catch (e) {
      debugPrint("Profile fetch error: $e");
    }

    setState(() => _isLoading = false);
  }

  
Future<void> _switchToAdminMode() async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString("current_view", "admin");

  // 🔥 Read elevated role (admin or superadmin)
  final elevatedEmail =
      prefs.getString("admin_email") ??
      prefs.getString("superadmin_email");

  final elevatedRole =
      prefs.getString("admin_role") ??
      prefs.getString("superadmin_role");

  if (elevatedEmail == null || elevatedRole == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Admin/SuperAdmin session not found."),
      ),
    );
    return;
  }

  if (!mounted) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => AdminDashboard(
        email: elevatedEmail,
        role: elevatedRole,
      ),
    ),
  );
}


  // ----------------------------------------------------
  // PICK IMAGE
  // ----------------------------------------------------
  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) return;

      final file = File(picked.path);

      if (await file.length() > 2 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Image must be below 2MB.")),
        );
        return;
      }

      setState(() => _localProfileImage = file);

      await _uploadProfilePicture(file);
    } catch (e) {
      debugPrint("Pick image error: $e");
    }
  }

  // ----------------------------------------------------
  // UPLOAD TO BACKEND (EMAIL REQUIRED)
  // ----------------------------------------------------
  Future<void> _uploadProfilePicture(File file) async {
    try {
      final uri = Uri.parse("$baseUrl/upload-profile-picture");

      final req = http.MultipartRequest("POST", uri)
        ..fields["email"] = email
        ..files.add(await http.MultipartFile.fromPath(
          "profile_picture",
          file.path,
        ));

      final streamed = await req.send();
      final response = await http.Response.fromStream(streamed);

      print("UPLOAD STATUS: ${response.statusCode}");
      print("UPLOAD BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String? url = data["profile_picture_url"];

        if (url != null) {
          _profileImageUrl = url;

          final prefs = await SharedPreferences.getInstance();
          prefs.setString("profile_picture_url", url);

          setState(() {
            _localProfileImage = null;
          });
        }
      } else {
        print("Upload failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("Upload error: $e");
    }
  }

  // ----------------------------------------------------
  // LOGOUT
  // ----------------------------------------------------
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // ----------------------------------------------------
  // AVATAR PROVIDER
  // ----------------------------------------------------
 // ----------------------------------------------------
// AVATAR WIDGET (SAFE, WITH FALLBACK)
// ----------------------------------------------------
Widget _avatarWidget() {
  // 1. If user just picked an image locally
  if (_localProfileImage != null) {
    return CircleAvatar(
      radius: 42,
      backgroundColor: Colors.white,
      backgroundImage: FileImage(_localProfileImage!),
    );
  }

  // 2. If backend has a URL (Supabase public URL)
  if (_profileImageUrl != null && _profileImageUrl!.startsWith("http")) {
    return CircleAvatar(
      radius: 42,
      backgroundColor: Colors.white,
      child: ClipOval(
        child: Image.network(
          _profileImageUrl!,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
          // 👇 This prevents crashes when the URL returns 400/404/etc.
          errorBuilder: (context, error, stackTrace) {
            print("Profile image load error: $error");
            return Image.asset(
              "assets/profile_placeholder.jpg",
              width: 84,
              height: 84,
              fit: BoxFit.cover,
            );
          },
        ),
      ),
    );
  }

  // 3. Fallback placeholder
  return const CircleAvatar(
    radius: 42,
    backgroundImage: AssetImage("assets/profile_placeholder.jpg"),
  );
}

  // ----------------------------------------------------
  // BUILD UI
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.cardWhite,
        centerTitle: true,
        title: Text(
          "Profile",
          style: GoogleFonts.poppins(
            color: AppTheme.textDark,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 26),

                  _buildSectionTitle("Account Settings"),
                  const SizedBox(height: 14),

                  _buildOption(
                    Icons.person_outline,
                    "My Account",
                    subtitle: "Edit your profile and details",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileDetailsPage(),
                        ),
                      );
                    },
                  ),

                  _buildOption(
                    Icons.bookmark_outline,
                    "Saved Articles",
                    subtitle: "View your saved posts",
                    onTap: () {},
                  ),

                  _buildOption(
                    Icons.notifications_outlined,
                    "Notification Settings",
                    subtitle: "Manage your alerts",
                    onTap: () {},
                  ),

                  const SizedBox(height: 26),
                  _buildSectionTitle("More"),
                  const SizedBox(height: 14),

                  _buildOption(
                    Icons.help_outline,
                    "Help & Support",
                    subtitle: "Assistance & FAQs",
                    onTap: () {},
                  ),

                  _buildOption(
                    Icons.privacy_tip_outlined,
                    "Privacy Policy",
                    subtitle: "View data protection details",
                    onTap: () {},
                  ),

                  _buildOption(
                    Icons.info_outline,
                    "About App",
                    subtitle: "Learn more about The Gears",
                    onTap: () {},
                  ),

                  const SizedBox(height: 26),
                  _buildLogoutButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      bottomNavigationBar: BottomNav(
        currentIndex: 3,
        email: email,
        userId: userId,
      ),
    );
  }

  // -----------------------------------------------------
  // SECTION TITLE
  // -----------------------------------------------------
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppTheme.textDark,
        ),
      ),
    );
  }

  // -----------------------------------------------------
  // HEADER CARD
  // -----------------------------------------------------
Widget _buildHeaderCard() {
  return Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppTheme.primaryOrange, AppTheme.primaryRed],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: AppTheme.primaryRed.withOpacity(0.25),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Stack(
              children: [
                _avatarWidget(),

                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(5),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 18,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 18),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Text(
                        "User ID: $userId",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 10),

                      if (userStatus.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: userStatus == "approved"
                                ? Colors.green.shade600
                                : Colors.orange.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            userStatus.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // SWITCH TO ADMIN BUTTON (✔ FIXED), ONLY ONE FUTUREBUILDER
        FutureBuilder(
  future: SharedPreferences.getInstance(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const SizedBox.shrink();
    final prefs = snapshot.data as SharedPreferences;

    final elevatedEmail =
        prefs.getString("admin_email") ??
        prefs.getString("superadmin_email");

    final elevatedRole =
        prefs.getString("admin_role") ??
        prefs.getString("superadmin_role");

    final hasElevatedSession =
        elevatedEmail != null && elevatedRole != null;

    final isElevatedRole =
        elevatedRole == "admin" ||
        elevatedRole == "superadmin";

    if (currentView == "admin") return const SizedBox.shrink();
    if (!hasElevatedSession || !isElevatedRole) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDashboard(
              email: elevatedEmail!,
              role: elevatedRole!,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.22),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.35),
            width: 1.3,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              elevatedRole == "superadmin"
                  ? "Switch to SuperAdmin Mode"
                  : "Switch to Admin Mode",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  },
),

      ],
    ),
  );
}



  // -----------------------------------------------------
  // OPTION TILE
  // -----------------------------------------------------
  Widget _buildOption(
    IconData icon,
    String title, {
    required VoidCallback onTap,
    String? subtitle,
    Widget? trailing,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.lightCardShadow,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryOrange, AppTheme.primaryRed],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: textColor ?? AppTheme.textDark,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: AppTheme.textGrey,
                ),
              )
            : null,
        trailing: trailing ??
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
      ),
    );
  }

  // -----------------------------------------------------
  // LOGOUT BUTTON
  // -----------------------------------------------------
  Widget _buildLogoutButton() {
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
              color: Colors.redAccent,
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
