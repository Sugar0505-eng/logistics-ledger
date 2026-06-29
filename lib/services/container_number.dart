/// 集装箱柜号（ISO 6346）解析与校验。
///
/// 标准格式：4 个字母（3 位所有者代码 + 1 位类别标识 U/J/Z） + 6 位序列号 + 1 位校验码。
/// 例如：MSKU1234567，其中末位 7 为校验码，可由前 10 位数学验算。
library;

class ContainerNumber {
  ContainerNumber._();

  /// ISO 6346 字母数值映射。跳过 11 的倍数（11、22、33），因此 K=21 之后为 L=23。
  static const Map<String, int> _letterValues = {
    'A': 10, 'B': 12, 'C': 13, 'D': 14, 'E': 15, 'F': 16, 'G': 17, 'H': 18,
    'I': 19, 'J': 20, 'K': 21, 'L': 23, 'M': 24, 'N': 25, 'O': 26, 'P': 27,
    'Q': 28, 'R': 29, 'S': 30, 'T': 31, 'U': 32, 'V': 34, 'W': 35, 'X': 36,
    'Y': 37, 'Z': 38,
  };

  /// 完整柜号正则：4 字母 + 7 数字（含校验码）。
  static final RegExp pattern = RegExp(r'[A-Z]{4}\d{7}');

  /// 计算 ISO 6346 校验码（0-9）。要求 [code] 为 4 字母 + 6 数字（共 10 位）。
  /// 若格式不符返回 null。
  static int? computeCheckDigit(String code) {
    final body = code.toUpperCase();
    if (!RegExp(r'^[A-Z]{4}\d{6}$').hasMatch(body)) return null;

    var sum = 0;
    for (var i = 0; i < 10; i++) {
      final ch = body[i];
      final value = i < 4 ? _letterValues[ch]! : int.parse(ch);
      sum += value * (1 << i); // 权重 2^i：1,2,4,...,512
    }
    final remainder = sum % 11;
    // 余数 10 时校验码记为 0
    return remainder == 10 ? 0 : remainder;
  }

  /// 校验完整柜号（4 字母 + 7 数字）的校验码是否正确。
  static bool isValid(String number) {
    final n = number.toUpperCase();
    if (!RegExp(r'^[A-Z]{4}\d{7}$').hasMatch(n)) return false;
    final expected = computeCheckDigit(n.substring(0, 10));
    if (expected == null) return false;
    return expected == int.parse(n[10]);
  }

  /// 从一段（可能含无关文字的）OCR 文本中提取候选柜号。
  ///
  /// 先把文本归一化（转大写、去掉空格/连字符等分隔符），再按格式匹配。
  /// 返回去重后的候选列表，**校验通过的排在前面**。
  static List<String> extractCandidates(String text) {
    final normalized = text.toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');
    final matches = pattern.allMatches(normalized).map((m) => m.group(0)!);

    final seen = <String>{};
    final unique = <String>[];
    for (final m in matches) {
      if (seen.add(m)) unique.add(m);
    }

    unique.sort((a, b) {
      final va = isValid(a) ? 0 : 1;
      final vb = isValid(b) ? 0 : 1;
      return va.compareTo(vb);
    });
    return unique;
  }
}
