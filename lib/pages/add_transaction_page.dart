import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/expense_store.dart';
import '../widgets/glass_ui.dart';
import '../widgets/standard_page.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key, required this.store});
  final ExpenseStore store;

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  int selected = 0;
  late final TextEditingController noteController;
  final names = const ['Food & dining', 'Transport', 'Shopping', 'More'];
  final icons = const [
    Icons.restaurant_rounded,
    Icons.directions_car_rounded,
    Icons.shopping_bag_rounded,
    Icons.more_horiz_rounded,
  ];
  final colors = [
    AppColor.coral,
    AppColor.violet,
    AppColor.mint,
    AppColor.muted,
  ];

  @override
  void initState() {
    super.initState();
    noteController = TextEditingController(text: widget.store.latestNote);
    final savedCategory = widget.store.latestCategory;
    final savedIndex = names.indexOf(savedCategory);
    if (savedIndex >= 0) selected = savedIndex;
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StandardPage(
    title: 'Add transaction',
    subtitle: 'Log an expense in seconds',
    children: [
      GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rs. 0.00',
              style: TextStyle(
                color: AppColor.text,
                fontSize: 42,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Expense',
                style: TextStyle(
                  color: AppColor.coral,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      Text(
        'Category',
        style: TextStyle(
          color: AppColor.muted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(4, (i) {
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 50) / 2,
            height: 58,
            child: InkWell(
              onTap: () => setState(() => selected = i),
              borderRadius: BorderRadius.circular(20),
              child: GlassCard(
                radius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(icons[i], color: colors[i], size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        names[i],
                        style: TextStyle(
                          color: AppColor.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (selected == i)
                      Icon(
                        Icons.check_circle,
                        color: AppColor.mint,
                        size: 16,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 24),
      GlassCard(
        radius: 18,
        padding: EdgeInsets.zero,
        child: TextField(
          controller: noteController,
          style: TextStyle(color: AppColor.text),
          decoration: InputDecoration(
            hintText: 'Add a note (optional)',
            hintStyle: TextStyle(color: AppColor.muted),
            contentPadding: EdgeInsets.symmetric(horizontal: 18),
            border: InputBorder.none,
          ),
        ),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () async {
          await widget.store.saveExpense(
            note: noteController.text.trim(),
            category: names[selected],
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Expense saved')));
        },
        style: FilledButton.styleFrom(
          backgroundColor: AppColor.mint,
          foregroundColor: AppColor.bg,
          minimumSize: const Size.fromHeight(56),
        ),
        child: const Text('Save expense'),
      ),
    ],
  );
}
