import 'package:flutter_test/flutter_test.dart';
import 'package:logistics_ledger/data/database.dart';
import 'package:logistics_ledger/data/repositories.dart';
import 'package:logistics_ledger/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late PlateRepository plates;
  late FeePresetRepository presets;
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
    );

    await ledgers.updateLedger(
      Ledger(
        id: ledger.id,
        name: '七月已结批次',
        createdAt: ledger.createdAt,
        status: LedgerStatus.completed,
      ),
    );

    final updated = (await ledgers.allLedgers()).single;
    expect(updated.name, '七月已结批次');
    expect(updated.status, LedgerStatus.completed);
  });

  test('账单和费用在事务中保存并可完整读取', () async {
    final ledger = await ledgers.createLedger(createdAt: '2026-07-16');
    final billId = await ledgers.saveBill(
      Bill(
        ledgerId: ledger.id,
        containerNo: 'CSQU3054383',
        date: '2026-07-16',
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
    expect(bill.subtotalCents, 175000);
    expect(await ledgers.billCount(ledger.id!), 1);
  });

  test('非法柜号和重复费用名在写入前被拒绝', () async {
    final ledger = await ledgers.createLedger(createdAt: '2026-07-16');

    Future<int> save(String containerNo, List<ExtraFee> fees) {
      return ledgers.saveBill(
        Bill(
          ledgerId: ledger.id,
          containerNo: containerNo,
          date: '2026-07-16',
          freightCents: 10000,
          plateNumber: '京A12345',
          extraFees: fees,
        ),
      );
    }

    expect(() => save('ABC123', const []), throwsA(isA<ValidationException>()));
    expect(
      () => save('CSQU3054383', const [
        ExtraFee(name: '吊柜费', amountCents: 1000),
        ExtraFee(name: '吊柜费', amountCents: 2000),
      ]),
      throwsA(isA<ValidationException>()),
    );
    expect(await ledgers.billCount(ledger.id!), 0);
  });

  test('删除账目会级联删除账单与额外费用', () async {
    final ledger = await ledgers.createLedger(createdAt: '2026-07-16');
    await ledgers.saveBill(
      Bill(
        ledgerId: ledger.id,
        containerNo: 'CSQU3054383',
        date: '2026-07-16',
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
