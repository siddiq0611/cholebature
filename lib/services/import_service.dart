// Imports both transactions and scheduled (future) transactions.
// The user picks one or more CSV files — each is auto-detected by its header.
//
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../models/future_transaction_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class ImportResult {
  final int importedTx;
  final int skippedTx;
  final int importedFt;
  final int skippedFt;
  final int failed;
  final List<String> errors;
  final List<Transaction> transactions;
  final List<FutureTransaction> futureTransactions;

  const ImportResult({
    required this.importedTx,
    required this.skippedTx,
    required this.importedFt,
    required this.skippedFt,
    required this.failed,
    required this.errors,
    required this.transactions,
    required this.futureTransactions,
  });

  bool get hasAnything => importedTx > 0 || importedFt > 0;
}

class ImportService {
  static const _uuid = Uuid();

  /// Opens file picker (multi-select), parses every chosen CSV, and merges results.
  static Future<ImportResult?> pickAndParseAll({
    required List<Transaction> existingTx,
    required List<FutureTransaction> existingFt,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final allTx  = <Transaction>[];
    final allFt  = <FutureTransaction>[];
    final errors = <String>[];
    int skippedTx = 0, skippedFt = 0, failed = 0;

    // Build duplicate keys
    final txKeys = existingTx
        .map((t) =>
            '${formatDate(t.date)}|${t.title.toLowerCase()}|${t.amount}')
        .toSet();
    final ftKeys = existingFt
        .map((f) =>
            '${f.title.toLowerCase()}|${f.nextDue.toIso8601String()}')
        .toSet();

    for (final pf in result.files) {
      if (pf.path == null) continue;
      final raw = await File(pf.path!).readAsString();
      final rows = const CsvToListConverter(eol: '\n').convert(raw);
      if (rows.isEmpty) continue;

      final header = rows.first
          .map((c) => c.toString().trim().toLowerCase())
          .toList();

      if (_isFutureHeader(header)) {
        // ── Scheduled transactions ──────────────────────────────────────────
        for (var i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (_isBlankRow(row)) continue;
          try {
            String cell(int col) =>
                col < row.length ? row[col].toString().trim() : '';

            final id         = cell(0);
            final title      = cell(1);
            final amountStr  = cell(2).replaceAll('₹', '').replaceAll(',', '');
            final typeStr    = cell(3).toLowerCase();
            final catStr     = cell(4).toLowerCase();
            final recStr     = cell(5).toLowerCase();
            final daysStr    = cell(6);
            final nextDueStr = cell(7);
            final statusStr  = cell(8).toLowerCase();
            final offsetsStr = cell(9);
            final note       = cell(10);
            final createdStr = cell(11);

            final amount = double.tryParse(amountStr) ?? 0;
            final nextDue = DateTime.tryParse(nextDueStr);
            if (nextDue == null) {
              errors.add('Row ${i + 1}: invalid nextDue "$nextDueStr"');
              failed++;
              continue;
            }

            final key = '${title.toLowerCase()}|${nextDue.toIso8601String()}';
            if (ftKeys.contains(key)) { skippedFt++; continue; }

            final ft = FutureTransaction(
              id: id.length > 8 ? id : _uuid.v4(),
              title: title,
              amount: amount,
              category: _parseCat(catStr) ?? TransactionCategory.misc,
              type: typeStr == 'income'
                  ? TransactionType.income
                  : TransactionType.expense,
              note: note.isEmpty ? null : note,
              recurrence: _parseRecurrence(recStr),
              recurrenceDays: _parseIntList(daysStr),
              nextDue: nextDue,
              status: _parseStatus(statusStr),
              reminderOffsets: _parseIntList(offsetsStr).isEmpty
                  ? [0]
                  : _parseIntList(offsetsStr),
              createdAt:
                  DateTime.tryParse(createdStr) ?? DateTime.now(),
            );

            allFt.add(ft);
            ftKeys.add(key);
          } catch (e) {
            errors.add('Row ${i + 1}: $e');
            failed++;
          }
        }
      } else {
        // ── Normal transactions ─────────────────────────────────────────────
        final hasId = header.isNotEmpty && header[0] == 'id';
        final colId   = hasId ? 0 : -1;
        final colDate = hasId ? 1 : 0;
        final colTitle  = hasId ? 2 : 1;
        final colType   = hasId ? 3 : 2;
        final colCat    = hasId ? 4 : 3;
        final colAmt    = hasId ? 5 : 4;
        final colNote   = hasId ? 6 : 5;

        for (var i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (_isBlankRow(row)) continue;
          try {
            String cell(int col) =>
                col < row.length ? row[col].toString().trim() : '';

            final dateStr   = cell(colDate);
            final title     = cell(colTitle);
            final typeStr   = cell(colType).toLowerCase();
            final catStr    = cell(colCat).toLowerCase();
            final amountStr = cell(colAmt)
                .replaceAll('₹', '')
                .replaceAll(',', '');
            final note    = cell(colNote);
            final idStr   = colId >= 0 ? cell(colId) : '';

            final amount = double.tryParse(amountStr);
            if (amount == null) {
              errors.add('Row ${i + 1}: invalid amount "$amountStr"');
              failed++;
              continue;
            }

            final date = _parseDate(dateStr);
            if (date == null) {
              errors.add('Row ${i + 1}: invalid date "$dateStr"');
              failed++;
              continue;
            }

            final type = _parseTxType(typeStr);
            if (type == null) {
              errors.add('Row ${i + 1}: unknown type "$typeStr"');
              failed++;
              continue;
            }

            final key =
                '${formatDate(date)}|${title.toLowerCase()}|$amount';
            if (txKeys.contains(key)) { skippedTx++; continue; }

            allTx.add(Transaction(
              id: idStr.length > 8 ? idStr : _uuid.v4(),
              title: title,
              amount: amount,
              category: _parseCat(catStr) ?? TransactionCategory.misc,
              type: type,
              date: date,
              note: note.isEmpty ? null : note,
            ));
            txKeys.add(key);
          } catch (e) {
            errors.add('Row ${i + 1}: $e');
            failed++;
          }
        }
      }
    }

    return ImportResult(
      importedTx: allTx.length,
      skippedTx: skippedTx,
      importedFt: allFt.length,
      skippedFt: skippedFt,
      failed: failed,
      errors: errors,
      transactions: allTx,
      futureTransactions: allFt,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static bool _isFutureHeader(List<String> h) =>
      h.any((c) => c.contains('recurrence') || c.contains('nextdue') || c.contains('next_due'));

  static bool _isBlankRow(List row) =>
      row.isEmpty ||
      (row.length == 1 && row.first.toString().trim().isEmpty);

  static DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    final monthNames = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final parts = s.trim().split(RegExp(r'[\s/\-]'));
    if (parts.length == 3) {
      final monthNum =
          monthNames[parts[1].toLowerCase().substring(0, 3)];
      if (monthNum != null) {
        final day  = int.tryParse(parts[0]);
        final year = int.tryParse(parts[2]);
        if (day != null && year != null) return DateTime(year, monthNum, day);
      }
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      if (a != null && b != null && c != null) {
        if (a > 31) return DateTime(a, b, c);
        return DateTime(c, b, a);
      }
    }
    return DateTime.tryParse(s);
  }

  static TransactionType? _parseTxType(String s) {
    switch (s) {
      case 'expense':  return TransactionType.expense;
      case 'income':   return TransactionType.income;
      case 'borrowed':
      case 'borrow':   return TransactionType.borrowed;
      case 'lend':
      case 'lent':     return TransactionType.lend;
      default:         return null;
    }
  }

  static TransactionCategory? _parseCat(String s) {
    const map = {
      'food': TransactionCategory.food,
      'travel': TransactionCategory.travel,
      'essentials': TransactionCategory.essentials,
      'work': TransactionCategory.work,
      'misc': TransactionCategory.misc,
      'shopping': TransactionCategory.shop,
      'shop': TransactionCategory.shop,
      'home': TransactionCategory.home,
      'health': TransactionCategory.health,
      'salary': TransactionCategory.salary,
      'cashback': TransactionCategory.cashback,
      'gifts': TransactionCategory.gifts,
      'others': TransactionCategory.otherIncome,
      'otherincome': TransactionCategory.otherIncome,
      'borrowed': TransactionCategory.borrowed,
      'lend': TransactionCategory.lend,
    };
    return map[s.toLowerCase()];
  }

  static RecurrenceType _parseRecurrence(String s) {
    switch (s) {
      case 'daily':   return RecurrenceType.daily;
      case 'weekly':  return RecurrenceType.weekly;
      case 'monthly': return RecurrenceType.monthly;
      default:        return RecurrenceType.once;
    }
  }

  static FutureStatus _parseStatus(String s) {
    switch (s) {
      case 'paused':         return FutureStatus.paused;
      case 'skipped':        return FutureStatus.skipped;
      case 'completedcycle': return FutureStatus.completedCycle;
      default:               return FutureStatus.pending;
    }
  }

  static List<int> _parseIntList(String s) {
    if (s.isEmpty) return [];
    return s
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
  }
}