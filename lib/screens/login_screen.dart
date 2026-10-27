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
      backgroundColor: YmColors.ink,
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 980;
        final form = _FormPanel(child: _form(app));
        if (!wide) {
          // layar sempit: gambar kerja di belakang, form di tengah
          return Stack(children: [
            const Positioned.fill(child: LoginHeroBackground()),
            Center(child: SizedBox(width: 440, child: form)),
          ]);
        }
        return Row(children: [
          Expanded(
            child: Stack(children: [
              const Positioned.fill(child: LoginHeroBackground()),
              Positioned(
                left: 56,
                top: 48,
                child: Row(children: [
                  const ArsipLogo(size: 40),
                  const SizedBox(width: 14),
                  Text('Arsip Dokumen PU',
                      style: TextStyle(fontFamily: kFont, color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
              ),
              Positioned(
                left: 56,
                right: 56,
                bottom: 120,
                child: ListenableBuilder(
                  listenable: app,
                  builder: (_, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Arsip proyek\njalan, jembatan, dan gedung.',
                        style: TextStyle(fontFamily: kFont, color: Colors.white, fontSize: 34, height: 1.18, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
                    const SizedBox(height: 14),
                    Text(
                      '${app.settings.connected ? app.agencyName : 'Dinas Pekerjaan Umum'} — tetap bisa dipakai tanpa internet, '
                      'dokumen terkirim otomatis saat server terhubung.',
                      style: TextStyle(fontFamily: kFont, color: Colors.white.withOpacity(0.6), fontSize: 14, height: 1.55),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
          SizedBox(width: 480, child: form),
        ]);
      }),
    );
  }

  Widget _form(AppState app) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          ListenableBuilder(listenable: app, builder: (_, __) => NetStatusPill(status: app.net)),
          const Spacer(),
          _TopIcon(icon: Icons.south_east_rounded, tooltip: 'Kecilkan ke system tray', onTap: TrayService.hideToTray),
          const SizedBox(width: 6),
          _TopIcon(icon: Icons.fullscreen_rounded, tooltip: 'Layar penuh (F11)', onTap: toggleFullScreen),
          const SizedBox(width: 6),
          _TopIcon(icon: Icons.power_settings_new_rounded, tooltip: 'Keluar aplikasi', onTap: () => confirmExit(context)),
        ]),
        const SizedBox(height: 56),
        const Text('Masuk', style: TextStyle(fontFamily: kFont, fontSize: 28, fontWeight: FontWeight.w800, color: YmColors.textDark, letterSpacing: -0.6)),
        const SizedBox(height: 6),
        Text('Gunakan akun yang diberikan admin.', style: YmTextStyles.label.copyWith(fontSize: 13.5)),
        const SizedBox(height: 28),
        _Field(controller: _userCtrl, label: 'Username', icon: Icons.person_outline_rounded, onSubmitted: (_) => _submit(), autofocus: true),
        const SizedBox(height: 14),
        _Field(
          controller: _passCtrl,
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          obscure: _obscure,
          onSubmitted: (_) => _submit(),
          suffix: IconButton(
            tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19, color: YmColors.textMuted),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        AnimatedSize(
          duration: motion(context),
          curve: kMotionCurve,
          child: _error == null
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: YmColors.buzzRed.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: YmColors.buzzRed.withOpacity(0.25)),
                  ),
                  child: Text(_error!, style: const TextStyle(fontFamily: kFont, color: Color(0xFFB3261E), fontSize: 12.5, height: 1.45)),
                ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: primaryButtonStyle(),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Masuk', style: TextStyle(fontFamily: kFont, fontWeight: FontWeight.w700, fontSize: 14.5)),
          ),
        ),
        const SizedBox(height: 22),
        ListenableBuilder(listenable: app, builder: (_, __) => _LoginHint(app: app)),
      ],
    );
  }
}

/// Panel putih form login — meluncur masuk dari kanan sekali saat dibuka.
class _FormPanel extends StatefulWidget {
  final Widget child;
  const _FormPanel({required this.child});

