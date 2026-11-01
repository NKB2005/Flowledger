import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import '../models/app_transaction.dart';

class ExpenseNoteImporter {
  /// Parses a CSV or Excel (.xlsx / .xls / HTML / TSV) file bytes and returns a list of [AppTransaction].
  static Future<List<AppTransaction>> parseFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    List<List<dynamic>> rows = [];

    // 1. Check if file is a legacy BIFF8 (.xls) Compound File (starts with 0xD0, 0xCF, 0x11, 0xE0)
    if (_isBiff8(bytes)) {
      try {
        rows = Biff8Parser.parse(bytes);
      } catch (_) {
        rows = [];
      }
    }

    // 2. If not BIFF8 or BIFF8 returned empty, try package:excel (for modern .xlsx)
    if (rows.isEmpty && (fileName.toLowerCase().endsWith('.xlsx') || fileName.toLowerCase().endsWith('.xls'))) {
      try {
        rows = _readExcelRows(bytes);
      } catch (_) {
        rows = [];
      }
    }

    // 3. Fallback to CSV / TSV / HTML table text decoding
    if (rows.isEmpty) {
      rows = _readCsvOrHtmlRows(bytes);
    }

    if (rows.isEmpty) return [];

    // 4. Check if it's the special Expense Note 12-Month Grid layout
    if (_isExpenseNoteGrid(rows)) {
      return _parseExpenseNoteGrid(rows);
    }

