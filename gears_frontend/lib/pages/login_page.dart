import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../../utils/config.dart';
import 'home_page.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import '../admin/admin_dashboard.dart';
import '../superadmin/superadmin_dashboard.dart';
import 'verification_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool hidePassword = true;
  bool rememberMe = false;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadRememberedUser();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedUser() async {
  final prefs = await SharedPreferences.getInstance();
  final savedRemember = prefs.getBool('remember_me') ?? false;
  final savedEmail = prefs.getString('remember_email') ?? '';

  if (!mounted) return;

  setState(() {
    rememberMe = savedRemember;
    if (rememberMe && savedEmail.isNotEmpty) {
      emailController.text = savedEmail;
    }
  });
}


  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email);
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // LOGIN FUNCTION
  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text;

    if (!_isValidEmail(email)) {
      _showSnackBar("Please enter a valid email address", isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (!mounted) return;

      final body = jsonDecode(response.body);

      // 🔥 NEW LOGIC: Check if backend says verification is required
if (response.statusCode == 200 && body["needs_verification"] == true) {
  _showSnackBar("Email not verified. Redirecting...", isError: false);

  await Future.delayed(const Duration(milliseconds: 800));

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => VerificationPage(
        email: email,
        isFromForgotPassword: false,
      ),
    ),
  );

  return;
}

// 🔥 Still handle real login errors
if (response.statusCode != 200) {
  _showSnackBar(body["message"] ?? "Invalid email or password", isError: true);
  return;
}


      // Extract login fields
      final role = body["role"];
      final status = body["status"];

      // FIX EMAIL INCONSISTENCY
      final loginEmail = body["email"]
          ?? body["user_email"]
          ?? body["data"]?["email"]
          ?? body["user"]?["email"]
          ?? email;

      

     final prefs = await SharedPreferences.getInstance();

// Save email for system use
// Save email for system use
// Store for user mode sessions (safe)
await prefs.setString("user_email", loginEmail);

// Reset view mode only
prefs.remove("current_view");

// Overwrite stale user-only fields
prefs.remove("user_status");
prefs.remove("id");

// Save user id
if (body["id"] == null) {
  _showSnackBar("Login error: missing user ID", isError: true);
  return;
}

final userId = int.parse(body["id"].toString());
await prefs.setInt("id", userId);

// Save role + status for user view
await prefs.setString("user_role", role);
await prefs.setString("user_status", status);

// Remember Me ONLY keeps email for autofill, not dashboard
if (rememberMe) {
  await prefs.setString("remember_email", loginEmail);
  await prefs.setBool("remember_me", true);
} else {
  await prefs.remove("remember_email");
  await prefs.setBool("remember_me", false);
}


_showSnackBar("Welcome back! 👋", isError: false);



      if (status == "disapproved") {
        await Future.delayed(const Duration(milliseconds: 500));
        _showSnackBar("⚠️ Your account was disapproved.", isError: true);
      }

      await Future.delayed(const Duration(milliseconds: 800));

      // ROUTING
      // ROUTING
Widget destination;

// SUPERADMIN
if (role == "superadmin") {

  // SAVE SUPERADMIN SESSION
  await prefs.setString("superadmin_email", loginEmail);
  await prefs.setString("superadmin_role", "superadmin");
  await prefs.setInt("superadmin_id", userId);

  destination = SuperAdminDashboard(
    email: loginEmail,
    role: "superadmin",
  );
}

// ADMIN
else if (role == "admin") {

  // SAVE ADMIN SESSION
  await prefs.setString("admin_email", loginEmail);
  await prefs.setString("admin_role", "admin");
  await prefs.setInt("admin_id", userId);

  destination = AdminDashboard(
    email: loginEmail,
    role: "admin",
  );
}

// NORMAL USER
else {

  // 🔥 Fetch fresh status BEFORE navigating
  final freshStatusResponse = await http.get(
    Uri.parse("$baseUrl/get-user-status/$userId"),
  );

  String freshStatus = status;

  if (freshStatusResponse.statusCode == 200) {
    final decoded = jsonDecode(freshStatusResponse.body);
    freshStatus = decoded["status"] ?? status;
  }

  destination = HomePage(
    email: loginEmail,
    userId: userId,
    userStatus: freshStatus,
  );
}

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );

    } catch (e) {
      _showSnackBar("Connection failed. Check your internet.", isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // UI BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Logo
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryOrange.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/gears_logo.png',
                        width: 80,
                        height: 80,
                      ),
                    ),
                    const SizedBox(height: 24),

                    ShaderMask(
                      shaderCallback: (bounds) => AppTheme.titleGradient
                          .createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                      child: Text(
                        "The Gears",
                        style: GoogleFonts.hedvigLettersSerif(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      "Welcome back! Please login to continue.",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textGrey,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          // EMAIL FIELD
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: "Email Address",
                              hintText: "you@example.com",
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: AppTheme.primaryOrange,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppTheme.primaryOrange,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return "Email is required";
                              }
                              if (!_isValidEmail(v.trim())) {
                                return "Invalid email format";
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // PASSWORD FIELD
                          TextFormField(
                            controller: passwordController,
                            obscureText: hidePassword,
                            decoration: InputDecoration(
                              labelText: "Password",
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: AppTheme.primaryOrange,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  hidePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.grey.shade600,
                                ),
                                onPressed: () =>
                                    setState(() => hidePassword = !hidePassword),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? "Password is required" : null,
                          ),

                          const SizedBox(height: 16),

                          // REMEMBER ME + FORGOT
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () =>
                                    setState(() => rememberMe = !rememberMe),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        gradient: rememberMe
                                            ? AppTheme.titleGradient
                                            : null,
                                        color: rememberMe
                                            ? null
                                            : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: rememberMe
                                          ? const Icon(Icons.check,
                                              size: 16, color: Colors.white)
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Remember me",
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordPage(),
                                  ),
                                ),
                                child: Text(
                                  "Forgot Password?",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppTheme.primaryOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // LOGIN BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFF9A825), Color(0xFFF57C00)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Text(
                                          "LOGIN",
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "OR",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.textGrey,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignUpPage(),
                            ),
                          ),
                          child: Text(
                            "Sign Up",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
