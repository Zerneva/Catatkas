import 'package:flutter/material.dart';
import '../models/ledger_models.dart';
import '../state/ledger_store.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/common_widgets.dart';
import 'catat_transaksi_sheet.dart';

class DetailRekanScreen extends StatefulWidget {
  final LedgerStore store;
  final String partnerId;

  const DetailRekanScreen({super.key, required this.store, required this.partnerId});

  @override
  State<DetailRekanScreen> createState() => _DetailRekanScreenState();
}

enum _DetailFilter { semua, pinjaman, cicilan }

class _DetailRekanScreenState extends State<DetailRekanScreen> {
  _DetailFilter _filter = _DetailFilter.semua;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final partner = widget.store.partnerById(widget.partnerId);
        if (partner == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Rekan Dihapus')),
            body: const Center(child: Text('Rekan ini sudah dihapus.')),
          );
        }
        final summary = widget.store.summaryForPartner(widget.partnerId);
        final masked = widget.store.privacyMode;

        final txs = summary.transactions.where((t) {
          if (_filter == _DetailFilter.pinjaman) return t.kind == TxKind.loan;
          if (_filter == _DetailFilter.cicilan) return t.kind != TxKind.loan;
          return true;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.card,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 0,
            shape: const Border(bottom: BorderSide(color: AppColors.outlineVariant, width: 1)),
            title: const Text('Detail Rekan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) => _handleMenu(context, v, summary),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit Rekan')),
                  const PopupMenuItem(value: 'hapus', child: Text('Hapus Rekan & Semua Data')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _buildPartnerHeader(context, partner),
                    const SizedBox(height: 16),
                    _buildBalanceCard(context, summary, masked),
                    const SizedBox(height: 14),
                    _buildPrimaryCtas(context, summary),
                    const SizedBox(height: 20),
                    _buildFilterTabs(context, summary.transactions),
                    const SizedBox(height: 12),
                    if (txs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.card, borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.outlineVariant)),
                        child: const Center(child: Text('Belum ada transaksi.')),
                      )
                    else
                      ...txs.map((tx) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildTimelineCard(context, tx, summary, masked),
                          )),
                  ],
                ),
              ),
              if (!summary.isSettled && !summary.hasNoDebt)
                _buildBottomReminderBar(context, summary),
            ],
          ),
        );
      },
    );
  }

  void _handleMenu(BuildContext context, String action, PartnerSummary summary) {
    if (action == 'edit') {
      _showEditPartnerDialog(context, summary.partner);
    } else if (action == 'hapus') {
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hapus Rekan?'),
          content: Text('Semua data transaksi ${summary.partner.name} akan dihapus permanen.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.hutang),
              onPressed: () {
                widget.store.deletePartner(summary.partner.id);
                Navigator.pop(ctx);
                Navigator.of(context).pop();
              },
              child: const Text('Hapus'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showEditPartnerDialog(BuildContext context, Partner p) async {
    final nameCtrl = TextEditingController(text: p.name);
    final phoneCtrl = TextEditingController(text: p.phone);
    final roleCtrl = TextEditingController(text: p.roleTag);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Rekan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama')),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'No. HP / WhatsApp')),
            const SizedBox(height: 10),
            TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: 'Label')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              widget.store.updatePartner(p.id,
                  name: nameCtrl.text, phone: phoneCtrl.text, roleTag: roleCtrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerHeader(BuildContext context, Partner p) {
    return Row(
      children: [
        PartnerAvatar(name: p.name, color: p.avatarColor, radius: 26, isVerified: p.isVerified),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(child: Text(p.name, style: Theme.of(context).textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis)),
                if (p.isVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded, size: 18, color: AppColors.secondary),
                ],
              ]),
              const SizedBox(height: 2),
              Text('${p.phone} • ${p.roleTag}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(BuildContext context, PartnerSummary summary, bool masked) {
    final progressPct = (summary.paymentProgress * 100).round();
    final netColor = (summary.isSettled || summary.hasNoDebt)
        ? AppColors.settled
        : (summary.isPiutang ? AppColors.piutang : AppColors.hutang);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                summary.hasNoDebt
                    ? 'Belum ada catatan hutang/piutang'
                    : summary.isSettled
                        ? 'Semua tagihan ${summary.partner.name} sudah lunas'
                        : (summary.isPiutang
                            ? 'Total Piutang Anda pada ${summary.partner.name}'
                            : 'Total Hutang Anda ke ${summary.partner.name}'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
            ),
            StatusBadge(
              label: summary.hasNoDebt ? 'Baru' : (summary.isSettled ? '✅ Lunas' : 'Belum Lunas'),
              textColor: (summary.isSettled || summary.hasNoDebt) ? AppColors.piutang : AppColors.warning,
              backgroundColor: (summary.isSettled || summary.hasNoDebt) ? AppColors.piutangSoft : AppColors.warningSoft),
          ]),
          const SizedBox(height: 8),
          AnimatedRupiahText(
            amount: summary.netBalance.abs(),
            formatter: (val) => Formatters.rupiah(val, masked: masked),
            style: AppTheme.tabular(Theme.of(context).textTheme.headlineLarge,
                fontSize: 28, color: netColor),
          ),
          if (!summary.isSettled && !summary.hasNoDebt && summary.nearestDueDate != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.hutangSoft, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.event_available_rounded, size: 15, color: AppColors.hutang),
                const SizedBox(width: 6),
                Text('Jatuh tempo: ${Formatters.shortDate(summary.nearestDueDate!)}',
                    style: const TextStyle(color: AppColors.hutang, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
          if (!summary.hasNoDebt) ...[
            const SizedBox(height: 14),
            Row(children: [
              Text('Progress Pembayaran', style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Text('$progressPct% Terbayar',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondary)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: summary.paymentProgress),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutCubic,
                builder: (context, val, _) => LinearProgressIndicator(
                  value: val,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceLow,
                  color: AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Pokok: ${Formatters.rupiah(summary.activePrincipal, masked: masked)}',
                  style: Theme.of(context).textTheme.bodySmall),
              Text('Dicicil: ${Formatters.rupiah(summary.activePaid, masked: masked)}',
                  style: Theme.of(context).textTheme.bodySmall),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryCtas(BuildContext context, PartnerSummary summary) {
    final isActive = !summary.isSettled && !summary.hasNoDebt;
    return Column(
      children: [
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                CatatTransaksiSheet.show(context, store: widget.store,
                    initialPartnerId: summary.partner.id,
                    initialDirection: summary.isHutang ? DebtDirection.hutang : DebtDirection.piutang,
                    initialKind: isActive ? TxKind.installment : TxKind.loan);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: Icon(isActive ? Icons.payments_outlined : Icons.add_rounded, size: 18),
              label: Text(isActive ? 'Catat Cicilan' : 'Catat Transaksi Baru',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                Formatters.launchWhatsApp(
                  phone: summary.partner.phone,
                  message: 'Halo ${summary.partner.name}, saya ingin mengingatkan catatan kas di CatatKas'
                      ' sebesar ${Formatters.rupiah(summary.netBalance.abs())}. Terima kasih!');
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: const Text('Tagih via WA', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
        if (isActive) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showMarkSettledDialog(context, summary),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.piutang,
                side: const BorderSide(color: AppColors.piutang),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Tandai Lunas (Sudah Dibayar Semua)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showMarkSettledDialog(BuildContext context, PartnerSummary summary) async {
    String method = 'Tunai';
    final noteCtrl = TextEditingController(text: 'Sudah lunas semua');
    final methods = ['Tunai', 'Transfer BCA', 'Transfer BRI', 'QRIS Mandiri', 'DANA', 'GoPay', 'OVO', 'ShopeePay'];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tandai Lunas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${summary.partner.name} akan dicatat telah membayar sisa tagihan '
                'sebesar ${Formatters.rupiah(summary.netBalance.abs())}.',
                style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Metode Pembayaran'),
                items: methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setDialogState(() => method = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Catatan'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton.icon(
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Konfirmasi Lunas'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.piutang),
              onPressed: () async {
                await widget.store.markAsSettled(
                  partnerId: summary.partner.id,
                  paymentMethod: method,
                  note: noteCtrl.text.trim().isEmpty ? 'Ditandai lunas' : noteCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${summary.partner.name} berhasil ditandai lunas!'),
                    behavior: SnackBarBehavior.floating));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context, List<LedgerTransaction> allTxs) {
    final cicilanCount = allTxs.where((t) => t.kind != TxKind.loan).length;
    final loanCount = allTxs.where((t) => t.kind == TxKind.loan).length;
    return Row(children: [
      _tabChip('Semua (${allTxs.length})', _filter == _DetailFilter.semua,
          () => setState(() => _filter = _DetailFilter.semua)),
      const SizedBox(width: 8),
      _tabChip('Pinjaman ($loanCount)', _filter == _DetailFilter.pinjaman,
          () => setState(() => _filter = _DetailFilter.pinjaman)),
      const SizedBox(width: 8),
      _tabChip('Cicilan ($cicilanCount)', _filter == _DetailFilter.cicilan,
          () => setState(() => _filter = _DetailFilter.cicilan)),
    ]);
  }

  Widget _tabChip(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? AppColors.primary : AppColors.outlineVariant)),
        child: Text(label, style: TextStyle(
            color: active ? Colors.white : AppColors.onSurfaceVariant,
            fontSize: 12.5, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildTimelineCard(BuildContext context, LedgerTransaction tx, PartnerSummary summary, bool masked) {
    final isInstallment = tx.kind == TxKind.installment;
    final isSettlement = tx.kind == TxKind.settlement;
    final isPayment = isInstallment || isSettlement;

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.hutang, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hapus Transaksi?'),
          content: Text('Transaksi "${tx.note.isNotEmpty ? tx.note : (isPayment ? 'Pembayaran' : 'Pinjaman')}" '
              'sebesar ${Formatters.rupiah(tx.amount)} akan dihapus.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.hutang),
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
          ],
        ),
      ),
      onDismissed: (_) {
        widget.store.deleteTransaction(tx.id);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaksi berhasil dihapus.'), behavior: SnackBarBehavior.floating));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outlineVariant)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isSettlement
                    ? AppColors.piutangSoft
                    : (isInstallment ? AppColors.piutangSoft : AppColors.hutangSoft),
                child: Icon(
                  isSettlement
                      ? Icons.check_circle_rounded
                      : (isInstallment ? Icons.call_received_rounded : Icons.call_made_rounded),
                  size: 16,
                  color: isSettlement ? AppColors.piutang
                      : (isInstallment ? AppColors.piutang : AppColors.hutang)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSettlement ? '✅ Pelunasan (Lunas)'
                          : (isInstallment ? 'Cicilan Pembayaran #${tx.installmentNumber ?? ''}' : 'Pinjaman Awal'),
                      style: Theme.of(context).textTheme.labelLarge),
                    Text(
                      '${Formatters.shortDate(tx.createdAt)} • ${Formatters.timeWib(tx.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              Text(
                Formatters.rupiah(tx.amount, masked: masked,
                    showMinus: isPayment, showPlus: !isPayment),
                style: AppTheme.tabular(Theme.of(context).textTheme.labelLarge,
                    fontSize: 14.5, color: isPayment ? AppColors.piutang : AppColors.hutang)),
            ]),
            if (tx.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(tx.note, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              StatusBadge(label: tx.paymentMethod,
                  textColor: AppColors.onSurfaceVariant, backgroundColor: AppColors.surfaceLow),
              StatusBadge(label: tx.category,
                  textColor: AppColors.secondary, backgroundColor: AppColors.secondarySoft),
            ]),
            if (tx.attachmentName != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.image_outlined, size: 16, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${tx.attachmentName} • ${tx.attachmentSizeLabel ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurface, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ],
            if (tx.agreementNote != null && tx.agreementNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Perjanjian: ${tx.agreementNote}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            ],
            // Swipe hint
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('← Geser untuk hapus',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10, color: AppColors.outline, fontStyle: FontStyle.italic)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomReminderBar(BuildContext context, PartnerSummary summary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(color: AppColors.primary),
      child: SafeArea(
        top: false,
        child: Row(children: [
          const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Tagihan aktif ${summary.partner.name} masih berjalan',
            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500))),
          FilledButton(
            onPressed: () {
              Formatters.launchWhatsApp(
                phone: summary.partner.phone,
                message: 'Halo ${summary.partner.name}, mengingatkan catatan kas sebesar '
                    '${Formatters.rupiah(summary.netBalance.abs())}. Terima kasih!');
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Ingatkan', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}