    // 5. Otherwise process as standard tabular transactions
    return _processRows(rows);
  }

  static bool _isBiff8(Uint8List bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0 &&
        bytes[4] == 0xA1 &&
        bytes[5] == 0xB1 &&
        bytes[6] == 0x1A &&
        bytes[7] == 0xE1;
  }

  static List<List<dynamic>> _readExcelRows(Uint8List bytes) {
    final excel = xl.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];

    final sheet = excel.tables.values.first;
    final rows = <List<dynamic>>[];

    for (final row in sheet.rows) {
      final list = row.map((cell) => cell?.value?.toString() ?? '').toList();
      rows.add(list);
    }

    return rows;
  }

  static List<List<dynamic>> _readCsvOrHtmlRows(Uint8List bytes) {
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      try {
        content = latin1.decode(bytes);
      } catch (_) {
        return [];
      }
    }

    // Check if content is HTML table (common with web exports named .xls)
    if (content.toLowerCase().contains('<table') && content.toLowerCase().contains('<tr')) {
      return _parseHtmlTable(content);
    }

    try {
      return csv.decode(content);
    } catch (_) {
      return [];
    }
  }

  static List<List<dynamic>> _parseHtmlTable(String html) {
    final rows = <List<dynamic>>[];
    final trReg = RegExp(r'<tr[^>]*>(.*?)<\/tr>', caseSensitive: false, dotAll: true);
    final tdReg = RegExp(r'<t[dh][^>]*>(.*?)<\/t[dh]>', caseSensitive: false, dotAll: true);
    final tagReg = RegExp(r'<[^>]*>');

    for (final trMatch in trReg.allMatches(html)) {
      final trContent = trMatch.group(1) ?? '';
      final cells = <dynamic>[];
      for (final tdMatch in tdReg.allMatches(trContent)) {
        final cellContent = tdMatch.group(1) ?? '';
        final clean = cellContent.replaceAll(tagReg, '').replaceAll('&nbsp;', ' ').trim();
        cells.add(clean);
      }
      if (cells.isNotEmpty) {
        rows.add(cells);
      }
    }
    return rows;
  }

  static bool _isExpenseNoteGrid(List<List<dynamic>> rows) {
    if (rows.length < 3) return false;
    final monthNames = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december'
    ];

    for (int r = 0; r < 3 && r < rows.length; r++) {
      int count = 0;
      for (final cell in rows[r]) {
        final str = cell.toString().trim().toLowerCase();
        for (final m in monthNames) {
          if (str.contains(m)) {
            count++;
            break;
          }
        }
      }
      if (count >= 3) return true;
    }
    return false;
  }

  static List<AppTransaction> _parseExpenseNoteGrid(List<List<dynamic>> rows) {
    int year = DateTime.now().year;
    for (final cell in rows[0]) {
      final match = RegExp(r'20\d\d').firstMatch(cell.toString());
      if (match != null) {
        year = int.parse(match.group(0)!);
        break;
      }
    }

    final monthNames = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december'
    ];

    final monthBlocks = <int, int>{};
    for (int r = 0; r < 3 && r < rows.length; r++) {
      final row = rows[r];
      for (int c = 0; c < row.length; c++) {
        final cell = row[c].toString().trim().toLowerCase();
        for (int m = 0; m < monthNames.length; m++) {
          if (cell.contains(monthNames[m])) {
            monthBlocks[m + 1] = c;
            break;
          }
        }
      }
      if (monthBlocks.length >= 3) break;
    }

    final transactions = <AppTransaction>[];

    for (final entry in monthBlocks.entries) {
      final month = entry.key;
      final startCol = entry.value;

      int currentDay = 1;

      for (int r = 3; r < rows.length; r++) {
        final row = rows[r];
        if (startCol + 3 >= row.length) continue;

        final dateStr = row[startCol].toString().trim();
        final detailStr = row[startCol + 1].toString().trim();
        final incomeStr = row[startCol + 2].toString().trim();
        final expenseStr = row[startCol + 3].toString().trim();

        if (dateStr.isNotEmpty) {
          final d = int.tryParse(dateStr.split('.').first.replaceAll(RegExp(r'[^\d]'), ''));
          if (d != null && d >= 1 && d <= 31) {
            currentDay = d;
          }
        }

        if (detailStr.isEmpty || detailStr.toLowerCase() == 'total') {
          continue;
        }

        final incClean = incomeStr.replaceAll(RegExp(r'[^\d.]'), '');
        final expClean = expenseStr.replaceAll(RegExp(r'[^\d.]'), '');

        final income = double.tryParse(incClean) ?? 0.0;
        final expense = double.tryParse(expClean) ?? 0.0;

        final daysInMonth = DateTime(year, month + 1, 0).day;
        final safeDay = currentDay.clamp(1, daysInMonth);
        final date = DateTime(year, month, safeDay);

        if (income > 0) {
          transactions.add(
            AppTransaction(
              amount: income,
              isExpense: false,
              category: _detectCategory(detailStr, false),
              note: detailStr,
              paymentMethod: 'Expense Note',
              date: date,
            ),
          );
        }

        if (expense > 0) {
          transactions.add(
            AppTransaction(
              amount: expense,
              isExpense: true,
              category: _detectCategory(detailStr, true),
              note: detailStr,
              paymentMethod: 'Expense Note',
              date: date,
            ),
          );
        }
      }
    }

    return transactions;
  }

  static String _detectCategory(String detail, bool isExpense) {
    if (!isExpense) {
      final d = detail.toLowerCase();
      if (d.contains('salary') || d.contains('wage') || d.contains('pay')) return 'Salary';
      if (d.contains('free') || d.contains('work') || d.contains('project') || d.contains('client')) return 'Freelance';
      if (d.contains('gift') || d.contains('bonus') || d.contains('reward')) return 'Gift';
      return 'Salary';
    }

    final d = detail.toLowerCase();
    if (d.contains('food') || d.contains('samosa') || d.contains('tea') || d.contains('coffee') ||
        d.contains('lunch') || d.contains('dinner') || d.contains('breakfast') || d.contains('snack') ||
        d.contains('hotel') || d.contains('restaurant') || d.contains('cafe') || d.contains('meal') ||
        d.contains('swiggy') || d.contains('zomato') || d.contains('bakery') || d.contains('milk') ||
        d.contains('vegetable') || d.contains('fruit') || d.contains('grocery')) {
      return 'Food';
    }
    if (d.contains('bus') || d.contains('auto') || d.contains('rickshaw') || d.contains('train') ||
        d.contains('metro') || d.contains('uber') || d.contains('ola') || d.contains('cab') ||
        d.contains('petrol') || d.contains('diesel') || d.contains('fuel') || d.contains('fare') ||
        d.contains('fair') || d.contains('travel') || d.contains('ticket') || d.contains('toll')) {
      return 'Transport';
    }
    if (d.contains('rent') || d.contains('wifi') || d.contains('internet') || d.contains('electricity') ||
        d.contains('bill') || d.contains('water') || d.contains('recharge') || d.contains('advance') ||
        d.contains('pg ') || d.contains('maintenance') || d.contains('fund')) {
      return 'Bills';
    }
    if (d.contains('shirt') || d.contains('t-shirt') || d.contains('pant') || d.contains('cloth') ||
        d.contains('purchase') || d.contains('buy') || d.contains('book') || d.contains('amazon') ||
        d.contains('flipkart') || d.contains('shop') || d.contains('mall')) {
      return 'Shopping';
    }
    if (d.contains('movie') || d.contains('game') || d.contains('netflix') || d.contains('prime') ||
        d.contains('party') || d.contains('outing') || d.contains('cinema')) {
      return 'Entertainment';
    }
    if (d.contains('teeth') || d.contains('doctor') || d.contains('medicine') || d.contains('hospital') ||
        d.contains('clinic') || d.contains('tablet') || d.contains('health') || d.contains('dental') ||
        d.contains('haircut') || d.contains('salon')) {
      return 'Health';
    }

    return 'Other';
  }

  static List<AppTransaction> _processRows(List<List<dynamic>> rows) {
    if (rows.length < 2) return [];

    final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();

    int dateCol = -1;
    int amountCol = -1;
    int expenseCol = -1;
    int incomeCol = -1;
    int categoryCol = -1;
    int noteCol = -1;
    int typeCol = -1;
    int paymentCol = -1;

    for (int i = 0; i < header.length; i++) {
      final col = header[i];
      if (col.contains('date') || col.contains('time') || col.contains('day') || col.contains('when')) {
        dateCol = i;
      } else if (col == 'amount' || col.contains('price') || col.contains('total') || col.contains('cost') || col.contains('value')) {
        amountCol = i;
      } else if (col.contains('expense') || col.contains('out') || col.contains('debit') || col.contains('spent')) {
        expenseCol = i;
      } else if (col.contains('income') || col.contains('in') || col.contains('credit') || col.contains('deposit')) {
        incomeCol = i;
      } else if (col.contains('category') || col.contains('tag') || col.contains('classification')) {
        categoryCol = i;
      } else if (col.contains('note') || col.contains('memo') || col.contains('desc') || col.contains('remark') || col.contains('particular') || col.contains('detail')) {
        noteCol = i;
      } else if (col.contains('type') || col.contains('dr/cr')) {
        typeCol = i;
      } else if (col.contains('pay') || col.contains('mode') || col.contains('method') || col.contains('wallet') || col.contains('bank')) {
        paymentCol = i;
      }
    }

    if (dateCol == -1) dateCol = 0;
    if (categoryCol == -1 && rows.first.length > 1) categoryCol = 1;
    if (amountCol == -1 && expenseCol == -1 && rows.first.length > 2) amountCol = 2;

    final result = <AppTransaction>[];

    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;

      DateTime? date;
      if (dateCol >= 0 && dateCol < row.length) {
        date = _tryParseDate(row[dateCol].toString().trim());
      }
      date ??= DateTime.now();

      String category = 'Other';
      if (categoryCol >= 0 && categoryCol < row.length) {
        final catStr = row[categoryCol].toString().trim();
        if (catStr.isNotEmpty) category = catStr;
      }

      String note = '';
      if (noteCol >= 0 && noteCol < row.length) {
        note = row[noteCol].toString().trim();
      }

      String paymentMethod = 'Excel Import';
      if (paymentCol >= 0 && paymentCol < row.length) {
        final payStr = row[paymentCol].toString().trim();
        if (payStr.isNotEmpty) paymentMethod = payStr;
      }

      double amount = 0.0;
      bool isExpense = true;

      if (expenseCol >= 0 && expenseCol < row.length && _toDouble(row[expenseCol]) > 0) {
        amount = _toDouble(row[expenseCol]);
        isExpense = true;
      } else if (incomeCol >= 0 && incomeCol < row.length && _toDouble(row[incomeCol]) > 0) {
        amount = _toDouble(row[incomeCol]);
        isExpense = false;
      } else if (amountCol >= 0 && amountCol < row.length) {
        final rawVal = _toDouble(row[amountCol]);
        amount = rawVal.abs();
        if (rawVal < 0) {
          isExpense = true;
        } else if (typeCol >= 0 && typeCol < row.length) {
          final typeStr = row[typeCol].toString().toLowerCase();
          isExpense = !typeStr.contains('income');
        }
      }

      if (amount <= 0) continue;

      result.add(
        AppTransaction(
          amount: amount,
          isExpense: isExpense,
          category: category,
          note: note,
          paymentMethod: paymentMethod,
          date: date,
        ),
      );
    }

    return result;
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final clean = val.toString().replaceAll(RegExp(r'[^\d.-]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  static DateTime? _tryParseDate(String str) {
    if (str.isEmpty) return null;

    final numVal = double.tryParse(str);
    if (numVal != null && numVal >= 30000 && numVal <= 65000) {
      final base = DateTime(1899, 12, 30);
      final days = numVal.floor();
      final millis = ((numVal - days) * 86400000).round();
      return base.add(Duration(days: days, milliseconds: millis));
    }

    final formats = [
      'yyyy-MM-dd',
      'yyyy/MM/dd',
      'dd-MM-yyyy',
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'yyyy.MM.dd',
      'dd MMM yyyy',
      'd MMM yyyy',
      'dd-MMM-yyyy',
      'MMM dd, yyyy',
      'MMM d, yyyy',
      'yyyy-MM-dd HH:mm:ss',
      'yyyy/MM/dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy/MM/dd HH:mm',
      'dd/MM/yyyy HH:mm',
      'dd-MM-yyyy HH:mm',
    ];

    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parseLoose(str);
      } catch (_) {}
    }
    return DateTime.tryParse(str);
  }
}

