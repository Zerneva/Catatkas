import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/update_service.dart';
import '../state/ledger_store.dart';
import '../theme/app_theme.dart';
import 'beranda_screen.dart';
import 'buku_kas_screen.dart';
import 'catat_transaksi_sheet.dart';
import 'pengaturan_screen.dart';
import 'riwayat_screen.dart';

class MainShell extends StatefulWidget {
  final LedgerStore store;
  final AuthService? authService;

  const MainShell({super.key, required this.store, this.authService});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UpdateService.checkForUpdate(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final screens = [
          BerandaScreen(
            store: widget.store,
            onNavigateBukuKas: () => setState(() => _index = 1),
            onNavigateRiwayat: () => setState(() => _index = 2),
          ),
          BukuKasScreen(store: widget.store),
          RiwayatScreen(store: widget.store),
          PengaturanScreen(store: widget.store, authService: widget.authService),
        ];

        return Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_index),
              child: screens[_index],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => CatatTransaksiSheet.show(context, store: widget.store),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            tooltip: 'Catat Transaksi Baru',
            child: const Icon(Icons.add_rounded, size: 28),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomAppBar(
            color: AppColors.card,
            surfaceTintColor: Colors.transparent,
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            elevation: 8,
            height: 66,
            padding: EdgeInsets.zero,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Beranda'),
                _navItem(1, Icons.menu_book_rounded, Icons.menu_book_outlined, 'Buku Kas'),
                const SizedBox(width: 52),
                _navItem(2, Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Riwayat'),
                _navItem(3, Icons.tune_rounded, Icons.tune_outlined, 'Pengaturan'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _navItem(int idx, IconData activeIcon, IconData inactiveIcon, String label) {
    final selected = _index == idx;
    return InkWell(
      onTap: () => setState(() => _index = idx),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? activeIcon : inactiveIcon,
              color: selected ? AppColors.primary : AppColors.outline,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
