import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_colors.dart';
import '../core/bank_sms_parser.dart';
import '../core/bank_sms_service.dart';
import '../core/excel_service.dart';
import '../core/expense_note_importer.dart';
import '../providers/providers.dart';
import '../widgets/glass_ui.dart';
import '../widgets/standard_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({
    super.key,
    this.userId,
    required this.isDarkMode,
    required this.onThemeChanged,
    this.onLogOut,
  });
  final String? userId;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final Future<void> Function()? onLogOut;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _customizationExpanded = false;

  bool _isImporting = false;
  bool _isExporting = false;
  bool _smsSyncEnabled = false;
  bool _isScanningSms = false;

  User? get _safeFirebaseUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  String? get _effectiveUserId {
    if (widget.userId != null && widget.userId!.isNotEmpty) {
      return widget.userId;
    }
    try {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid != null && uid.isNotEmpty) return uid;
    } catch (_) {}
    return _safeFirebaseUser?.uid;
  }

  String get _accountDisplayName {
    final user = _safeFirebaseUser;
    if (user != null && (user.displayName?.isNotEmpty ?? false)) {
      return user.displayName!;
    }
    if (user != null && (user.email?.isNotEmpty ?? false)) {
      return user.email!;
    }
    final uid = _effectiveUserId;
    if (uid != null && uid.isNotEmpty) {
      return 'Account (${uid.substring(0, uid.length.clamp(0, 6))}...)';
    }
    return 'Current Account';
  }

  @override
  void initState() {
    super.initState();
    _loadSmsPreference();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadSmsPreference();
    }
  }

  Future<void> _loadSmsPreference() async {
    final enabled =
        await BankSmsService.isAutoSyncEnabled(userId: _effectiveUserId);
    if (mounted) {
      setState(() => _smsSyncEnabled = enabled);
    }
  }

  Future<void> _toggleSmsSync(bool value) async {
    final uid = _effectiveUserId;
    if (value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColor.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: AppColor.border.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColor.mint.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_read_rounded,
                  color: AppColor.mint,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enable Bank SMS Sync?',
                  style: TextStyle(
                    color: AppColor.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FlowLedger will monitor incoming bank SMS on this device and automatically log transactions into this account:',
                style: TextStyle(
                  color: AppColor.muted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColor.glassSurface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColor.border.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_circle_outlined,
                      size: 18,
                      color: AppColor.mint,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _accountDisplayName,
                        style: TextStyle(
                          color: AppColor.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Personal SMS, OTPs, and private messages are completely ignored.',
                style: TextStyle(
                  color: AppColor.muted,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColor.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColor.mint,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Enable',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        if (mounted) setState(() => _smsSyncEnabled = false);
        return;
      }

      final hasPermission = await BankSmsService.checkPermission();
      bool granted = hasPermission;
      if (!hasPermission) {
        granted = await BankSmsService.requestPermission();
      }
      if (!granted) {
        if (mounted) {
          setState(() => _smsSyncEnabled = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'SMS permission is required on Android to detect bank transactions.',
              ),
            ),
          );
        }
        return;
      }
      await BankSmsService.setAutoSyncEnabled(true, userId: uid);
      if (mounted) setState(() => _smsSyncEnabled = true);

      BankSmsService.startListening(
        userId: uid,
        getRepo: () => ref.read(transactionRepositoryProvider),
        onAutoLogged: (parsed) {
          if (!mounted) return;
          final type = parsed.isExpense ? 'Expense' : 'Income';
          final symbol = parsed.isExpense ? '-' : '+';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
              backgroundColor: AppColor.card,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppColor.mint.withValues(alpha: 0.5),
                  width: 1.2,
                ),
              ),
              content: Row(
                children: [
                  Icon(
                    parsed.isExpense
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: parsed.isExpense ? AppColor.coral : AppColor.mint,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-logged $type from Bank SMS',
                          style: TextStyle(
                            color: AppColor.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${parsed.note}  ·  $symbol₹${parsed.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppColor.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColor.mint,
            content: const Text(
              'Real-time Bank SMS auto-tracking enabled!',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
    } else {
      await BankSmsService.setAutoSyncEnabled(false, userId: uid);
      BankSmsService.stopListening();
      if (mounted) {
        setState(() => _smsSyncEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank SMS auto-tracking disabled.')),
        );
      }
    }
  }

  Future<void> _scanRecentBankSms() async {
    if (_isScanningSms) return;
    final repo = ref.read(transactionRepositoryProvider);
    if (repo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first.')),
      );
      return;
    }

    final hasPerm = await BankSmsService.checkPermission();
    if (!hasPerm) {
      final granted = await BankSmsService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'SMS read permission is required on Android to scan recent bank messages.',
              ),
            ),
          );
        }
        return;
      }
    }

    setState(() => _isScanningSms = true);
    try {
      final parsedList = await BankSmsService.scanRecentBankSms(limit: 50);
      if (!mounted) return;

      if (parsedList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No bank transaction messages found in your recent SMS inbox.'),
          ),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Import Bank Transactions?'),
          content: Text(
            'Found ${parsedList.length} bank transactions in your SMS inbox.\n\nWould you like to import them into FlowLedger?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColor.mint,
                foregroundColor: Colors.black,
              ),
              child: Text('Import All (${parsedList.length})'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        final txs = parsedList.map((p) => p.toAppTransaction()).toList();
        final count = await repo.addBatch(txs);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColor.mint,
              content: Text(
                'Successfully imported $count transactions from bank SMS!',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to scan SMS: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanningSms = false);
      }
    }
  }

  void _showTestBankSmsDialog() {
    final presets = [
      {
        'label': 'Zomato Food (Debit ₹450)',
        'text': 'Dear UPI user A/C 9876 debited by 450.0 on 24-Oct-26 to Zomato UPI Ref 410293. Avl Bal Rs 18,240.50',
      },
      {
        'label': 'Shell Fuel (Debit ₹1,200)',
        'text': 'Your A/C ending 4321 has been debited by INR 1,200.00 on 24-Oct-26 at SHELL PETROL PUMP. Avl Bal INR 14,800.00',
      },
      {
        'label': 'Monthly Salary (Credit ₹65,000)',
        'text': 'Your A/C 1234 is credited with INR 65,000.00 on 01-Nov-26 towards Salary. Clear Bal INR 85,200.00',
      },
      {
        'label': 'Amazon Refund (Credit ₹899)',
        'text': 'Your A/C 5544 has been credited by Rs 899.00 on 25-Oct-26. Info: Amazon Refund. Avl Bal Rs 22,400.00',
      },
    ];

    final controller = TextEditingController(text: presets[0]['text']);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final parsed = BankSmsParser.parse(controller.text);
          return Container(
            decoration: BoxDecoration(
              color: AppColor.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: AppColor.border.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColor.muted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.science_outlined, color: AppColor.mint, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Bank SMS Simulator',
                        style: TextStyle(
                          color: AppColor.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Test real-time parsing or paste any bank transaction message.',
                    style: TextStyle(color: AppColor.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'QUICK SAMPLES',
                    style: TextStyle(
                      color: AppColor.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((sample) {
                      final isSelected = controller.text == sample['text'];
                      return ActionChip(
                        backgroundColor: isSelected
                            ? AppColor.mint.withValues(alpha: 0.2)
                            : AppColor.glassSurface,
                        side: BorderSide(
                          color: isSelected
                              ? AppColor.mint
                              : AppColor.border.withValues(alpha: 0.5),
                        ),
                        label: Text(
                          sample['label']!,
                          style: TextStyle(
                            color: isSelected ? AppColor.mint : AppColor.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          setModalState(() {
                            controller.text = sample['text']!;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    style: TextStyle(color: AppColor.text, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'SMS Message Body',
                      labelStyle: TextStyle(color: AppColor.muted),
                      filled: true,
                      fillColor: AppColor.glassSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: AppColor.border.withValues(alpha: 0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColor.mint, width: 1.5),
                      ),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 16),
                  if (parsed != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: (parsed.isExpense ? AppColor.coral : AppColor.mint)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (parsed.isExpense ? AppColor.coral : AppColor.mint)
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: parsed.isExpense
                                      ? AppColor.coral
                                      : AppColor.mint,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  parsed.isExpense ? 'DEBIT (EXPENSE)' : 'CREDIT (INCOME)',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${parsed.isExpense ? '-' : '+'}₹${parsed.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: parsed.isExpense
                                      ? AppColor.coral
                                      : AppColor.mint,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                'Category: ',
                                style: TextStyle(
                                  color: AppColor.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                parsed.category,
                                style: TextStyle(
                                  color: AppColor.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Note: ',
                                style: TextStyle(
                                  color: AppColor.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  parsed.note,
                                  style: TextStyle(
                                    color: AppColor.text,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (parsed.accountDigits != null &&
                              parsed.accountDigits!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Account / Ref: ${parsed.accountDigits}',
                              style: TextStyle(
                                color: AppColor.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColor.mint,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.flash_on_rounded, size: 20),
                        label: const Text(
                          'Simulate & Auto-Log to FlowLedger',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        onPressed: () async {
                          final repo = ref.read(transactionRepositoryProvider);
                          if (repo == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please log in to auto-log transactions.'),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          await repo.add(parsed.toAppTransaction());
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
                                backgroundColor: AppColor.card,
                                elevation: 6,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: AppColor.mint.withValues(alpha: 0.5),
                                    width: 1.2,
                                  ),
                                ),
                                content: Row(
                                  children: [
                                    Icon(
                                      parsed.isExpense
                                          ? Icons.arrow_upward_rounded
                                          : Icons.arrow_downward_rounded,
                                      color: parsed.isExpense
                                          ? AppColor.coral
                                          : AppColor.mint,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Simulated Bank SMS Logged!',
                                            style: TextStyle(
                                              color: AppColor.muted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '${parsed.note}  ·  ${parsed.isExpense ? '-' : '+'}₹${parsed.amount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: AppColor.text,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColor.glassSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColor.border.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppColor.muted, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No bank debit/credit transaction detected in this text (or OTP/notification).',
                              style: TextStyle(color: AppColor.muted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportExcel() async {
    try {
      final repo = ref.read(transactionRepositoryProvider);
      if (repo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to export transactions.')),
        );
        return;
      }

      setState(() => _isExporting = true);

      final list = await repo.getAll();
      if (list.isEmpty) {
        if (mounted) {
          setState(() => _isExporting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No transactions to export yet.')),
          );
        }
        return;
      }

      await ExcelService.exportToExcel(list);

      if (mounted) {
        setState(() => _isExporting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importExpenseNote() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'Expense file',
        extensions: <String>['csv', 'xls', 'xlsx', 'txt'],
      );

      final file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      );

      if (file == null) return;

      setState(() => _isImporting = true);

      final bytes = await file.readAsBytes();

      final transactions = await ExpenseNoteImporter.parseFile(
        fileName: file.name,
        bytes: bytes,
      );

      if (transactions.isEmpty) {
        if (mounted) {
          setState(() => _isImporting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No transactions found in this file.'),
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // Ask for confirmation before importing
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Import Transactions?'),
          content: Text(
            'Found ${transactions.length} transactions from "${file.name}".\n\nWould you like to import them into FlowLedger?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Import All'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() => _isImporting = false);
        return;
      }

      final repo = ref.read(transactionRepositoryProvider);
      if (repo == null) {
        setState(() => _isImporting = false);
        return;
      }

      final count = await repo.addBatch(transactions);

      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColor.mint,
            content: Text(
              'Successfully imported $count transactions!',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  void _setPalette(String paletteId) {
    setState(() => AppColor.setPalette(paletteId));
    unawaited(AppColor.saveAppearance());
  }

  void _setDockBlur(double value) {
    setState(() => AppColor.dockBlur = value);
    AppColor.revision.value++;
  }

  void _setDockOpacity(double value) {
    setState(() => AppColor.dockOpacity = value);
    AppColor.revision.value++;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppColor.revision,
    builder: (context, _) => StandardPage(
      title: 'Settings',
      subtitle: 'Make FlowLedger yours',
      children: [
        GlassCard(
          radius: 20,
          padding: EdgeInsets.zero,
          child: SwitchListTile.adaptive(
            value: AppColor.isDarkMode,
            onChanged: (val) {
              widget.onThemeChanged(val);
              setState(() {});
            },
            activeThumbColor: AppColor.mint,
            secondary: Icon(
              AppColor.isDarkMode
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              color: AppColor.mint,
            ),
            title: Text(
              AppColor.isDarkMode ? 'Dark mode' : 'Light mode',
              style:
                  TextStyle(color: AppColor.text, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              AppColor.isDarkMode
                  ? 'Easy on the eyes at night'
                  : 'Bright and clear for daytime',
              style: TextStyle(color: AppColor.muted, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          radius: 20,
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            leading: Icon(Icons.tune_rounded, color: AppColor.mint),
            iconColor: AppColor.mint,
            collapsedIconColor: AppColor.muted,
            textColor: AppColor.text,
            collapsedTextColor: AppColor.text,
            title: Text(
              'Customization',
              style:
                  TextStyle(color: AppColor.text, fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              'Colors, dock glass, and page effects',
              style: TextStyle(color: AppColor.muted, fontSize: 12),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            onExpansionChanged: (expanded) {
              setState(() => _customizationExpanded = expanded);
            },
            initiallyExpanded: _customizationExpanded,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'COLOR PALETTE',
                  style: TextStyle(
                    color: AppColor.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppColor.palettes.map((palette) {
                  return ChoiceChip(
                    selected: AppColor.paletteId == palette.id,
                    onSelected: (_) => _setPalette(palette.id),
                    avatar: _ColorDot(palette.primary),
                    label: Text(
                      palette.name,
                      style: TextStyle(
                        color: AppColor.paletteId == palette.id
                            ? (AppColor.isDarkMode ? Colors.black : Colors.black87)
                            : AppColor.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Dock blur',
                    style: TextStyle(
                      color: AppColor.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${AppColor.dockBlur.round()} px',
                  style: TextStyle(color: AppColor.muted, fontSize: 12),
                ),
              ],
            ),
            Slider(
              value: AppColor.dockBlur,
              min: 0,
              max: 28,
              divisions: 14,
              activeColor: AppColor.mint,
              onChanged: _setDockBlur,
              onChangeEnd: (_) => unawaited(AppColor.saveAppearance()),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Dock transparency',
                    style: TextStyle(
                      color: AppColor.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${(AppColor.dockOpacity * 100).round()}%',
                  style: TextStyle(color: AppColor.muted, fontSize: 12),
                ),
              ],
            ),
            Slider(
              value: AppColor.dockOpacity,
              min: 0,
              max: 1,
              divisions: 20,
              activeColor: AppColor.mint,
              onChanged: _setDockOpacity,
              onChangeEnd: (_) => unawaited(AppColor.saveAppearance()),
            ),
            const SizedBox(height: 8),
            GlassCard(
              radius: 18,
              surfaceColor: AppColor.dockSurface,
              blurSigma: AppColor.dockBlur,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Icon(Icons.home_outlined, color: AppColor.muted),
                  Icon(Icons.list_alt_rounded, color: AppColor.muted),
                  Icon(Icons.add_circle_rounded, color: AppColor.mint),
                  Icon(Icons.insights_outlined, color: AppColor.muted),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: AppColor.showAmbientBackground,
              onChanged: (value) {
                setState(() => AppColor.showAmbientBackground = value);
                AppColor.revision.value++;
                unawaited(AppColor.saveAppearance());
              },
              activeThumbColor: AppColor.mint,
              title: Text(
                'Ambient background',
                style: TextStyle(
                  color: AppColor.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Show soft color lighting behind pages',
                style: TextStyle(color: AppColor.muted, fontSize: 12),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: AppColor.showDockLabels,
              onChanged: (value) {
                setState(() => AppColor.showDockLabels = value);
                AppColor.revision.value++;
                unawaited(AppColor.saveAppearance());
              },
              activeThumbColor: AppColor.mint,
              title: Text(
                'Dock labels',
                style: TextStyle(
                  color: AppColor.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Show names under navigation icons',
                style: TextStyle(color: AppColor.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      GlassCard(
        radius: 20,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SwitchListTile.adaptive(
              value: _smsSyncEnabled,
              onChanged: _toggleSmsSync,
              activeThumbColor: AppColor.mint,
              secondary: Icon(
                Icons.mark_email_read_outlined,
                color: AppColor.mint,
              ),
              title: Text(
                'Bank SMS auto-tracking',
                style: TextStyle(
                  color: AppColor.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                _smsSyncEnabled
                    ? 'Active · Auto-logging to $_accountDisplayName'
                    : 'Turned off · Tap to enable for $_accountDisplayName',
                style: TextStyle(color: AppColor.muted, fontSize: 12),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              indent: 56,
              color: AppColor.border.withValues(alpha: 0.3),
            ),
            ListTile(
              leading: Icon(
                Icons.history_toggle_off_rounded,
                color: AppColor.mint,
              ),
              title: Text(
                'Scan recent bank SMS',
                style: TextStyle(
                  color: AppColor.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Scan your inbox for recent bank credits & debits and import them',
                style: TextStyle(color: AppColor.muted, fontSize: 12),
              ),
              trailing: _isScanningSms
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColor.mint),
                      ),
                    )
                  : Icon(Icons.chevron_right, color: AppColor.muted),
              onTap: _isScanningSms ? null : _scanRecentBankSms,
            ),
            Divider(
              height: 1,
              thickness: 1,
              indent: 56,
              color: AppColor.border.withValues(alpha: 0.3),
            ),
            ListTile(
              leading: Icon(Icons.science_outlined, color: AppColor.mint),
              title: Text(
                'Bank SMS simulator / tester',
                style: TextStyle(
                  color: AppColor.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Test SMS parsing or paste a sample bank message',
                style: TextStyle(color: AppColor.muted, fontSize: 12),
              ),
              trailing: Icon(Icons.chevron_right, color: AppColor.muted),
              onTap: _showTestBankSmsDialog,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      GlassCard(
        radius: 20,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.file_upload_outlined, color: AppColor.mint),
              title: Text(
                'Import from Excel / CSV',
                style: TextStyle(
                  color: AppColor.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Import .xlsx, .xls, or .csv from Excel or other apps',
                style: TextStyle(color: AppColor.muted, fontSize: 12),
              ),
              trailing: _isImporting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColor.mint),
                      ),
                    )
                  : Icon(Icons.chevron_right, color: AppColor.muted),
              onTap: _isImporting || _isExporting ? null : _importExpenseNote,
            ),
            Divider(
              height: 1,
              thickness: 1,
              indent: 56,
              color: AppColor.border.withValues(alpha: 0.3),
            ),
            ListTile(
              leading: Icon(Icons.table_chart_outlined, color: AppColor.mint),
              title: Text(
                'Export to Excel (.xlsx)',
                style: TextStyle(
                  color: AppColor.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Share or download your expenses as an Excel workbook',
                style: TextStyle(color: AppColor.muted, fontSize: 12),
              ),
              trailing: _isExporting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColor.mint),
                      ),
                    )
                  : Icon(Icons.chevron_right, color: AppColor.muted),
              onTap: _isImporting || _isExporting ? null : _exportExcel,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      GlassCard(
        radius: 20,
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(Icons.info_outline_rounded, color: AppColor.violet),
          title: Text(
            'About FlowLedger',
            style: TextStyle(color: AppColor.text, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            'Version 1.0.0',
            style: TextStyle(color: AppColor.muted, fontSize: 12),
          ),
          trailing: Icon(Icons.chevron_right, color: AppColor.muted),
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'FlowLedger',
            applicationVersion: '1.0.0',
            applicationLegalese: 'A calmer way to understand your spending.',
          ),
        ),
      ),
      const SizedBox(height: 12),
      GlassCard(
        radius: 20,
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(Icons.logout_rounded, color: AppColor.coral),
          title: Text(
            'Log out',
            style: TextStyle(
              color: AppColor.coral,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTap: () async {
            final shouldLogOut = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Log out?'),
                content: const Text('You can sign back in anytime.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColor.coral,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Log out'),
                  ),
                ],
              ),
            );
            if (shouldLogOut == true) await widget.onLogOut?.call();
          },
        ),
      ),
      const SizedBox(height: 24),
      Center(
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/logo/app_logo_full.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'FlowLedger',
              style: TextStyle(
                color: AppColor.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Version 1.0.0 • A calmer way to understand your money',
              style: TextStyle(
                color: AppColor.muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
        const SizedBox(height: 16),
      ],
    ),
  );
}

class _ColorDot extends StatelessWidget {
  const _ColorDot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
