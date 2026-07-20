import 'package:flutter_test/flutter_test.dart';
import 'package:logistics_ledger/services/pasted_bill_parser.dart';

void main() {
  test('从多行文本提取账单字段和所有已存费用项目', () {
    const text = '''
日期：2026年7月20日
柜号：CSQU 305438 3
封条号：SL-8899
订舱号：BK20260720
地点：广州南沙
车牌：粤A12345
运费：1,500.50元
吊柜费：200元
清洁费 50.5
未保存费用：999元
''';

    final result = PastedBillParser.parse(
      text,
      feePresetNames: const ['吊柜费', '清洁费'],
    );

    expect(result.containerNumber, 'CSQU3054383');
    expect(result.sealNumber, 'SL-8899');
    expect(result.bookingNumber, 'BK20260720');
    expect(result.date, '2026-07-20');
    expect(result.location, '广州南沙');
    expect(result.plateNumber, '粤A12345');
    expect(result.freightCents, 150050);
    expect(result.feeAmountsCents, {'吊柜费': 20000, '清洁费': 5050});
  });

  test('优先采用通过 ISO 6346 校验的柜号', () {
    final result = PastedBillParser.parse(
      '柜号 ABCU1234567，实际柜号 CSQU3054383',
      feePresetNames: const [],
    );

    expect(result.containerNumber, 'CSQU3054383');
  });

  test('支持从单行标签文本中截取地点', () {
    final result = PastedBillParser.parse(
      '地点：广州南沙 车牌：粤A12345 运费：800',
      feePresetNames: const [],
    );

    expect(result.location, '广州南沙');
    expect(result.plateNumber, '粤A12345');
    expect(result.freightCents, 80000);
  });

  test('支持英文标签并忽略没有金额的费用预设', () {
    final result = PastedBillParser.parse(
      'Container No: TEST-001\nSeal No: SEAL9\nBooking No: BOOK8\n吊柜费待确认',
      feePresetNames: const ['吊柜费'],
    );

    expect(result.containerNumber, 'TEST-001');
    expect(result.sealNumber, 'SEAL9');
    expect(result.bookingNumber, 'BOOK8');
    expect(result.feeAmountsCents, isEmpty);
  });

  test('无可识别字段时返回空结果', () {
    final result = PastedBillParser.parse(
      '这是一段普通备注',
      feePresetNames: const ['吊柜费'],
    );

    expect(result.isEmpty, isTrue);
  });
}
