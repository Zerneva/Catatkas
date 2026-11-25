import 'package:flutter/material.dart';
import '../models/ledger_models.dart';
import '../state/ledger_store.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/common_widgets.dart';
import 'detail_rekan_screen.dart';

enum _BukuFilter { semua, hutang, piutang }

enum _BukuSort { tertinggi, nama }

class BukuKasScreen extends StatefulWidget {
  final LedgerStore store;

  const BukuKasScreen({super.key, required this.store});

  @override
  State<BukuKasScreen> createState() => _BukuKasScreenState();
}

class _BukuKasScreenState extends State<BukuKasScreen> {
  final _searchCtrl = TextEditingController();
  _BukuFilter _filter = _BukuFilter.semua;
  _BukuSort _sort = _BukuSort.tertinggi;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final masked = widget.store.privacyMode;
    final all = widget.store.allPartnerSummaries;
    final query = _searchCtrl.text.trim().toLowerCase();

    final hutangCount = all.where((s) => s.isHutang).length;
    final piutangCount = all.where((s) => s.isPiutang).length;

    final filtered = all.where((s) {
      if (_filter == _BukuFilter.hutang && !s.isHutang) return false;
      if (_filter == _BukuFilter.piutang && !s.isPiutang) return false;
      if (query.isNotEmpty) {
        final matchName = s.partner.name.toLowerCase().contains(query);
        final matchPhone = s.partner.phone.toLowerCase().contains(query);
        return matchName || matchPhone;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (_sort == _BukuSort.tertinggi) {
        return b.netBalance.abs().compareTo(a.netBalance.abs());
      }
      return a.partner.name.compareTo(b.partner.name);
    });

    return Scaffold(
      appBar: const CatatKasAppBar(subtitle: 'Buku Kas'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          _buildSearchBar(context),
          const SizedBox(height: 12),
          _buildSegmentedPills(context, all.length, hutangCount, piutangCount),
          const SizedBox(height: 14),
          _buildSummaryStrip(context, all.length, masked),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: const Center(
                child: Text('Tidak ada rekan yang sesuai pencarian.'),
              ),
            )
          else
            ...filtered.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FadeSlideTransition(
                    delay: Duration(milliseconds: (entry.key * 40).clamp(0, 300)),
                    child: _buildPartnerCard(context, entry.value, masked),
                  ),
                )),
          const SizedBox(height: 10),
          _buildAddPartnerBanner(context),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return TextField(
      controller: _searchCtrl,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Cari nama atau nomor telepon...',
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.outline),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_searchCtrl.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {});
                },
              ),
            IconButton(
              tooltip: 'Tambah Rekan Baru',
              icon: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.secondary),
              onPressed: () => _showAddPartnerDialog(context),
            ),
          ],
        ),
        fillColor: AppColors.card,
      ),
    );
  }

  Widget _buildSegmentedPills(
      BuildContext context, int total, int hutangCount, int piutangCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterPill(
            label: 'Semua $total',
            selected: _filter == _BukuFilter.semua,
            onTap: () => setState(() => _filter = _BukuFilter.semua),
          ),
          const SizedBox(width: 8),
          _filterPill(
            label: 'Saya Berhutang $hutangCount',
            dotColor: AppColors.hutang,
            selected: _filter == _BukuFilter.hutang,
            onTap: () => setState(() => _filter = _BukuFilter.hutang),
          ),
          const SizedBox(width: 8),
          _filterPill(
            label: 'Orang Berhutang $piutangCount',
            dotColor: AppColors.piutang,
            selected: _filter == _BukuFilter.piutang,
            onTap: () => setState(() => _filter = _BukuFilter.piutang),
          ),
        ],
      ),
    );
  }

  Widget _filterPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? dotColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.onSurfaceVariant,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStrip(BuildContext context, int count, bool masked) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total $count Rekan Terdata',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 2),
              Text(
                '↓ ${Formatters.rupiah(widget.store.totalPiutang, masked: masked)}  •  ↑ ${Formatters.rupiah(widget.store.totalHutang, masked: masked)}',
                style: AppTheme.tabular(
                  Theme.of(context).textTheme.bodySmall,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () {
            setState(() {
              _sort = _sort == _BukuSort.tertinggi ? _BukuSort.nama : _BukuSort.tertinggi;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swap_vert_rounded, size: 15, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  _sort == _BukuSort.tertinggi ? 'Tertinggi' : 'Nama A-Z',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurface,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerCard(BuildContext context, PartnerSummary summary, bool masked) {
    final p = summary.partner;
    final isSettled = summary.isSettled;
    final isPiutang = summary.isPiutang;

    String statusText = 'Lunas';
    Color statusColor = AppColors.settled;
    Color statusBg = AppColors.settledBg;

    if (!isSettled && summary.nearestDueDate != null) {
      final days = summary.nearestDueDate!.difference(DateTime.now()).inDays;
      if (days <= 1) {
        statusText = 'Jatuh tempo besok';
        statusColor = AppColors.hutang;
        statusBg = AppColors.hutangSoft;
      } else if (days <= 5) {
        statusText = 'Tempo $days hari';
        statusColor = AppColors.warning;
        statusBg = AppColors.warningSoft;
      } else {
        statusText = 'Tempo ${Formatters.dayMonth(summary.nearestDueDate!)}';
        statusColor = AppColors.piutang;
        statusBg = AppColors.piutangSoft;
      }
    }

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          SmoothPageRoute(
            page: DetailRekanScreen(store: widget.store, partnerId: p.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            PartnerAvatar(
              name: p.name,
              color: p.avatarColor,
              isVerified: p.isVerified,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.name,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      StatusBadge(
                        label: statusText,
                        textColor: statusColor,
                        backgroundColor: statusBg,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${p.phone} • ${summary.transactions.length} transaksi',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSettled
                        ? 'Semua tagihan selesai'
                        : (isPiutang ? 'Berhutang ke Anda' : 'Anda Berhutang'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isSettled
                              ? AppColors.settled
                              : (isPiutang ? AppColors.piutang : AppColors.hutang),
                        ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.rupiah(summary.netBalance.abs(), masked: masked),
                  style: AppTheme.tabular(
                    Theme.of(context).textTheme.labelLarge,
                    fontSize: 14.5,
                    color: isSettled
                        ? AppColors.settled
                        : (isPiutang ? AppColors.piutang : AppColors.hutang),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () async {
                        final phone = p.phone.trim();
                        if (phone.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nomor HP rekan ini belum diisi.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        final ok = await Formatters.launchWhatsApp(
                          phone: phone,
                          message:
                              'Halo ${p.name}, berikut catatan kas kita di CatatKas sebesar ${Formatters.rupiah(summary.netBalance.abs())}.',
                        );
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tidak dapat membuka WhatsApp. Pastikan WhatsApp terpasang.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.piutangSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.chat_rounded,
                          size: 16,
                          color: AppColors.piutang,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.outline),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPartnerBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.secondarySoft,
            child: Icon(Icons.contacts_outlined, color: AppColors.secondary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tambah Rekan Baru',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  'Catat kontak teman, supplier, atau pelanggan',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => _showAddPartnerDialog(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddPartnerDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: 'Pribadi / Teman');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Rekan Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama Lengkap'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor WhatsApp / HP'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: roleCtrl,
              decoration: const InputDecoration(labelText: 'Label (mis. Rekan UMKM)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await widget.store.addPartner(
                name: nameCtrl.text,
                phone: phoneCtrl.text.isEmpty ? '0812-0000-0000' : phoneCtrl.text,
                roleTag: roleCtrl.text.isEmpty ? 'Rekan' : roleCtrl.text,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