class Biff8Parser {
  static List<List<String>> parse(Uint8List bytes) {
    if (bytes.length < 512) return [];
    if (bytes[0] != 0xD0 ||
        bytes[1] != 0xCF ||
        bytes[2] != 0x11 ||
        bytes[3] != 0xE0) {
      return [];
    }

    final byteData = ByteData.sublistView(bytes);
    final sectorShift = byteData.getUint16(30, Endian.little);
    final sectorSize = 1 << sectorShift;
    final firstDirSector = byteData.getUint32(48, Endian.little);

    final fatSectors = <int>[];
    for (int i = 0; i < 109; i++) {
      final s = byteData.getUint32(76 + i * 4, Endian.little);
      if (s < 0xFFFFFFFD) {
        fatSectors.add(s);
      }
    }

    final fat = <int>[];
    for (final s in fatSectors) {
      final offset = (s + 1) * sectorSize;
      if (offset + sectorSize <= bytes.length) {
        for (int i = 0; i < sectorSize; i += 4) {
          fat.add(byteData.getUint32(offset + i, Endian.little));
        }
      }
    }

    final dirBytes = BytesBuilder();
    int currDir = firstDirSector;
    final visitedDir = <int>{};
    while (currDir < 0xFFFFFFFD && currDir < fat.length && visitedDir.add(currDir)) {
      final offset = (currDir + 1) * sectorSize;
      if (offset + sectorSize <= bytes.length) {
        dirBytes.add(bytes.sublist(offset, offset + sectorSize));
      }
      currDir = fat[currDir];
    }
    final dirData = dirBytes.takeBytes();
    final dirByteData = ByteData.sublistView(dirData);

    int wbStartSector = -1;
    int wbStreamSize = 0;

    for (int i = 0; i + 128 <= dirData.length; i += 128) {
      final nameLen = dirByteData.getUint16(i + 64, Endian.little);
      if (nameLen > 0 && nameLen <= 64) {
        final nameChars = <int>[];
        for (int c = 0; c < nameLen - 2; c += 2) {
          nameChars.add(dirByteData.getUint16(i + c, Endian.little));
        }
        final name = String.fromCharCodes(nameChars).toLowerCase();
        if (name == 'workbook' || name == 'book') {
          wbStartSector = dirByteData.getUint32(i + 116, Endian.little);
          wbStreamSize = dirByteData.getUint32(i + 120, Endian.little);
          break;
        }
      }
    }

    if (wbStartSector == -1) return [];

    final wbBytes = BytesBuilder();
    int currWb = wbStartSector;
    final visitedWb = <int>{};
    while (currWb < 0xFFFFFFFD &&
        currWb < fat.length &&
        wbBytes.length < wbStreamSize &&
        visitedWb.add(currWb)) {
      final offset = (currWb + 1) * sectorSize;
      if (offset + sectorSize <= bytes.length) {
        wbBytes.add(bytes.sublist(offset, offset + sectorSize));
      }
      currWb = fat[currWb];
    }
    var stream = wbBytes.takeBytes();
    if (stream.length > wbStreamSize) {
      stream = stream.sublist(0, wbStreamSize);
    }
    final wbByteData = ByteData.sublistView(stream);

    final sst = <String>[];
    final cells = <int, Map<int, String>>{};

    int pos = 0;
    while (pos + 4 <= stream.length) {
      final rtype = wbByteData.getUint16(pos, Endian.little);
      final rlen = wbByteData.getUint16(pos + 2, Endian.little);
      pos += 4;
      if (pos + rlen > stream.length) break;

      if (rtype == 0x00FC) {
        _parseSST(stream, pos, rlen, sst);
      } else if (rtype == 0x00FD) {
        if (rlen >= 10) {
          final row = wbByteData.getUint16(pos, Endian.little);
          final col = wbByteData.getUint16(pos + 2, Endian.little);
          final sstIdx = wbByteData.getUint32(pos + 6, Endian.little);
          final val = (sstIdx < sst.length) ? sst[sstIdx] : '';
          cells.putIfAbsent(row, () => {})[col] = val;
        }
      } else if (rtype == 0x0203) {
        if (rlen >= 14) {
          final row = wbByteData.getUint16(pos, Endian.little);
          final col = wbByteData.getUint16(pos + 2, Endian.little);
          final val = wbByteData.getFloat64(pos + 6, Endian.little);
          final strVal = val == val.roundToDouble()
              ? val.toInt().toString()
              : val.toStringAsFixed(2);
          cells.putIfAbsent(row, () => {})[col] = strVal;
        }
      } else if (rtype == 0x027E) {
        if (rlen >= 10) {
          final row = wbByteData.getUint16(pos, Endian.little);
          final col = wbByteData.getUint16(pos + 2, Endian.little);
          final rk = wbByteData.getUint32(pos + 6, Endian.little);
          final val = _decodeRk(rk);
          final strVal = val == val.roundToDouble()
              ? val.toInt().toString()
              : val.toStringAsFixed(2);
          cells.putIfAbsent(row, () => {})[col] = strVal;
        }
      }

      pos += rlen;
    }

    if (cells.isEmpty) return [];

    final maxRow = cells.keys.reduce((a, b) => a > b ? a : b);
    int maxCol = 0;
    for (final cols in cells.values) {
      for (final c in cols.keys) {
        if (c > maxCol) maxCol = c;
      }
    }

    final table = <List<String>>[];
    for (int r = 0; r <= maxRow; r++) {
      final rowList = <String>[];
      final rowMap = cells[r];
      for (int c = 0; c <= maxCol; c++) {
        rowList.add(rowMap?[c] ?? '');
      }
      table.add(rowList);
    }

    return table;
  }

