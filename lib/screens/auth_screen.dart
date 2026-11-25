import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../state/ledger_store.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_widgets.dart';
import 'main_shell.dart';

class AuthScreen extends StatefulWidget {
  final AuthService authService;
  final LedgerStore store;
  final bool isInitialScreen;

  const AuthScreen({
    super.key,
    required this.authService,
    required this.store,
    this.isInitialScreen = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegister = false;
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscure = true;
  String? _error;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePostAuth() async {
    final user = widget.authService.currentUser;
    if (user != null) {
      await widget.store.syncFromCloud(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
      );
    }

    if (!mounted) return;

    if (widget.isInitialScreen) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainShell(
            store: widget.store,
            authService: widget.authService,
          ),
        ),
      );
    } else {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });

    final err = await widget.authService.signInWithGoogle();

    if (!mounted) return;
    if (err != null) {
      setState(() {
        _googleLoading = false;
        _error = err;
      });
      return;
    }

    // Jika user cancel Google Sign-in tanpa error
    if (!widget.authService.isLoggedIn) {
      setState(() => _googleLoading = false);
      return;
    }

    await _handlePostAuth();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final name = _nameCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty || (_isRegister && name.isEmpty)) {
      setState(() => _error = 'Mohon lengkapi semua kolom.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final err = _isRegister
        ? await widget.authService.registerWithEmail(
            email: email,
            password: pass,
            displayName: name,
          )
        : await widget.authService.signInWithEmail(
            email: email,
            password: pass,
          );

    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }

    await _handlePostAuth();
  }

  void _skipLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MainShell(
          store: widget.store,
          authService: widget.authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _loading || _googleLoading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: !widget.isInitialScreen,
        title: Text(
          _isRegister ? 'Daftar Akun' : 'Masuk Catat Kas',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (widget.isInitialScreen)
            TextButton(
              onPressed: isBusy ? null : _skipLogin,
              child: const Text(
                'Lewati',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: FadeSlideTransition(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isRegister ? 'Buat Akun Catat Kas' : 'Selamat Datang Kembali',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kelola catatan hutang & piutang dengan aman. Data otomatis tersimpan di cloud.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Google Sign In Button
                  OutlinedButton(
                    onPressed: isBusy ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.outlineVariant, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: Colors.white,
                    ),
                    child: _googleLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://lh3.googleusercontent.com/COxitqgJr1sJnIDe8-jiKhxDx1FrYbtRHKJ9zqoA1W0vJYt2503KPCKit0nTRGKMeOiPhqqnh10=s120',
                                height: 20,
                                width: 20,
                                errorBuilder: (ctx, err, stack) => const Icon(
                                  Icons.g_mobiledata_rounded,
                                  size: 26,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Masuk dengan Google',
                                style: TextStyle(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 20),

                  // Divider "atau"
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'atau dengan email',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppColors.outlineVariant)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (_isRegister) ...[
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.hutangSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.hutang, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.hutang,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: isBusy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _isRegister ? 'Daftar Akun Baru' : 'Masuk',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isBusy
                        ? null
                        : () => setState(() {
                              _isRegister = !_isRegister;
                              _error = null;
                            }),
                    child: Text(
                      _isRegister
                          ? 'Sudah punya akun? Masuk di sini'
                          : 'Belum punya akun? Buat akun baru',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
