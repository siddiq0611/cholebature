// Imports transactions from a CSV file exported by ExportService.
// Expected columns (order matters, matches export):
//   Date, Title, Type, Category, Amount (₹), Note
//
// Also handles the extended format which includes an ID column:
//   ID, Date, Title, Type, Category, Amount (₹), Note
//
// Duplicate detection: a transaction is considered a duplicate if
// the combination of (date string + title + amount) already exists
// in the provided existing transactions list.
//
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../models/transaction_model.dart';
import '../utils/formatters.dart';
import 'package:uuid/uuid.dart';

class ImportResult {
  final int imported;
  final int skipped;   // duplicates
  final int failed;    // parse errors
  final List<String> errors;
  final List<Transaction> transactions;

  const ImportResult({
    required this.imported,
    required this.skipped,
    required this.failed,
    required this.errors,
    required this.transactions,
  });
}

class ImportService {
  static const _uuid = Uuid();

  /// Opens a file picker, parses the chosen CSV, and returns an ImportResult.
  /// Call [DatabaseService.insertTransaction] for each transaction in the result.
  static Future<ImportResult?> pickAndParse(
      List<Transaction> existing) async {
    // Open file picker (CSV only)
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final path = result.files.single.path;
    if (path == null) return null;

    final file = File(path);
    final raw = await file.readAsString();
    return _parseCsv(raw, existing);
  }

  /// Parse a raw CSV string. Exposed separately so it can be unit-tested.
  static ImportResult _parseCsv(
      String raw, List<Transaction> existing) {
    final rows = const CsvToListConverter(eol: '\n').convert(raw);
    if (rows.isEmpty) {
      return const ImportResult(
          imported: 0, skipped: 0, failed: 0,
          errors: ['File is empty'], transactions: []);
    }

    // Detect header and column layout
    final header = rows.first.map((c) => c.toString().trim().toLowerCase()).toList();
    final hasIdCol = header.first == 'id';

    int colId = hasIdCol ? 0 : -1;
    int colDate = hasIdCol ? 1 : 0;
    int colTitle = hasIdCol ? 2 : 1;
    int colType = hasIdCol ? 3 : 2;
    int colCategory = hasIdCol ? 4 : 3;
    int colAmount = hasIdCol ? 5 : 4;
    int colNote = hasIdCol ? 6 : 5;

    // Build duplicate lookup: "dateStr|title|amount"
    final existingKeys = existing.map((t) {
      return '${formatDate(t.date)}|${t.title.toLowerCase()}|${t.amount}';
    }).toSet();

    final imported = <Transaction>[];
    final errors = <String>[];
    int skipped = 0;
    int failed = 0;

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty ||
          (row.length == 1 && row.first.toString().trim().isEmpty)) {
        continue; // blank row
      }

      try {
        // Safely read cell
        String cell(int col) =>
            col < row.length ? row[col].toString().trim() : '';

        final dateStr = cell(colDate);
        final title = cell(colTitle);
        final typeStr = cell(colType).toLowerCase();
        final categoryStr = cell(colCategory).toLowerCase();
        final amountStr =
            cell(colAmount).replaceAll('₹', '').replaceAll(',', '').trim();
        final note = colNote < row.length ? cell(colNote) : null;
        final idStr = hasIdCol ? cell(colId) : '';

        // Parse amount
        final amount = double.tryParse(amountStr);
        if (amount == null) {
          errors.add('Row ${i + 1}: invalid amount "$amountStr"');
          failed++;
          continue;
        }

        // Parse date
        final date = _parseDate(dateStr);
        if (date == null) {
          errors.add('Row ${i + 1}: invalid date "$dateStr"');
          failed++;
          continue;
        }

        // Parse type
        final type = _parseType(typeStr);
        if (type == null) {
          errors.add('Row ${i + 1}: unknown type "$typeStr"');
          failed++;
          continue;
        }

        // Parse category
        final category = _parseCategory(categoryStr);
        // If category unknown, default to misc
        final resolvedCategory = category ?? TransactionCategory.misc;

        // Duplicate check
        final key =
            '${formatDate(date)}|${title.toLowerCase()}|$amount';
        if (existingKeys.contains(key)) {
          skipped++;
          continue;
        }

        // Use exported ID if valid, otherwise generate new one
        final id =
            (idStr.isNotEmpty && idStr.length > 8) ? idStr : _uuid.v4();

        imported.add(Transaction(
          id: id,
          title: title,
          amount: amount,
          category: resolvedCategory,
          type: type,
          date: date,
          note: (note != null && note.isNotEmpty) ? note : null,
        ));

        // Add to local lookup to prevent duplicates within the same import file
        existingKeys.add(key);
      } catch (e) {
        errors.add('Row ${i + 1}: unexpected error — $e');
        failed++;
      }
    }

    return ImportResult(
      imported: imported.length,
      skipped: skipped,
      failed: failed,
      errors: errors,
      transactions: imported,
    );
  }

  // ── Parsers ─────────────────────────────────────────────────────────────────

  /// Accepts "d MMM yyyy" (export format) and "dd/MM/yyyy" and "yyyy-MM-dd"
  static DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;

    // "15 Mar 2024"
    final monthNames = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };

    final parts = s.trim().split(RegExp(r'[\s/\-]'));
    if (parts.length == 3) {
      // Try "d MMM yyyy"
      final monthNum = monthNames[parts[1].toLowerCase().substring(0, 3)];
      if (monthNum != null) {
        final day = int.tryParse(parts[0]);
        final year = int.tryParse(parts[2]);
        if (day != null && year != null) {
          return DateTime(year, monthNum, day);
        }
      }
      // Try "dd/MM/yyyy" or "yyyy-MM-dd"
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      if (a != null && b != null && c != null) {
        if (a > 31) return DateTime(a, b, c); // yyyy-MM-dd
        return DateTime(c, b, a); // dd/MM/yyyy
      }
    }
    return null;
  }

  static TransactionType? _parseType(String s) {
    switch (s) {
      case 'expense':
        return TransactionType.expense;
      case 'income':
        return TransactionType.income;
      case 'borrowed':
      case 'borrow':
        return TransactionType.borrowed;
      case 'lend':
      case 'lent':
        return TransactionType.lend;
      default:
        return null;
    }
  }

  static TransactionCategory? _parseCategory(String s) {
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
}