  static void _parseSST(Uint8List stream, int pos, int rlen, List<String> sst) {
    if (rlen < 8) return;
    final end = pos + rlen;
    final byteData = ByteData.sublistView(stream);
    var p = pos + 8;

    while (p + 3 <= end) {
      final numChars = byteData.getUint16(p, Endian.little);
      final flags = stream[p + 2];
      p += 3;

      final isUtf16 = (flags & 0x01) != 0;
      final hasRich = (flags & 0x08) != 0;
      final hasExt = (flags & 0x04) != 0;

      if (hasRich && p + 2 <= end) p += 2;
      if (hasExt && p + 4 <= end) p += 4;

      if (numChars == 0) {
        sst.add('');
        continue;
      }

      final byteLen = isUtf16 ? numChars * 2 : numChars;
      if (p + byteLen > end) {
        final raw = stream.sublist(p, end);
        if (isUtf16) {
          final chars = <int>[];
          for (int i = 0; i + 1 < raw.length; i += 2) {
            chars.add(raw[i] | (raw[i + 1] << 8));
          }
          sst.add(String.fromCharCodes(chars));
        } else {
          sst.add(String.fromCharCodes(raw));
        }
        break;
      }

      final raw = stream.sublist(p, p + byteLen);
      p += byteLen;

      if (isUtf16) {
        final chars = <int>[];
        for (int i = 0; i + 1 < raw.length; i += 2) {
          chars.add(raw[i] | (raw[i + 1] << 8));
        }
        sst.add(String.fromCharCodes(chars));
      } else {
        sst.add(String.fromCharCodes(raw));
      }
    }
  }

  static double _decodeRk(int rk) {
    var val = 0.0;
    if ((rk & 0x02) != 0) {
      val = (rk >> 2).toDouble();
    } else {
      final bd = ByteData(8);
      bd.setUint32(4, rk & ~0x03, Endian.little);
      val = bd.getFloat64(0, Endian.little);
    }
    if ((rk & 0x01) != 0) {
      val /= 100.0;
    }
    return val;
  }
}
