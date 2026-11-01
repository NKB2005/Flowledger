import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/expense_store.dart';
import '../widgets/glass_ui.dart';
import '../widgets/standard_page.dart';
import '../widgets/transaction_tile.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key, required this.store});
  final ExpenseStore store;
  @override
  Widget build(BuildContext context) => StandardPage(
    title: 'Activity',
    subtitle: 'September 2026',
    children: [
      GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SPENT THIS MONTH',
              style: TextStyle(
                color: AppColor.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Rs. 18,740',
              style: TextStyle(
                color: AppColor.text,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Down 12% vs August',
              style: TextStyle(
                color: AppColor.mint,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      if (store.latestNote.isNotEmpty) ...[
        const SizedBox(height: 24),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SAVED NOTE',
                style: TextStyle(
                  color: AppColor.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                store.latestNote,
                style: TextStyle(
                  color: AppColor.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                store.latestCategory,
                style: TextStyle(color: AppColor.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 24),
      Text(
        'TODAY',
        style: TextStyle(
          color: AppColor.mint,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      SizedBox(height: 12),
      TransactionTile(
        Icons.ramen_dining_rounded,
        'Noodle house',
        'Food & dining',
        '- Rs. 410',
        AppColor.coral,
      ),
      SizedBox(height: 10),
      TransactionTile(
        Icons.directions_subway_rounded,
        'Metro card',
        'Transport',
        '- Rs. 68',
        AppColor.violet,
      ),
      SizedBox(height: 10),
      TransactionTile(
        Icons.design_services_rounded,
        'Design subscription',
        'Subscriptions',
        '- Rs. 799',
        AppColor.coral,
      ),
    ],
  );
}
