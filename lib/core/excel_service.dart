import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/app_transaction.dart';
import 'expense_note_importer.dart';

class ExcelService {
  /// Parses Excel (.xlsx, .xls) or CSV files into transactions.
  static Future<List<AppTransaction>> importFromFile({
    required String fileName,
    required Uint8List bytes,
  }) =>
      ExpenseNoteImporter.parseFile(fileName: fileName, bytes: bytes);

  /// Exports transactions to a Microsoft Excel (.xlsx) workbook and prompts the system share sheet.
  static Future<void> exportToExcel(List<AppTransaction> transactions) async {
    final excel = Excel.createExcel();
    const sheetName = 'FlowLedger';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    final headerTitles = [
      'Date & Time',
      'Type',
      'Category',
      'Amount (Rs.)',
      'Payment Method',
      'Notes',
    ];

    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: '#FFFFFF'.excelColor,
      backgroundColorHex: '#00C48C'.excelColor,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    sheet.appendRow(headerTitles.map((t) => TextCellValue(t)).toList());

    for (int col = 0; col < headerTitles.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.cellStyle = headerStyle;
    }

    double totalIncome = 0.0;
    double totalExpense = 0.0;

    for (final t in transactions) {
      if (t.isExpense) {
        totalExpense += t.amount;
      } else {
        totalIncome += t.amount;
      }

      sheet.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(t.date)),
        TextCellValue(t.isExpense ? 'Expense' : 'Income'),
        TextCellValue(t.category),
        DoubleCellValue(t.amount),
        TextCellValue(t.paymentMethod),
        TextCellValue(t.note),
      ]);
    }

    // Add spacing and summary
    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('SUMMARY'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    sheet.appendRow([
      TextCellValue('Total Income'),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalIncome),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    sheet.appendRow([
      TextCellValue('Total Expenses'),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalExpense),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    sheet.appendRow([
      TextCellValue('Net Balance'),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalIncome - totalExpense),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Could not generate Excel spreadsheet.');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'FlowLedger_Export_$timestamp.xlsx';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            name: fileName,
          ),
        ],
        subject: 'FlowLedger Transactions Export ($fileName)',
        title: 'Share FlowLedger Excel Sheet',
      ),
    );
  }
}
