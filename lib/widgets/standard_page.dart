import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import 'glass_ui.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.badgeText,
    this.badgeSubtext,
    this.showDateBadge = false,
  });
  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;
  final String? badgeText;
  final String? badgeSubtext;
  final bool showDateBadge;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColor.mint;
    final textColor = isDark
        ? const Color(0xFFF0F7FF)
        : const Color(0xFF172033);
    final mutedColor = isDark
        ? const Color(0xFF9EB0CC)
        : const Color(0xFF5C6A80);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          // Main Telegram Capsule Pill
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: 54,
                  padding: EdgeInsets.symmetric(
                    horizontal: showDateBadge || leading != null ? 7 : 18,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C2738).withValues(alpha: 0.90)
                        : Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 8),
                      ] else if (showDateBadge) ...[
                        // Dynamic Theme-Adaptive Circle Badge (only on Home)
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                primaryColor,
                                primaryColor.withValues(alpha: 0.75),
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                badgeText ?? DateFormat('d').format(DateTime.now()),
                                style: const TextStyle(
                                  color: Color(0xFF091410),
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                badgeSubtext ?? DateFormat('EEE').format(DateTime.now()).toUpperCase(),
                                style: TextStyle(
                                  color: const Color(0xFF091410).withValues(alpha: 0.85),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: mutedColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C2738).withValues(alpha: 0.90)
                        : Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: trailing!,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StandardPage extends StatelessWidget {
  const StandardPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBackButton = false,
    this.onBack,
    this.trailing,
    this.badgeText,
    this.badgeSubtext,
    this.showDateBadge = false,
  });
  final String title, subtitle;
  final List<Widget> children;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget? trailing;
  final String? badgeText;
  final String? badgeSubtext;
  final bool showDateBadge;

  @override
  Widget build(BuildContext context) => LiquidBackground(
    child: CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          floating: false,
          snap: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          toolbarHeight: 68,
          titleSpacing: 0,
          title: AppHeader(
            title: title,
            subtitle: subtitle,
            badgeText: badgeText,
            badgeSubtext: badgeSubtext,
            showDateBadge: showDateBadge,
            leading: showBackButton
                ? IconButton(
                    onPressed: onBack ?? () => Navigator.maybePop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: AppColor.text),
                    tooltip: 'Back',
                  )
                : null,
            trailing: trailing,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 150),
          sliver: SliverList(
            delegate: SliverChildListDelegate(children),
          ),
        ),
      ],
    ),
  );
}
