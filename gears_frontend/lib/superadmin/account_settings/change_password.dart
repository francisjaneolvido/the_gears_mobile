import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;



import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';

class ChangePasswordPage extends StatefulWidget {
  final String email;

  const ChangePasswordPage({super.key, required this.email});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final oldCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  bool loading = false;
  bool showOld = false;
  bool showNew = false;
  bool showConfirm = false;

  // =============== PASSWORD VALIDATION FLAGS ===============
  bool has8Chars = false;
  bool hasUpper = false;
  bool hasLower = false;
  bool hasNumber = false;
  bool hasSpecial = false;

  // Update validation state real-time
  void _validatePassword(String value) {
    setState(() {
      has8Chars = value.length >= 8;
      hasUpper = value.contains(RegExp(r'[A-Z]'));
      hasLower = value.contains(RegExp(r'[a-z]'));
      hasNumber = value.contains(RegExp(r'[0-9]'));
      hasSpecial = value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    });
  }

  // ---------------------------------------------------------------------------
  // SEND REQUEST
  // ---------------------------------------------------------------------------
  Future<void> _changePassword() async {
    if (!has8Chars || !hasUpper || !hasLower || !hasNumber || !hasSpecial) {
      _showErrorDialog("Your new password does not meet all requirements.");
      return;
    }

    if (newCtrl.text != confirmCtrl.text) {
      _showErrorDialog("Passwords do not match");
      return;
    }

    setState(() => loading = true);

    final res = await http.post(
      Uri.parse("$baseUrl/change-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": widget.email,
        "old_password": oldCtrl.text,
        "new_password": newCtrl.text,
      }),
    );

    setState(() => loading = false);

    final body = jsonDecode(res.body);

    if (res.statusCode == 200) {
      _showSuccessDialog();
    } else {
      _showErrorDialog(body["message"]);
    }
  }

  // ---------------------------------------------------------------------------
  // MODERN SUCCESS DIALOG
  // ---------------------------------------------------------------------------
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.titleGradient,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                "Password Updated",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your password has been changed successfully.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textGrey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30, vertical: 12),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Text(
                  "Done",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MODERN ERROR DIALOG
  // ---------------------------------------------------------------------------
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.15),
                ),
                child: const Icon(Icons.error_outline,
                    color: Colors.red, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                "Error",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textGrey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "OK",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,

      // -------------------- GRADIENT APP BAR ---------------------
appBar: AppBar(
  automaticallyImplyLeading: false,
  flexibleSpace: Container(
    decoration: const BoxDecoration(
      gradient: AppTheme.titleGradient,
    ),
  ),
  titleSpacing: 0,
  title: Row(
    children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SvgPicture.asset(
            "assets/icons/back.svg",
            height: 24,
            width: 24,
            color: Colors.white,
          ),
        ),
      ),
      Text(
        "Change Password",
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
    ],
  ),
),




      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // OLD PASSWORD
            _fieldLabel("Old Password"),
            _passwordField(oldCtrl, showOld, () {
              setState(() => showOld = !showOld);
            }),
            const SizedBox(height: 20),

            // NEW PASSWORD
            _fieldLabel("New Password"),
            _passwordField(newCtrl, showNew, () {
              setState(() => showNew = !showNew);
            }, onChanged: _validatePassword),
            const SizedBox(height: 14),

            // PASSWORD REQUIREMENTS
            _buildRequirement("At least 8 characters", has8Chars),
            _buildRequirement("Include uppercase letter (A-Z)", hasUpper),
            _buildRequirement("Include lowercase letter (a-z)", hasLower),
            _buildRequirement("Include number (0-9)", hasNumber),
            _buildRequirement("Include special character (!@#\$...)", hasSpecial),

            const SizedBox(height: 25),

            // CONFIRM PASSWORD
            _fieldLabel("Confirm New Password"),
            _passwordField(confirmCtrl, showConfirm, () {
              setState(() => showConfirm = !showConfirm);
            }),
            const SizedBox(height: 40),

            // SUBMIT BUTTON
            loading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Update Password",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  Widget _buildRequirement(String text, bool satisfied) {
    return Row(
      children: [
        Icon(
          satisfied ? Icons.check_circle : Icons.circle_outlined,
          size: 18,
          color: satisfied ? AppTheme.primaryOrange : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: satisfied ? AppTheme.primaryOrange : Colors.grey[600],
            fontWeight: satisfied ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AppTheme.textDark,
      ),
    );
  }

  Widget _passwordField(TextEditingController controller, bool visible,
      VoidCallback toggle,
      {Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      style: GoogleFonts.poppins(),
      onChanged: onChanged,
      decoration: InputDecoration(
        suffixIcon: IconButton(
          icon: Icon(
            visible ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey,
          ),
          onPressed: toggle,
        ),
      ),
    );
  }
}
