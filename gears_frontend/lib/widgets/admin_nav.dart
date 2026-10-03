import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

class AdminNav extends StatelessWidget {
  final int currentIndex;
  final Function(int)? onTap;

  const AdminNav({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': 'assets/icons/dashboard.svg', 'label': 'Dashboard'},
      {'icon': 'assets/icons/articles.svg', 'label': 'Articles'},
      {'icon': 'assets/icons/users.svg', 'label': 'Users'},
      {'icon': 'assets/icons/profile.svg', 'label': 'Settings'},
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
              final isSelected = currentIndex == index;

              return GestureDetector(
                onTap: () => onTap?.call(index),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 1.0,
                    end: isSelected ? 1.2 : 1.0,
                  ),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  builder: (context, scale, child) {
                    final gradient = LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isSelected
                          ? [AppTheme.primaryOrange, AppTheme.primaryRed]
                          : [
                              const Color.fromARGB(255, 90, 90, 90),
                              const Color.fromARGB(255, 90, 90, 90)
                            ],
                    );

                    return Transform.scale(
                      scale: scale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ICON WITH GRADIENT
                          ShaderMask(
                            shaderCallback: gradient.createShader,
                            child: SvgPicture.asset(
                              items[index]['icon']!,
                              height: 24,
                              width: 24,
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // LABEL WITH GRADIENT
                          ShaderMask(
                            shaderCallback: gradient.createShader,
                            blendMode: BlendMode.srcIn,
                            child: Text(
                              items[index]['label']!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white, // controlled by shader
                              ),
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
