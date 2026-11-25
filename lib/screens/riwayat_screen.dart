import 'package:flutter/material.dart';
import '../models/ledger_models.dart';
import '../state/ledger_store.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/common_widgets.dart';
import 'detail_rekan_screen.dart';

enum _StatusFilter { semua, belumLunas, lunas, cicilan }
enum _TypeFilter { semua, piutang, hutang }

class RiwayatScreen extends StatefulWidget {
  final LedgerStore store;
  const RiwayatScreen({super.key, required this.store});
  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  _StatusFilter _statusFilter = _StatusFilter.semua;
  _TypeFilter _typeFilter = _TypeFilter.semua;
  bool _newestFirst = true;
  String _searchQuery = '';
  bool _showSearch = false;

  @override
  Widget build(BuildContext context) {
    final masked = widget.store.privacyMode;
    final allTxs = widget.store.transactions;

    final filtered = allTxs.where((tx) {
      final partner = widget.store.partnerById(tx.partnerId);
      if (partner == null) return false;
      final summary = widget.store.summaryForPartner(tx.partnerId);

      if (_statusFilter == _StatusFilter.belumLunas && (summary.isSettled || summary.hasNoDebt)) return false;
      if (_statusFilter == _StatusFilter.lunas && !summary.isSettled) return false;
      if (_statusFilter == _StatusFilter.cicilan && tx.kind == TxKind.loan) return false;
      if (_typeFilter == _TypeFilter.piutang && tx.direction != DebtDirection.piutang) return false;
      if (_typeFilter == _TypeFilter.hutang && tx.direction != DebtDirection.hutang) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return (partner.name.toLowerCase().contains(q)) || tx.note.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    filtered.sort((a, b) =>
        _newestFirst ? b.createdAt.compareTo(a.createdAt) : a.createdAt.compareTo(b.createdAt));

    final now = DateTime.now();
    final grouped = <String, List<LedgerTransaction>>{};
    for (final tx in filtered) {
      final key = Formatters.relativeGroupLabel(tx.createdAt, now);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    return Scaffold(
      appBar: CatatKasAppBar(subtitle: 'Riwayat Transaksi', actions: [
        IconButton(
          tooltip: 'Cari',
          icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
          onPressed: () => setState(() { _showSearch = !_showSearch; if (!_showSearch) _searchQuery = ''; }),
        ),
        IconButton(tooltip: 'Urutkan', icon: const Icon(Icons.swap_vert_rounded),
            onPressed: () => setState(() => _newestFirst = !_newestFirst)),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          if (_showSearch) ...[
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(
                hintText: 'Cari nama rekan atau catatan...', prefixIcon: Icon(Icons.search_rounded),
                fillColor: AppColors.card)),
            const SizedBox(height: 12),
          ],
          FadeSlideTransition(
            delay: Duration.zero,
            child: _buildStatusPills(context, allTxs),
          ),
          const SizedBox(height: 8),
          FadeSlideTransition(
            delay: const Duration(milliseconds: 50),
            child: _buildTypePills(context),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: grouped.isEmpty
                ? FadeSlideTransition(
                    key: const ValueKey('empty'),
                    delay: const Duration(milliseconds: 80),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Column(children: [
                        const Icon(Icons.inbox_rounded, size: 32, color: AppColors.outline),
                        const SizedBox(height: 8),
                        Text(
                          allTxs.isEmpty
                              ? 'Belum ada transaksi tercatat.'
                              : 'Tidak ada transaksi pada filter ini.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ]),
                    ),
                  )
                : Column(
                    key: ValueKey('$_statusFilter-$_typeFilter-$_newestFirst-$_searchQuery'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: grouped.entries.map((entry) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 4),
                          child: Row(children: [
                            Text(entry.key, style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.onSurfaceVariant)),
                            const Spacer(),
                            Text('${entry.value.length} Transaksi', style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        ),
                        ...entry.value.asMap().entries.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FadeSlideTransition(
                            delay: Duration(milliseconds: (item.key * 40).clamp(0, 240)),
                            child: _buildTxCard(context, item.value, masked),
                          ),
                        )),
                      ],
                    )).toList(),
                  ),
          ),
          const SizedBox(height: 12),
          Center(child: Text('Semua Catatan Ditampilkan',
              style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }

  Widget _buildStatusPills(BuildContext context, List<LedgerTransaction> allTxs) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _chip('Semua ${allTxs.length}', _statusFilter == _StatusFilter.semua,
            () => setState(() => _statusFilter = _StatusFilter.semua)),
        const SizedBox(width: 8),
        _chip('Belum Lunas', _statusFilter == _StatusFilter.belumLunas,
            () => setState(() => _statusFilter = _StatusFilter.belumLunas)),
        const SizedBox(width: 8),
        _chip('Sudah Lunas', _statusFilter == _StatusFilter.lunas,
            () => setState(() => _statusFilter = _StatusFilter.lunas)),
        const SizedBox(width: 8),
        _chip('Cicilan', _statusFilter == _StatusFilter.cicilan,
            () => setState(() => _statusFilter = _StatusFilter.cicilan)),
      ]),
    );
  }

  Widget _buildTypePills(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _chip('Semua Tipe', _typeFilter == _TypeFilter.semua,
            () => setState(() => _typeFilter = _TypeFilter.semua), secondary: true),
        const SizedBox(width: 8),
        _chip('Piutang (Masuk)', _typeFilter == _TypeFilter.piutang,
            () => setState(() => _typeFilter = _TypeFilter.piutang), secondary: true),
        const SizedBox(width: 8),
        _chip('Hutang (Keluar)', _typeFilter == _TypeFilter.hutang,
            () => setState(() => _typeFilter = _TypeFilter.hutang), secondary: true),
      ]),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {bool secondary = false}) {
    final activeColor = secondary ? AppColors.secondary : AppColors.primary;
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? activeColor : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? activeColor : AppColors.outlineVariant)),
        child: Text(label, style: TextStyle(
            color: selected ? Colors.white : AppColors.onSurfaceVariant,
            fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildTxCard(BuildContext context, LedgerTransaction tx, bool masked) {
    final partner = widget.store.partnerById(tx.partnerId);
    if (partner == null) return const SizedBox.shrink();
    final isInstallment = tx.kind == TxKind.installment;
    final isSettlement = tx.kind == TxKind.settlement;
    final isPayment = isInstallment || isSettlement;
    final isPiutang = tx.direction == DebtDirection.piutang;

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
          content: Text('Transaksi ${Formatters.rupiah(tx.amount)} akan dihapus permanen.'),
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
            const SnackBar(content: Text('Transaksi dihapus.'), behavior: SnackBarBehavior.floating));
      },
      child: InkWell(
        onTap: () => Navigator.of(context).push(
            SmoothPageRoute(page: DetailRekanScreen(store: widget.store, partnerId: partner.id))),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outlineVariant)),
          child: Row(children: [
            PartnerAvatar(name: partner.name, color: partner.avatarColor, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(partner.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.5),
                        overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    StatusBadge(
                      label: isSettlement ? '✅ Lunas'
                          : (isInstallment ? 'Cicilan #${tx.installmentNumber ?? 1}' : 'Pinjaman'),
                      textColor: isSettlement ? AppColors.piutang
                          : (isInstallment ? AppColors.secondary : AppColors.warning),
                      backgroundColor: isSettlement ? AppColors.piutangSoft
                          : (isInstallment ? AppColors.secondarySoft : AppColors.warningSoft)),
                  ]),
                  const SizedBox(height: 3),
                  Text(tx.note.isNotEmpty ? tx.note : tx.category,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${Formatters.timeWib(tx.createdAt)} • ${tx.paymentMethod}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Formatters.rupiah(tx.amount, masked: masked,
                  showPlus: isPayment && isPiutang, showMinus: !isPiutang && !isPayment),
              style: AppTheme.tabular(Theme.of(context).textTheme.labelLarge,
                  fontSize: 13.5, color: isPayment ? AppColors.piutang : AppColors.onSurface)),
          ]),
        ),
      ),
    );
  }
}
