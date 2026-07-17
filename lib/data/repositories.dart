import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'database.dart';

/// 车牌库仓储。
class PlateRepository {
  PlateRepository(this._app);
  final AppDatabase _app;

  Future<List<Plate>> all() async {
    final rows = await _app.db.query('plates', orderBy: 'number ASC');
    return rows.map(Plate.fromMap).toList();
  }

  Future<bool> exists(String number) async {
    final rows = await _app.db.query(
      'plates',
      where: 'number = ?',
      whereArgs: [number],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// 新增车牌。重复时抛出 [DuplicateException]。
  Future<Plate> add(String number) async {
    final trimmed = number.trim();
    if (await exists(trimmed)) {
      throw DuplicateException('车牌号已存在：$trimmed');
    }
    final id = await _app.db.insert('plates', {'number': trimmed});
    return Plate(id: id, number: trimmed);
  }

  /// 录入时"取或建"：已存在则返回既有车牌，否则新建。
  Future<Plate> getOrCreate(String number) async {
    final trimmed = number.trim();
    final rows = await _app.db.query(
      'plates',
      where: 'number = ?',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (rows.isNotEmpty) return Plate.fromMap(rows.first);
    final id = await _app.db.insert('plates', {'number': trimmed});
    return Plate(id: id, number: trimmed);
  }

  Future<void> update(int id, String number) async {
    final trimmed = number.trim();
    final dup = await _app.db.query(
      'plates',
      where: 'number = ? AND id != ?',
      whereArgs: [trimmed, id],
      limit: 1,
    );
    if (dup.isNotEmpty) throw DuplicateException('车牌号已存在：$trimmed');
    await _app.db.update(
      'plates',
      {'number': trimmed},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    await _app.db.delete('plates', where: 'id = ?', whereArgs: [id]);
  }
}

/// 费用预设仓储。
class FeePresetRepository {
  FeePresetRepository(this._app);
  final AppDatabase _app;

  Future<List<FeePreset>> all() async {
    final rows = await _app.db.query('fee_presets', orderBy: 'name ASC');
    return rows.map(FeePreset.fromMap).toList();
  }

  Future<FeePreset> add(String name) async {
    final trimmed = name.trim();
    final dup = await _app.db.query(
      'fee_presets',
      where: 'name = ?',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (dup.isNotEmpty) throw DuplicateException('费用预设已存在：$trimmed');
    final id = await _app.db.insert('fee_presets', {'name': trimmed});
    return FeePreset(id: id, name: trimmed);
  }

  Future<void> update(int id, String name) async {
    final trimmed = name.trim();
    final dup = await _app.db.query(
      'fee_presets',
      where: 'name = ? AND id != ?',
      whereArgs: [trimmed, id],
      limit: 1,
    );
    if (dup.isNotEmpty) throw DuplicateException('费用预设已存在：$trimmed');
    await _app.db.update(
      'fee_presets',
      {'name': trimmed},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    await _app.db.delete('fee_presets', where: 'id = ?', whereArgs: [id]);
  }
}

/// 可供账目选择的公司账户预设。
class AccountPresetRepository {
  AccountPresetRepository(this._app);
  final AppDatabase _app;

  Future<List<AccountPreset>> all() async {
    final rows = await _app.db.query('account_presets', orderBy: 'id ASC');
    return rows.map(AccountPreset.fromMap).toList();
  }

  Future<AccountPreset?> byId(int? id) async {
    if (id == null) return null;
    final rows = await _app.db.query(
      'account_presets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : AccountPreset.fromMap(rows.first);
  }

  Future<AccountPreset> add({
    required String companyAccount,
    required String accountName,
  }) async {
    final values = _validatedValues(companyAccount, accountName);
    await _ensureUnique(values);
    final id = await _app.db.insert('account_presets', values);
    return AccountPreset(
      id: id,
      companyAccount: values['company_account']!,
      accountName: values['account_name']!,
    );
  }

  Future<void> update(
    int id, {
    required String companyAccount,
    required String accountName,
  }) async {
    final values = _validatedValues(companyAccount, accountName);
    await _ensureUnique(values, exceptId: id);
    await _app.db.update(
      'account_presets',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    final used = await _app.db.query(
      'ledgers',
      columns: ['id'],
      where: 'account_preset_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (used.isNotEmpty) {
      throw ValidationException('该账户预设已被账目使用，不能删除');
    }
    await _app.db.delete('account_presets', where: 'id = ?', whereArgs: [id]);
  }

  Map<String, String> _validatedValues(
    String companyAccount,
    String accountName,
  ) {
    final account = companyAccount.trim();
    final name = accountName.trim();
    if (account.isEmpty) throw ValidationException('公司账户不能为空');
    if (name.isEmpty) throw ValidationException('账户名不能为空');
    return {'company_account': account, 'account_name': name};
  }

  Future<void> _ensureUnique(
    Map<String, String> values, {
    int? exceptId,
  }) async {
    final rows = await _app.db.query(
      'account_presets',
      columns: ['id'],
      where:
          'company_account = ? AND account_name = ?${exceptId == null ? '' : ' AND id != ?'}',
      whereArgs: [
        values['company_account'],
        values['account_name'],
        if (exceptId != null) exceptId,
      ],
      limit: 1,
    );
    if (rows.isNotEmpty) throw DuplicateException('相同的账户预设已存在');
  }
}

/// 账目记录 / 账单 / 额外费用仓储。
class LedgerRepository {
  LedgerRepository(this._app);
  final AppDatabase _app;

  Future<List<Ledger>> allLedgers() async {
    final rows = await _app.db.query(
      'ledgers',
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(Ledger.fromMap).toList();
  }

  Future<Ledger> ledgerById(int id) async {
    final rows = await _app.db.query(
      'ledgers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('账目记录不存在：$id');
    return Ledger.fromMap(rows.first);
  }

  Future<int> billCount(int ledgerId) async {
    final result = await _app.db.rawQuery(
      'SELECT COUNT(*) AS c FROM bills WHERE ledger_id = ?',
      [ledgerId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Ledger> createLedger({
    String? name,
    required String createdAt,
    required int accountPresetId,
  }) async {
    await _requireAccountPreset(accountPresetId);
    final ledger = Ledger(
      name: name,
      createdAt: createdAt,
      status: LedgerStatus.editing,
      accountPresetId: accountPresetId,
    );
    final id = await _app.db.insert('ledgers', ledger.toMap()..remove('id'));
    return Ledger(
      id: id,
      name: name,
      createdAt: createdAt,
      status: LedgerStatus.editing,
      accountPresetId: accountPresetId,
    );
  }

  Future<void> updateLedger(Ledger ledger) async {
    if (ledger.id == null) throw ValidationException('账目记录缺少 id');
    await _requireAccountPreset(ledger.accountPresetId);
    final values = ledger.toMap()..remove('id');
    await _app.db.update(
      'ledgers',
      values,
      where: 'id = ?',
      whereArgs: [ledger.id],
    );
  }

  Future<void> deleteLedger(int id) async {
    // 外键 ON DELETE CASCADE 会级联删除 bills 及其 extra_fees
    await _app.db.delete('ledgers', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _requireAccountPreset(int? id) async {
    if (id == null) throw ValidationException('请选择账户预设');
    final rows = await _app.db.query(
      'account_presets',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw ValidationException('所选账户预设不存在');
  }

  /// 读取某账目记录下的全部账单（含各自额外费用）。
  Future<List<Bill>> billsOf(int ledgerId) async {
    final billRows = await _app.db.query(
      'bills',
      where: 'ledger_id = ?',
      whereArgs: [ledgerId],
      orderBy: 'id ASC',
    );
    final bills = <Bill>[];
    for (final row in billRows) {
      final billId = row['id'] as int;
      final feeRows = await _app.db.query(
        'extra_fees',
        where: 'bill_id = ?',
        whereArgs: [billId],
        orderBy: 'id ASC',
      );
      final fees = feeRows.map(ExtraFee.fromMap).toList();
      bills.add(Bill.fromMap(row, extraFees: fees));
    }
    return bills;
  }

  /// 新增或更新账单（连同其额外费用）。返回账单 id。
  Future<int> saveBill(Bill bill) async {
    _validateBill(bill);
    return _app.db.transaction((txn) async {
      int billId;
      if (bill.id == null) {
        billId = await txn.insert('bills', bill.toMap()..remove('id'));
      } else {
        billId = bill.id!;
        await txn.update(
          'bills',
          bill.toMap(),
          where: 'id = ?',
          whereArgs: [billId],
        );
        await txn.delete(
          'extra_fees',
          where: 'bill_id = ?',
          whereArgs: [billId],
        );
      }
      for (final fee in bill.extraFees) {
        await txn.insert('extra_fees', {
          'bill_id': billId,
          'name': fee.name.trim(),
          'amount_cents': fee.amountCents,
        });
      }
      return billId;
    });
  }

  Future<void> deleteBill(int id) async {
    await _app.db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }

  void _validateBill(Bill bill) {
    if (bill.ledgerId == null) {
      throw ValidationException('账单必须关联账目记录');
    }
    if (bill.date.trim().isEmpty) throw ValidationException('日期不能为空');
    if (bill.location.trim().isEmpty) {
      throw ValidationException('地点不能为空');
    }
    if (bill.plateNumber.trim().isEmpty) {
      throw ValidationException('车牌号不能为空');
    }
    if (bill.freightCents < 0) throw ValidationException('运费不能为负数');

    final names = <String>{};
    for (final fee in bill.extraFees) {
      final name = fee.name.trim();
      if (name.isEmpty) throw ValidationException('额外费用名称不能为空');
      if (fee.amountCents < 0) {
        throw ValidationException('额外费用金额不能为负数');
      }
      if (!names.add(name.toLowerCase())) {
        throw ValidationException('额外费用名称不能重复：$name');
      }
    }
  }
}

/// 唯一性冲突异常。
class DuplicateException implements Exception {
  DuplicateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 领域数据不满足保存约束。
class ValidationException implements Exception {
  ValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}
