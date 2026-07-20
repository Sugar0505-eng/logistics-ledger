import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logistics_ledger/data/database.dart';
import 'package:logistics_ledger/data/repositories.dart';
import 'package:logistics_ledger/state/providers.dart';
import 'package:logistics_ledger/ui/home_page.dart';
import 'package:logistics_ledger/ui/ledgers/bill_edit_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('用户可以编辑账目名称并标记为已完成', (tester) async {
    final database = AppDatabase(
      databaseFactory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    await database.init();
    addTearDown(database.close);
    final account = await AccountPresetRepository(
      database,
    ).add(companyAccount: '招商银行 6214 0000', accountName: '邓杨');
    final secondAccount = await AccountPresetRepository(
      database,
    ).add(companyAccount: '建设银行 6227 0000', accountName: '李明');
    await LedgerRepository(database).createLedger(
      name: '七月批次',
      createdAt: '2026-07-16',
      accountPresetId: account.id!,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await _pumpUntilFound(tester, find.text('七月批次'));

    expect(find.text('七月批次'), findsOneWidget);
    expect(find.text('编辑中'), findsOneWidget);

    await tester.tap(find.byTooltip('账目操作'));
    await tester.pumpAndSettle();
    final editMenuItem = find.ancestor(
      of: find.text('编辑'),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
    );
    await tester.tap(editMenuItem);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '七月已结批次');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('李明 · 建设银行 6227 0000').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('已完成'));
    await tester.tap(find.text('保存'));
    await _pumpUntilFound(tester, find.text('七月已结批次'));
    await tester.pumpAndSettle();

    expect(find.text('七月已结批次'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.textContaining('李明'), findsOneWidget);
    expect(
      (await LedgerRepository(database).allLedgers()).single.accountPresetId,
      secondAccount.id,
    );
  });

  testWidgets('用户可以粘贴文本识别并填入新账单', (tester) async {
    final database = AppDatabase(
      databaseFactory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    await database.init();
    addTearDown(database.close);
    await FeePresetRepository(database).add('吊柜费');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: BillEditPage(ledgerId: 1)),
      ),
    );

    await tester.tap(find.byTooltip('粘贴文本识别'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      '柜号：CSQU3054383\n封条号：SL001\n订舱号：BK001\n吊柜费：200',
    );
    await tester.tap(find.text('识别'));
    await tester.pumpAndSettle();

    expect(find.textContaining('柜号：CSQU3054383'), findsOneWidget);
    expect(find.textContaining('吊柜费：200.00 元'), findsOneWidget);
    await tester.tap(find.text('填入账单'));
    await tester.pumpAndSettle();

    expect(find.text('CSQU3054383'), findsOneWidget);
    expect(find.text('SL001'), findsOneWidget);
    expect(find.text('BK001'), findsOneWidget);
    expect(find.text('吊柜费'), findsOneWidget);
    expect(find.text('200.00'), findsOneWidget);
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('等待控件超时：$finder');
}
