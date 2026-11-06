import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../core/merchant_category_store.dart';
import '../models/app_transaction.dart';
import '../models/categories.dart';
import '../providers/providers.dart';
import '../widgets/app_text.dart';
import '../widgets/glass_ui.dart';
import '../widgets/standard_page.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.existing,
    this.onSaved,
    this.onBack,
  });

  final AppTransaction? existing;
  final VoidCallback? onSaved;
  final VoidCallback? onBack;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late final TextEditingController _customCategory;
  late bool _isExpense;
  late String _category;
  late String _payment;
  late DateTime _date;
  bool _saving = false;

  static const _paymentMethods = ['Cash', 'UPI', 'Card', 'Bank'];

  List<AppCategory> get _cats =>
      _isExpense ? expenseCategories : incomeCategories;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _amount = TextEditingController(text: t == null ? '' : t.amount.toString());
    _note = TextEditingController(text: t?.note ?? '');
    _isExpense = t?.isExpense ?? true;
    _category = t?.category ?? expenseCategories.first.name;
    final isPreset = _cats.any((category) => category.name == _category);
    _customCategory = TextEditingController(text: isPreset ? '' : _category);
    _payment = t?.paymentMethod ?? 'Cash';
    _date = t?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _customCategory.dispose();
    super.dispose();
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _resetForm() {
    _amount.clear();
    _note.clear();
    _customCategory.clear();
    _isExpense = true;
    _category = expenseCategories.first.name;
    _payment = 'Cash';
    _date = DateTime.now();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      _snack('Enter a valid amount');
      return;
    }
    final repo = ref.read(transactionRepositoryProvider);
    if (repo == null) {
      _snack('Please log in again');
      return;
    }
    setState(() => _saving = true);
    try {
      final transaction = AppTransaction(
        id: widget.existing?.id ?? '',
        amount: amount,
        isExpense: _isExpense,
        category: _customCategory.text.trim().isEmpty
            ? _category
            : _customCategory.text.trim(),
        note: _note.text.trim(),
        paymentMethod: _payment,
        date: _date,
      );
      if (widget.existing == null) {
        await repo.add(transaction).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Network timed out while saving to Firestore.'),
        );
      } else {
        await repo.update(transaction).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Network timed out while updating in Firestore.'),
        );
      }
      if (transaction.note.trim().isNotEmpty) {
        unawaited(MerchantCategoryStore.learn(transaction.note.trim(), transaction.category));
      }
      if (mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() {
          _saving = false;
          if (widget.existing == null) {
            _resetForm();
          }
        });
        if (widget.onSaved != null) {
          widget.onSaved!();
        } else {
          Navigator.pop(context);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Could not save: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final canPop = Navigator.canPop(context);
    return Scaffold(
      backgroundColor: AppColor.bg,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: StandardPage(
        title: editing ? 'Edit transaction' : 'Add transaction',
        subtitle: _isExpense
            ? 'Log an expense in seconds'
            : 'Record incoming money',
        showBackButton: editing || canPop || widget.onBack != null,
        onBack: widget.onBack,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Expense')),
                    ButtonSegment(value: false, label: Text('Income')),
                  ],
                  selected: {_isExpense},
                  onSelectionChanged: (selection) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() {
                      _isExpense = selection.first;
                      _customCategory.clear();
                      _category = _cats.first.name;
                    });
                  },
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    color: AppColor.text,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    hintText: '0',
                    border: InputBorder.none,
                    prefixStyle: TextStyle(color: AppColor.mint),
                    hintStyle: TextStyle(color: AppColor.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          heading('Category'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cats
                .map(
                  (category) => ChoiceChip(
                    avatar: Icon(
                      category.icon,
                      size: 18,
                      color: category.color,
                    ),
                    label: Text(category.name),
                    selectedColor: AppColor.mint.withValues(alpha: .18),
                    labelStyle: TextStyle(color: AppColor.text),
                    selected:
                        _customCategory.text.trim().isEmpty &&
                        _category == category.name,
                    onSelected: (_) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() {
                        _customCategory.clear();
                        _category = category.name;
                      });
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customCategory,
            style: TextStyle(color: AppColor.text),
            onChanged: (value) {
              setState(() {
                _category = value.trim().isEmpty ? _cats.first.name : '';
              });
            },
            decoration: const InputDecoration(
              labelText: 'Custom category (optional)',
              hintText: 'e.g. Pet care or Bonus',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment method',
                  style: TextStyle(
                    color: AppColor.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: _paymentMethods
                      .map(
                        (payment) => ChoiceChip(
                          label: Text(payment),
                          selectedColor: AppColor.violet.withValues(alpha: .24),
                          labelStyle: TextStyle(color: AppColor.text),
                          selected: _payment == payment,
                          onSelected: (_) {
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() => _payment = payment);
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_today, color: AppColor.mint),
                  title: Text(
                    DateFormat('EEE, d MMM y').format(_date),
                    style: TextStyle(color: AppColor.text),
                  ),
                  trailing: Icon(Icons.chevron_right, color: AppColor.muted),
                  onTap: _pickDate,
                ),
                TextField(
                  controller: _note,
                  style: TextStyle(color: AppColor.text),
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    labelStyle: TextStyle(color: AppColor.muted),
                    prefixIcon: Icon(Icons.notes, color: AppColor.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColor.mint,
              foregroundColor: AppColor.bg,
              minimumSize: const Size.fromHeight(52),
            ),
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(editing ? 'Save changes' : 'Save'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    ),
  );
  }
}
