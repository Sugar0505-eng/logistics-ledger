/// 金额工具：内部一律以"分"（整数）存储与计算，避免浮点精度误差。
/// 仅在 UI 显示与 CSV 输出的边界处格式化为元（两位小数）。
library;

class Money {
  Money._();

  /// 将用户输入的金额字符串解析为分（整数）。
  ///
  /// 接受形如 "1500"、"1500.5"、"1500.50"、" 1,500.50 " 的输入。
  /// 解析失败返回 null（调用方据此提示用户）。
  static int? parseToCents(String input) {
    final cleaned = input.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;

    // 仅允许：可选数字 + 可选小数点 + 至多两位小数
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
    if (match == null) return null;

    final whole = int.parse(match.group(1)!);
    final fracStr = match.group(2);
    var frac = 0;
    if (fracStr != null) {
      // "5" => 50 分，"50" => 50 分
      frac = int.parse(fracStr.padRight(2, '0'));
    }
    return whole * 100 + frac;
  }

  /// 将分格式化为两位小数的字符串，如 150050 => "1500.50"。
  static String formatCents(int cents) {
    final negative = cents < 0;
    final abs = cents.abs();
    final whole = abs ~/ 100;
    final frac = abs % 100;
    final s = '$whole.${frac.toString().padLeft(2, '0')}';
    return negative ? '-$s' : s;
  }
}
