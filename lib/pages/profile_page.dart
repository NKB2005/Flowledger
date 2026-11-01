import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_colors.dart';
import '../core/auth_service.dart';
import '../models/app_transaction.dart';
import '../models/weekly_budget.dart';
import '../providers/providers.dart';
import '../widgets/glass_ui.dart';
import '../widgets/standard_page.dart';
import '../core/profile_image_store.dart';

class FinancialHealthSummary {
  const FinancialHealthSummary({
    required this.score,
    required this.status,
    required this.detail,
  });

  final int? score;
  final String status;
  final String detail;
}

FinancialHealthSummary calculateFinancialHealth({
  required List<AppTransaction> transactions,
  required List<WeeklyBudget> budgets,
  DateTime? now,
}) {
  final date = now ?? DateTime.now();
  final monthlyTransactions = transactions.where((transaction) {
    return transaction.date.year == date.year &&
        transaction.date.month == date.month;
  });
  var income = 0.0;
  var expenses = 0.0;
  for (final transaction in monthlyTransactions) {
    if (transaction.isExpense) {
      expenses += transaction.amount;
    } else {
      income += transaction.amount;
    }
  }

  if (income == 0) {
    final hasMonthlyActivity = expenses > 0;
    return FinancialHealthSummary(
      score: null,
      status: hasMonthlyActivity ? 'Add your income' : 'Not enough data',
      detail: hasMonthlyActivity
          ? 'Record income this month to calculate your financial health.'
          : 'Add this month’s income and expenses to calculate your score.',
    );
  }

  final savingsRate = (income - expenses) / income;
  final cashFlowScore = ((savingsRate + .2) / .4 * 100).clamp(0, 100);
  final weekStart = DateTime(
    date.year,
    date.month,
    date.day,
  ).subtract(Duration(days: date.weekday - 1));
  final weeklyExpenses = transactions.where((transaction) {
    return transaction.isExpense &&
        !transaction.date.isBefore(weekStart) &&
        transaction.date.isBefore(weekStart.add(const Duration(days: 7)));
  });
  final totalBudget = budgets.fold<double>(
    0,
    (sum, budget) => sum + budget.limit,
  );
  final spentAgainstBudgets = weeklyExpenses
      .where((transaction) {
        return budgets.any(
          (budget) => _sameCategory(transaction.category, budget.category),
        );
      })
      .fold<double>(0, (sum, transaction) => sum + transaction.amount);

  final score = totalBudget <= 0
      ? cashFlowScore.round()
      : (cashFlowScore * .7 +
                _budgetScore(spentAgainstBudgets / totalBudget) * .3)
            .round();
  final status = score >= 75
      ? 'On a healthy track'
      : score >= 50
      ? 'Room to improve'
      : 'Needs attention';
  final detail = totalBudget <= 0
      ? 'Based on this month’s savings rate. Add a weekly budget for a fuller score.'
      : 'Based on this month’s savings rate and this week’s budget use.';

  return FinancialHealthSummary(score: score, status: status, detail: detail);
}

double _budgetScore(double usage) {
  if (usage <= .8) return 100;
  if (usage >= 1.2) return 0;
  return (1.2 - usage) / .4 * 100;
}

bool _sameCategory(String first, String second) {
  String normalize(String category) {
    final normalized = category.trim().toLowerCase();
    return normalized == 'travel' ? 'transport' : normalized;
  }

  return normalize(first) == normalize(second);
}

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Future<void> _pickProfileImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (image != null && mounted) {
      await ProfileImageStore.save(
        image.path,
        userId: AuthService().currentUser?.uid,
      );
    }
  }

  Future<void> _logOut() async {
    final shouldLogOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign back in anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColor.coral,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (shouldLogOut != true) return;

    try {
      await AuthService().signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not log out: $error')));
      }
    }
  }

  Widget _profileAvatar() {
    final user = AuthService().currentUser;

    return ValueListenableBuilder<String?>(
      valueListenable: ProfileImageStore.path,
      builder: (context, imagePath, child) {
        ImageProvider? avatarImage;
        if (imagePath != null && imagePath.isNotEmpty) {
          avatarImage = FileImage(File(imagePath));
        } else if (user?.photoURL != null && user!.photoURL!.isNotEmpty) {
          avatarImage = NetworkImage(user.photoURL!);
        }

        return GestureDetector(
          onTap: _pickProfileImage,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 33,
                backgroundColor: const Color(0x403BEBB0),
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Text(
                        initialsForUser(user),
                        style: TextStyle(
                          color: AppColor.mint,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColor.mint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.edit_rounded, color: AppColor.bg, size: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final name = displayNameForUser(user);
    final transactions = ref.watch(transactionsProvider).value ?? const [];
    final budgets = ref.watch(weeklyBudgetsProvider).value ?? const [];
    final health = calculateFinancialHealth(
      transactions: transactions,
      budgets: budgets,
    );

    return Material(
      color: AppColor.bg,
      child: StandardPage(
        title: 'Profile',
        subtitle: 'Your money space',
        showBackButton: true,
        children: [
          Row(
            children: [
              _profileAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: AppColor.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColor.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FINANCIAL HEALTH',
                  style: TextStyle(
                    color: AppColor.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  health.score == null ? '— / 100' : '${health.score} / 100',
                  style: TextStyle(
                    color: AppColor.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  health.status,
                  style: TextStyle(
                    color: AppColor.mint,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  health.detail,
                  style: TextStyle(color: AppColor.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logOut,
              icon: Icon(Icons.logout_rounded, color: AppColor.coral),
              label: Text(
                'Log out',
                style: TextStyle(
                  color: AppColor.coral,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColor.coral.withValues(alpha: .55)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
