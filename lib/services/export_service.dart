// lib/services/export_service.dart
//
// Single CSV export containing ALL data:
//   DataType | ID | Date/NextDue | Title | Type | Category | Amount | Note | ExtraJson
//
// DataType values:
//   "Transaction"  — normal / borrow / lend transactions
//   "Scheduled"    — future/recurring transactions (extra fields in ExtraJson)
//
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction_model.dart';
import '../models/future_transaction_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class ExportService {
  static const _header = [
    'DataType', 'ID', 'Date', 'Title', 'Type', 'Category',
    'Amount (₹)', 'Note', 'ExtraJson',
  ];

  static Future<void> exportAll({
    required List<Transaction> transactions,
    required List<FutureTransaction> futureTransactions,
  }) async {
    final rows = <List<String>>[_header];

    // ── Normal / Borrow / Lend transactions ────────────────────────────────
    for (final t in transactions) {
      rows.add([
        'Transaction',
        t.id,
        formatDate(t.date),
        t.title,
        _txTypeLabel(t.type),
        categoryInfoMap[t.category]!.label,
        t.amount.toStringAsFixed(2),
        t.note ?? '',
        '', // no extra
      ]);
    }

    // ── Scheduled / Future transactions ────────────────────────────────────
    for (final ft in futureTransactions) {
      final extra = jsonEncode({
        'recurrence': ft.recurrence.name,
        'recurrenceDays': ft.recurrenceDays,
        'nextDue': ft.nextDue.toIso8601String(),
        'status': ft.status.name,
        'reminderOffsets': ft.reminderOffsets,
        'createdAt': ft.createdAt.toIso8601String(),
      });
      rows.add([
        'Scheduled',
        ft.id,
        ft.nextDue.toIso8601String(),
        ft.title,
        ft.type == TransactionType.income ? 'Income' : 'Expense',
        categoryInfoMap[ft.category]!.label,
        ft.amount.toStringAsFixed(2),
        ft.note ?? '',
        extra,
      ]);
    }

    final csv  = const ListToCsvConverter().convert(rows);
    final ts   = DateTime.now().millisecondsSinceEpoch;
    final name = 'cholebature_backup_$ts.csv';

    final tmpDir = await getTemporaryDirectory();
    final tmpFile = File('${tmpDir.path}/$name');
    await tmpFile.writeAsString(csv);

    // Copy to public Downloads on Android
    if (Platform.isAndroid) {
      try {
        const dl = '/storage/emulated/0/Download';
        if (await Directory(dl).exists()) {
          await tmpFile.copy('$dl/$name');
        }
      } catch (_) {}
    }

    await Share.shareXFiles(
      [XFile(tmpFile.path, mimeType: 'text/csv')],
      subject: 'CholeBature — Full Backup',
      text: 'Exported ${transactions.length} transactions'
            ' + ${futureTransactions.length} scheduled',
    );
  }

  static String _txTypeLabel(TransactionType t) => switch (t) {
        TransactionType.expense  => 'Expense',
        TransactionType.income   => 'Income',
        TransactionType.borrowed => 'Borrowed',
        TransactionType.lend     => 'Lend',
      };
}