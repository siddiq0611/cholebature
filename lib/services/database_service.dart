import 'package:chole_bature/models/custom_category_model.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/future_transaction_model.dart';
import '../models/budget_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'cholebature_v4.db');

    return openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        amount REAL NOT NULL,
        category INTEGER NOT NULL,
        type INTEGER NOT NULL,
        date INTEGER NOT NULL,
        note TEXT,
        custom_category_id TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_tx_type ON transactions(type)');
 
    await db.execute('''
      CREATE TABLE future_transactions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        amount REAL NOT NULL,
        category INTEGER NOT NULL,
        type INTEGER NOT NULL,
        note TEXT,
        recurrence_type INTEGER NOT NULL DEFAULT 0,
        recurrence_days TEXT DEFAULT '[]',
        next_due INTEGER NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        reminder_offsets TEXT DEFAULT '[0]',
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_ft_due ON future_transactions(next_due)');
 
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        period INTEGER NOT NULL UNIQUE,
        amount REAL NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');
 
    // NEW in v4
    await db.execute('''
      CREATE TABLE custom_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        icon_code_point INTEGER NOT NULL,
        icon_font_family TEXT NOT NULL DEFAULT 'MaterialIcons',
        deleted INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
        category_type INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE transactions ADD COLUMN title TEXT NOT NULL DEFAULT ''");
    }
    if (oldVersion < 3) {
      // Add lend category support — no schema change needed (enum index handles it)
      // Add future_transactions table if upgrading from v2
      final tables = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      if (!tableNames.contains('future_transactions')) {
        await db.execute('''
          CREATE TABLE future_transactions (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL DEFAULT '',
            amount REAL NOT NULL,
            category INTEGER NOT NULL,
            type INTEGER NOT NULL,
            note TEXT,
            recurrence_type INTEGER NOT NULL DEFAULT 0,
            recurrence_days TEXT DEFAULT '[]',
            next_due INTEGER NOT NULL,
            status INTEGER NOT NULL DEFAULT 0,
            reminder_offsets TEXT DEFAULT '[0]',
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_ft_due ON future_transactions(next_due)');
      }
      if (!tableNames.contains('budgets')) {
        await db.execute('''
          CREATE TABLE budgets (
            id TEXT PRIMARY KEY,
            period INTEGER NOT NULL UNIQUE,
            amount REAL NOT NULL,
            active INTEGER NOT NULL DEFAULT 1
          )
        ''');
      }
    }
    if (oldVersion < 4) {
      // Add custom_category_id column to transactions
      try {
        await db.execute(
            'ALTER TABLE transactions ADD COLUMN custom_category_id TEXT');
      } catch (_) {}
 
      // Create custom_categories table if it doesn't exist yet
      final tables = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((t) => t['name'] as String).toSet();
      if (!tableNames.contains('custom_categories')) {
        await db.execute('''
          CREATE TABLE custom_categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color_value INTEGER NOT NULL,
            icon_code_point INTEGER NOT NULL,
            icon_font_family TEXT NOT NULL DEFAULT 'MaterialIcons',
            deleted INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');
      }
    }
    if (oldVersion < 5) {
     try {
       await db.execute(
            'ALTER TABLE custom_categories ADD COLUMN category_type INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
    }
  }

  // ─── Transactions ──────────────────────────────────────────────────────────

  Future<void> insertTransaction(Transaction tx) async {
    final db = await database;
    await db.insert('transactions', tx.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTransaction(Transaction tx) async {
    final db = await database;
    await db.update('transactions', tx.toMap(),
        where: 'id = ?', whereArgs: [tx.id]);
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Transaction>> getAllTransactions() async {
    final db = await database;
    final maps = await db.query('transactions', orderBy: 'date DESC');
    return maps.map(Transaction.fromMap).toList();
  }

  Future<List<Transaction>> getTransactionsByDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'date DESC',
    );
    return maps.map(Transaction.fromMap).toList();
  }

  Future<List<Transaction>> getTransactionsByMonth(
      int year, int month) async {
    return getTransactionsByDateRange(
      DateTime(year, month, 1),
      DateTime(year, month + 1, 1),
    );
  }

  Future<List<Transaction>> getTransactionsByYear(int year) async {
    return getTransactionsByDateRange(
      DateTime(year, 1, 1),
      DateTime(year + 1, 1, 1),
    );
  }

  Future<List<Transaction>> getTransactionsByWeek(
      DateTime weekStart) async {
    return getTransactionsByDateRange(
      weekStart,
      weekStart.add(const Duration(days: 7)),
    );
  }

  // ─── Future Transactions ───────────────────────────────────────────────────

  Future<void> insertFutureTransaction(FutureTransaction ft) async {
    final db = await database;
    await db.insert('future_transactions', ft.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateFutureTransaction(FutureTransaction ft) async {
    final db = await database;
    await db.update('future_transactions', ft.toMap(),
        where: 'id = ?', whereArgs: [ft.id]);
  }

  Future<void> deleteFutureTransaction(String id) async {
    final db = await database;
    await db
        .delete('future_transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FutureTransaction>> getAllFutureTransactions() async {
    final db = await database;
    final maps = await db.query('future_transactions',
        orderBy: 'next_due ASC');
    return maps.map(FutureTransaction.fromMap).toList();
  }

  // ─── Budgets ───────────────────────────────────────────────────────────────

  Future<void> upsertBudget(Budget budget) async {
    final db = await database;
    await db.insert('budgets', budget.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteBudget(String id) async {
    final db = await database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Budget>> getAllBudgets() async {
    final db = await database;
    final maps =
        await db.query('budgets', where: 'active = 1');
    return maps.map(Budget.fromMap).toList();
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  Future<void> insertCustomCategory(CustomCategory cat) async {
    final db = await database;
    await db.insert('custom_categories', cat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
 
  Future<void> updateCustomCategory(CustomCategory cat) async {
    final db = await database;
    await db.update('custom_categories', cat.toMap(),
        where: 'id = ?', whereArgs: [cat.id]);
  }
 
  /// Soft-delete: sets deleted = 1. Transactions still resolve the category.
  Future<void> softDeleteCustomCategory(String id) async {
    final db = await database;
    await db.update('custom_categories', {'deleted': 1},
        where: 'id = ?', whereArgs: [id]);
  }
 
  /// Hard-delete: permanently removes the row.
  Future<void> hardDeleteCustomCategory(String id) async {
    final db = await database;
    await db.delete('custom_categories', where: 'id = ?', whereArgs: [id]);
  }
 
  /// Returns ALL custom categories including soft-deleted ones,
  /// so transactions can always resolve their category for display.
  Future<List<CustomCategory>> getAllCustomCategories() async {
    final db = await database;
    final maps = await db.query('custom_categories',
        orderBy: 'deleted ASC, created_at ASC');
    return maps.map(CustomCategory.fromMap).toList();
  }
}