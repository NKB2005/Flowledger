import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class GlassDock extends StatelessWidget {
  const GlassDock({super.key, required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  static const items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.format_list_bulleted_rounded, Icons.format_list_bulleted_rounded, 'Activity'),
    (Icons.add_rounded, Icons.add_rounded, 'Add'),
    (Icons.insights_rounded, Icons.insights_outlined, 'Insights'),
    (Icons.settings_rounded, Icons.settings_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = AppColor.isDarkMode;
    final blur = AppColor.dockBlur;
    final opacity = AppColor.dockOpacity;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          // Deep diffused ambient shadow for floating optical depth
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.16),
            blurRadius: 32,
            offset: const Offset(0, 14),
            spreadRadius: -4,
          ),
          // Subtle active glow reflection underneath the glass
          BoxShadow(
            color: AppColor.mint.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Static frosted glass layer - isolated so blur is NEVER re-calculated when icons animate
          RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    // Ultra-glassy optical sheen modulated by user transparency setting
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              Colors.white.withValues(alpha: (0.12 + opacity * 0.20).clamp(0.0, 1.0)),
                              Colors.white.withValues(alpha: (0.02 + opacity * 0.10).clamp(0.0, 1.0)),
                              Colors.white.withValues(alpha: (0.01 + opacity * 0.05).clamp(0.0, 1.0)),
                              Colors.black.withValues(alpha: (0.20 + opacity * 0.35).clamp(0.0, 1.0)),
                            ]
                          : [
                              Colors.white.withValues(alpha: (0.60 + opacity * 0.38).clamp(0.0, 1.0)),
                              Colors.white.withValues(alpha: (0.35 + opacity * 0.35).clamp(0.0, 1.0)),
                              Colors.white.withValues(alpha: (0.20 + opacity * 0.30).clamp(0.0, 1.0)),
                            ],
                      stops: isDark ? const [0.0, 0.35, 0.70, 1.0] : const [0.0, 0.5, 1.0],
                    ),
                    // Glass highlight border: bright on top, faint on bottom
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: (0.15 + opacity * 0.25).clamp(0.0, 1.0))
                          : Colors.white.withValues(alpha: (0.50 + opacity * 0.40).clamp(0.0, 1.0)),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 2. Interactive tab items on top - purely local lightweight repaints
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: List.generate(items.length, (i) {
                final active = i == selected;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      onTap: () => onSelect(i),
                      borderRadius: BorderRadius.circular(26),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: active
                              ? LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColor.mint.withValues(alpha: isDark ? 0.32 : 0.25),
                                    AppColor.mint.withValues(alpha: isDark ? 0.08 : 0.05),
                                  ],
                                )
                              : null,
                          border: active
                              ? Border.all(
                                  color: AppColor.mint.withValues(alpha: isDark ? 0.55 : 0.40),
                                  width: 1,
                                )
                              : Border.all(color: Colors.transparent, width: 1),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: AppColor.mint.withValues(alpha: isDark ? 0.25 : 0.15),
                                    blurRadius: 12,
                                    spreadRadius: -2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: active ? 1.08 : 1.0,
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutBack,
                              child: Icon(
                                active ? items[i].$1 : items[i].$2,
                                color: active
                                    ? AppColor.mint
                                    : (isDark ? AppColor.muted : const Color(0xFF6B7280)),
                                size: i == 2 ? 23 : 20,
                              ),
                            ),
                            if (AppColor.showDockLabels) ...[
                              const SizedBox(height: 2),
                              Text(
                                items[i].$3,
                                style: TextStyle(
                                  color: active
                                      ? (isDark ? AppColor.text : const Color(0xFF111827))
                                      : (isDark ? AppColor.muted : const Color(0xFF6B7280)),
                                  fontSize: 9.5,
                                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
