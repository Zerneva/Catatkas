import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/update_service.dart';
import '../state/ledger_store.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/common_widgets.dart';
import 'auth_screen.dart';

class PengaturanScreen extends StatelessWidget {
  final LedgerStore store;
  final AuthService? authService;

  const PengaturanScreen({
    super.key,
    required this.store,
    this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CatatKasAppBar(subtitle: 'Pengaturan'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          FadeSlideTransition(
            delay: Duration.zero,
            child: Container(
              padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.person_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.userName, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        store.userEmail != null
                            ? 'Tersinkron: ${store.userEmail}'
                            : 'Penyimpanan Lokal Offline Aktif',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _editNameDialog(context),
                  child: const Text('Ubah'),
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 16),
          FadeSlideTransition(
            delay: const Duration(milliseconds: 80),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant),
              ),
            child: Column(
              children: [
                if (authService != null) ...[
                  ListTile(
                    leading: Icon(
                      store.userEmail != null ? Icons.cloud_done_rounded : Icons.login_rounded,
                      color: store.userEmail != null ? AppColors.piutang : AppColors.secondary,
                    ),
                    title: Text(store.userEmail != null ? 'Akun Terhubung' : 'Masuk / Hubungkan Akun'),
                    subtitle: Text(
                      store.userEmail != null
                          ? 'Data otomatis tersinkron dengan ${store.userEmail}'
                          : 'Masuk dengan Google atau Email agar data aman',
                    ),
                    trailing: store.userEmail != null
                        ? TextButton(
                            onPressed: () async {
                              await authService!.signOut();
                              await store.clearCloudUser();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Berhasil keluar dari akun.')),
                                );
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => AuthScreen(
                                      authService: authService!,
                                      store: store,
                                      isInitialScreen: true,
                                    ),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                            child: const Text('Keluar', style: TextStyle(color: AppColors.hutang)),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: store.userEmail != null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              SmoothPageRoute(
                                page: AuthScreen(
                                  authService: authService!,
                                  store: store,
                                  isInitialScreen: false,
                                ),
                              ),
                            );
                          },
                  ),
                  const Divider(height: 1, color: AppColors.outlineVariant),
                ],
                SwitchListTile(
                  title: const Text('Mode Privasi Saldo'),
                  subtitle: const Text('Sembunyikan nominal Rupiah di layar utama'),
                  value: store.privacyMode,
                  onChanged: (_) => store.togglePrivacyMode(),
                ),
                const Divider(height: 1, color: AppColors.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.system_update_rounded, color: AppColors.secondary),
                  title: const Text('Cek Pembaruan Aplikasi'),
                  subtitle: const Text('Periksa versi terbaru dari GitHub Releases'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => UpdateService.checkForUpdate(
                    context,
                    showNoUpdateMessage: true,
                  ),
                ),
                const Divider(height: 1, color: AppColors.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_rounded, color: AppColors.hutang),
                  title: const Text('Kosongkan Semua Data'),
                  subtitle: const Text('Hapus seluruh rekan dan riwayat transaksi untuk mulai dari nol'),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Kosongkan Data?'),
                        content: const Text('Semua catatan hutang/piutang dan rekan akan dihapus.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.hutang),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Hapus Semua'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await store.clearAllData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Semua data berhasil dikosongkan.')),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 1, color: AppColors.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.restore_rounded, color: AppColors.secondary),
                  title: const Text('Isi Data Contoh (Demo)'),
                  subtitle: const Text('Muat kembali contoh data CatatKas'),
                  onTap: () async {
                    await store.resetDemoData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Data demo berhasil dimuat.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }

  Future<void> _editNameDialog(BuildContext context) async {
    final ctrl = TextEditingController(text: store.userName);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Nama Pengguna'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nama Lengkap'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              store.setUserName(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
