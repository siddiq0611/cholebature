import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/custom_category_model.dart';
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
    // Pass ALL custom categories (including soft-deleted so transactions
    // that reference them can still be resolved on import)
    List<CustomCategory> customCategories = const [],
  }) async {
    final rows = <List<String>>[_header];

    // ── 1. Custom category definition rows (come FIRST so import can
    //       create them before processing transactions that reference them)
    for (final cat in customCategories) {
      final extra = jsonEncode({
        'colorHex': '#${cat.colorValue.toRadixString(16).padLeft(8, '0').toUpperCase()}',
        'iconCodePoint': cat.iconCodePoint,
        'iconFontFamily': cat.iconFontFamily,
        'categoryType': cat.categoryType.name, // 'expense' or 'income'
        'deleted': cat.deleted,
      });
      rows.add([
        'CustomCategory',
        cat.id,
        '', // no date
        cat.name,
        '', // no type
        cat.categoryType.name,
        '', // no amount
        '', // no note
        extra,
      ]);
    }

    // ── 2. Normal / Borrow / Lend transactions
    for (final t in transactions) {
      // Resolve the human-readable category label
      String catLabel;
      if (t.customCategoryId != null) {
        // Find the custom category by id so we export its name
        final customCat = customCategories
            .where((c) => c.id == t.customCategoryId)
            .firstOrNull;
        catLabel = customCat?.name ?? categoryInfoMap[t.category]!.label;
      } else {
        catLabel = categoryInfoMap[t.category]!.label;
      }

      final extra = t.customCategoryId != null
          ? jsonEncode({'customCategoryId': t.customCategoryId})
          : '';

      rows.add([
        'Transaction',
        t.id,
        formatDate(t.date),
        t.title,
        _txTypeLabel(t.type),
        catLabel,
        t.amount.toStringAsFixed(2),
        t.note ?? '',
        extra,
      ]);
    }

    // ── 3. Scheduled / Future transactions
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

    final tmpDir  = await getTemporaryDirectory();
    final tmpFile = File('${tmpDir.path}/$name');
    await tmpFile.writeAsString(csv);

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
            ' + ${futureTransactions.length} scheduled'
            ' + ${customCategories.where((c) => !c.deleted).length} custom categories',
    );
  }

  static String _txTypeLabel(TransactionType t) => switch (t) {
        TransactionType.expense  => 'Expense',
        TransactionType.income   => 'Income',
        TransactionType.borrowed => 'Borrowed',
        TransactionType.lend     => 'Lend',
      };
}