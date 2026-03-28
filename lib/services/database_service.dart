import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/transaction_model.dart';

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
    final path = join(dbPath, 'expense_tracker_v2.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL DEFAULT '',
            amount REAL NOT NULL,
            category INTEGER NOT NULL,
            type INTEGER NOT NULL,
            date INTEGER NOT NULL,
            note TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_date ON transactions(date)');
        await db.execute('CREATE INDEX idx_type ON transactions(type)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add title column to existing databases
          await db.execute(
              "ALTER TABLE transactions ADD COLUMN title TEXT NOT NULL DEFAULT ''");
        }
      },
    );
  }

  Future<void> insertTransaction(Transaction tx) async {
    final db = await database;
    await db.insert(
      'transactions',
      tx.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTransaction(Transaction tx) async {
    final db = await database;
    await db.update(
      'transactions',
      tx.toMap(),
      where: 'id = ?',
      whereArgs: [tx.id],
    );
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Transaction>> getAllTransactions() async {
    final db = await database;
    final maps = await db.query('transactions', orderBy: 'date DESC');
    return maps.map((m) => Transaction.fromMap(m)).toList();
  }

  Future<List<Transaction>> getTransactionsByMonth(
      int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return maps.map((m) => Transaction.fromMap(m)).toList();
  }

  Future<List<Transaction>> getTransactionsByYear(int year) async {
    final db = await database;
    final start = DateTime(year, 1, 1).millisecondsSinceEpoch;
    final end = DateTime(year + 1, 1, 1).millisecondsSinceEpoch;
    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return maps.map((m) => Transaction.fromMap(m)).toList();
  }

  Future<List<Transaction>> getTransactionsByWeek(
      DateTime weekStart) async {
    final db = await database;
    final start = weekStart.millisecondsSinceEpoch;
    final end =
        weekStart.add(const Duration(days: 7)).millisecondsSinceEpoch;
    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return maps.map((m) => Transaction.fromMap(m)).toList();
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}