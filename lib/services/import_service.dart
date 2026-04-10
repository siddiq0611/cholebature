// Imports from the unified single-CSV format produced by ExportService.
// Also still handles old-style transaction-only CSVs for backwards compat.
//
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../models/future_transaction_model.dart';
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

    final txKeys = existingTx
        .map((t) => '${formatDate(t.date)}|${t.title.toLowerCase()}|${t.amount}')
        .toSet();
    final ftKeys = existingFt
        .map((f) => '${f.title.toLowerCase()}|${f.nextDue.toIso8601String()}')
        .toSet();

    for (final pf in result.files) {
      if (pf.path == null) continue;
      final raw  = await File(pf.path!).readAsString();
      final rows = const CsvToListConverter(eol: '\n').convert(raw);
      if (rows.isEmpty) continue;

      final header = rows.first
          .map((c) => c.toString().trim().toLowerCase())
          .toList();

      final isUnified = header.isNotEmpty && header[0] == 'datatype';

      if (isUnified) {
        // ── New unified format ───────────────────────────────────────────
        for (var i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (_blank(row)) continue;
          try {
            String c(int col) =>
                col < row.length ? row[col].toString().trim() : '';

            final dataType  = c(0).toLowerCase();
            final id        = c(1);
            final dateStr   = c(2);
            final title     = c(3);
            final typeStr   = c(4).toLowerCase();
            final catStr    = c(5).toLowerCase();
            final amtStr    = c(6).replaceAll('₹', '').replaceAll(',', '');
            final note      = c(7);
            final extraRaw  = c(8);

            final amount = double.tryParse(amtStr);
            if (amount == null) {
              errors.add('Row ${i + 1}: invalid amount "$amtStr"');
              failed++; continue;
            }

            final cat = _parseCat(catStr) ?? TransactionCategory.misc;

            if (dataType == 'scheduled') {
              final nextDue = DateTime.tryParse(dateStr);
              if (nextDue == null) {
                errors.add('Row ${i + 1}: invalid date "$dateStr"');
                failed++; continue;
              }
              final key =
                  '${title.toLowerCase()}|${nextDue.toIso8601String()}';
              if (ftKeys.contains(key)) { skippedFt++; continue; }

              Map<String, dynamic> extra = {};
              try { extra = jsonDecode(extraRaw) as Map<String, dynamic>; }
              catch (_) {}

              final ft = FutureTransaction(
                id: id.length > 8 ? id : _uuid.v4(),
                title: title,
                amount: amount,
                category: cat,
                type: typeStr == 'income'
                    ? TransactionType.income
                    : TransactionType.expense,
                note: note.isEmpty ? null : note,
                recurrence: _parseRec(extra['recurrence'] as String? ?? ''),
                recurrenceDays: _intList(extra['recurrenceDays']),
                nextDue: nextDue,
                status: _parseStatus(extra['status'] as String? ?? ''),
                reminderOffsets: _intList(extra['reminderOffsets']).isEmpty
                    ? [0]
                    : _intList(extra['reminderOffsets']),
                createdAt: extra['createdAt'] != null
                    ? (DateTime.tryParse(extra['createdAt'] as String) ??
                        DateTime.now())
                    : DateTime.now(),
              );
              allFt.add(ft);
              ftKeys.add(key);
            } else {
              // Transaction / Borrowed / Lend
              final date = _parseDate(dateStr);
              if (date == null) {
                errors.add('Row ${i + 1}: invalid date "$dateStr"');
                failed++; continue;
              }
              final type = _parseTxType(typeStr);
              if (type == null) {
                errors.add('Row ${i + 1}: unknown type "$typeStr"');
                failed++; continue;
              }
              final key =
                  '${formatDate(date)}|${title.toLowerCase()}|$amount';
              if (txKeys.contains(key)) { skippedTx++; continue; }

              allTx.add(Transaction(
                id: id.length > 8 ? id : _uuid.v4(),
                title: title,
                amount: amount,
                category: cat,
                type: type,
                date: date,
                note: note.isEmpty ? null : note,
              ));
              txKeys.add(key);
            }
          } catch (e) {
            errors.add('Row ${i + 1}: $e');
            failed++;
          }
        }
      } else {
        // ── Legacy transaction-only format ───────────────────────────────
        final hasId   = header.isNotEmpty && header[0] == 'id';
        final colId   = hasId ? 0 : -1;
        final colDate = hasId ? 1 : 0;
        final colTitle  = hasId ? 2 : 1;
        final colType   = hasId ? 3 : 2;
        final colCat    = hasId ? 4 : 3;
        final colAmt    = hasId ? 5 : 4;
        final colNote   = hasId ? 6 : 5;

        for (var i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (_blank(row)) continue;
          try {
            String c(int col) =>
                col < row.length ? row[col].toString().trim() : '';

            final date = _parseDate(c(colDate));
            if (date == null) {
              errors.add('Row ${i + 1}: invalid date'); failed++; continue;
            }
            final title  = c(colTitle);
            final type   = _parseTxType(c(colType).toLowerCase());
            if (type == null) {
              errors.add('Row ${i + 1}: unknown type'); failed++; continue;
            }
            final amtStr = c(colAmt).replaceAll('₹', '').replaceAll(',', '');
            final amount = double.tryParse(amtStr);
            if (amount == null) {
              errors.add('Row ${i + 1}: invalid amount'); failed++; continue;
            }
            final key = '${formatDate(date)}|${title.toLowerCase()}|$amount';
            if (txKeys.contains(key)) { skippedTx++; continue; }

            final idStr = colId >= 0 ? c(colId) : '';
            allTx.add(Transaction(
              id: idStr.length > 8 ? idStr : _uuid.v4(),
              title: title,
              amount: amount,
              category:
                  _parseCat(c(colCat).toLowerCase()) ?? TransactionCategory.misc,
              type: type,
              date: date,
              note: c(colNote).isEmpty ? null : c(colNote),
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

  // ── Parsers ──────────────────────────────────────────────────────────────────

  static bool _blank(List row) =>
      row.isEmpty || (row.length == 1 && row.first.toString().trim().isEmpty);

  static DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    final dt = DateTime.tryParse(s);
    if (dt != null) return dt;
    final monthNames = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final parts = s.trim().split(RegExp(r'[\s/\-]'));
    if (parts.length == 3) {
      final mn =
          monthNames[parts[1].toLowerCase().substring(0, 3)];
      if (mn != null) {
        final d = int.tryParse(parts[0]);
        final y = int.tryParse(parts[2]);
        if (d != null && y != null) return DateTime(y, mn, d);
      }
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      if (a != null && b != null && c != null) {
        return a > 31 ? DateTime(a, b, c) : DateTime(c, b, a);
      }
    }
    return null;
  }

  static TransactionType? _parseTxType(String s) => switch (s) {
        'expense'  => TransactionType.expense,
        'income'   => TransactionType.income,
        'borrowed' => TransactionType.borrowed,
        'borrow'   => TransactionType.borrowed,
        'lend'     => TransactionType.lend,
        'lent'     => TransactionType.lend,
        _          => null,
      };

  static TransactionCategory? _parseCat(String s) => {
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
      }[s.toLowerCase()];

  static RecurrenceType _parseRec(String s) => switch (s) {
        'daily'   => RecurrenceType.daily,
        'weekly'  => RecurrenceType.weekly,
        'monthly' => RecurrenceType.monthly,
        _         => RecurrenceType.once,
      };

  static FutureStatus _parseStatus(String s) => switch (s) {
        'paused'         => FutureStatus.paused,
        'skipped'        => FutureStatus.skipped,
        'completedcycle' => FutureStatus.completedCycle,
        _                => FutureStatus.pending,
      };

  static List<int> _intList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => (e as num).toInt()).toList();
    return raw
        .toString()
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
  }
}