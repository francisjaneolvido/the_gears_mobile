import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'pages/intro_page.dart';
import 'pages/home_page.dart';
import 'admin/admin_dashboard.dart';
import 'superadmin/superadmin_dashboard.dart';

// Superadmin pages
import 'superadmin/superadmin_articles_page.dart';
import 'superadmin/superadmin_users_page.dart';
import 'superadmin/superadmin_profile_page.dart';

import 'utils/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initBaseUrl();

  // ---------------------------------------------------
  // ⭐ REAL SUPABASE PROJECT INITIALIZATION
  // ---------------------------------------------------
  await Supabase.initialize(
    url: "https://vkllnewjkagdmqdclywg.supabase.co",
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZrbGxuZXdqa2FnZG1xZGNseXdnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzOTIyNDAsImV4cCI6MjA5NDk2ODI0MH0.S9ZCfJ0wwt-Du01rwY3fsMnhTQbkO-kllII0WcZSszM",
    debug: true,
  );

  runApp(ToastificationWrapper(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _getStartingPage() async {
    final prefs = await SharedPreferences.getInstance();

    final email = prefs.getString("email");
    final userId = prefs.getInt("id");
    final role = prefs.getString("role");
    final status = prefs.getString("status") ?? "pending";

    if (email == null || role == null) {
      return const IntroPage();
    }

    if (role == "superadmin") {
      return SuperAdminDashboard(email: email, role: "superadmin");
    }

    if (role == "admin") {
      return AdminDashboard(email: email, role: "admin");
    }

    if (userId != null) {
      return HomePage(email: email, userId: userId, userStatus: status);
    }

    return const IntroPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Gears Publication',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        scaffoldBackgroundColor: AppTheme.backgroundLight,
        primaryColor: AppTheme.primaryOrange,

        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.primaryOrange,
          primary: AppTheme.primaryRed,
          secondary: AppTheme.primaryRed,
          surface: AppTheme.cardWhite,
        ),

        appBarTheme: AppBarTheme(
          backgroundColor: AppTheme.cardWhite,
          foregroundColor: AppTheme.primaryRed,
          centerTitle: true,
          elevation: 2,
          shadowColor: Colors.black12,
          titleTextStyle: AppTheme.titleText.copyWith(
            color: AppTheme.primaryRed,
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppTheme.cardWhite,
          labelStyle: TextStyle(
            color: AppTheme.textDark.withOpacity(0.87),
            fontFamily: GoogleFonts.poppins().fontFamily,
          ),
          hintStyle: TextStyle(
            color: AppTheme.textDark.withOpacity(0.54),
            fontFamily: GoogleFonts.poppins().fontFamily,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppTheme.cardRadius,
            borderSide: BorderSide(color: AppTheme.borderGrey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppTheme.cardRadius,
            borderSide: const BorderSide(
              color: AppTheme.primaryOrange,
              width: 2,
            ),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
            elevation: 5,
            shadowColor: AppTheme.shadowBlack.withOpacity(0.2),
          ),
        ),

        cardTheme: const CardThemeData(
          color: AppTheme.cardWhite,
          elevation: 0,
          margin: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
        ),

        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: AppTheme.primaryRed,
          unselectedItemColor: Colors.grey.shade500,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.cardWhite,
          elevation: 0,
        ),

        textTheme: GoogleFonts.poppinsTextTheme(
          const TextTheme(
            bodyMedium: TextStyle(color: AppTheme.textDark, fontSize: 16),
            bodySmall: TextStyle(color: AppTheme.textGrey),
          ),
        ),
      ),

      home: FutureBuilder<Widget>(
        future: _getStartingPage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryOrange),
              ),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          return snapshot.data ?? const IntroPage();
        },
      ),

      // -------------------------------------------------------------
      // ⭐ SUPERADMIN ROUTES
      // -------------------------------------------------------------
      routes: {
        "/dashboard-superadmin": (context) => _routeWrapper(
          (email) => SuperAdminDashboard(email: email, role: "superadmin"),
        ),

        "/articles-superadmin": (context) =>
            _routeWrapper((email) => SuperAdminArticlesPage(email: email)),

        "/users-superadmin": (context) =>
            _routeWrapper((email) => SuperAdminUsersPage(email: email)),

        "/profile-superadmin": (context) =>
            _routeWrapper((email) => SuperAdminProfilePage(email: email)),
      },
    );
  }

  // Helper: Automatically inject email into routes
  Widget _routeWrapper(Widget Function(String email) builder) {
    return FutureBuilder(
      future: SharedPreferences.getInstance(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final args = ModalRoute.of(context)?.settings.arguments;
        if (args != null && args is String && args.isNotEmpty) {
          return builder(args);
        }

        final email = snap.data!.getString("email") ?? "";

        return builder(email);
      },
    );
  }
}
