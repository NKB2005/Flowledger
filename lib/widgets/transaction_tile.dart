import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'app_text.dart';
import 'glass_ui.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile(
    this.icon,
    this.title,
    this.meta,
    this.amount,
    this.color, {
    super.key,
  });
  final IconData icon;
  final String title, meta, amount;
  final Color color;
  @override
  Widget build(BuildContext context) => GlassCard(
    radius: 20,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColor.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              secondary(meta, 11),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
