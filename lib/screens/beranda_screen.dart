import 'package:flutter/material.dart';
import '../models/ledger_models.dart';
import '../state/ledger_store.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/common_widgets.dart';
import 'catat_transaksi_sheet.dart';
import 'detail_rekan_screen.dart';

class BerandaScreen extends StatelessWidget {
  final LedgerStore store;
  final VoidCallback onNavigateBukuKas;
  final VoidCallback onNavigateRiwayat;

  const BerandaScreen({
    super.key,
    required this.store,
    required this.onNavigateBukuKas,
    required this.onNavigateRiwayat,
  });

  @override
  Widget build(BuildContext context) {
    final masked = store.privacyMode;
    final upcoming = store.upcomingDueSummaries.take(3).toList();
    final recentTxs = store.transactions.take(4).toList();
    final hasData = store.partners.isNotEmpty;

    return Scaffold(
      appBar: const CatatKasAppBar(subtitle: 'Beranda'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          FadeSlideTransition(
            delay: Duration.zero,
            child: _buildGreetingHeader(context),
          ),
          const SizedBox(height: 16),
          FadeSlideTransition(
            delay: const Duration(milliseconds: 60),
            child: _buildDualSummaryCard(context, masked),
          ),
          const SizedBox(height: 16),
          FadeSlideTransition(
            delay: const Duration(milliseconds: 120),
            child: _buildQuickActionPills(context),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            context,
            title: 'Jatuh Tempo Terdekat',
            actionLabel: 'Lihat Semua',
            onTap: onNavigateBukuKas,
          ),
          const SizedBox(height: 12),
          if (!hasData || upcoming.isEmpty)
            _buildEmptyCard(context,
                hasData ? 'Tidak ada tagihan jatuh tempo.' : 'Belum ada data. Mulai catat transaksi pertama Anda!')
          else
            ...upcoming.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FadeSlideTransition(
                    delay: Duration(milliseconds: 150 + (entry.key * 60)),
                    child: _buildDueCard(context, entry.value, masked),
                  ),
                )),
          const SizedBox(height: 20),
          _buildSectionHeader(
            context,
            title: 'Aktivitas Terkini',
            actionLabel: 'Riwayat',
            onTap: onNavigateRiwayat,
          ),
          const SizedBox(height: 12),
          if (recentTxs.isEmpty)
            _buildEmptyCard(context, 'Belum ada transaksi tercatat.')
          else
            FadeSlideTransition(
              delay: const Duration(milliseconds: 220),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < recentTxs.length; i++) ...[
                      _buildActivityTile(context, recentTxs[i], masked),
                      if (i < recentTxs.length - 1)
                        const Divider(height: 1, indent: 60, color: AppColors.outlineVariant),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          FadeSlideTransition(
            delay: const Duration(milliseconds: 280),
            child: _buildFinanceTipBanner(context),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 11 ? 'Selamat pagi' : (hour < 15 ? 'Selamat siang' : (hour < 18 ? 'Selamat sore' : 'Selamat malam'));
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary,
          child: Text(
            Formatters.initials(store.userName),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, 👋',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant, fontSize: 12.5),
              ),
              Text(store.userName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const StatusBadge(
          label: 'Tersinkron',
          textColor: AppColors.piutang,
          backgroundColor: AppColors.piutangSoft,
          icon: Icons.verified_user_rounded,
        ),
      ],
    );
  }

  Widget _buildDualSummaryCard(BuildContext context, bool masked) {
    final net = store.netSaldo;
    final isSurplus = net >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('RINGKASAN KAS PRIBADI',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w700)),
              const Spacer(),
              InkWell(
                onTap: store.togglePrivacyMode,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        masked ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 14, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(masked ? 'Tampilkan' : 'Privasi',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _summaryTile(context, 'Total Piutang', 'Hak Anda',
                  store.totalPiutang, masked, AppColors.piutang, AppColors.piutangSoft,
                  '${store.piutangPartnerCount} orang rekan', Icons.south_west_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _summaryTile(context, 'Total Hutang', 'Kewajiban',
                  store.totalHutang, masked, AppColors.hutang, AppColors.hutangSoft,
                  '${store.hutangPartnerCount} pihak terkait', Icons.north_east_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Text(isSurplus ? 'Saldo Bersih (Surplus)' : 'Saldo Bersih (Defisit)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  Formatters.rupiahSigned(net, masked: masked),
                  style: AppTheme.tabular(Theme.of(context).textTheme.labelLarge,
                      fontSize: 14, color: isSurplus ? AppColors.piutang : AppColors.hutang),
                ),
                const SizedBox(width: 8),
                StatusBadge(
                  label: isSurplus ? 'Aman' : 'Perhatian',
                  textColor: isSurplus ? AppColors.piutang : AppColors.hutang,
                  backgroundColor: isSurplus ? AppColors.piutangSoft : AppColors.hutangSoft,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(BuildContext context, String title, String subtitle,
      int amount, bool masked, Color color, Color bg, String footer, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
          ]),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.rupiah(amount, masked: masked),
              style: AppTheme.tabular(Theme.of(context).textTheme.titleMedium,
                  fontSize: 18, color: color),
            ),
          ),
          const SizedBox(height: 4),
          Text('dari $footer', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildQuickActionPills(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: () => CatatTransaksiSheet.show(context, store: store),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            icon: const Icon(Icons.bolt_rounded, size: 17),
            label: const Text('Catat Cepat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          _outlinedPill(context, Icons.chat_bubble_outline_rounded, 'Kirim Tagihan WA',
              AppColors.piutang, () async {
            final target = store.upcomingDueSummaries.isNotEmpty
                ? store.upcomingDueSummaries.first : null;
            if (target == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tidak ada tagihan aktif.'), behavior: SnackBarBehavior.floating));
              return;
            }
            final phone = target.partner.phone.trim();
            if (phone.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nomor HP rekan ini belum diisi.'), behavior: SnackBarBehavior.floating),
              );
              return;
            }
            final ok = await Formatters.launchWhatsApp(
              phone: phone,
              message: 'Halo ${target.partner.name}, mengingatkan catatan sebesar '
                  '${Formatters.rupiah(target.netBalance.abs())} yang akan jatuh tempo. Terima kasih!',
            );
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tidak dapat membuka WhatsApp. Pastikan WhatsApp terpasang.'), behavior: SnackBarBehavior.floating),
              );
            }
          }),
        ],
      ),
    );
  }

  Widget _outlinedPill(BuildContext context, IconData icon, String label, Color iconColor, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.onSurface,
        side: const BorderSide(color: AppColors.outlineVariant),
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
      icon: Icon(icon, size: 16, color: iconColor),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildSectionHeader(BuildContext context,
      {required String title, required String actionLabel, required VoidCallback onTap}) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700, fontSize: 16)),
        const Spacer(),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(children: [
              Text(actionLabel, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.secondary)),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.secondary),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildDueCard(BuildContext context, PartnerSummary summary, bool masked) {
    final due = summary.nearestDueDate!;
    final daysLeft = due.difference(DateTime.now()).inDays;
    final isUrgent = daysLeft <= 1;
    final isPiutang = summary.isPiutang;
    return InkWell(
      onTap: () => _pushDetail(context, summary.partner.id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUrgent ? AppColors.hutang.withValues(alpha: 0.35) : AppColors.outlineVariant)),
        child: Row(
          children: [
            PartnerAvatar(name: summary.partner.name, color: summary.partner.avatarColor,
                isVerified: summary.partner.isVerified),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(summary.partner.name,
                        style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    StatusBadge(
                      label: isUrgent ? 'MENDESAK' : (isPiutang ? 'Mendatang' : 'Perlu Bayar'),
                      textColor: isUrgent ? AppColors.hutang : (isPiutang ? AppColors.settled : AppColors.warning),
                      backgroundColor: isUrgent ? AppColors.hutangSoft : (isPiutang ? AppColors.settledBg : AppColors.warningSoft)),
                  ]),
                  const SizedBox(height: 3),
                  Text('Jatuh tempo ${Formatters.shortDate(due)}',
                      style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Formatters.rupiah(summary.netBalance.abs(), masked: masked),
                    style: AppTheme.tabular(Theme.of(context).textTheme.labelLarge,
                        fontSize: 14, color: isPiutang ? AppColors.piutang : AppColors.hutang)),
                const SizedBox(height: 6),
                _actionPill(context, isPiutang ? 'Tagih' : 'Bayar',
                    isPiutang ? Icons.send_rounded : Icons.payments_outlined,
                    isPiutang ? AppColors.piutang : AppColors.primary, () async {
                  if (isPiutang) {
                    final phone = summary.partner.phone.trim();
                    if (phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nomor HP rekan ini belum diisi.'), behavior: SnackBarBehavior.floating),
                      );
                      return;
                    }
                    final ok = await Formatters.launchWhatsApp(
                      phone: phone,
                      message: 'Halo ${summary.partner.name}, mengingatkan catatan piutang sebesar '
                          '${Formatters.rupiah(summary.netBalance.abs())} jatuh tempo '
                          '${Formatters.shortDate(due)}. Terima kasih!',
                    );
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tidak dapat membuka WhatsApp. Pastikan WhatsApp terpasang.'), behavior: SnackBarBehavior.floating),
                      );
                    }
                  } else {
                    CatatTransaksiSheet.show(context, store: store,
                        initialPartnerId: summary.partner.id,
                        initialDirection: DebtDirection.hutang, initialKind: TxKind.installment);
                  }
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionPill(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _buildActivityTile(BuildContext context, LedgerTransaction tx, bool masked) {
    final partner = store.partnerById(tx.partnerId);
    final isInstallment = tx.kind == TxKind.installment || tx.kind == TxKind.settlement;
    final isPiutang = tx.direction == DebtDirection.piutang;
    final isSettlement = tx.kind == TxKind.settlement;
    final title = isSettlement
        ? 'Lunas • ${partner?.name ?? ''}'
        : isInstallment
            ? 'Cicilan ${isPiutang ? 'Diterima' : 'Dibayar'} • ${partner?.name ?? ''}'
            : '${isPiutang ? 'Piutang Baru' : 'Hutang Baru'} • ${partner?.name ?? ''}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: CircleAvatar(
        radius: 19,
        backgroundColor: isSettlement
            ? AppColors.settledBg
            : (isInstallment ? AppColors.piutangSoft : AppColors.secondarySoft),
        child: Icon(
          isSettlement
              ? Icons.check_circle_outline_rounded
              : (isInstallment ? Icons.call_received_rounded : Icons.receipt_long_rounded),
          size: 18,
          color: isSettlement
              ? AppColors.settled
              : (isInstallment ? AppColors.piutang : AppColors.secondary)),
      ),
      title: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13.5),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        tx.note.isNotEmpty ? '${tx.note} • ${tx.paymentMethod}' : tx.paymentMethod,
        style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Formatters.rupiah(tx.amount, masked: masked,
                showPlus: isInstallment && isPiutang),
            style: AppTheme.tabular(Theme.of(context).textTheme.labelLarge,
                fontSize: 13.5, color: isInstallment ? AppColors.piutang : AppColors.onSurface)),
          const SizedBox(height: 2),
          Text(Formatters.timeWib(tx.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5)),
        ],
      ),
      onTap: partner == null ? null : () => _pushDetail(context, partner.id),
    );
  }

  Widget _buildFinanceTipBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: AppColors.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tips Keuangan Aman',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.secondaryDark)),
                const SizedBox(height: 3),
                Text(
                  'Gunakan fitur pengingat WhatsApp 1-klik sebelum tanggal jatuh tempo agar arus kas tetap sehat.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant)),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, size: 32, color: AppColors.outline),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _pushDetail(BuildContext context, String partnerId) {
    Navigator.of(context).push(
      SmoothPageRoute(page: DetailRekanScreen(store: store, partnerId: partnerId)));
  }
}
