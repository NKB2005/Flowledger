import '../models/app_transaction.dart';
import 'merchant_category_store.dart';

class ParsedBankSms {
  final double amount;
  final bool isExpense;
  final String category;
  final String note;
  final String paymentMethod;
  final DateTime date;
  final String? accountDigits;
  final double? availableBalance;
  final String rawMessage;
  final String sender;
  final bool isConfident;
  final String? transactionId;

  const ParsedBankSms({
    required this.amount,
    required this.isExpense,
    required this.category,
    required this.note,
    required this.paymentMethod,
    required this.date,
    this.accountDigits,
    this.availableBalance,
    required this.rawMessage,
    required this.sender,
    this.isConfident = true,
    this.transactionId,
  });

  String get merchant => note;

  ParsedBankSms copyWith({
    double? amount,
    bool? isExpense,
    String? category,
    String? note,
    String? paymentMethod,
    DateTime? date,
    String? accountDigits,
    double? availableBalance,
    String? rawMessage,
    String? sender,
    bool? isConfident,
    String? transactionId,
  }) {
    return ParsedBankSms(
      amount: amount ?? this.amount,
      isExpense: isExpense ?? this.isExpense,
      category: category ?? this.category,
      note: note ?? this.note,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
      accountDigits: accountDigits ?? this.accountDigits,
      availableBalance: availableBalance ?? this.availableBalance,
      rawMessage: rawMessage ?? this.rawMessage,
      sender: sender ?? this.sender,
      isConfident: isConfident ?? this.isConfident,
      transactionId: transactionId ?? this.transactionId,
    );
  }

  AppTransaction toAppTransaction({String? id}) {
    return AppTransaction(
      id: id ?? transactionId ?? '',
      amount: amount,
      isExpense: isExpense,
      category: category,
      note: note,
      paymentMethod: paymentMethod,
      date: date,
    );
  }
}

class BankSmsParser {
  // Amount regex handles: "Rs 450", "Rs. 1,200.50", "INR 300", "₹500.00"
  static final _amountPattern = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final _amountSuffixPattern = RegExp(
    r'([\d,]+(?:\.\d{1,2})?)\s*(?:Rs\.?|INR|₹)',
    caseSensitive: false,
  );

