import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logistics_ledger/data/database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('版本 1 升级后保留账单并新增地点与账户关联', () async {
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
      final ledgers = await upgraded.db.query('ledgers');
      final presets = await upgraded.db.query('account_presets');

      expect(bills.single['container_no'], 'OLD001');
      expect(bills.single['location'], '');
      expect(bills.single['seal_number'], '');
      expect(bills.single['booking_number'], '');
      expect(ledgers.single['account_preset_id'], isNull);
      expect(presets, isEmpty);
      await upgraded.close();
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('版本 2 的单条账户设置迁移为预设并关联已有账目', () async {
    final tempDir = await Directory.systemTemp.createTemp('account_migration_');
    final databasePath = p.join(tempDir.path, 'ledger.db');
    try {
      final oldDb = await databaseFactoryFfiNoIsolate.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 2,
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
                location TEXT NOT NULL DEFAULT '',
                freight_cents INTEGER NOT NULL,
                plate_number TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE export_settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                company_account TEXT NOT NULL DEFAULT '',
                account_name TEXT NOT NULL DEFAULT ''
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
      await oldDb.insert('export_settings', {
        'id': 1,
        'company_account': '招商银行 6214 0000',
        'account_name': '邓杨',
      });
      await oldDb.close();

      final upgraded = AppDatabase(
        databaseFactory: databaseFactoryFfiNoIsolate,
        databasePath: databasePath,
      );
      await upgraded.init();
      final preset = (await upgraded.db.query('account_presets')).single;
      final ledger = (await upgraded.db.query('ledgers')).single;
      final oldTable = await upgraded.db.query(
        'sqlite_master',
        where: "type = 'table' AND name = 'export_settings'",
      );

      expect(preset['company_account'], '招商银行 6214 0000');
      expect(preset['account_name'], '邓杨');
      expect(ledger['account_preset_id'], preset['id']);
      expect(oldTable, isEmpty);
      await upgraded.close();
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
