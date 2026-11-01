import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class FlowLedgerSplashScreen extends StatefulWidget {
  const FlowLedgerSplashScreen({
    super.key,
    required this.onFinished,
  });

  final VoidCallback onFinished;

  @override
  State<FlowLedgerSplashScreen> createState() => _FlowLedgerSplashScreenState();
}

class _FlowLedgerSplashScreenState extends State<FlowLedgerSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _logoFadeAnimation;
  late final Animation<double> _textFadeAnimation;
  late final Animation<double> _letterSpacingAnimation;
  late final Animation<Offset> _textSlideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Ambient glow breathe in
    _glowAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    // Central emblem scale up with gentle bounce
    _logoScaleAnimation = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.08, 0.60, curve: Curves.easeOutBack),
      ),
    );

    // Emblem fade in
    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.45, curve: Curves.easeIn),
      ),
    );

    // Text slide & fade
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.80, curve: Curves.easeOut),
      ),
    );

    _letterSpacingAnimation = Tween<double>(begin: 5.0, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.80, curve: Curves.easeOutCubic),
      ),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.30),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.80, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    // After animation completes, transition to home
    Timer(const Duration(milliseconds: 2400), () {
      if (mounted) {
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF090E1C);

    return Scaffold(
      backgroundColor: bgColor,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Top-left Violet ambient glow
              Positioned(
                top: -60,
                left: -60,
                width: 320,
                height: 320,
                child: Opacity(
                  opacity: (_glowAnimation.value * 0.95).clamp(0.0, 1.0),
                  child: Image.asset(
                    'assets/logo/glow_purple.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Bottom-right Mint ambient glow
              Positioned(
                bottom: -60,
                right: -60,
                width: 320,
                height: 320,
                child: Opacity(
                  opacity: (_glowAnimation.value * 0.95).clamp(0.0, 1.0),
                  child: Image.asset(
                    'assets/logo/glow_mint.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Floating subtle glowing particles
              Positioned(
                top: 140,
                right: 48,
                width: 14,
                height: 14,
                child: Opacity(
                  opacity: (_glowAnimation.value * 0.75).clamp(0.0, 1.0),
                  child: Image.asset('assets/logo/dot.png'),
                ),
              ),
              Positioned(
                bottom: 180,
                left: 45,
                width: 18,
                height: 18,
                child: Opacity(
                  opacity: (_glowAnimation.value * 0.70).clamp(0.0, 1.0),
                  child: Image.asset('assets/logo/dot.png'),
                ),
              ),

              // Decorative ambient background light blur
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3BEBB0).withValues(
                          alpha: 0.18 * _glowAnimation.value,
                        ),
                        blurRadius: 80,
                        spreadRadius: 20,
                      ),
                      BoxShadow(
                        color: const Color(0xFF8C6BFF).withValues(
                          alpha: 0.15 * _glowAnimation.value,
                        ),
                        blurRadius: 100,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
              ),

              // Center content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Scaling Logo Emblem
                    Transform.scale(
                      scale: _logoScaleAnimation.value,
                      child: Opacity(
                        opacity: _logoFadeAnimation.value,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3BEBB0).withValues(alpha: 0.25),
                                blurRadius: 36,
                                offset: const Offset(0, 12),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Image.asset(
                              'assets/logo/app_logo_full.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Animated FlowLedger Typography
                    SlideTransition(
                      position: _textSlideAnimation,
                      child: Opacity(
                        opacity: _textFadeAnimation.value,
                        child: Column(
                          children: [
                            ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFF8C6BFF),
                                  Color(0xFF45C0F5),
                                  Color(0xFF3BEBB0),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: Text(
                                'FlowLedger',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: _letterSpacingAnimation.value,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'A calmer way to understand your money',
                              style: TextStyle(
                                color: Color(0xFF9EB0CC),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom subtle indicator
              Positioned(
                bottom: 48,
                left: 0,
                right: 0,
                child: Center(
                  child: Opacity(
                    opacity: _textFadeAnimation.value * 0.7,
                    child: SizedBox(
                      width: 36,
                      height: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(AppColor.mint),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
