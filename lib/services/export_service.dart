// lib/services/export_service.dart
//
// Exports transactions to CSV. Now includes an ID column as the first column
// so that if the CSV is re-imported, IDs are preserved and duplicates are
// correctly detected even if date+title+amount coincidentally matches.
//
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class ExportService {
  /// Exports [transactions] as a CSV and opens the system share sheet.
  static Future<void> exportToCsv(
    List<Transaction> transactions, {
    String? fileName,
  }) async {
    final rows = <List<String>>[
      // Header — ID first so import can match it
      ['ID', 'Date', 'Title', 'Type', 'Category', 'Amount (₹)', 'Note'],
      ...transactions.map((t) => [
            t.id,
            formatDate(t.date),
            t.title,
            _typeLabel(t.type),
            categoryInfoMap[t.category]!.label,
            t.amount.toStringAsFixed(2),
            t.note ?? '',
          ]),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final name = fileName ??
        'cholebature_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${dir.path}/$name');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'CholeBature — Transaction Export',
      text: 'Exported ${transactions.length} transactions',
    );
  }

  static String _typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.expense:  return 'Expense';
      case TransactionType.income:   return 'Income';
      case TransactionType.borrowed: return 'Borrowed';
      case TransactionType.lend:     return 'Lend';
    }
  }
}