import 'package:flutter_test/flutter_test.dart';
import 'package:logistics_ledger/data/database.dart';
import 'package:logistics_ledger/data/repositories.dart';
import 'package:logistics_ledger/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late PlateRepository plates;
  late FeePresetRepository presets;
  late AccountPresetRepository accountPresets;
  late AccountPreset defaultAccount;
  late LedgerRepository ledgers;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = AppDatabase(
      databaseFactory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    await database.init();
    plates = PlateRepository(database);
    presets = FeePresetRepository(database);
    accountPresets = AccountPresetRepository(database);
    defaultAccount = await accountPresets.add(
      companyAccount: '招商银行 6214 0000',
      accountName: '邓杨',
    );
    ledgers = LedgerRepository(database);
  });

  tearDown(() => database.close());

  test('车牌和费用预设执行唯一性校验', () async {
    await plates.add('京A12345');
    await presets.add('吊柜费');

    expect(() => plates.add('京A12345'), throwsA(isA<DuplicateException>()));
    expect(() => presets.add('吊柜费'), throwsA(isA<DuplicateException>()));
  });

  test('账目名称与状态可以更新', () async {
    final ledger = await ledgers.createLedger(
      name: '七月批次',
      createdAt: '2026-07-16',
      accountPresetId: defaultAccount.id!,
    );

    await ledgers.updateLedger(
      Ledger(
        id: ledger.id,
        name: '七月已结批次',
        createdAt: ledger.createdAt,
        status: LedgerStatus.completed,
        accountPresetId: defaultAccount.id,
      ),
    );

    final updated = (await ledgers.allLedgers()).single;
    expect(updated.name, '七月已结批次');
    expect(updated.status, LedgerStatus.completed);
    expect(updated.accountPresetId, defaultAccount.id);
  });

  test('账户预设支持多条、编辑和删除保护', () async {
    final second = await accountPresets.add(
      companyAccount: '建设银行 6227 0000',
      accountName: '李明',
    );
    expect(await accountPresets.all(), hasLength(2));

    await accountPresets.update(
      second.id!,
      companyAccount: '建设银行 6227 1111',
      accountName: '李明',
    );
    expect(
      (await accountPresets.byId(second.id))!.companyAccount,
      '建设银行 6227 1111',
    );

    final ledger = await ledgers.createLedger(
      createdAt: '2026-07-16',
      accountPresetId: defaultAccount.id!,
    );
    expect(ledger.accountPresetId, defaultAccount.id);
    expect(
      () => accountPresets.delete(defaultAccount.id!),
      throwsA(isA<ValidationException>()),
    );
    await accountPresets.delete(second.id!);
    expect(await accountPresets.all(), hasLength(1));
  });

  test('账单和费用在事务中保存并可完整读取', () async {
    final ledger = await ledgers.createLedger(
      createdAt: '2026-07-16',
      accountPresetId: defaultAccount.id!,
    );
    final billId = await ledgers.saveBill(
      Bill(
        ledgerId: ledger.id,
        containerNo: 'CSQU3054383',
        date: '2026-07-16',
        location: '广州',
        freightCents: 150000,
        plateNumber: '京A12345',
        extraFees: const [
          ExtraFee(name: '吊柜费', amountCents: 20000),
          ExtraFee(name: '清洁费', amountCents: 5000),
        ],
      ),
    );

    final bill = (await ledgers.billsOf(ledger.id!)).single;
    expect(bill.id, billId);
    expect(bill.extraFees, hasLength(2));
    expect(bill.location, '广州');
    expect(bill.subtotalCents, 175000);
    expect(await ledgers.billCount(ledger.id!), 1);
  });

  test('柜号不校验，重复费用名仍在写入前被拒绝', () async {
    final ledger = await ledgers.createLedger(
      createdAt: '2026-07-16',
      accountPresetId: defaultAccount.id!,
    );

    Future<int> save(String containerNo, List<ExtraFee> fees) {
      return ledgers.saveBill(
        Bill(
          ledgerId: ledger.id,
          containerNo: containerNo,
          date: '2026-07-16',
          location: '乐从',
          freightCents: 10000,
          plateNumber: '京A12345',
          extraFees: fees,
        ),
      );
    }

    await save('ABC123', const []);
    expect(
      () => save('CSQU3054383', const [
        ExtraFee(name: '吊柜费', amountCents: 1000),
        ExtraFee(name: '吊柜费', amountCents: 2000),
      ]),
      throwsA(isA<ValidationException>()),
    );
    expect(await ledgers.billCount(ledger.id!), 1);
  });

  test('删除账目会级联删除账单与额外费用', () async {
    final ledger = await ledgers.createLedger(
      createdAt: '2026-07-16',
      accountPresetId: defaultAccount.id!,
    );
    await ledgers.saveBill(
      Bill(
        ledgerId: ledger.id,
        containerNo: 'CSQU3054383',
        date: '2026-07-16',
        location: '东涌',
        freightCents: 10000,
        plateNumber: '京A12345',
        extraFees: const [ExtraFee(name: '吊柜费', amountCents: 1000)],
      ),
    );

    await ledgers.deleteLedger(ledger.id!);

    final billCount = await database.db.rawQuery(
      'SELECT COUNT(*) c FROM bills',
    );
    final feeCount = await database.db.rawQuery(
      'SELECT COUNT(*) c FROM extra_fees',
    );
    expect(billCount.single['c'], 0);
    expect(feeCount.single['c'], 0);
  });
}
