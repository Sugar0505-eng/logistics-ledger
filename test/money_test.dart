import 'package:flutter_test/flutter_test.dart';
import 'package:logistics_ledger/services/money.dart';

void main() {
  group('Money.parseToCents', () {
    test('整数元', () => expect(Money.parseToCents('1500'), 150000));
    test('一位小数', () => expect(Money.parseToCents('1500.5'), 150050));
    test('两位小数', () => expect(Money.parseToCents('1500.50'), 150050));
    test('含逗号与空格', () =>
        expect(Money.parseToCents(' 1,500.50 '), 150050));
    test('零', () => expect(Money.parseToCents('0'), 0));
    test('非法输入返回 null', () {
      expect(Money.parseToCents(''), isNull);
      expect(Money.parseToCents('abc'), isNull);
      expect(Money.parseToCents('1.234'), isNull); // 超过两位小数
      expect(Money.parseToCents('1.2.3'), isNull);
    });
  });

  group('Money.formatCents', () {
    test('整百', () => expect(Money.formatCents(150000), '1500.00'));
    test('带分', () => expect(Money.formatCents(150050), '1500.50'));
    test('个位分', () => expect(Money.formatCents(5), '0.05'));
    test('零', () => expect(Money.formatCents(0), '0.00'));
  });

  test('parse 与 format 往返一致', () {
    for (final s in ['0.00', '1500.50', '0.05', '99999.99']) {
      expect(Money.formatCents(Money.parseToCents(s)!), s);
    }
  });
}
