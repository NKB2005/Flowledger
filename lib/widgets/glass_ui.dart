import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class LiquidBackground extends StatelessWidget {
  const LiquidBackground({
    super.key,
    required this.child,
    this.standalone = false,
  });
  final Widget child;
  final bool standalone;

  static bool hasShellBackground = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppColor.revision,
      builder: (context, _) {
        if (!AppColor.showAmbientBackground) return child;
        if (hasShellBackground && !standalone) return child;

        return Stack(
          children: [
            Positioned(
              top: 40,
              left: -85,
              child: GlowOrb(AppColor.violet, 245),
            ),
            Positioned(
              top: 145,
              right: -85,
              child: GlowOrb(AppColor.mint, 230),
            ),
            Positioned(
              bottom: -90,
              left: 60,
              child: GlowOrb(AppColor.coral, 260),
            ),
            child,
          ],
        );
      },
    );
  }
}

class GlowOrb extends StatelessWidget {
  const GlowOrb(this.color, this.size, {super.key});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: .34), color.withValues(alpha: .02)],
            ),
          ),
        ),
      );
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 22,
    this.surfaceColor,
    this.blurSigma = 0,
  });
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? surfaceColor;
  final double blurSigma;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark
        ? const Color(0xFF151F30).withValues(alpha: 0.80)
        : Colors.white.withValues(alpha: 0.90);
    final defaultBorder = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.07);

    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor ?? defaultBg,
        border: Border.all(color: defaultBorder),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );

    if (blurSigma > 0.5) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: content,
    );
  }
}
