import 'package:flutter/material.dart';
import '../api.dart';
import '../config_store.dart';
import '../ui.dart';

class LoginScreen extends StatefulWidget {
  final void Function(AdminApi api, Map<String, dynamic> user) onLoggedIn;
  const LoginScreen({super.key, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false, _obscure = true;
  String? _error, _info;

  @override
  void initState() {
    super.initState();
    final cfg = ConfigStore.read();
    _url.text = (cfg['url'] ?? 'http://localhost:8000/api').toString();
    _user.text = (cfg['username'] ?? 'admin').toString();
  }

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final api = AdminApi(_url.text);
      final h = await api.health();
      if (h['app'] != 'arsip-dokumen-pu') throw AdminApiException(0, 'Alamat ini bukan server Arsip Dokumen PU.');
      final user = await api.login(_user.text.trim(), _pass.text);
      ConfigStore.write({'url': api.baseUrl, 'username': _user.text.trim()});
      widget.onLoggedIn(api, user);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final api = AdminApi(_url.text);
      final h = await api.health();
      _url.text = api.baseUrl;
      setState(() => _info = 'Terhubung ✓  ${h['server'] ?? ''} v${h['version'] ?? ''} • ${h['agency'] ?? ''}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF141B4D), Color(0xFF3C2E7A)]),
        ),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 34),
              ),
              const Text('Admin Server', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.text)),
              const Text('Arsip Dokumen PU', textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
              const SizedBox(height: 22),
              TextField(
                controller: _url,
                decoration: field('Alamat server API', icon: Icons.dns_rounded, hint: 'http://192.168.1.10:8000/api',
                    suffix: TextButton(onPressed: _busy ? null : _test, child: const Text('Tes'))),
              ),
              const SizedBox(height: 12),
              TextField(controller: _user, decoration: field('Username admin', icon: Icons.person_rounded)),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: _obscure,
                onSubmitted: (_) => _login(),
                decoration: field('Password', icon: Icons.lock_rounded,
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    )),
              ),
              if (_info != null) ...[const SizedBox(height: 10), Text(_info!, style: const TextStyle(color: C.green, fontSize: 12.5))],
              if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: C.red, fontSize: 12.5))],
              const SizedBox(height: 18),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  style: primary(),
                  onPressed: _busy ? null : _login,
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Masuk', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Hanya akun ADMIN dari server. Lupa password? Di folder server jalankan: python reset_admin.py',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: C.muted)),
            ]),
          ),
        ),
      ),
    );
  }
}
