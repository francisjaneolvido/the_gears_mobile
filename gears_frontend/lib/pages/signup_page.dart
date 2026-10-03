import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../theme/app_theme.dart';
import '../../utils/config.dart';
import '../../utils/notifications/app_toastification.dart';

import 'login_page.dart';
import 'verification_page.dart';
import '../../widgets/gradient_button.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool isPasswordVisible = false;
  bool isConfirmVisible = false;
  bool agreedTerms = false;
  String? selectedGender;

  double passwordStrength = 0.0;
  String passwordStrengthText = "";
  Color passwordStrengthColor = Colors.grey;

  final genders = ["Male", "Female", "Other"];

  // Allows letters, spaces, hyphen & apostrophe
  final nameFormatter = FilteringTextInputFormatter.allow(
    RegExp(r"[a-zA-Z\s\-']"),
  );

  final maskDobFormatter = MaskTextInputFormatter(
    mask: '####-##-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_checkPasswordStrength);

    // AUTO-CAPITALIZE LISTENERS
    firstNameController.addListener(() {
      final text = firstNameController.text;
      final capitalized = _capitalize(text);
      if (text != capitalized) {
        firstNameController.value =
            firstNameController.value.copyWith(text: capitalized);
      }
    });

    middleNameController.addListener(() {
      final text = middleNameController.text;
      final capitalized = _capitalize(text);
      if (text != capitalized) {
        middleNameController.value =
            middleNameController.value.copyWith(text: capitalized);
      }
    });

    lastNameController.addListener(() {
      final text = lastNameController.text;
      final capitalized = _capitalize(text);
      if (text != capitalized) {
        lastNameController.value =
            lastNameController.value.copyWith(text: capitalized);
      }
    });
  }

  @override
  void dispose() {
    passwordController.removeListener(_checkPasswordStrength);

    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    dobController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  // CAPITALIZATION HELPER
  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value
        .split(' ')
        .map((word) =>
            word.isEmpty ? "" : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  // PASSWORD STRENGTH
  void _checkPasswordStrength() {
    final password = passwordController.text;
    double strength = 0.0;

    if (password.isEmpty) {
      setState(() {
        passwordStrength = 0.0;
        passwordStrengthText = "";
        passwordStrengthColor = Colors.grey;
      });
      return;
    }

    if (password.length >= 8) strength += 0.25;
    if (password.length >= 12) strength += 0.15;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.2;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.2;

    setState(() {
      passwordStrength = strength.clamp(0.0, 1.0);
      if (passwordStrength < 0.3) {
        passwordStrengthText = "Weak";
        passwordStrengthColor = Colors.red;
      } else if (passwordStrength < 0.6) {
        passwordStrengthText = "Fair";
        passwordStrengthColor = Colors.orange;
      } else if (passwordStrength < 0.8) {
        passwordStrengthText = "Good";
        passwordStrengthColor = Colors.blue;
      } else {
        passwordStrengthText = "Strong";
        passwordStrengthColor = Colors.green;
      }
    });
  }

  // EMAIL VALIDATION
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$')
        .hasMatch(email);
  }

  // DOB VALIDATION (ONLY FUTURE DATE BLOCKED)
  bool _isValidDob(String value) {
    try {
      final dt = DateTime.parse(value);
      final now = DateTime.now();
      if (dt.isAfter(now)) return false; // Only reject future dates now
      return true;
    } catch (e) {
      return false;
    }
  }

  // REGISTER FUNCTION
  Future<void> register() async {
    if (isLoading) return;

    if (!_formKey.currentState!.validate()) return;

    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (!_isValidEmail(emailController.text.trim())) {
      AppToastification.error(context, "Invalid email address");
      return;
    }

    if (!_isValidDob(dobController.text.trim())) {
      AppToastification.error(context, "Please enter a valid Date of Birth");
      return;
    }

    if (!agreedTerms) {
      AppToastification.warning(
          context, "You must agree to the terms and conditions");
      return;
    }

    if (password != confirmPassword) {
      AppToastification.error(context, "Passwords do not match");
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "first_name": firstNameController.text.trim(),
          "middle_name": middleNameController.text.trim().isEmpty
              ? null
              : middleNameController.text.trim(),
          "last_name": lastNameController.text.trim(),
          "birthday": dobController.text.trim(),
          "email": emailController.text.trim().toLowerCase(),
          "gender": selectedGender,
          "password": password,
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        AppToastification.success(context, "Verification code sent!");

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerificationPage(
              email: emailController.text.trim().toLowerCase(),
              isFromForgotPassword: false,
            ),
          ),
        );
      } else {
        AppToastification.error(
          context,
          responseBody["message"] ?? "Registration failed",
        );
      }
    } catch (e) {
      AppToastification.error(context, "Connection error.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // TERMS & CONDITIONS POPUP
  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.titleGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.description, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                "Terms & Conditions",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              termsAndConditionsText,
              style: GoogleFonts.poppins(fontSize: 13, height: 1.6),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Decline",
                  style: GoogleFonts.poppins(color: Colors.grey.shade700)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => agreedTerms = true);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
              ),
              child: Text("Accept",
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // INPUT DECORATION
  InputDecoration inputDecoration(
    String label, {
    Widget? suffix,
    bool required = true,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label + (required ? " *" : ""),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffix,
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppTheme.primaryOrange, width: 2),
      ),
    );
  }

  // BUILD UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,

      // 🚫 NO APPBAR ANYMORE
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  "Create Account",
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Join The Gears and stay updated with campus stories.",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 24),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Image.asset('assets/images/gears_logo.png',
                          height: 60),
                      const SizedBox(height: 20),

                      // FIRST NAME
                      TextFormField(
                        controller: firstNameController,
                        inputFormatters: [nameFormatter],
                        decoration: inputDecoration("First Name"),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? "First name is required"
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // MIDDLE NAME
                      TextFormField(
                        controller: middleNameController,
                        inputFormatters: [nameFormatter],
                        decoration: inputDecoration(
                          "Middle Name",
                          required: false,
                          hint: "Optional",
                        ),
                      ),
                      const SizedBox(height: 16),

                      // LAST NAME
                      TextFormField(
                        controller: lastNameController,
                        inputFormatters: [nameFormatter],
                        decoration: inputDecoration("Last Name"),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? "Last name is required"
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // DOB INPUT
                      TextFormField(
                        controller: dobController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          maskDobFormatter,
                          DobInputFormatter()
                        ],
                        decoration: inputDecoration(
                          "Date of Birth",
                          hint: "YYYY-MM-DD",
                          suffix: const Icon(Icons.calendar_today,
                              size: 20),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return "Date of birth is required";
                          }
                          if (!_isValidDob(v.trim())) {
                            return "Invalid date";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // GENDER DROPDOWN
                      DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: inputDecoration("Gender"),
                        items: genders.map((g) {
                          return DropdownMenuItem(
                            value: g,
                            child: Text(g,
                                style: GoogleFonts.poppins(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => selectedGender = v),
                        validator: (v) =>
                            v == null ? "Select gender" : null,
                      ),
                      const SizedBox(height: 16),

                      // EMAIL INPUT
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: inputDecoration("Email",
                            hint: "you@example.com"),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return "Email is required";
                          }
                          if (!_isValidEmail(v.trim())) {
                            return "Invalid email";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // PASSWORD FIELD
                      TextFormField(
                        controller: passwordController,
                        obscureText: !isPasswordVisible,
                        decoration: inputDecoration(
                          "Password",
                          suffix: IconButton(
                            icon: Icon(
                              isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () => setState(() =>
                                isPasswordVisible = !isPasswordVisible),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 8
                            ? "Min. 8 characters"
                            : null,
                      ),

                      // PASSWORD STRENGTH BAR
                      if (passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: passwordStrength,
                                backgroundColor: Colors.grey.shade200,
                                color: passwordStrengthColor,
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              passwordStrengthText,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: passwordStrengthColor,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 16),

                      // CONFIRM PASSWORD
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: !isConfirmVisible,
                        decoration: inputDecoration(
                          "Confirm Password",
                          suffix: IconButton(
                            icon: Icon(
                              isConfirmVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () => setState(
                                () => isConfirmVisible = !isConfirmVisible),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return "Please confirm password";
                          }
                          if (v != passwordController.text) {
                            return "Passwords do not match";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // TERMS & CONDITIONS
                      InkWell(
                        onTap: () {
                          if (!agreedTerms) {
                            _showTermsAndConditions();
                          } else {
                            setState(() => agreedTerms = false);
                          }
                        },
                        child: Row(
                          children: [
                            Icon(
                              agreedTerms
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: agreedTerms
                                  ? AppTheme.primaryOrange
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "I agree to the Terms & Conditions",
                                style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    color: AppTheme.textDark),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      GradientButton(
                        text: "Create Account",
                        isLoading: isLoading,
                        onPressed: register,
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginPage()),
                            ),
                            child: Text(
                              "Login",
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// UPDATED TERMS WITHOUT AGE REQUIREMENT
const termsAndConditionsText = """
By signing up, you agree to the following terms and conditions:

1. Account Usage  
Your use of The Gears platform must follow applicable laws. You are responsible for your account security.

2. Content Guidelines  
You may not submit harmful, illegal, or offensive content.

3. Account Termination  
We may suspend or terminate accounts that violate policies.

4. Privacy & Data  
Your provided information is handled under our privacy policy. Data will not be shared without your consent.

5. Changes to Terms  
We may update these terms at any time. Continued use means you accept the changes.
""";

// DOB VALIDATION FORMATTER
class DobInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.length < oldValue.text.length) return newValue;

    final text = newValue.text;

    // Validate month
    if (text.length >= 7) {
      final m = int.tryParse(text.substring(5, 7));
      if (m == null || m < 1 || m > 12) return oldValue;
    }

    // Validate day
    if (text.length == 10) {
      final d = int.tryParse(text.substring(8, 10));
      if (d == null || d < 1 || d > 31) return oldValue;
    }

    return newValue;
  }
}
