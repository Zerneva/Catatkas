import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:catatkas/main.dart';
import 'package:catatkas/state/ledger_store.dart';

void main() {
  testWidgets('CatatKas renders Beranda, toggles privacy, navigates, and opens Catat sheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LedgerStore();
    await store.init();

    await tester.pumpWidget(CatatKasApp(store: store));
    await tester.pumpAndSettle();

    // Should show summary with zero values
    expect(find.text('RINGKASAN KAS PRIBADI'), findsOneWidget);
    expect(find.text('Total Piutang'), findsOneWidget);
    expect(find.text('Total Hutang'), findsOneWidget);

    // Toggle privacy mode
    await tester.tap(find.text('Privasi'));
    await tester.pumpAndSettle();
    expect(find.text('Rp •••••••'), findsWidgets);

    // Toggle back
    await tester.tap(find.text('Tampilkan'));
    await tester.pumpAndSettle();

    // Navigate to Buku Kas
    await tester.tap(find.text('Buku Kas'));
    await tester.pumpAndSettle();
    expect(find.text('Total 0 Rekan Terdata'), findsOneWidget);

    // Navigate to Riwayat
    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada transaksi tercatat.'), findsOneWidget);

    // Open Catat Transaksi sheet via FAB
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Catat Transaksi'), findsOneWidget);
    expect(find.text('NOMINAL TRANSAKSI'), findsOneWidget);
  });
}
