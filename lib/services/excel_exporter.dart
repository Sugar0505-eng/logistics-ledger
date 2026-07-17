import 'package:excel/excel.dart';

import '../models/models.dart';
import '../ui/date_utils.dart';

/// 按用户提供的现金单样式导出单个账目记录。
class ExcelExporter {
  ExcelExporter._();

  static const List<String> _leadingHeaders = ['日期', '柜号', '地点', '运费'];
  static const String _totalHeader = '合计';
  static const String _plateHeader = '车牌';

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

  static List<String> headers(List<Bill> bills) => [
    ..._leadingHeaders,
    ...feeColumns(bills),
    _totalHeader,
    _plateHeader,
  ];

  static String normalizeFileName(String input, {String fallback = '账目'}) {
    var name = input.trim().replaceFirst(
      RegExp(r'\.xlsx$', caseSensitive: false),
      '',
    );
    name = name
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'[. ]+$'), '')
        .trim();
    if (name.isEmpty) name = fallback;
    return '$name.xlsx';
  }

  static List<int> buildWorkbook({
    required Ledger ledger,
    required List<Bill> bills,
    required ExportSettings settings,
  }) {
    final workbook = Excel.createExcel();
    final sheet = workbook['Sheet1'];
    final feeCols = feeColumns(bills);
    final sheetHeaders = headers(bills);
    final lastColumn = sheetHeaders.length - 1;
    final totalColumn = lastColumn - 1;
    final thinBorder = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.black,
    );

    CellStyle borderedStyle({
      bool bold = false,
      int? fontSize,
      HorizontalAlign horizontalAlign = HorizontalAlign.Left,
      ExcelColor backgroundColor = ExcelColor.white,
      NumFormat numberFormat = NumFormat.standard_0,
    }) => CellStyle(
      bold: bold,
      fontSize: fontSize,
      fontFamily: '等线',
      horizontalAlign: horizontalAlign,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: backgroundColor,
      numberFormat: numberFormat,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );

    final titleStyle = borderedStyle(
      fontSize: 16,
      horizontalAlign: HorizontalAlign.Center,
    );
    final headerStyle = borderedStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
    final textStyle = borderedStyle();
    final centeredTextStyle = borderedStyle(
      horizontalAlign: HorizontalAlign.Center,
    );
    final amountStyle = borderedStyle(
      horizontalAlign: HorizontalAlign.Right,
      numberFormat: const CustomNumericNumFormat(formatCode: '#,##0.00'),
    );
    final totalFill = ExcelColor.fromHexString('#00FF00');
    final totalLabelStyle = borderedStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Right,
      backgroundColor: totalFill,
    );
    final totalAmountStyle = borderedStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Right,
      backgroundColor: totalFill,
      numberFormat: const CustomNumericNumFormat(formatCode: '#,##0.00'),
    );

    final titleStart = _index(0, 0);
    sheet.merge(
      titleStart,
      _index(lastColumn, 0),
      customValue: TextCellValue(
        ledger.name?.trim().isNotEmpty == true ? ledger.name!.trim() : '账目',
      ),
    );
    sheet.setMergedCellStyle(titleStart, titleStyle);
    sheet.setRowHeight(0, 30);

    for (var column = 0; column < sheetHeaders.length; column++) {
      sheet.updateCell(
        _index(column, 1),
        TextCellValue(sheetHeaders[column]),
        cellStyle: headerStyle,
      );
    }
    sheet.setRowHeight(1, 22);

    for (var billIndex = 0; billIndex < bills.length; billIndex++) {
      final bill = bills[billIndex];
      final row = billIndex + 2;
      final feeByName = <String, int>{};
      for (final fee in bill.extraFees) {
        feeByName.update(
          fee.name,
          (amount) => amount + fee.amountCents,
          ifAbsent: () => fee.amountCents,
        );
      }

      _writeText(sheet, 0, row, formatChineseDate(bill.date), textStyle);
      _writeText(sheet, 1, row, bill.containerNo, centeredTextStyle);
      _writeText(sheet, 2, row, bill.location, textStyle);
      _writeAmount(sheet, 3, row, bill.freightCents, amountStyle);
      for (var feeIndex = 0; feeIndex < feeCols.length; feeIndex++) {
        final amount = feeByName[feeCols[feeIndex]];
        if (amount == null) {
          sheet.updateCell(
            _index(4 + feeIndex, row),
            null,
            cellStyle: amountStyle,
          );
        } else {
          _writeAmount(sheet, 4 + feeIndex, row, amount, amountStyle);
        }
      }
      _writeAmount(sheet, totalColumn, row, bill.subtotalCents, amountStyle);
      _writeText(sheet, lastColumn, row, bill.plateNumber, centeredTextStyle);
      sheet.setRowHeight(row, 20);
    }

    final totalRow = bills.length + 2;
    final totalStart = _index(0, totalRow);
    sheet.merge(
      totalStart,
      _index(totalColumn - 1, totalRow),
      customValue: TextCellValue('合计费用：'),
    );
    sheet.setMergedCellStyle(totalStart, totalLabelStyle);
    _writeAmount(
      sheet,
      totalColumn,
      totalRow,
      bills.fold<int>(0, (sum, bill) => sum + bill.subtotalCents),
      totalAmountStyle,
    );
    sheet.updateCell(
      _index(lastColumn, totalRow),
      null,
      cellStyle: totalLabelStyle,
    );
    sheet.setRowHeight(totalRow, 22);

    _writeMergedFooter(
      sheet,
      totalRow + 1,
      lastColumn,
      '公司账户：${settings.companyAccount}',
      textStyle,
    );
    _writeMergedFooter(
      sheet,
      totalRow + 2,
      lastColumn,
      '账户名：${settings.accountName}',
      textStyle,
    );

    final widths = <double>[15, 18, 14, 11];
    for (var i = 0; i < feeCols.length; i++) {
      widths.add(11);
    }
    widths.addAll([12, 14]);
    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }

    final bytes = workbook.save();
    if (bytes == null) throw StateError('Excel 文件生成失败');
    return bytes;
  }

  static CellIndex _index(int column, int row) =>
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row);

  static void _writeText(
    Sheet sheet,
    int column,
    int row,
    String value,
    CellStyle style,
  ) {
    sheet.updateCell(
      _index(column, row),
      TextCellValue(value),
      cellStyle: style,
    );
  }

  static void _writeAmount(
    Sheet sheet,
    int column,
    int row,
    int cents,
    CellStyle style,
  ) {
    sheet.updateCell(
      _index(column, row),
      DoubleCellValue(cents / 100),
      cellStyle: style,
    );
  }

  static void _writeMergedFooter(
    Sheet sheet,
    int row,
    int lastColumn,
    String value,
    CellStyle style,
  ) {
    final start = _index(0, row);
    sheet.merge(
      start,
      _index(lastColumn, row),
      customValue: TextCellValue(value),
    );
    sheet.setMergedCellStyle(start, style);
    sheet.setRowHeight(row, 22);
  }
}
