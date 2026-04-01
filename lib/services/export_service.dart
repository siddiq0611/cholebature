// Exports ALL data as three separate CSV files bundled in one share action:
//   1. transactions.csv          — all normal transactions
//   2. scheduled_transactions.csv — future/recurring transactions
//
// On Android the files are also copied to ~/Downloads.
//
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction_model.dart';
import '../models/future_transaction_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class ExportService {
  static Future<void> exportAll({
    required List<Transaction> transactions,
    required List<FutureTransaction> futureTransactions,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final tmpDir = await getTemporaryDirectory();
    final files  = <XFile>[];

    // ── 1. Transactions ──────────────────────────────────────────────────────
    if (transactions.isNotEmpty) {
      final rows = <List<String>>[
        ['ID', 'Date', 'Title', 'Type', 'Category', 'Amount (₹)', 'Note'],
        ...transactions.map((t) => [
              t.id,
              formatDate(t.date),
              t.title,
              _txTypeLabel(t.type),
              categoryInfoMap[t.category]!.label,
              t.amount.toStringAsFixed(2),
              t.note ?? '',
            ]),
      ];
      final f = await _writeCSV(tmpDir, 'transactions_$ts.csv', rows);
      files.add(XFile(f.path, mimeType: 'text/csv'));
      await _copyToDownloads(f, 'transactions_$ts.csv');
    }

    // ── 2. Scheduled / Future transactions ───────────────────────────────────
    if (futureTransactions.isNotEmpty) {
      final rows = <List<String>>[
        [
          'ID', 'Title', 'Amount (₹)', 'Type', 'Category',
          'Recurrence', 'RecurrenceDays', 'NextDue',
          'Status', 'ReminderOffsets', 'Note', 'CreatedAt',
        ],
        ...futureTransactions.map((ft) => [
              ft.id,
              ft.title,
              ft.amount.toStringAsFixed(2),
              _ftTypeLabel(ft.type),
              categoryInfoMap[ft.category]!.label,
              ft.recurrence.name,
              ft.recurrenceDays.join(','),
              ft.nextDue.toIso8601String(),
              ft.status.name,
              ft.reminderOffsets.join(','),
              ft.note ?? '',
              ft.createdAt.toIso8601String(),
            ]),
      ];
      final f = await _writeCSV(
          tmpDir, 'scheduled_transactions_$ts.csv', rows);
      files.add(XFile(f.path, mimeType: 'text/csv'));
      await _copyToDownloads(f, 'scheduled_transactions_$ts.csv');
    }

    if (files.isEmpty) return;

    await Share.shareXFiles(
      files,
      subject: 'CholeBature — Full Export',
      text: 'Exported ${transactions.length} transactions'
          '${futureTransactions.isNotEmpty ? ' + ${futureTransactions.length} scheduled' : ''}',
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static Future<File> _writeCSV(
      Directory dir, String name, List<List<String>> rows) async {
    final csv  = const ListToCsvConverter().convert(rows);
    final file = File('${dir.path}/$name');
    await file.writeAsString(csv);
    return file;
  }

  static Future<void> _copyToDownloads(File src, String name) async {
    if (!Platform.isAndroid) return;
    try {
      const dl = '/storage/emulated/0/Download';
      if (await Directory(dl).exists()) {
        await src.copy('$dl/$name');
      }
    } catch (_) {}
  }

  static String _txTypeLabel(TransactionType t) {
    switch (t) {
      case TransactionType.expense:  return 'Expense';
      case TransactionType.income:   return 'Income';
      case TransactionType.borrowed: return 'Borrowed';
      case TransactionType.lend:     return 'Lend';
    }
  }

  static String _ftTypeLabel(TransactionType t) =>
      t == TransactionType.income ? 'Income' : 'Expense';
}