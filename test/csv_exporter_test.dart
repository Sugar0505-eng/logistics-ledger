import 'package:flutter_test/flutter_test.dart';
import 'package:logistics_ledger/models/models.dart';
import 'package:logistics_ledger/services/csv_exporter.dart';

void main() {
  final bills = [
    const Bill(
      containerNo: 'MSKU1234567',
      date: '2026-06-29',
      freightCents: 150000,
      plateNumber: '京A12345',
      extraFees: [
        ExtraFee(name: '吊柜费', amountCents: 20000),
        ExtraFee(name: '清洁费', amountCents: 5000),
      ],
    ),
    const Bill(
      containerNo: 'TCLU7654321',
      date: '2026-06-29',
      freightCents: 180000,
      plateNumber: '京B67890',
      extraFees: [
        ExtraFee(name: '滞港费', amountCents: 30000),
      ],
    ),
  ];

  test('费用列为并集，保持首次出现顺序', () {
    expect(CsvExporter.feeColumns(bills), ['吊柜费', '清洁费', '滞港费']);
  });

  test('表头含固定列 + 动态费用列 + 合计', () {
    final rows = CsvExporter.buildRows(bills);
    expect(rows.first,
        ['柜号', '日期', '运费', '车牌号', '吊柜费', '清洁费', '滞港费', '合计']);
  });

  test('缺失费用单元格留空，合计正确', () {
    final rows = CsvExporter.buildRows(bills);
    // 第二条账单没有吊柜费/清洁费 -> 留空；有滞港费
    expect(rows[2],
        ['TCLU7654321', '2026-06-29', '1800.00', '京B67890', '', '', '300.00', '2100.00']);
    // 第一条小计 = 1500 + 200 + 50 = 1750
    expect(rows[1].last, '1750.00');
  });

  test('输出含 UTF-8 BOM 前缀', () {
    final csv = CsvExporter.toCsv(bills);
    expect(csv.codeUnitAt(0), 0xFEFF);
  });

  test('空账单列表只有表头', () {
    final rows = CsvExporter.buildRows([]);
    expect(rows.length, 1);
    expect(rows.first, ['柜号', '日期', '运费', '车牌号', '合计']);
  });
}
