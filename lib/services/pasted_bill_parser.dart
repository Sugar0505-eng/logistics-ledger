import 'container_number.dart';
import 'money.dart';

/// 从用户粘贴的物流文本中提取可直接填入账单的结构化字段。
class PastedBillData {
  const PastedBillData({
    this.containerNumber,
    this.sealNumber,
    this.bookingNumber,
    this.date,
    this.location,
    this.plateNumber,
    this.freightCents,
    this.feeAmountsCents = const {},
  });

  final String? containerNumber;
  final String? sealNumber;
  final String? bookingNumber;
  final String? date;
  final String? location;
  final String? plateNumber;
  final int? freightCents;
  final Map<String, int> feeAmountsCents;

  bool get isEmpty =>
      containerNumber == null &&
      sealNumber == null &&
      bookingNumber == null &&
      date == null &&
      location == null &&
      plateNumber == null &&
      freightCents == null &&
      feeAmountsCents.isEmpty;
}

class PastedBillParser {
  PastedBillParser._();

  static final RegExp _platePattern = RegExp(
    r'[\u4E00-\u9FFF][A-Z][A-Z0-9]{5,6}',
    caseSensitive: false,
  );
  static final RegExp _datePattern = RegExp(
    r'(?<!\d)(20\d{2})\s*[年/.-]\s*(\d{1,2})\s*[月/.-]\s*(\d{1,2})\s*日?',
  );
  static final RegExp _amountPattern = RegExp(
    r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
  );

  static PastedBillData parse(
    String text, {
    required Iterable<String> feePresetNames,
  }) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final candidates = ContainerNumber.extractCandidates(normalized);
    final labeledContainer = _extractCode(normalized, const [
      '柜号',
      '箱号',
      '集装箱号',
      'container no',
      'container',
    ]);
    final container = candidates.isNotEmpty
        ? candidates.first
        : labeledContainer?.toUpperCase();

    final feeAmounts = <String, int>{};
    final names =
        feePresetNames
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    for (final name in names) {
      final amount = _extractAmountAfterLabels(normalized, [name]);
      if (amount != null) feeAmounts[name] = amount;
    }

    return PastedBillData(
      containerNumber: _nonEmpty(container),
      sealNumber: _extractCode(normalized, const [
        '封条号',
        '封号',
        '铅封号',
        'seal no',
        'seal',
      ]),
      bookingNumber: _extractCode(normalized, const [
        '订舱号',
        '订仓号',
        '订舱单号',
        'booking no',
        'booking',
      ]),
      date: _extractDate(normalized),
      location: _extractText(normalized, const [
        '地点',
        '装货地点',
        '卸货地点',
        '地址',
        'location',
      ]),
      plateNumber: _extractPlate(normalized),
      freightCents: _extractAmountAfterLabels(normalized, const [
        '运费',
        '运输费',
        'freight',
      ]),
      feeAmountsCents: feeAmounts,
    );
  }

  static String? _extractCode(String text, List<String> labels) {
    final value = _extractAfterLabels(
      text,
      labels,
      RegExp(r'[A-Z0-9][A-Z0-9_./-]*', caseSensitive: false),
    );
    return _nonEmpty(value?.toUpperCase());
  }

  static String? _extractText(String text, List<String> labels) {
    for (final line in text.split('\n')) {
      for (final label in labels) {
        final match = RegExp(
          '${RegExp.escape(label)}\\s*[:：=]?\\s*(.+)',
          caseSensitive: false,
        ).firstMatch(line);
        if (match == null) continue;
        final value = match
            .group(1)!
            .split(
              RegExp(
                r'\s{2,}|[，,;；|]|\s+(?=(?:柜号|箱号|集装箱号|封条号|封号|铅封号|订舱号|订仓号|订舱单号|日期|车牌号|车牌|运费|运输费|container|seal|booking|date|plate|freight)\s*[:：=])',
                caseSensitive: false,
              ),
            )
            .first
            .trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  static String? _extractPlate(String text) {
    final labeled = _extractCode(text, const ['车牌号', '车牌', 'plate no']);
    if (labeled != null) return labeled;
    return _platePattern.firstMatch(text.toUpperCase())?.group(0);
  }

  static String? _extractDate(String text) {
    final match = _datePattern.firstMatch(text);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime.tryParse(
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
    );
    if (parsed == null ||
        parsed.year != year ||
        parsed.month != month ||
        parsed.day != day) {
      return null;
    }
    return '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
  }

  static int? _extractAmountAfterLabels(String text, List<String> labels) {
    final value = _extractAfterLabels(text, labels, _amountPattern);
    return value == null ? null : Money.parseToCents(value);
  }

  static String? _extractAfterLabels(
    String text,
    List<String> labels,
    RegExp valuePattern,
  ) {
    for (final label in labels) {
      final match = RegExp(
        '${RegExp.escape(label)}\\s*(?:金额)?\\s*[:：=￥¥]?\\s*(${valuePattern.pattern})',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
