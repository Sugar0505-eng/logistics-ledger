import 'package:csv/csv.dart';

import '../models/models.dart';
import 'money.dart';

/// 将单个账目记录的账单导出为 CSV。
///
/// 额外费用动态成列：取该账目记录下所有账单出现过的费用名称并集，
/// 按"首次出现顺序"各成一列；某账单缺少该费用时单元格留空。
class CsvExporter {
  CsvExporter._();

  /// UTF-8 BOM，确保中文在 Excel 中正确显示。
  static const String bom = '\u{FEFF}';

  static const List<String> _fixedHeaders = ['柜号', '日期', '运费', '车牌号'];
  static const String _totalHeader = '合计';

  /// 收集额外费用名称并集，保持首次出现顺序。
  static List<String> feeColumns(List<Bill> bills) {
    final seen = <String>{};
    final columns = <String>[];
    for (final bill in bills) {
      for (final fee in bill.extraFees) {
        if (seen.add(fee.name)) columns.add(fee.name);
      }
    }
    return columns;
  }

  /// 构建二维表（首行为表头）。金额格式化为两位小数字符串。
  static List<List<String>> buildRows(List<Bill> bills) {
    final feeCols = feeColumns(bills);
    final header = <String>[
      ..._fixedHeaders,
      ...feeCols,
      _totalHeader,
    ];

    final rows = <List<String>>[header];
    for (final bill in bills) {
      final feeByName = {for (final f in bill.extraFees) f.name: f.amountCents};
      final row = <String>[
        bill.containerNo,
        bill.date,
        Money.formatCents(bill.freightCents),
        bill.plateNumber,
        for (final name in feeCols)
          feeByName.containsKey(name)
              ? Money.formatCents(feeByName[name]!)
              : '',
        Money.formatCents(bill.subtotalCents),
      ];
      rows.add(row);
    }
    return rows;
  }

  /// 生成完整 CSV 文本（含 BOM 前缀）。
  static String toCsv(List<Bill> bills) {
    final rows = buildRows(bills);
    final body = const ListToCsvConverter().convert(rows);
    return '$bom$body';
  }
}
