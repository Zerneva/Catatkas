import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ledger_models.dart';
import '../state/ledger_store.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class CatatTransaksiSheet extends StatefulWidget {
  final LedgerStore store;
  final String? initialPartnerId;
  final DebtDirection? initialDirection;
  final TxKind? initialKind;

  const CatatTransaksiSheet({
    super.key,
    required this.store,
    this.initialPartnerId,
    this.initialDirection,
    this.initialKind,
  });

  static Future<void> show(BuildContext context, {
    required LedgerStore store,
    String? initialPartnerId,
    DebtDirection? initialDirection,
    TxKind? initialKind,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => CatatTransaksiSheet(
        store: store,
        initialPartnerId: initialPartnerId,
        initialDirection: initialDirection,
        initialKind: initialKind,
      ),
    );
  }

  @override
  State<CatatTransaksiSheet> createState() => _CatatTransaksiSheetState();
}

class _CatatTransaksiSheetState extends State<CatatTransaksiSheet> {
  late DebtDirection _direction;
  late TxKind _kind;
  late String? _selectedPartnerId;
  int _amount = 0;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime? _dueDate;
  String _duePreset = '+7 Hari';
  String _category = 'Pribadi / Teman';
  String _paymentMethod = 'Tunai';
  String? _attachmentName;

  static const _categories = ['Bisnis / Modal', 'Pribadi / Teman', 'Belanja', 'Lainnya'];
  static const _methods = ['Tunai', 'Transfer BCA', 'Transfer BRI', 'QRIS Mandiri', 'DANA', 'GoPay', 'OVO', 'ShopeePay'];

  @override
  void initState() {
    super.initState();
    _direction = widget.initialDirection ?? DebtDirection.piutang;
    _kind = widget.initialKind ?? TxKind.loan;
    _selectedPartnerId = widget.initialPartnerId ??
        (widget.store.partners.isNotEmpty ? widget.store.partners.first.id : null);
    _dueDate = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _setAmount(int value) {
    setState(() {
      _amount = value < 0 ? 0 : value;
      _amountCtrl.text = Formatters.rupiahPlain(_amount);
      _amountCtrl.selection = TextSelection.collapsed(offset: _amountCtrl.text.length);
    });
  }

  void _addAmount(int delta) => _setAmount(_amount + delta);

  Future<void> _save() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mohon isi nominal transaksi.'), behavior: SnackBarBehavior.floating));
      return;
    }

    // Auto-create partner if none exists
    if (_selectedPartnerId == null || widget.store.partnerById(_selectedPartnerId!) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih atau tambah rekan transaksi terlebih dahulu.'), behavior: SnackBarBehavior.floating));
      return;
    }

