import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;

/// 本地 SQLite 数据库封装。负责建表、外键、级联删除。
class AppDatabase {
  AppDatabase({
    this.fileName = 'logistics_ledger.db',
    this.databaseFactory,
    this.databasePath,
  });

  final String fileName;
  final sqflite.DatabaseFactory? databaseFactory;
  final String? databasePath;
  sqflite.Database? _db;

  sqflite.Database get db {
    final d = _db;
    if (d == null) {
      throw StateError('AppDatabase 未初始化，请先调用 init()');
    }
    return d;
  }

  Future<void> init() async {
    final factory = databaseFactory ?? sqflite.databaseFactory;
    final path =
        databasePath ?? p.join(await factory.getDatabasesPath(), fileName);
    _db = await factory.openDatabase(
      path,
      options: sqflite.OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
      ),
    );
  }

  Future<void> _onCreate(sqflite.Database db, int version) async {
    await db.execute('''
      CREATE TABLE plates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE fee_presets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE ledgers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        container_no TEXT NOT NULL,
        date TEXT NOT NULL,
        freight_cents INTEGER NOT NULL,
        plate_number TEXT NOT NULL,
        FOREIGN KEY (ledger_id) REFERENCES ledgers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE extra_fees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        FOREIGN KEY (bill_id) REFERENCES bills (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_bills_ledger ON bills (ledger_id)');
    await db.execute('CREATE INDEX idx_fees_bill ON extra_fees (bill_id)');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
