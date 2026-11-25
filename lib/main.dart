import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'state/ledger_store.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final authService = AuthService();
  final store = LedgerStore();
  await store.init();

  final user = authService.currentUser;
  if (user != null) {
    await store.syncFromCloud(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
    );
  }

  runApp(CatatKasApp(store: store, authService: authService));
}

class CatatKasApp extends StatelessWidget {
  final LedgerStore store;
  final AuthService? authService;

  const CatatKasApp({
    super.key,
    required this.store,
    this.authService,
  });

  @override
  Widget build(BuildContext context) {
    // Jika belum login, buka AuthScreen sebagai halaman awal
    final initialHome = (authService != null && !authService!.isLoggedIn)
        ? AuthScreen(
            authService: authService!,
            store: store,
            isInitialScreen: true,
          )
        : MainShell(store: store, authService: authService);

    return MaterialApp(
      title: 'Catat Kas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: initialHome,
    );
  }
}
