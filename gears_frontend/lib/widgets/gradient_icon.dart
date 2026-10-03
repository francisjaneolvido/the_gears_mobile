import 'package:flutter/material.dart';
import 'package:gears_frontend/theme/app_theme.dart';

class GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const GradientIcon(this.icon, {this.size = 28, super.key});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => AppTheme.iconGradientShader(rect),
      child: Icon(icon, size: size),
    );
  }
}
