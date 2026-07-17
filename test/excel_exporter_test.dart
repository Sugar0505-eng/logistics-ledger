import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logistics_ledger/models/models.dart';
import 'package:logistics_ledger/services/excel_exporter.dart';

void main() {
  final bills = [
    const Bill(
      containerNo: 'MSKU1234567',
      date: '2026-07-17',
      location: '东涌',
      freightCents: 150000,
      plateNumber: '粤A12345',
      extraFees: [
        ExtraFee(name: '吊柜费', amountCents: 20000),
        ExtraFee(name: '清洁费', amountCents: 5000),
      ],
    ),
    const Bill(
      containerNo: 'TCLU7654321',
      date: '2026-07-18',
      location: '广州',
      freightCents: 180000,
      plateNumber: '粤B67890',
      extraFees: [ExtraFee(name: '滞港费', amountCents: 30000)],
    ),
  ];

  test('费用列为并集，车牌位于最后一列', () {
    expect(ExcelExporter.feeColumns(bills), ['吊柜费', '清洁费', '滞港费']);
    expect(ExcelExporter.headers(bills), [
      '日期',
      '柜号',
      '地点',
      '运费',
      '吊柜费',
      '清洁费',
      '滞港费',
      '合计',
      '车牌',
    ]);
  });

  test('导出包含标题、完整中文日期、地点、合计和账户尾行', () {
    final bytes = ExcelExporter.buildWorkbook(
      ledger: const Ledger(name: '挚盛7月份现金单', createdAt: '2026-07-17'),
      bills: bills,
      accountPreset: const AccountPreset(
        companyAccount: '招商银行 6214 0000',
        accountName: '邓杨',
      ),
    );
    final sheet = Excel.decodeBytes(bytes)['Sheet1'];

    expect(_text(sheet, 0, 0), '挚盛7月份现金单');
    expect(_text(sheet, 0, 1), '日期');
    expect(_text(sheet, 8, 1), '车牌');
    expect(_text(sheet, 0, 2), '2026年7月17日');
    expect(_text(sheet, 2, 2), '东涌');
    expect(_number(sheet, 7, 4), 3850);
    expect(_text(sheet, 0, 5), '公司账户：招商银行 6214 0000');
    expect(_text(sheet, 0, 6), '账户名：邓杨');
  });

  test('历史同名费用按名称累加', () {
    const duplicateFees = Bill(
      containerNo: 'CSQU3054383',
      date: '2026-07-16',
      location: '乐从',
      freightCents: 100000,
      plateNumber: '粤A12345',
      extraFees: [
        ExtraFee(name: '吊柜费', amountCents: 10000),
        ExtraFee(name: '吊柜费', amountCents: 20000),
      ],
    );
    final sheet = Excel.decodeBytes(
      ExcelExporter.buildWorkbook(
        ledger: const Ledger(createdAt: '2026-07-16'),
        bills: const [duplicateFees],
        accountPreset: const AccountPreset(
          companyAccount: '招商银行 6214 0000',
          accountName: '邓杨',
        ),
      ),
    )['Sheet1'];

    expect(_number(sheet, 4, 2), 300);
    expect(_number(sheet, 5, 2), 1300);
  });

  test('导出文件名自动清理非法字符并补充扩展名', () {
    expect(
      ExcelExporter.normalizeFileName(' 挚盛/7月:现金单.xlsx '),
      '挚盛_7月_现金单.xlsx',
    );
    expect(ExcelExporter.normalizeFileName('***'), '___.xlsx');
  });
}

String _text(Sheet sheet, int column, int row) =>
    sheet.cell(_index(column, row)).value.toString();

double _number(Sheet sheet, int column, int row) {
  return switch (sheet.cell(_index(column, row)).value) {
    DoubleCellValue(:final value) => value,
    IntCellValue(:final value) => value.toDouble(),
    final value => throw TestFailure('单元格不是数字：$value'),
  };
}

CellIndex _index(int column, int row) =>
    CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row);
