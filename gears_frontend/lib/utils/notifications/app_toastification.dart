import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:google_fonts/google_fonts.dart';

class AppToastification {
  // ✅ Success Toast
  static void success(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flatColored,
      autoCloseDuration: const Duration(seconds: 3),
      alignment: Alignment.topRight,
      title: Text(
        'Success',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      description: Text(
        message,
        style: GoogleFonts.poppins(
          color: Colors.black.withOpacity(0.95),
          fontSize: 13,
        ),
      ),
      primaryColor: Colors.green.shade600,
      backgroundColor: Colors.green.shade600,
      borderRadius: BorderRadius.circular(12),
      showProgressBar: true,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );
  }

  // ❌ Error Toast
  static void error(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flatColored,
      autoCloseDuration: const Duration(seconds: 4),
      alignment: Alignment.topRight,
      title: Text(
        'Error',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      description: Text(
        message,
        style: GoogleFonts.poppins(
          color: Colors.black.withOpacity(0.95),
          fontSize: 13,
        ),
      ),
      primaryColor: Colors.red.shade600,
      backgroundColor: Colors.red.shade600,
      borderRadius: BorderRadius.circular(12),
      showProgressBar: true,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );
  }

  // ⚠️ Warning Toast
  static void warning(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.warning,
      style: ToastificationStyle.flatColored,
      autoCloseDuration: const Duration(seconds: 3),
      alignment: Alignment.topRight,
      title: Text(
        'Warning',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      description: Text(
        message,
        style: GoogleFonts.poppins(
          color: Colors.black.withOpacity(0.8),
          fontSize: 13,
        ),
      ),
      primaryColor: Colors.amber.shade400,
      backgroundColor: Colors.amber.shade400,
      borderRadius: BorderRadius.circular(12),
      showProgressBar: true,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );
  }

  // ℹ️ Info Toast
  static void info(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.flatColored,
      autoCloseDuration: const Duration(seconds: 3),
      alignment: Alignment.topRight,
      title: Text(
        'Info',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      description: Text(
        message,
        style: GoogleFonts.poppins(
          color: Colors.black.withOpacity(0.9),
          fontSize: 13,
        ),
      ),
      primaryColor: Colors.blue.shade600,
      backgroundColor: Colors.blue.shade600,
      borderRadius: BorderRadius.circular(12),
      showProgressBar: true,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );
  }
}
  