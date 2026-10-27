import 'package:flutter/material.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../services/tray_service.dart';
import '../widgets/login_hero_background.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await AppState.instance.login(_userCtrl.text, _passCtrl.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: LoginHeroBackground()),
          // Bar atas: status server + tombol full screen + keluar
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Row(
              children: [
                const ArsipLogo(size: 30),
                const SizedBox(width: 10),
                const Text('Arsip Dokumen PU', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                ListenableBuilder(listenable: app, builder: (_, __) => NetStatusPill(status: app.net, onDark: true)),
                const SizedBox(width: 12),
                _TopIcon(icon: Icons.south_east_rounded, tooltip: 'Kecilkan ke system tray', onTap: TrayService.hideToTray),
                const SizedBox(width: 6),
                _TopIcon(icon: Icons.fullscreen_rounded, tooltip: 'Full screen (F11)', onTap: toggleFullScreen),
                const SizedBox(width: 6),
                _TopIcon(icon: Icons.power_settings_new_rounded, tooltip: 'Keluar aplikasi', onTap: () => confirmExit(context)),
              ],
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: 380,
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 26),
                decoration: BoxDecoration(
                  color: YmColors.cardGlass,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 40, offset: const Offset(0, 16))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: ArsipLogo(size: 78)),
                    const SizedBox(height: 14),
                    const Center(
                      child: Text('Arsip Dokumen PU', style: TextStyle(
                        fontFamily: 'Tahoma', fontFamilyFallback: ['Segoe UI', 'Arial'],
                        fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white,
                      )),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: ListenableBuilder(
                        listenable: app,
                        builder: (_, __) => Text(
                          app.settings.connected ? app.agencyName : 'Arsip Proyek Jalan • Jembatan • Gedung',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _DarkField(controller: _userCtrl, hint: 'Username', icon: Icons.person_outline, onSubmitted: (_) => _submit()),
                    const SizedBox(height: 12),
                    _DarkField(
                      controller: _passCtrl,
                      hint: 'Password',
                      icon: Icons.lock_outline,
                      obscure: _obscure,
                      onSubmitted: (_) => _submit(),
                      suffix: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 18, color: Colors.white70),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 12, height: 1.4)),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: YmColors.accentPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Masuk', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListenableBuilder(listenable: app, builder: (_, __) => _LoginHint(app: app)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginHint extends StatelessWidget {
  final AppState app;
  const _LoginHint({required this.app});

  @override
  Widget build(BuildContext context) {
    final String text;
    final IconData icon;
    if (app.setupMode) {
      icon = Icons.info_outline;
      text = 'Mode awal: belum terhubung ke server.\nMasuk dengan administrator / administrator, lalu atur alamat API.';
    } else if (app.net == NetStatus.offline) {
      icon = Icons.wifi_off_rounded;
      final n = app.users.where((u) => u.active && u.hash.isNotEmpty).length;
      text = 'Server tidak terjangkau — MODE OFFLINE.\n'
          '$n akun (admin & staf) tersimpan di PC ini dan tetap bisa login. Dokumen yang disimpan akan terkirim otomatis saat server online.';
    } else {
      icon = Icons.dns_rounded;
      final name = app.settings.serverName.isEmpty ? '' : ' (${app.settings.serverName})';
      final n = app.users.where((u) => u.active && u.hash.isNotEmpty).length;
      text = 'Terhubung ke ${app.settings.apiUrl}$name\n'
          'Masuk dengan akun dari server. Admin bawaan server: admin / Admin@12345.\n'
          '$n akun (admin & staf) tersimpan di PC ini, tetap bisa login walau server mati.';
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.white54),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 11.5, height: 1.4, color: Colors.white.withOpacity(0.65)))),
      ],
    );
  }
}

class _TopIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _TopIcon({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  const _DarkField({required this.controller, required this.hint, required this.icon, this.obscure = false, this.suffix, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13.5),
        prefixIcon: Icon(icon, color: Colors.white70, size: 18),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        filled: true,
        fillColor: YmColors.fieldFillOnDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: YmColors.accentPurple, width: 1.5),
        ),
      ),
    );
  }
}
