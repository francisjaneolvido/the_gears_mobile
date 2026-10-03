import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:gears_frontend/utils/config.dart';
import 'login_page.dart';
import 'reset_password_page.dart';

class VerificationPage extends StatefulWidget {
  final String email;
  final bool isFromForgotPassword;

  const VerificationPage({
    super.key,
    required this.email,
    this.isFromForgotPassword = false,
  });

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage>
    with TickerProviderStateMixin {
  final TextEditingController codeController = TextEditingController();
  final FocusNode codeFocusNode = FocusNode();

  bool isLoading = false;
  bool isResending = false;

  int resendCountdown = 60;
  Timer? resendTimer;

  late AnimationController bgController;
  late AnimationController cardController;
  late AnimationController shakeController;

  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;
  late Animation<double> shakeAnimation;

  @override
  void initState() {
    super.initState();

    bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    fadeAnimation = CurvedAnimation(
      parent: cardController,
      curve: Curves.easeOut,
    );

    slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
          CurvedAnimation(parent: cardController, curve: Curves.easeOutCubic),
        );

    shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: shakeController, curve: Curves.easeInOut),
        );

    cardController.forward();
    startResendTimer();

    codeController.addListener(() {
      final code = codeController.text.trim();
      if (code.length == 6 && !isLoading) {
        verifyCode();
      }
    });
  }

  @override
  void dispose() {
    resendTimer?.cancel();
    bgController.dispose();
    cardController.dispose();
    shakeController.dispose();
    codeController.dispose();
    codeFocusNode.dispose();
    super.dispose();
  }

  void startResendTimer() {
    resendTimer?.cancel();

    if (!mounted) return;
    setState(() => resendCountdown = 60);

    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (resendCountdown > 0) {
        setState(() => resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void shakeCard() {
    shakeController.forward(from: 0);
  }

  void clearCode() {
    codeController.clear();
    codeFocusNode.requestFocus();
  }

  Future<void> resendCode() async {
    if (resendCountdown > 0 || isResending) return;

    setState(() => isResending = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/resend-code"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        showMessage("New code sent to your email.", isError: false);
        clearCode();
        startResendTimer();
      } else {
        showMessage("Failed to resend code.", isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      showMessage("Network error. Please try again.", isError: true);
    } finally {
      if (mounted) {
        setState(() => isResending = false);
      }
    }
  }

  Future<void> verifyCode() async {
    final code = codeController.text.trim();

    if (code.length != 6) {
      shakeCard();
      showMessage("Please enter the 6-digit code.", isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      final endpoint = widget.isFromForgotPassword
          ? "$baseUrl/verify-reset"
          : "$baseUrl/verify";

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email, "code": code}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        showMessage("Verification successful!", isError: false);

        await Future.delayed(const Duration(milliseconds: 700));

        if (!mounted) return;

        if (widget.isFromForgotPassword) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResetPasswordPage(email: widget.email),
            ),
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
      } else {
        shakeCard();

        String message = "Invalid or expired code.";
        try {
          final body = jsonDecode(response.body);
          message = body["message"] ?? message;
        } catch (_) {}

        showMessage(message, isError: true);
        clearCode();
      }
    } catch (_) {
      if (!mounted) return;
      shakeCard();
      showMessage("Error verifying code. Please try again.", isError: true);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void showMessage(String message, {required bool isError}) {
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
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 420;

    return Scaffold(
      body: AnimatedBuilder(
        animation: bgController,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + (bgController.value * 2), -1),
                end: Alignment(1 - (bgController.value * 2), 1),
                colors: const [
                  Color(0xFFF19421),
                  Color(0xFFB02029),
                  Color(0xFFF19421),
                  Color(0xFFB02029),
                ],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 12,
                left: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),

              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
                  ),
                  child: FadeTransition(
                    opacity: fadeAnimation,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: AnimatedBuilder(
                        animation: shakeAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(shakeAnimation.value, 0),
                            child: child,
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxWidth: 390),
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmall ? 26 : 36,
                                vertical: isSmall ? 34 : 40,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.62),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.45),
                                    blurRadius: 28,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 86,
                                    height: 86,
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.10),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.30),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.25),
                                          blurRadius: 15,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        "assets/images/gears_logo.png",
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  Text(
                                    widget.isFromForgotPassword
                                        ? "Verify Reset Code"
                                        : "Verify Your Email",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.hedvigLettersSerif(
                                      color: Colors.white,
                                      fontSize: isSmall ? 26 : 29,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  Text(
                                    widget.isFromForgotPassword
                                        ? "Enter the 6-digit code sent to your email to reset your password."
                                        : "Enter the 6-digit code sent to your email to complete your registration.",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 14.5,
                                      height: 1.6,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  Text(
                                    widget.email,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFF19421),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  const SizedBox(height: 26),

                                  TextField(
                                    controller: codeController,
                                    focusNode: codeFocusNode,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    maxLength: 6,
                                    cursorColor: const Color(0xFFF19421),
                                    autofillHints: const [
                                      AutofillHints.oneTimeCode,
                                    ],
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 5,
                                    ),
                                    decoration: InputDecoration(
                                      counterText: "",
                                      hintText: "Enter Code",
                                      hintStyle: GoogleFonts.poppins(
                                        color: Colors.white.withOpacity(0.65),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 1,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.15),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 15,
                                          ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.30),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFF19421),
                                          width: 1.7,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: isLoading ? null : verifyCode,
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        elevation: 0,
                                        backgroundColor: Colors.transparent,
                                        disabledBackgroundColor:
                                            Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Ink(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isLoading
                                                ? [
                                                    Colors.grey.shade600,
                                                    Colors.grey.shade700,
                                                  ]
                                                : const [
                                                    Color(0xFFF19421),
                                                    Color(0xFFB02029),
                                                  ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(
                                                0.25,
                                              ),
                                              blurRadius: 15,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          alignment: Alignment.center,
                                          child: isLoading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2.4,
                                                      ),
                                                )
                                              : Text(
                                                  widget.isFromForgotPassword
                                                      ? "Verify Code"
                                                      : "Verify Account",
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 22),

                                  Text(
                                    "Didn't receive a code?",
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withOpacity(0.82),
                                      fontSize: 14,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  isResending
                                      ? const Padding(
                                          padding: EdgeInsets.only(top: 6),
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Color(0xFFF19421),
                                              strokeWidth: 2.2,
                                            ),
                                          ),
                                        )
                                      : TextButton(
                                          onPressed: resendCountdown > 0
                                              ? null
                                              : resendCode,
                                          child: Text(
                                            resendCountdown > 0
                                                ? "Resend in ${resendCountdown}s"
                                                : "Resend",
                                            style: GoogleFonts.poppins(
                                              color: resendCountdown > 0
                                                  ? Colors.white.withOpacity(
                                                      0.45,
                                                    )
                                                  : const Color(0xFFF19421),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),

                                  const SizedBox(height: 4),

                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const LoginPage(),
                                        ),
                                        (route) => false,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      size: 17,
                                      color: Colors.white70,
                                    ),
                                    label: Text(
                                      "Back to Login",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
