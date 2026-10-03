import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';
import '../pages/home_page.dart';
import '../pages/search_page.dart';
import '../pages/bookmark_page.dart';
import '../pages/profile_page.dart';
import '../utils/config.dart';

class BottomNav extends StatefulWidget {
  final int currentIndex;
  final String? email;
  final int? userId;

  const BottomNav({
    super.key,
    required this.currentIndex,
    this.email,
    this.userId,
  });

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  String userStatus = "pending";

  @override
  void initState() {
    super.initState();
    _loadCachedStatus();
  }

  /// Load saved user status from SharedPreferences
  Future<void> _loadCachedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('status');

    if (saved != null && mounted) {
      setState(() => userStatus = saved);
    }
  }

  /// Navigate without calling backend (prevents 429)
  void _navigate(BuildContext context, int index) {
    if (index == widget.currentIndex) return;

    Widget nextPage;

    switch (index) {
      case 0:
        nextPage = HomePage(
          email: widget.email ?? "",
          userId: widget.userId ?? 0,
          userStatus: userStatus,
        );
        break;

      case 1:
        nextPage = const SearchPage();
        break;

      case 2:
        nextPage = const BookmarkPage();
        break;

      case 3:
        nextPage = ProfilePage(
          email: widget.email ?? "",
          userId: widget.userId ?? 0,
        );
        break;

      default:
        nextPage = HomePage(
          email: widget.email ?? "",
          userId: widget.userId ?? 0,
          userStatus: userStatus,
        );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': 'assets/icons/home.svg', 'label': 'Home'},
      {'icon': 'assets/icons/search.svg', 'label': 'Search'},
      {'icon': 'assets/icons/save.svg', 'label': 'Saved'},
      {'icon': 'assets/icons/profile.svg', 'label': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final isSelected = widget.currentIndex == index;

              return GestureDetector(
                onTap: () => _navigate(context, index),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 1.0,
                    end: isSelected ? 1.2 : 1.0,
                  ),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ICON
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isSelected
                                  ? [
                                      AppTheme.primaryOrange,
                                      AppTheme.primaryRed
                                    ]
                                  : [
                                      Colors.grey.shade500,
                                      Colors.grey.shade500
                                    ],
                            ).createShader(bounds),
                            child: SvgPicture.asset(
                              items[index]['icon']!,
                              height: 24,
                              width: 24,
                              color: Colors.white, // must stay white for ShaderMask
                            ),
                          ),

                          const SizedBox(height: 4),

                          // LABEL (FIXED)
                          isSelected
                              ? ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppTheme.primaryOrange,
                                      AppTheme.primaryRed,
                                    ],
                                  ).createShader(bounds),
                                  child: Text(
                                    items[index]['label']!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  items[index]['label']!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
