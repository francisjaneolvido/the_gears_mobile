import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_page.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> with SingleTickerProviderStateMixin {
  static const Color _brandOrange = Color(0xFFF19421);
  static const Color _brandRed = Color(0xFFE53935);

  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _taglineOpacity;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _buttonOpacity;
  late final Animation<Offset> _buttonSlide;
  bool _precached = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.35, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.85, end: 1.00).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.00, 0.35, curve: Curves.easeOutBack),
      ),
    );

    _taglineOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.70, curve: Curves.easeOut),
    );

    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    _buttonOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.65, 1.00, curve: Curves.easeOut),
    );

    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 1.00, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    precacheImage(const AssetImage('assets/images/paper_bg.png'), context);
    precacheImage(const AssetImage('assets/images/gears_logo.png'), context);
    _precached = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToLogin() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginPage(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  Shader get _titleGradient => const LinearGradient(
        colors: [
          Color(0xFFF19421), // Orange
          Color(0xFFE53935), // Red
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset('assets/images/paper_bg.png', fit: BoxFit.cover),

          // Overlay + blur
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.93),
                    Colors.white.withOpacity(0.86),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: const SizedBox(),
            ),
          ),

          // Accent blobs
          const Positioned(top: -60, left: -80, child: _Blob(size: 220)),
          const Positioned(bottom: -80, right: -70, child: _Blob(size: 280, radial: true)),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo (smaller)
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoOpacity,
                        child: Image.asset(
                          'assets/images/gears_logo.png',
                          width: size.width * 0.32,
                          height: size.width * 0.32,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),

                    // Title & tagline
                    SlideTransition(
                      position: _taglineSlide,
                      child: FadeTransition(
                        opacity: _taglineOpacity,
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => _titleGradient,
                              child: Text(
                                'The Gears',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.hedvigLettersSerif(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 30,
                                  color: Colors.white, // Text color ignored due to shader
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'WRITE WITHOUT FAVOR,\nEXPRESS WITHOUT FEAR',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                letterSpacing: 0.9,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.black.withOpacity(0.7),
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 45),

                    // Get Started Button
                    SlideTransition(
                      position: _buttonSlide,
                      child: FadeTransition(
                        opacity: _buttonOpacity,
                        child: SizedBox(
                          width: size.width * 0.70,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _goToLogin,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 7,
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_brandOrange, _brandRed],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                child: Text(
                                  'Get Started',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Footer line
                    FadeTransition(
                      opacity: _buttonOpacity,
                      child: Text(
                        'Powered by your campus newsroom',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12.8,
                          color: Colors.black.withOpacity(0.55),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Background accent blob
class _Blob extends StatelessWidget {
  const _Blob({required this.size, this.radial = false});
  final double size;
  final bool radial;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: radial
              ? const RadialGradient(
                  colors: [Color(0x66F19421), Colors.transparent],
                  radius: .9,
                )
              : const RadialGradient(
                  colors: [Color(0x33F19421), Color(0x11F19421)],
                ),
        ),
      ),
    );
  }
}