    await widget.store.addTransaction(
      partnerId: _selectedPartnerId!,
      direction: _direction,
      kind: _kind,
      amount: _amount,
      dueDate: _kind == TxKind.loan ? _dueDate : null,
      category: _category,
      paymentMethod: _paymentMethod,
      note: _noteCtrl.text,
      attachmentName: _attachmentName,
      attachmentSizeLabel: _attachmentName != null ? '248 KB' : null,
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_kind == TxKind.installment
              ? 'Pembayaran/cicilan berhasil dicatat!'
              : 'Transaksi baru berhasil disimpan!'),
          behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPartners = widget.store.partners.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.93, minChildSize: 0.6, maxChildSize: 0.97, expand: false,
      builder: (context, scrollCtrl) {
        return Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _buildDirectionSwitcher(),
                  const SizedBox(height: 10),
                  _buildKindSwitcher(),
                  const SizedBox(height: 16),
                  _buildAmountCard(context),
                  const SizedBox(height: 16),
                  _buildPartnerSelector(context, hasPartners),
                  const SizedBox(height: 16),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: _kind == TxKind.loan
                        ? Column(
                            children: [
                              _buildDueDateSection(context),
                              const SizedBox(height: 16),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  _buildCategorySection(context),
                  const SizedBox(height: 16),
                  _buildPaymentMethodSection(context),
                  const SizedBox(height: 16),
                  _buildNoteSection(context),
                  const SizedBox(height: 16),
                  _buildAttachmentSection(context),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.cloud_done_rounded, size: 15, color: AppColors.piutang),
                    const SizedBox(width: 6),
                    Text('Data tersimpan otomatis di perangkat',
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text(
                      _kind == TxKind.installment ? 'Simpan Pembayaran / Cicilan' : 'Simpan Catatan Transaksi',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant))),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop()),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_kind == TxKind.installment ? 'Catat Cicilan' : 'Catat Transaksi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text('Input Cepat • Offline-first', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        FilledButton(onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _buildDirectionSwitcher() {
    final isPiutang = _direction == DebtDirection.piutang;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(child: _directionButton('↓ Saya Memberi (Piutang)', isPiutang,
            AppColors.piutang, () => setState(() => _direction = DebtDirection.piutang))),
        Expanded(child: _directionButton('↑ Saya Meminjam (Hutang)', !isPiutang,
            AppColors.hutang, () => setState(() => _direction = DebtDirection.hutang))),
      ]),
    );
  }

  Widget _directionButton(String label, bool active, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text(label, style: TextStyle(
            color: active ? Colors.white : AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w700, fontSize: 12.5))),
      ),
    );
  }

  Widget _buildKindSwitcher() {
    return Row(children: [
      ChoiceChip(label: const Text('Pinjaman Baru'), selected: _kind == TxKind.loan,
          onSelected: (_) => setState(() => _kind = TxKind.loan)),
      const SizedBox(width: 8),
      ChoiceChip(label: const Text('Pembayaran / Cicilan'), selected: _kind == TxKind.installment,
          onSelected: (_) => setState(() => _kind = TxKind.installment)),
    ]);
  }

  Widget _buildAmountCard(BuildContext context) {
    final isPiutang = _direction == DebtDirection.piutang;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('NOMINAL TRANSAKSI', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0.7)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isPiutang ? AppColors.piutangSoft : AppColors.hutangSoft,
                borderRadius: BorderRadius.circular(999)),
              child: Text(isPiutang ? 'Hak Tagih (+)' : 'Kewajiban (-)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: isPiutang ? AppColors.piutang : AppColors.hutang)),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTheme.tabular(Theme.of(context).textTheme.headlineLarge,
                fontSize: 28, color: AppColors.primary),
            decoration: const InputDecoration(
              prefixText: 'Rp ', hintText: '0', fillColor: AppColors.surfaceLow),
            onChanged: (val) {
              final parsed = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              setState(() => _amount = parsed);
            },
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _quickAmountChip('+50rb', () => _addAmount(50000)),
              const SizedBox(width: 6),
              _quickAmountChip('+100rb', () => _addAmount(100000)),
              const SizedBox(width: 6),
              _quickAmountChip('+500rb', () => _addAmount(500000)),
              const SizedBox(width: 6),
              _quickAmountChip('+1jt', () => _addAmount(1000000)),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () {
                  final rounded = ((_amount + 49999) ~/ 50000) * 50000;
                  _setAmount(rounded);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  side: const BorderSide(color: AppColors.secondary),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Bulatkan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _quickAmountChip(String label, VoidCallback onTap) {
    return ActionChip(label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        onPressed: onTap, backgroundColor: AppColors.surfaceLow,
        side: const BorderSide(color: AppColors.outlineVariant));
  }

  Widget _buildPartnerSelector(BuildContext context, bool hasPartners) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Rekan Transaksi', style: Theme.of(context).textTheme.labelLarge),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _showAddPartnerInline(context),
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
            label: const Text('Tambah Baru'),
          ),
        ]),
        const SizedBox(height: 8),
        if (!hasPartners)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant)),
            child: const Center(child: Text('Belum ada rekan. Ketuk "Tambah Baru" di atas.')),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _selectedPartnerId,
            decoration: const InputDecoration(
              fillColor: AppColors.card, prefixIcon: Icon(Icons.person_outline_rounded)),
            items: widget.store.partners
                .map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.roleTag})')))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedPartnerId = val);
            },
          ),
      ],
    );
  }

  Future<void> _showAddPartnerInline(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Rekan Baru'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Lengkap')),
          const SizedBox(height: 10),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'No. HP / WhatsApp')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            final p = await widget.store.addPartner(
                name: nameCtrl.text,
                phone: phoneCtrl.text.isEmpty ? '0812-0000-0000' : phoneCtrl.text);
            setState(() => _selectedPartnerId = p.id);
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text('Simpan')),
        ],
      ),
    );
  }

  Widget _buildDueDateSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Tanggal Jatuh Tempo', style: Theme.of(context).textTheme.labelLarge),
          const Spacer(),
          if (_dueDate != null) TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context, initialDate: _dueDate!,
                firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (picked != null) setState(() { _dueDate = picked; _duePreset = 'Pilih'; });
            },
            child: Text(Formatters.fullIndonesianDate(_dueDate!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
          ),
        ]),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _dueChip('Hari Ini', () => setState(() { _duePreset = 'Hari Ini'; _dueDate = DateTime.now(); })),
            const SizedBox(width: 6),
            _dueChip('Besok', () => setState(() { _duePreset = 'Besok'; _dueDate = DateTime.now().add(const Duration(days: 1)); })),
            const SizedBox(width: 6),
            _dueChip('+7 Hari', () => setState(() { _duePreset = '+7 Hari'; _dueDate = DateTime.now().add(const Duration(days: 7)); })),
            const SizedBox(width: 6),
            _dueChip('+30 Hari', () => setState(() { _duePreset = '+30 Hari'; _dueDate = DateTime.now().add(const Duration(days: 30)); })),
            const SizedBox(width: 6),
            _dueChip('Bebas', () => setState(() { _duePreset = 'Bebas'; _dueDate = null; })),
          ]),
        ),
      ],
    );
  }

  Widget _dueChip(String label, VoidCallback onTap) {
    final active = _duePreset == label;
    return ChoiceChip(label: Text(label), selected: active,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: active ? Colors.white : AppColors.onSurface,
            fontSize: 12, fontWeight: FontWeight.w600),
        onSelected: (_) => onTap());
  }

  Widget _buildCategorySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kategori Keperluan', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _categories.map((c) => ChoiceChip(
            label: Text(c), selected: _category == c, selectedColor: AppColors.secondary,
            labelStyle: TextStyle(color: _category == c ? Colors.white : AppColors.onSurface,
                fontSize: 12.5, fontWeight: FontWeight.w600),
            onSelected: (_) => setState(() => _category = c))).toList()),
      ],
    );
  }

  Widget _buildPaymentMethodSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Metode Pembayaran', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _methods.map((m) => ChoiceChip(
            label: Text(m), selected: _paymentMethod == m,
            onSelected: (_) => setState(() => _paymentMethod = m))).toList()),
      ],
    );
  }

  Widget _buildNoteSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Catatan Tambahan', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(controller: _noteCtrl, maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Contoh: Pinjaman operasional warung', fillColor: AppColors.card)),
      ],
    );
  }

  Widget _buildAttachmentSection(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _attachmentName = _attachmentName == null ? 'bukti_trf.jpg' : null),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _attachmentName != null ? AppColors.secondary : AppColors.outlineVariant)),
        child: Row(children: [
          Icon(_attachmentName != null ? Icons.check_circle_rounded : Icons.add_a_photo_outlined,
              color: _attachmentName != null ? AppColors.piutang : AppColors.secondary),
          const SizedBox(width: 10),
          Expanded(child: Text(
            _attachmentName != null
                ? 'Terlampir: $_attachmentName (Ketuk untuk hapus)'
                : '+ Lampirkan Bukti Transaksi',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}
