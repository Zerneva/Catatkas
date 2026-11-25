import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ledger_models.dart';

class LedgerStore extends ChangeNotifier {
  static const _storageKey = 'catatkas_ledger_v1';

  String _userName = 'Budi Santoso';
  String? _uid;
  String? _userEmail;
  bool _privacyMode = false;
  bool _isSyncing = false;
  List<Partner> _partners = [];
  List<LedgerTransaction> _transactions = [];
  bool _loaded = false;

  String get userName => _userName;
  String? get uid => _uid;
  String? get userEmail => _userEmail;
  bool get isSyncing => _isSyncing;
  bool get privacyMode => _privacyMode;
  List<Partner> get partners => List.unmodifiable(_partners);
  List<LedgerTransaction> get transactions => List.unmodifiable(_transactions);
  bool get isLoaded => _loaded;

  // ─── Lifecycle ───
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _userName = (map['userName'] as String?) ?? 'Budi Santoso';
        _privacyMode = (map['privacyMode'] as bool?) ?? false;
        _partners = (map['partners'] as List<dynamic>)
            .map((e) => Partner.fromJson(e as Map<String, dynamic>))
            .toList();
        _transactions = (map['transactions'] as List<dynamic>)
            .map((e) => LedgerTransaction.fromJson(e as Map<String, dynamic>))
            .toList();
        _loaded = true;
        notifyListeners();
        return;
      } catch (_) {
        // Fallback to empty.
      }
    }
    _partners = [];
    _transactions = [];
    _loaded = true;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final data = {
      'userName': _userName,
      'privacyMode': _privacyMode,
      'partners': _partners.map((e) => e.toJson()).toList(),
      'transactions': _transactions.map((e) => e.toJson()).toList(),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data));

    if (_uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('catatkas_users')
            .doc(_uid)
            .set({
          ...data,
          'email': _userEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Offline or network error: local data is already saved.
      }
    }
  }

  Future<void> syncFromCloud({
    required String uid,
    String? email,
    String? displayName,
  }) async {
    _uid = uid;
    _userEmail = email;
    if (displayName != null && displayName.trim().isNotEmpty) {
      _userName = displayName.trim();
    }
    _isSyncing = true;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('catatkas_users')
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final map = doc.data()!;
        _userName = (map['userName'] as String?) ?? _userName;
        _privacyMode = (map['privacyMode'] as bool?) ?? false;
        _partners = ((map['partners'] as List<dynamic>?) ?? [])
            .map((e) => Partner.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _transactions = ((map['transactions'] as List<dynamic>?) ?? [])
            .map((e) => LedgerTransaction.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, jsonEncode({
          'userName': _userName,
          'privacyMode': _privacyMode,
          'partners': _partners.map((e) => e.toJson()).toList(),
          'transactions': _transactions.map((e) => e.toJson()).toList(),
        }));
      } else {
        await _persist();
      }
    } catch (_) {
      // Keep local data if offline.
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> clearCloudUser() async {
    _uid = null;
    _userEmail = null;
    _partners = [];
    _transactions = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }

  // ─── User & Preferences ───
  void togglePrivacyMode() {
    _privacyMode = !_privacyMode;
    _persist();
    notifyListeners();
  }

  void setUserName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _userName = trimmed;
    _persist();
    notifyListeners();
  }

  // ─── Partner CRUD ───
  Partner? partnerById(String id) {
    for (final p in _partners) {
      if (p.id == id) return p;
    }
    return null;
  }

  static final _rand = Random();
  static const _avatarColors = [
    0xFF059669, 0xFF2563EB, 0xFFE11D48, 0xFFD97706,
    0xFF0F172A, 0xFF64748B, 0xFF7C3AED, 0xFF0891B2,
  ];

  Future<Partner> addPartner({
    required String name,
    required String phone,
    String roleTag = 'Rekan',
  }) async {
    final partner = Partner(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      phone: phone.trim(),
      roleTag: roleTag,
      avatarColorValue: _avatarColors[_rand.nextInt(_avatarColors.length)],
    );
    _partners.insert(0, partner);
    await _persist();
    notifyListeners();
    return partner;
  }

  Future<void> updatePartner(String id, {String? name, String? phone, String? roleTag}) async {
    final idx = _partners.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    _partners[idx] = _partners[idx].copyWith(name: name, phone: phone, roleTag: roleTag);
    await _persist();
    notifyListeners();
  }

  Future<void> deletePartner(String id) async {
    _partners.removeWhere((p) => p.id == id);
    _transactions.removeWhere((t) => t.partnerId == id);
    await _persist();
    notifyListeners();
  }

  // ─── Transaction CRUD ───
  Future<void> addTransaction({
    required String partnerId,
    required DebtDirection direction,
    required TxKind kind,
    required int amount,
    DateTime? dueDate,
    String category = 'Pribadi / Teman',
    String paymentMethod = 'Transfer BCA',
    String note = '',
    String? agreementNote,
    String? attachmentName,
    String? attachmentSizeLabel,
  }) async {
    int? installmentNum;
    if (kind == TxKind.installment) {
      installmentNum = _transactions
              .where((t) => t.partnerId == partnerId && t.kind == TxKind.installment)
              .length +
          1;
    }

    final tx = LedgerTransaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      partnerId: partnerId,
      direction: direction,
      kind: kind,
      amount: amount,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      category: category,
      paymentMethod: paymentMethod,
      note: note.trim(),
      agreementNote: agreementNote,
      attachmentName: attachmentName,
      attachmentSizeLabel: attachmentSizeLabel,
      installmentNumber: installmentNum,
    );
    _transactions.insert(0, tx);
    await _persist();
    notifyListeners();
  }

  Future<void> deleteTransaction(String txId) async {
    _transactions.removeWhere((t) => t.id == txId);
    await _persist();
    notifyListeners();
  }

  /// Mark all outstanding balance for [partnerId] as paid ("Lunas").
  /// This creates a settlement transaction that zeroes out the remaining balance.
  Future<void> markAsSettled({
    required String partnerId,
    String paymentMethod = 'Tunai',
    String note = 'Ditandai lunas',
  }) async {
    final summary = summaryForPartner(partnerId);
    if (summary.hasNoDebt || summary.isSettled) return;

    final remaining = summary.netBalance.abs();
    final direction = summary.isPiutang ? DebtDirection.piutang : DebtDirection.hutang;

    final tx = LedgerTransaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      partnerId: partnerId,
      direction: direction,
      kind: TxKind.settlement,
      amount: remaining,
      createdAt: DateTime.now(),
      category: 'Pelunasan',
      paymentMethod: paymentMethod,
      note: note,
    );
    _transactions.insert(0, tx);
    await _persist();
    notifyListeners();
  }

  // ─── Summary & Aggregation ───
  PartnerSummary summaryForPartner(String partnerId) {
    final partner = partnerById(partnerId)!;
    final txs = _transactions.where((t) => t.partnerId == partnerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    int pLoan = 0, pPaid = 0, hLoan = 0, hPaid = 0;
    DateTime? nearestDue;

    for (final tx in txs) {
      if (tx.direction == DebtDirection.piutang) {
        if (tx.kind == TxKind.loan) {
          pLoan += tx.amount;
          if (tx.dueDate != null) {
            if (nearestDue == null || tx.dueDate!.isBefore(nearestDue)) {
              nearestDue = tx.dueDate;
            }
          }
        } else {
          // installment or settlement
          pPaid += tx.amount;
        }
      } else {
        if (tx.kind == TxKind.loan) {
          hLoan += tx.amount;
          if (tx.dueDate != null) {
            if (nearestDue == null || tx.dueDate!.isBefore(nearestDue)) {
              nearestDue = tx.dueDate;
            }
          }
        } else {
          hPaid += tx.amount;
        }
      }
    }

    return PartnerSummary(
      partner: partner,
      transactions: txs,
      totalPiutangLoan: pLoan,
      totalPiutangPaid: pPaid,
      totalHutangLoan: hLoan,
      totalHutangPaid: hPaid,
      nearestDueDate: nearestDue,
    );
  }

  List<PartnerSummary> get allPartnerSummaries {
    return _partners.map((p) => summaryForPartner(p.id)).toList();
  }

  int get totalPiutang =>
      allPartnerSummaries.fold(0, (total, s) => total + (s.netBalance > 0 ? s.netBalance : 0));

  int get totalHutang =>
      allPartnerSummaries.fold(0, (total, s) => total + (s.netBalance < 0 ? s.netBalance.abs() : 0));

  int get netSaldo => totalPiutang - totalHutang;

  int get piutangPartnerCount =>
      allPartnerSummaries.where((s) => s.netBalance > 0).length;

  int get hutangPartnerCount =>
      allPartnerSummaries.where((s) => s.netBalance < 0).length;

  List<PartnerSummary> get upcomingDueSummaries {
    final list = allPartnerSummaries
        .where((s) => !s.isSettled && !s.hasNoDebt && s.nearestDueDate != null)
        .toList();
    list.sort((a, b) => a.nearestDueDate!.compareTo(b.nearestDueDate!));
    return list;
  }

  // ─── Bulk operations ───
  Future<void> clearAllData() async {
    _partners = [];
    _transactions = [];
    await _persist();
    notifyListeners();
  }

  Future<void> resetDemoData() async {
    _seedInitialData();
    await _persist();
    notifyListeners();
  }

  void _seedInitialData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 10, 42);

    _partners = const [
      Partner(id: 'p_dimas', name: 'Dimas Arya', phone: '0812-3456-7890',
          roleTag: 'Rekan UMKM', isVerified: true, avatarColorValue: 0xFF059669),
      Partner(id: 'p_sarah', name: 'Sarah Amalia', phone: '0813-7788-9900',
          roleTag: 'Karyawan', isVerified: true, avatarColorValue: 0xFF2563EB),
      Partner(id: 'p_toko_berkah', name: 'Toko Berkah', phone: '0821-4455-6677',
          roleTag: 'Supplier', avatarColorValue: 0xFFE11D48),
      Partner(id: 'p_hendra', name: 'Hendra Wijaya', phone: '0856-1122-3344',
          roleTag: 'Pribadi / Teman', avatarColorValue: 0xFFD97706),
      Partner(id: 'p_raka', name: 'Raka Pratama', phone: '0819-8877-6655',
          roleTag: 'Bisnis / Modal', avatarColorValue: 0xFF0F172A),
      Partner(id: 'p_citra', name: 'Citra Lestari', phone: '0878-2233-4455',
          roleTag: 'Teman Kantor', avatarColorValue: 0xFF64748B),
      Partner(id: 'p_anton', name: 'Anton', phone: '0811-9090-1212',
          roleTag: 'Pribadi / Teman', avatarColorValue: 0xFF059669),
      Partner(id: 'p_dewi', name: 'Dewi Kartika', phone: '0857-3344-5566',
          roleTag: 'Bisnis / Modal', avatarColorValue: 0xFFE11D48),
    ];

    _transactions = [
      LedgerTransaction(id: 'tx_1', partnerId: 'p_dimas', direction: DebtDirection.piutang,
          kind: TxKind.installment, amount: 500000,
          createdAt: today.subtract(const Duration(days: 2)),
          category: 'Bisnis / Modal', paymentMethod: 'Transfer BCA',
          note: 'Cicilan kedua modal warung', installmentNumber: 2),
      LedgerTransaction(id: 'tx_2', partnerId: 'p_dimas', direction: DebtDirection.piutang,
          kind: TxKind.installment, amount: 500000,
          createdAt: today.subtract(const Duration(days: 10)),
          category: 'Bisnis / Modal', paymentMethod: 'Tunai',
          note: 'Cicilan pertama', installmentNumber: 1),
      LedgerTransaction(id: 'tx_3', partnerId: 'p_dimas', direction: DebtDirection.piutang,
          kind: TxKind.loan, amount: 2500000,
          createdAt: today.subtract(const Duration(days: 20)),
          dueDate: today.add(const Duration(days: 1)),
          category: 'Bisnis / Modal', paymentMethod: 'Transfer BCA',
          note: 'Tambahan modal kulakan warung',
          agreementNote: 'Pelunasan fleksibel maks 25 hari kerja.'),
      LedgerTransaction(id: 'tx_4', partnerId: 'p_sarah', direction: DebtDirection.piutang,
          kind: TxKind.installment, amount: 500000, createdAt: today,
          category: 'Pribadi / Teman', paymentMethod: 'Transfer BCA',
          note: 'Cicilan #2 via m-Banking', installmentNumber: 2),
      LedgerTransaction(id: 'tx_5', partnerId: 'p_sarah', direction: DebtDirection.piutang,
          kind: TxKind.loan, amount: 1250000,
          createdAt: today.subtract(const Duration(days: 14)),
          dueDate: today.add(const Duration(days: 14)),
          category: 'Pribadi / Teman', paymentMethod: 'Transfer BRI',
          note: 'Pinjaman biaya servis motor'),
      LedgerTransaction(id: 'tx_6', partnerId: 'p_toko_berkah', direction: DebtDirection.hutang,
          kind: TxKind.loan, amount: 750000,
          createdAt: today.subtract(const Duration(days: 7)),
          dueDate: today.add(const Duration(days: 3)),
          category: 'Bisnis / Modal', paymentMethod: 'QRIS Mandiri',
          note: 'Stok bahan baku sembako'),
      LedgerTransaction(id: 'tx_7', partnerId: 'p_dewi', direction: DebtDirection.hutang,
          kind: TxKind.loan, amount: 450000,
          createdAt: today.subtract(const Duration(days: 1)),
          dueDate: today.add(const Duration(days: 9)),
          category: 'Belanja', paymentMethod: 'DANA',
          note: 'Talangan ongkir ekspedisi'),
      LedgerTransaction(id: 'tx_8', partnerId: 'p_hendra', direction: DebtDirection.piutang,
          kind: TxKind.loan, amount: 850000,
          createdAt: today.subtract(const Duration(days: 4)),
          dueDate: today.add(const Duration(days: 18)),
          category: 'Pribadi / Teman', paymentMethod: 'Transfer BCA',
          note: 'Talangan tiket & akomodasi'),
      LedgerTransaction(id: 'tx_9', partnerId: 'p_raka', direction: DebtDirection.piutang,
          kind: TxKind.loan, amount: 1500000,
          createdAt: today.subtract(const Duration(days: 5)),
          dueDate: today.add(const Duration(days: 6)),
          category: 'Bisnis / Modal', paymentMethod: 'Transfer BCA',
          note: 'DP pengadaan kemasan produk'),
      LedgerTransaction(id: 'tx_10', partnerId: 'p_anton', direction: DebtDirection.piutang,
          kind: TxKind.loan, amount: 250000,
          createdAt: today.subtract(const Duration(hours: 2)),
          dueDate: today.add(const Duration(days: 10)),
          category: 'Pribadi / Teman', paymentMethod: 'Tunai',
          note: 'Pinjaman dana darurat'),
      LedgerTransaction(id: 'tx_11', partnerId: 'p_citra', direction: DebtDirection.piutang,
          kind: TxKind.settlement, amount: 1500000,
          createdAt: today.subtract(const Duration(days: 2)),
          category: 'Pelunasan', paymentMethod: 'Transfer BCA',
          note: 'Pelunasan penuh'),
      LedgerTransaction(id: 'tx_12', partnerId: 'p_citra', direction: DebtDirection.piutang,
          kind: TxKind.loan, amount: 1500000,
          createdAt: today.subtract(const Duration(days: 15)),
          category: 'Pribadi / Teman', paymentMethod: 'Transfer BCA',
          note: 'Pinjaman acara keluarga'),
    ];
  }
}
