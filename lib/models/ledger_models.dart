import 'dart:ui';

enum DebtDirection {
  piutang, // Orang berhutang ke Anda (receivable)
  hutang,  // Anda berhutang ke orang (payable)
}

enum TxKind {
  loan,        // Pinjaman baru / awal
  installment, // Pembayaran / cicilan
  settlement,  // Pelunasan penuh (tandai lunas)
}

class Partner {
  final String id;
  final String name;
  final String phone;
  final String roleTag;
  final bool isVerified;
  final int avatarColorValue;

  const Partner({
    required this.id,
    required this.name,
    required this.phone,
    this.roleTag = 'Rekan',
    this.isVerified = false,
    this.avatarColorValue = 0xFF2563EB,
  });

  Color get avatarColor => Color(avatarColorValue);

  Partner copyWith({
    String? name,
    String? phone,
    String? roleTag,
  }) {
    return Partner(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      roleTag: roleTag ?? this.roleTag,
      isVerified: isVerified,
      avatarColorValue: avatarColorValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'roleTag': roleTag,
        'isVerified': isVerified,
        'avatarColorValue': avatarColorValue,
      };

  factory Partner.fromJson(Map<String, dynamic> json) => Partner(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        roleTag: (json['roleTag'] as String?) ?? 'Rekan',
        isVerified: (json['isVerified'] as bool?) ?? false,
        avatarColorValue: (json['avatarColorValue'] as int?) ?? 0xFF2563EB,
      );
}

class LedgerTransaction {
  final String id;
  final String partnerId;
  final DebtDirection direction;
  final TxKind kind;
  final int amount;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String category;
  final String paymentMethod;
  final String note;
  final String? agreementNote;
  final String? attachmentName;
  final String? attachmentSizeLabel;
  final int? installmentNumber;

  const LedgerTransaction({
    required this.id,
    required this.partnerId,
    required this.direction,
    required this.kind,
    required this.amount,
    required this.createdAt,
    this.dueDate,
    this.category = 'Pribadi / Teman',
    this.paymentMethod = 'Transfer BCA',
    this.note = '',
    this.agreementNote,
    this.attachmentName,
    this.attachmentSizeLabel,
    this.installmentNumber,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'partnerId': partnerId,
        'direction': direction.name,
        'kind': kind.name,
        'amount': amount,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'category': category,
        'paymentMethod': paymentMethod,
        'note': note,
        'agreementNote': agreementNote,
        'attachmentName': attachmentName,
        'attachmentSizeLabel': attachmentSizeLabel,
        'installmentNumber': installmentNumber,
      };

  factory LedgerTransaction.fromJson(Map<String, dynamic> json) => LedgerTransaction(
        id: json['id'] as String,
        partnerId: json['partnerId'] as String,
        direction: DebtDirection.values.byName(json['direction'] as String),
        kind: TxKind.values.byName(json['kind'] as String),
        amount: json['amount'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
        category: (json['category'] as String?) ?? 'Pribadi / Teman',
        paymentMethod: (json['paymentMethod'] as String?) ?? 'Transfer BCA',
        note: (json['note'] as String?) ?? '',
        agreementNote: json['agreementNote'] as String?,
        attachmentName: json['attachmentName'] as String?,
        attachmentSizeLabel: json['attachmentSizeLabel'] as String?,
        installmentNumber: json['installmentNumber'] as int?,
      );
}

class PartnerSummary {
  final Partner partner;
  final List<LedgerTransaction> transactions;
  final int totalPiutangLoan;
  final int totalPiutangPaid;
  final int totalHutangLoan;
  final int totalHutangPaid;
  final DateTime? nearestDueDate;

  PartnerSummary({
    required this.partner,
    required this.transactions,
    required this.totalPiutangLoan,
    required this.totalPiutangPaid,
    required this.totalHutangLoan,
    required this.totalHutangPaid,
    required this.nearestDueDate,
  });

  int get remainingPiutang => (totalPiutangLoan - totalPiutangPaid).clamp(0, 1 << 60);
  int get remainingHutang => (totalHutangLoan - totalHutangPaid).clamp(0, 1 << 60);

  /// Positive = partner owes you (Piutang). Negative = you owe partner (Hutang).
  int get netBalance => remainingPiutang - remainingHutang;

  bool get isSettled => netBalance == 0 && (totalPiutangLoan > 0 || totalHutangLoan > 0);
  bool get hasNoDebt => totalPiutangLoan == 0 && totalHutangLoan == 0;
  bool get isPiutang => netBalance > 0;
  bool get isHutang => netBalance < 0;

  int get totalPrincipal => totalPiutangLoan + totalHutangLoan;
  int get totalPaid => totalPiutangPaid + totalHutangPaid;

  int get activePrincipal => isPiutang ? totalPiutangLoan : totalHutangLoan;
  int get activePaid => isPiutang ? totalPiutangPaid : totalHutangPaid;

  double get paymentProgress {
    if (activePrincipal <= 0) return 1.0;
    return (activePaid / activePrincipal).clamp(0.0, 1.0);
  }
}
