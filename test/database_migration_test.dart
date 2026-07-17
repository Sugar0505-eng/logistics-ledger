import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logistics_ledger/data/database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('版本 1 升级后保留账单并新增地点与账户预设', () async {
    final tempDir = await Directory.systemTemp.createTemp('ledger_migration_');
    final databasePath = p.join(tempDir.path, 'ledger.db');
    try {
      final oldDb = await databaseFactoryFfiNoIsolate.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
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
                plate_number TEXT NOT NULL
              )
            ''');
          },
        ),
      );
      await oldDb.insert('ledgers', {
        'id': 1,
        'name': '历史账目',
        'created_at': '2026-07-01',
        'status': 'editing',
      });
      await oldDb.insert('bills', {
        'id': 1,
        'ledger_id': 1,
        'container_no': 'OLD001',
        'date': '2026-07-01',
        'freight_cents': 10000,
        'plate_number': '粤A12345',
      });
      await oldDb.close();

      final upgraded = AppDatabase(
        databaseFactory: databaseFactoryFfiNoIsolate,
        databasePath: databasePath,
      );
      await upgraded.init();
      final bills = await upgraded.db.query('bills');
      final settings = await upgraded.db.query('export_settings');

      expect(bills.single['container_no'], 'OLD001');
      expect(bills.single['location'], '');
      expect(settings.single['company_account'], '');
      expect(settings.single['account_name'], '');
      await upgraded.close();
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