  static final _actionAmountPattern = RegExp(
    r'(?:debited|credited|spent|withdrawn|paid|received)\s*(?:by|for|with|of)?\s*(?:Rs\.?|INR|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // Available balance pattern: "Avl Bal: Rs 15,200", "Available Balance: INR 500"
  static final _balancePattern = RegExp(
    r'(?:Avl|Available|Net)\s*(?:Bal|Balance)?[\s:]*(?:Rs\.?|INR|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // Account / Card pattern: "A/c ending 1234", "Card ending 5678", "A/C **4321"
  static final _accountPattern = RegExp(
    r'(?:A/c|Acct|Account|Card)\s*(?:no\.?)?\s*(?:ending\s*)?([xX*]*\d{3,4})',
    caseSensitive: false,
  );

  // Merchant patterns: "to VPA / Zomato", "at SWIGGY", "info: UBER"
  static final _merchantPattern = RegExp(
    r'(?:to|at|vpa|info|for|via)\s+([A-Za-z0-9\s._\-@&]{2,32}?)(?:\.|\s+on|\s+ref|\s+avl|\s+bal|\s+upi|\s+txn|$)',
    caseSensitive: false,
  );

  /// Returns a [ParsedBankSms] if the text represents a valid bank transaction, or null otherwise.
  static ParsedBankSms? parse(String message, {String sender = '', DateTime? timestamp}) {
    if (message.trim().isEmpty) return null;

    final lower = message.toLowerCase();

    // Ignore OTP messages, login alerts, promotional spam, balance inquiries
    if (_isNonTransactionMessage(lower)) return null;

    // Detect Transaction Type (Debit = Expense, Credit = Income)
    final rawIsDebit = _isDebit(lower);
    final rawIsCredit = _isCredit(lower);

    if (!rawIsDebit && !rawIsCredit) return null;

    // Resolve transaction direction:
    // "debited ... credited to [merchant]" is an expense (debit)
    final bool isDebit;
    if (rawIsDebit && rawIsCredit) {
      if (lower.contains('credited to your') || lower.contains('deposited in your') || lower.contains('received in your')) {
        isDebit = false;
      } else {
        isDebit = true;
      }
    } else {
      isDebit = rawIsDebit;
    }

    // Extract Transaction Amount
    final amount = _extractAmount(message);
    if (amount == null || amount <= 0) return null;

    // Extract Available Balance if present in message
    final avlBalance = _extractBalance(message);

    // Extract Account or Card ending digits
    final accountDigits = _extractAccount(message);

    // Extract Merchant / Payee
    final merchant = _extractMerchant(message, isExpense: isDebit);

    // Detect Payment Method
    final paymentMethod = _detectPaymentMethod(lower, sender, accountDigits);

    // Detect Category with Smart Learning Store & Keywords
    final learnedCat = MerchantCategoryStore.getCategory(merchant);
    final String category;
    final bool isConfident;

    if (learnedCat != null) {
      if (isDebit && learnedCat == 'Salary') {
        category = 'Other';
        isConfident = false;
      } else {
        category = learnedCat;
        isConfident = true;
      }
    } else if (isDebit) {
      final detected = _detectCategory(merchant, lower);
      final nonSalary = detected == 'Salary' ? 'Other' : detected;
      category = nonSalary;
      isConfident = nonSalary != 'Other';
    } else {
      final detected = _detectIncomeCategory(lower, merchant);
      category = detected;
      isConfident = detected != 'Other';
    }

    return ParsedBankSms(
      amount: amount,
      isExpense: isDebit,
      category: category,
      note: merchant,
      paymentMethod: paymentMethod,
      date: timestamp ?? DateTime.now(),
      accountDigits: accountDigits,
      availableBalance: avlBalance,
      rawMessage: message,
      sender: sender,
      isConfident: isConfident,
    );
  }

  static bool _isNonTransactionMessage(String lower) {
    if (lower.contains('otp') || lower.contains('one time password')) return true;
    if (lower.contains('verification code') || lower.contains('security code')) return true;
    if (lower.contains('login alert') || lower.contains('password changed')) return true;
    if (lower.contains('apply for loan') || lower.contains('pre-approved')) return true;
    if (lower.contains('credit card offer') || lower.contains('congratulations')) return true;
    return false;
  }

  static bool _isDebit(String lower) {
    if (lower.contains('debited') || lower.contains('debit')) return true;
    if (lower.contains('dr.') || lower.contains('dr ') || lower.contains('dr:') || lower.contains('a/c dr')) return true;
    if (lower.contains('spent') || lower.contains('paid') || lower.contains('payment of') || lower.contains('payment to') || lower.contains('payment towards')) return true;
    if (lower.contains('withdrawn') || lower.contains('withdrawal') || lower.contains('deducted') || lower.contains('deduction')) return true;
    if (lower.contains('sent to') || lower.contains('sent rs') || lower.contains('sent inr') || lower.contains('sent ₹')) return true;
    if (lower.contains('transferred to') || lower.contains('transfer to') || lower.contains('transfer of') || lower.contains('trf to')) return true;
    if (lower.contains('purchase of') || lower.contains('purchase at') || lower.contains('purchased at') || lower.contains('charged to') || lower.contains('charged')) return true;
    if (lower.contains('auto-debit') || lower.contains('auto debit')) return true;
    return false;
  }

  static bool _isCredit(String lower) {
    return lower.contains('credited') ||
        lower.contains('credited with') ||
        lower.contains('credited to your') ||
        lower.contains('received rs') ||
        lower.contains('received inr') ||
        lower.contains('received ₹') ||
        lower.contains('received from') ||
        lower.contains('deposited') ||
        lower.contains('refunded') ||
        lower.contains('added to your') ||
        lower.contains('salary credited') ||
        lower.contains('cashback');
  }

  static String _detectIncomeCategory(String text, String merchant) {
    final lower = '$text $merchant'.toLowerCase();
    if (lower.contains('salary') || lower.contains('payroll') || lower.contains('stipend') || lower.contains('wages')) {
      return 'Salary';
    }
    if (lower.contains('freelance') || lower.contains('client') || lower.contains('project') || lower.contains('consulting')) {
      return 'Freelance';
    }
    if (lower.contains('cashback') || lower.contains('reward') || lower.contains('gift') || lower.contains('bonus')) {
      return 'Gift';
    }
    return 'Other';
  }

  static double? _extractAmount(String text) {
    // 1. Try action-based amount first: "debited by 450.0", "credited with INR 65,000"
    final actionMatch = _actionAmountPattern.firstMatch(text);
    if (actionMatch != null) {
      final clean = actionMatch.group(1)!.replaceAll(',', '');
      final val = double.tryParse(clean);
      if (val != null && val > 0) return val;
    }

    // 2. Strip available balance snippet so balance amount isn't confused for transaction amount
    final textWithoutBalance = text.replaceAll(_balancePattern, '');

    final match = _amountPattern.firstMatch(textWithoutBalance);
    if (match != null) {
      final clean = match.group(1)!.replaceAll(',', '');
      final val = double.tryParse(clean);
      if (val != null && val > 0) return val;
    }

    final suffixMatch = _amountSuffixPattern.firstMatch(textWithoutBalance);
    if (suffixMatch != null) {
      final clean = suffixMatch.group(1)!.replaceAll(',', '');
      final val = double.tryParse(clean);
      if (val != null && val > 0) return val;
    }

    return null;
  }

  static double? _extractBalance(String text) {
    final match = _balancePattern.firstMatch(text);
    if (match != null) {
      final clean = match.group(1)!.replaceAll(',', '');
      return double.tryParse(clean);
    }
    return null;
  }

  static String? _extractAccount(String text) {
    final match = _accountPattern.firstMatch(text);
    if (match != null) {
      return match.group(1);
    }
    return null;
  }

  static String _extractMerchant(String text, {required bool isExpense}) {
    if (!isExpense) {
      final lower = text.toLowerCase();
      if (lower.contains('salary') || lower.contains('payroll')) return 'Salary';
      if (lower.contains('refund')) return 'Refund';
      if (lower.contains('cashback')) return 'Cashback';
      return 'Incoming Transfer';
    }

    final matches = _merchantPattern.allMatches(text);
    for (final match in matches) {
      String m = match.group(1)!.trim();
      // Skip if match is an amount like "Rs.55.00" or digits
      if (m.startsWith(RegExp(r'(?:Rs\.?|INR|₹|\d)', caseSensitive: false))) {
        continue;
      }
      if (m.toLowerCase().startsWith('account of ')) {
        m = m.substring(11).trim();
      } else if (m.toLowerCase().startsWith('a/c of ')) {
        m = m.substring(7).trim();
      }
      // Remove trailing words like 'on', 'via', 'ref'
      m = m.replaceAll(RegExp(r'\s+(?:on|via|ref|upi|avl|bal)$', caseSensitive: false), '').trim();
      if (m.isNotEmpty && m.length > 1) {
        // Clean up common VPA handles like xyz@okaxis
        if (m.contains('@')) {
          final prefix = m.split('@').first;
          if (prefix.isNotEmpty) return prefix.toUpperCase();
        }
        return _capitalize(m);
      }
    }

    return 'Bank Payment';
  }

  static String _detectPaymentMethod(String lower, String sender, String? accountDigits) {
    if (lower.contains('upi') || lower.contains('gpay') || lower.contains('phonepe') || lower.contains('paytm')) {
      return 'UPI';
    } else if (lower.contains('card') || lower.contains('credit card') || lower.contains('debit card')) {
      return 'Card';
    } else if (lower.contains('atm') || lower.contains('cash')) {
      return 'Cash';
    }
    return 'Bank Transfer';
  }

  static String _detectCategory(String merchant, String messageLower) {
    final m = '$merchant $messageLower'.toLowerCase();

    // Food & Dining
    if (m.contains('swiggy') ||
        m.contains('zomato') ||
        m.contains('mcdonald') ||
        m.contains('starbucks') ||
        m.contains('kfc') ||
        m.contains('domino') ||
        m.contains('pizza') ||
        m.contains('burger') ||
        m.contains('cafe') ||
        m.contains('coffee') ||
        m.contains('tea') ||
        m.contains('chai') ||
        m.contains('dhaba') ||
        m.contains('canteen') ||
        m.contains('snack') ||
        m.contains('sweets') ||
        m.contains('juice') ||
        m.contains('restaurant') ||
        m.contains('hotel') ||
        m.contains('bakery') ||
        m.contains('food') ||
        m.contains('dining') ||
        m.contains('milk') ||
        m.contains('grocery') ||
        m.contains('blinkit') ||
        m.contains('zepto') ||
        m.contains('instamart') ||
        m.contains('bigbasket')) {
      return 'Food';
    }

    // Transport
    if (m.contains('uber') ||
        m.contains('ola') ||
        m.contains('rapido') ||
        m.contains('metro') ||
        m.contains('bus') ||
        m.contains('train') ||
        m.contains('irctc') ||
        m.contains('petrol') ||
        m.contains('fuel') ||
        m.contains('diesel') ||
        m.contains('indian oil') ||
        m.contains('bharat petroleum') ||
        m.contains('shell') ||
        m.contains('hpcl') ||
        m.contains('toll') ||
        m.contains('fastag') ||
        m.contains('flight') ||
        m.contains('indigo') ||
        m.contains('airline')) {
      return 'Transport';
    }

    // Shopping
    if (m.contains('amazon') ||
        m.contains('flipkart') ||
        m.contains('myntra') ||
        m.contains('zara') ||
        m.contains('h&m') ||
        m.contains('ajio') ||
        m.contains('nykaa') ||
        m.contains('meesho') ||
        m.contains('mall') ||
        m.contains('retail') ||
        m.contains('mart') ||
        m.contains('store') ||
        m.contains('shopping')) {
      return 'Shopping';
    }

    // Bills & Utilities
    if (m.contains('electricity') ||
        m.contains('water') ||
        m.contains('gas') ||
        m.contains('recharge') ||
        m.contains('jio') ||
        m.contains('airtel') ||
        m.contains('vi ') ||
        m.contains('vodafone') ||
        m.contains('broadband') ||
        m.contains('wifi') ||
        m.contains('bill') ||
        m.contains('maintenance') ||
        m.contains('rent')) {
      return 'Bills';
    }

    // Entertainment
    if (m.contains('netflix') ||
        m.contains('spotify') ||
        m.contains('prime') ||
        m.contains('hotstar') ||
        m.contains('youtube') ||
        m.contains('pvr') ||
        m.contains('inox') ||
        m.contains('cinema') ||
        m.contains('movie') ||
        m.contains('bookmyshow') ||
        m.contains('gaming') ||
        m.contains('steam')) {
      return 'Entertainment';
    }

    // Health
    if (m.contains('pharmacy') ||
        m.contains('chemist') ||
        m.contains('apollo') ||
        m.contains('1mg') ||
        m.contains('pharmeasy') ||
        m.contains('hospital') ||
        m.contains('clinic') ||
        m.contains('doctor') ||
        m.contains('medical') ||
        m.contains('health')) {
      return 'Health';
    }

    return 'Other';
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    final words = s.split(RegExp(r'\s+'));
    return words.map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }
}
