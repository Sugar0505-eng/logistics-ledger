import 'package:flutter_test/flutter_test.dart';
import 'package:logistics_ledger/services/container_number.dart';

void main() {
  group('ISO 6346 校验码', () {
    test('计算已知柜号的校验码', () {
      // CSQU3054383 是 ISO 6346 文档常用示例，校验码为 3
      expect(ContainerNumber.computeCheckDigit('CSQU305438'), 3);
    });

    test('合法柜号通过校验', () {
      expect(ContainerNumber.isValid('CSQU3054383'), isTrue);
    });

    test('错误校验码不通过', () {
      expect(ContainerNumber.isValid('CSQU3054384'), isFalse);
    });

    test('格式不符返回 false', () {
      expect(ContainerNumber.isValid('ABC123'), isFalse);
      expect(ContainerNumber.isValid('CSQU30543830'), isFalse);
    });
  });

  group('从文本提取候选柜号', () {
    test('从混杂文本中提取并去分隔符', () {
      const text = '集装箱 CSQU 305438 3 已到港\n车牌 京A12345';
      final candidates = ContainerNumber.extractCandidates(text);
      expect(candidates, contains('CSQU3054383'));
    });

    test('校验通过的排在前面', () {
      // CSQU3054383 校验通过；ABCU1234567 校验码应为 0，故非法
      expect(ContainerNumber.isValid('ABCU1234567'), isFalse);
      const text = 'ABCU1234567 CSQU3054383';
      final candidates = ContainerNumber.extractCandidates(text);
      expect(candidates.first, 'CSQU3054383');
    });

    test('无合法格式返回空', () {
      expect(ContainerNumber.extractCandidates('no container here'), isEmpty);
    });
  });
}