  @override
  State<_FormPanel> createState() => _FormPanelState();
}

class _FormPanelState extends State<_FormPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: const Interval(0.15, 1, curve: Curves.easeOutCubic));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status == AnimationStatus.dismissed) {
      if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(_a),
        child: Container(
          color: Colors.white,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(48, 36, 48, 36),
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 384), child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHint extends StatelessWidget {
  final AppState app;
  const _LoginHint({required this.app});

  @override
  Widget build(BuildContext context) {
    // PC belum/tidak disetujui admin server -> peringatan jelas
    final st = app.deviceStatus;
    if (!app.setupMode && (st == 'pending' || st == 'rejected' || st == 'revoked')) {
      final pending = st == 'pending';
      final color = pending ? const Color(0xFFB07800) : const Color(0xFFB3261E);
      return _HintBox(
        icon: pending ? Icons.hourglass_top_rounded : Icons.block_rounded,
        color: color,
        tint: pending ? YmColors.marka.withOpacity(0.10) : YmColors.buzzRed.withOpacity(0.07),
        title: pending ? 'PC ini menunggu persetujuan admin' : 'PC ini ditolak atau dicabut admin',
        body: pending
            ? 'PC #${app.settings.deviceId}. Staf belum bisa masuk di PC ini sampai admin menyetujuinya di aplikasi Admin Server → Perangkat (PC). Akun admin tetap bisa masuk.'
            : 'PC #${app.settings.deviceId}. Staf tidak bisa masuk di PC ini. Hubungi admin server.',
      );
    }
    final n = app.users.where((u) => u.active && u.hash.isNotEmpty).length;
    if (app.setupMode) {
      return const _HintBox(
        icon: Icons.settings_ethernet_rounded,
        title: 'Belum terhubung ke server',
        body: 'Masuk dengan administrator / administrator, lalu isi alamat server di Pengaturan.',
      );
    }
    if (app.net == NetStatus.offline) {
      return _HintBox(
        icon: Icons.cloud_off_rounded,
        title: 'Server tidak terjangkau — mode offline',
        body: '$n akun tersimpan di PC ini dan tetap bisa masuk. Dokumen yang disimpan terkirim otomatis saat server kembali online.',
      );
    }
    final name = app.settings.serverName.isEmpty ? '' : ' (${app.settings.serverName})';
    return _HintBox(
      icon: Icons.dns_outlined,
      title: 'Terhubung ke ${app.settings.apiUrl}$name',
      body: 'Admin bawaan server: admin / Admin@12345. $n akun tersimpan di PC ini, tetap bisa masuk walau server mati.',
    );
  }
}

class _HintBox extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final Color color;
  final Color? tint;
  const _HintBox({required this.icon, required this.title, required this.body, this.color = YmColors.textMuted, this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tint ?? YmColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint == null ? YmColors.line : color.withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 17, color: color)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontFamily: kFont, fontSize: 12.5, fontWeight: FontWeight.w700, color: tint == null ? YmColors.textDark : color)),
            const SizedBox(height: 3),
            Text(body, style: const TextStyle(fontFamily: kFont, fontSize: 12, height: 1.5, color: YmColors.textMuted)),
          ]),
        ),
      ]),
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
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: YmColors.line)),
          child: Icon(icon, size: 18, color: YmColors.textMuted),
        ),
      ),
    );
  }
}

/// Kolom isian form login: label di atas, isian putih bergaris tipis.
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure, autofocus;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.autofocus = false,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontFamily: kFont, fontSize: 12.5, fontWeight: FontWeight.w600, color: YmColors.textDark)),
      const SizedBox(height: 7),
      TextField(
        controller: controller,
        obscureText: obscure,
        autofocus: autofocus,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontFamily: kFont, fontSize: 14, color: YmColors.textDark),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 19, color: YmColors.textMuted),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    ]);
  }
}
