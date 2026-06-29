/// 领域模型。金额字段一律为"分"（整数）。日期为 'yyyy-MM-dd' 字符串。
library;

/// 车牌库条目（仅存车牌号）。
class Plate {
  final int? id;
  final String number;

  const Plate({this.id, required this.number});

  Map<String, Object?> toMap() => {'id': id, 'number': number};

  factory Plate.fromMap(Map<String, Object?> m) =>
      Plate(id: m['id'] as int?, number: m['number'] as String);
}

/// 额外费用预设名称。
class FeePreset {
  final int? id;
  final String name;

  const FeePreset({this.id, required this.name});

  Map<String, Object?> toMap() => {'id': id, 'name': name};

  factory FeePreset.fromMap(Map<String, Object?> m) =>
      FeePreset(id: m['id'] as int?, name: m['name'] as String);
}

enum LedgerStatus {
  editing,
  completed;

  static LedgerStatus fromName(String s) =>
      LedgerStatus.values.firstWhere((e) => e.name == s,
          orElse: () => LedgerStatus.editing);
}

/// 账目记录（一个批次/单子）。
class Ledger {
  final int? id;
  final String? name;
  final String createdAt; // yyyy-MM-dd
  final LedgerStatus status;

  const Ledger({
    this.id,
    this.name,
    required this.createdAt,
    this.status = LedgerStatus.editing,
  });

  Ledger copyWith({String? name, LedgerStatus? status}) => Ledger(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        status: status ?? this.status,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'created_at': createdAt,
        'status': status.name,
      };

  factory Ledger.fromMap(Map<String, Object?> m) => Ledger(
        id: m['id'] as int?,
        name: m['name'] as String?,
        createdAt: m['created_at'] as String,
        status: LedgerStatus.fromName(m['status'] as String),
      );
}

/// 额外费用（隶属一条账单）。名称为快照值，与费用预设解耦。
class ExtraFee {
  final int? id;
  final int? billId;
  final String name;
  final int amountCents;

  const ExtraFee({
    this.id,
    this.billId,
    required this.name,
    required this.amountCents,
  });

  ExtraFee copyWith({String? name, int? amountCents}) => ExtraFee(
        id: id,
        billId: billId,
        name: name ?? this.name,
        amountCents: amountCents ?? this.amountCents,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'bill_id': billId,
        'name': name,
        'amount_cents': amountCents,
      };

  factory ExtraFee.fromMap(Map<String, Object?> m) => ExtraFee(
        id: m['id'] as int?,
        billId: m['bill_id'] as int?,
        name: m['name'] as String,
        amountCents: m['amount_cents'] as int,
      );
}

/// 账单（一条 = 一个柜号），可携带多条额外费用。
class Bill {
  final int? id;
  final int? ledgerId;
  final String containerNo;
  final String date; // yyyy-MM-dd
  final int freightCents;
  final String plateNumber;
  final List<ExtraFee> extraFees;

  const Bill({
    this.id,
    this.ledgerId,
    required this.containerNo,
    required this.date,
    required this.freightCents,
    required this.plateNumber,
    this.extraFees = const [],
  });

  /// 额外费用合计（分）。
  int get extraTotalCents =>
      extraFees.fold(0, (sum, f) => sum + f.amountCents);

  /// 账单小计（分）= 运费 + 额外费用合计。
  int get subtotalCents => freightCents + extraTotalCents;

  Bill copyWith({
    int? ledgerId,
    String? containerNo,
    String? date,
    int? freightCents,
    String? plateNumber,
    List<ExtraFee>? extraFees,
  }) =>
      Bill(
        id: id,
        ledgerId: ledgerId ?? this.ledgerId,
        containerNo: containerNo ?? this.containerNo,
        date: date ?? this.date,
        freightCents: freightCents ?? this.freightCents,
        plateNumber: plateNumber ?? this.plateNumber,
        extraFees: extraFees ?? this.extraFees,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'ledger_id': ledgerId,
        'container_no': containerNo,
        'date': date,
        'freight_cents': freightCents,
        'plate_number': plateNumber,
      };

  factory Bill.fromMap(Map<String, Object?> m,
          {List<ExtraFee> extraFees = const []}) =>
      Bill(
        id: m['id'] as int?,
        ledgerId: m['ledger_id'] as int?,
        containerNo: m['container_no'] as String,
        date: m['date'] as String,
        freightCents: m['freight_cents'] as int,
        plateNumber: m['plate_number'] as String,
        extraFees: extraFees,
      );
}
