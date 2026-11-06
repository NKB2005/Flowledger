import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/categories.dart';

class CategoryPickerSheet extends StatelessWidget {
  final String merchant;
  final double amount;
  final bool isExpense;
  final String currentCategory;
  final ValueChanged<String> onCategorySelected;

  const CategoryPickerSheet({
    super.key,
    required this.merchant,
    required this.amount,
    required this.isExpense,
    required this.currentCategory,
    required this.onCategorySelected,
  });

  static Future<String?> show({
    required BuildContext context,
    required String merchant,
    required double amount,
    required bool isExpense,
    required String currentCategory,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CategoryPickerSheet(
        merchant: merchant,
        amount: amount,
        isExpense: isExpense,
        currentCategory: currentCategory,
        onCategorySelected: (cat) => Navigator.of(ctx).pop(cat),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = isExpense ? expenseCategories : incomeCategories;
    final symbol = isExpense ? '-' : '+';
    final signColor = isExpense ? AppColor.coral : AppColor.mint;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColor.card.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: signColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: signColor.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      isExpense
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: signColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Categorize Transaction',
                          style: TextStyle(
                            color: AppColor.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$merchant  ·  $symbol₹${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppColor.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColor.mint.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColor.mint.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColor.mint, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'FlowLedger will remember your choice for future "$merchant" transactions.',
                        style: TextStyle(
                          color: AppColor.text.withValues(alpha: 0.85),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Category options Wrap
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: categories.map((cat) {
                  final isSelected = cat.name == currentCategory;
                  return InkWell(
                    onTap: () => onCategorySelected(cat.name),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cat.color.withValues(alpha: 0.25)
                            : AppColor.glassSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? cat.color
                              : Colors.white.withValues(alpha: 0.08),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.icon, color: cat.color, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            cat.name,
                            style: TextStyle(
                              color: isSelected ? AppColor.text : AppColor.muted,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
