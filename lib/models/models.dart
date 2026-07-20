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

/// 可供账目选择的公司账户预设。
class AccountPreset {
  final int? id;
  final String companyAccount;
  final String accountName;

  const AccountPreset({
    this.id,
    required this.companyAccount,
    required this.accountName,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'company_account': companyAccount,
    'account_name': accountName,
  };

  factory AccountPreset.fromMap(Map<String, Object?> map) => AccountPreset(
    id: map['id'] as int?,
    companyAccount: map['company_account'] as String,
    accountName: map['account_name'] as String,
  );
}

enum LedgerStatus {
  editing,
  completed;

  static LedgerStatus fromName(String s) => LedgerStatus.values.firstWhere(
    (e) => e.name == s,
    orElse: () => LedgerStatus.editing,
  );
}

/// 账目记录（一个批次/单子）。
class Ledger {
  final int? id;
  final String? name;
  final String createdAt; // yyyy-MM-dd
  final LedgerStatus status;
  final int? accountPresetId;

  const Ledger({
    this.id,
    this.name,
    required this.createdAt,
    this.status = LedgerStatus.editing,
    this.accountPresetId,
  });

  Ledger copyWith({String? name, LedgerStatus? status, int? accountPresetId}) =>
      Ledger(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        status: status ?? this.status,
        accountPresetId: accountPresetId ?? this.accountPresetId,
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'created_at': createdAt,
    'status': status.name,
    'account_preset_id': accountPresetId,
  };

  factory Ledger.fromMap(Map<String, Object?> m) => Ledger(
    id: m['id'] as int?,
    name: m['name'] as String?,
    createdAt: m['created_at'] as String,
    status: LedgerStatus.fromName(m['status'] as String),
    accountPresetId: m['account_preset_id'] as int?,
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
  final String sealNumber;
  final String bookingNumber;
  final String date; // yyyy-MM-dd
  final String location;
  final int freightCents;
  final String plateNumber;
  final List<ExtraFee> extraFees;

  const Bill({
    this.id,
    this.ledgerId,
    required this.containerNo,
    this.sealNumber = '',
    this.bookingNumber = '',
    required this.date,
    required this.location,
    required this.freightCents,
    required this.plateNumber,
    this.extraFees = const [],
  });

  /// 额外费用合计（分）。
  int get extraTotalCents => extraFees.fold(0, (sum, f) => sum + f.amountCents);

  /// 账单小计（分）= 运费 + 额外费用合计。
  int get subtotalCents => freightCents + extraTotalCents;

  Bill copyWith({
    int? ledgerId,
    String? containerNo,
    String? sealNumber,
    String? bookingNumber,
    String? date,
    String? location,
    int? freightCents,
    String? plateNumber,
    List<ExtraFee>? extraFees,
  }) => Bill(
    id: id,
    ledgerId: ledgerId ?? this.ledgerId,
    containerNo: containerNo ?? this.containerNo,
    sealNumber: sealNumber ?? this.sealNumber,
    bookingNumber: bookingNumber ?? this.bookingNumber,
    date: date ?? this.date,
    location: location ?? this.location,
    freightCents: freightCents ?? this.freightCents,
    plateNumber: plateNumber ?? this.plateNumber,
    extraFees: extraFees ?? this.extraFees,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'ledger_id': ledgerId,
    'container_no': containerNo,
    'seal_number': sealNumber,
    'booking_number': bookingNumber,
    'date': date,
    'location': location,
    'freight_cents': freightCents,
    'plate_number': plateNumber,
  };

  factory Bill.fromMap(
    Map<String, Object?> m, {
    List<ExtraFee> extraFees = const [],
  }) => Bill(
    id: m['id'] as int?,
    ledgerId: m['ledger_id'] as int?,
    containerNo: m['container_no'] as String,
    sealNumber: m['seal_number'] as String? ?? '',
    bookingNumber: m['booking_number'] as String? ?? '',
    date: m['date'] as String,
    location: m['location'] as String? ?? '',
    freightCents: m['freight_cents'] as int,
    plateNumber: m['plate_number'] as String,
    extraFees: extraFees,
  );
}
