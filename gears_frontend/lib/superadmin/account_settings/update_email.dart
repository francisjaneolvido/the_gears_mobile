import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';

class UpdateEmailPage extends StatefulWidget {
  final String email;

  const UpdateEmailPage({super.key, required this.email});

  @override
  State<UpdateEmailPage> createState() => _UpdateEmailPageState();
}

class _UpdateEmailPageState extends State<UpdateEmailPage> {
  final newEmailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool loading = false;
  bool showPass = false;

  // -------------------- Email Validation --------------------
  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$');
    return regex.hasMatch(email);
  }

  // -------------------- Submit Update --------------------
  Future<void> _updateEmail() async {
    final newEmail = newEmailCtrl.text.trim();
    final password = passCtrl.text;

    if (!_isValidEmail(newEmail)) {
      _showErrorDialog("Please enter a valid email address.");
      return;
    }

    if (newEmail == widget.email) {
      _showErrorDialog("New email cannot be the same as your current email.");
      return;
    }

    if (password.isEmpty) {
      _showErrorDialog("Please enter your password to verify.");
      return;
    }

    setState(() => loading = true);

    final res = await http.post(
      Uri.parse("$baseUrl/update-email"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "old_email": widget.email,
        "new_email": newEmail,
        "password": password,
      }),
    );

    setState(() => loading = false);

    final body = jsonDecode(res.body);

    if (res.statusCode == 200) {
      _showSuccessDialog(newEmail);
    } else {
      _showErrorDialog(body["message"]);
    }
  }

  // -------------------- SUCCESS DIALOG --------------------
  void _showSuccessDialog(String newEmail) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.titleGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                "Email Updated",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your email has been changed to:\n$newEmail",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textGrey,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context, newEmail); // return updated email
                },
                child: Text(
                  "Done",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------- ERROR DIALOG --------------------
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.error_outline, color: Colors.red, size: 36),
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
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "OK",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // USER INTERFACE
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,

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
              "Update Email",
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
            Text(
              "New Email Address",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: newEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.poppins(),
              decoration: const InputDecoration(
                hintText: "Enter your new email",
              ),
            ),

            const SizedBox(height: 24),

            Text(
              "Confirm with Password",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: passCtrl,
              obscureText: !showPass,
              style: GoogleFonts.poppins(),
              decoration: InputDecoration(
                hintText: "Enter your current password",
                suffixIcon: IconButton(
                  icon: Icon(
                    showPass ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() => showPass = !showPass);
                  },
                ),
              ),
            ),

            const SizedBox(height: 40),

            loading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _updateEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Update Email",
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
}
