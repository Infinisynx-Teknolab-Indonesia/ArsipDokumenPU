import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/server_config.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';

/// Koneksi server (admin). Pilihan:
///  - SERVER BAWAAN (hardcode, default) — alamat dari core/server_config.dart,
///    PC baru langsung terhubung tanpa mengetik alamat.
///  - SERVER LAIN — alamat diisi manual + login admin server.
class ServerPage extends StatefulWidget {
  const ServerPage({super.key});

  @override
  State<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  final _url = TextEditingController();
  final _adminUser = TextEditingController();
  final _adminPass = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _testResult;
  bool _testOk = false;

  /// Pilihan di layar (belum tentu sudah disimpan).
  late String _mode = AppState.instance.settings.usesDefault ? 'default' : 'custom';

  @override
  void initState() {
    super.initState();
    final s = AppState.instance.settings;
    _url.text = s.apiUrl.isNotEmpty ? s.apiUrl : (hasDefaultServer ? kDefaultServerUrl : 'http://localhost:8000/api');
  }

  @override
  void dispose() {
    _url.dispose();
    _adminUser.dispose();
    _adminPass.dispose();
    super.dispose();
  }

  Future<void> _test(String url) async {
    setState(() {
      _busy = true;
      _testResult = null;
    });
    try {
      final (u, info) = await AppState.instance.probe(url);
      if (_mode == 'custom') _url.text = u;
      _testOk = true;
      _testResult = 'Terhubung ✓  ${info['server'] ?? 'server'} • ${info['app'] ?? ''} '
          '${info['version'] != null ? 'v${info['version']}' : ''}${info['agency'] != null ? ' • ${info['agency']}' : ''}';
    } catch (e) {
      _testOk = false;
      _testResult = 'Gagal: $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _useDefault() async {
    final app = AppState.instance;
    final ok = await confirmDialog(
      context,
      title: 'Pakai server bawaan?',
      message: 'PC ini akan memakai alamat server bawaan aplikasi:\n$kDefaultServerUrl\n\n'
          'Login memakai akun dari server tersebut. Dokumen yang belum terupload tetap aman dan dikirim ke server ini.',
      ok: 'Pakai server bawaan',
    );
    if (!ok) return;
    await app.useDefaultServer();
    if (mounted) showSnack(context, 'Memakai server bawaan $kDefaultServerUrl');
  }

  Future<void> _connect() async {
    if (_adminUser.text.trim().isEmpty || _adminPass.text.isEmpty) {
      showSnack(context, 'Isi username & password ADMIN yang ada di server.', error: true);
      return;
    }
    setState(() => _busy = true);
    final err = await AppState.instance.connectServer(_url.text, _adminUser.text, _adminPass.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (err == null) _adminPass.clear();
    });
    if (err != null) {
      showSnack(context, err, error: true);
    } else {
      showSnack(
        context,
        AppState.instance.deviceStatus == 'pending'
            ? 'Berhasil terhubung. PC ini MENUNGGU PERSETUJUAN di menu Admin Server → Perangkat (PC) sebelum staf bisa login di sini.'
            : 'Berhasil terhubung ke server lain.',
      );
    }
  }

  Future<void> _disconnect() async {
    final ok = await confirmDialog(
      context,
      title: 'Putuskan koneksi server?',
      message: 'Aplikasi kembali ke mode awal (akun administrator/administrator aktif lagi), cache akun & proyek dihapus dari PC ini, '
          'dan Anda akan logout. Dokumen yang belum terupload TETAP tersimpan dan akan diunggah setelah terhubung lagi.',
      ok: 'Putuskan',
      danger: true,
    );
    if (ok) await AppState.instance.disconnectServer();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.settings;
        return PageBody(
          maxWidth: 1100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- pilih sumber alamat server
              Reveal(
                child: Panel(
                  title: 'Alamat server',
                  subtitle: 'Bawaan memakai alamat yang sudah tertanam di aplikasi (hardcode). Pilih "Server lain" bila ingin mengisi alamat sendiri.',
                  icon: Icons.dns_outlined,
                  trailing: NetStatusPill(status: app.net),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: _ModeCard(
                        selected: _mode == 'default',
                        active: s.usesDefault,
                        enabled: hasDefaultServer,
                        icon: Icons.lock_outline_rounded,
                        title: 'Server bawaan (hardcode)',
                        badge: 'Bawaan',
                        value: hasDefaultServer ? kDefaultServerUrl : 'Tidak diatur di aplikasi ini',
                        note: 'PC baru langsung terhubung tanpa mengetik alamat. Diatur di lib/core/server_config.dart atau saat build (--dart-define=ARSIP_SERVER=...).',
                        onTap: hasDefaultServer ? () => setState(() => _mode = 'default') : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ModeCard(
                        selected: _mode == 'custom',
                        active: !s.usesDefault && s.connected,
                        enabled: true,
                        icon: Icons.edit_location_alt_outlined,
                        title: 'Server lain',
                        value: !s.usesDefault && s.connected ? s.apiUrl : 'Isi alamat sendiri + akun admin server',
                        note: 'Untuk server cadangan, server uji, atau kantor lain. Backend FastAPI / C# .NET sesuai API.md.',
                        onTap: () => setState(() => _mode = 'custom'),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: motion(context),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a), child: c),
                ),
                child: _mode == 'default' ? KeyedSubtree(key: const ValueKey('d'), child: _defaultPanel(app)) : KeyedSubtree(key: const ValueKey('c'), child: _customPanel(app)),
              ),
              if (!app.setupMode) ...[const SizedBox(height: 24), Reveal(index: 1, child: _status(app))],
              const SizedBox(height: 24),
              Reveal(
                index: 2,
                child: Panel(
                  title: 'Cara kerja koneksi & mode offline',
                  icon: Icons.help_outline_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bullet('Bawaan: aplikasi memakai server bawaan (hardcode). Admin bisa beralih ke "Server lain" kapan saja, dan kembali ke bawaan dengan satu klik.'),
                      _bullet('Bila server bawaan tidak terjangkau dan belum ada akun tersimpan di PC ini, akun darurat administrator / administrator bisa dipakai untuk mengganti alamat server.'),
                      _bullet('Semua akun aktif (admin & staf) disalin ke PC ini dalam bentuk hash PBKDF2 (bukan password asli), jadi tetap bisa login saat internet/server mati.'),
                      _bullet('Setiap PC mendapat KUNCI PC saat admin pertama kali login di PC itu. PC baru perlu DISETUJUI di menu Perangkat (PC) sebelum staf bisa login.'),
                      _bullet('Dokumen yang disimpan saat offline masuk ke database lokal + salinan file, bisa diedit/dihapus selama belum terkirim, lalu diunggah otomatis begitu server bisa dihubungi (dicek tiap 10 detik).'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _defaultPanel(AppState app) {
    final s = app.settings;
    return Panel(
      title: s.usesDefault ? 'Memakai server bawaan' : 'Beralih ke server bawaan',
      icon: Icons.lock_outline_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(Icons.http_rounded, color: YmColors.primary),
            const SizedBox(width: 12),
            Expanded(child: SelectableText(kDefaultServerUrl, style: YmTextStyles.labelLg.copyWith(fontWeight: FontWeight.w600))),
            if (s.usesDefault) SoftChip.success('Aktif', icon: Icons.check_rounded),
          ]),
        ),
        if (_testResult != null) ...[
          const SizedBox(height: 8),
          Text(_testResult!, style: YmTextStyles.labelMd.copyWith(color: _testOk ? YmColors.success : YmColors.danger, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 16),
        Row(children: [
          OutlinedButton.icon(
            style: outlineButtonStyle(),
            onPressed: _busy ? null : () => _test(kDefaultServerUrl),
            icon: const Icon(Icons.network_check_rounded),
            label: const Text('Tes koneksi'),
          ),
          const SizedBox(width: 8),
          if (!s.usesDefault)
            ElevatedButton.icon(
              style: primaryButtonStyle(),
              onPressed: _busy ? null : _useDefault,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Pakai server bawaan'),
            ),
        ]),
      ]),
    );
  }

  Widget _customPanel(AppState app) {
    return Panel(
      title: 'Hubungkan ke server lain',
      subtitle: 'Isi alamat API, tes, lalu masuk dengan akun ADMIN yang ada di server tersebut.',
      icon: Icons.link_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _url,
                  decoration: fieldDecoration('Alamat API', icon: Icons.http_rounded, hint: 'http://192.168.1.10:8000/api'),
                  onChanged: (_) => setState(() => _testResult = null),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: outlineButtonStyle(),
                onPressed: _busy ? null : () => _test(_url.text),
                icon: const Icon(Icons.network_check_rounded),
                label: const Text('Tes koneksi'),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Text(_testResult!, style: YmTextStyles.labelMd.copyWith(color: _testOk ? YmColors.success : YmColors.danger, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 6),
          Text('Contoh: server di PC ini → http://localhost:8000/api • server di jaringan kantor → http://IP-SERVER:8000/api', style: YmTextStyles.bodySm),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: TextField(controller: _adminUser, decoration: fieldDecoration('Username admin server', icon: Icons.person_outline_rounded))),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _adminPass,
                  obscureText: _obscure,
                  onSubmitted: (_) => _connect(),
                  decoration: fieldDecoration(
                    'Password',
                    icon: Icons.lock_outline_rounded,
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            ElevatedButton.icon(
              style: primaryButtonStyle(),
              onPressed: _busy ? null : _connect,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.link_rounded),
              label: const Text('Simpan & hubungkan'),
            ),
            const Spacer(),
            if (!app.setupMode)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: YmColors.danger),
                onPressed: _busy ? null : _disconnect,
                icon: const Icon(Icons.link_off_rounded, size: 18),
                label: const Text('Putuskan koneksi'),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _status(AppState app) {
    final s = app.settings;
    return Panel(
      title: 'Status koneksi PC ini',
      icon: Icons.computer_outlined,
      trailing: OutlinedButton.icon(
        style: outlineButtonStyle(),
        onPressed: _busy || app.syncing ? null : () => app.tick(forcePull: true),
        icon: const Icon(Icons.sync_rounded),
        label: const Text('Sinkronkan sekarang'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv('Alamat yang dipakai', '${s.activeUrl}${s.usesDefault ? '  (bawaan)' : '  (server lain)'}'),
          _kv('Jenis server', s.serverName.isEmpty ? '-' : s.serverName),
          _kv('Instansi', app.agencyName),
          _kv('Akun tersimpan untuk login offline', '${app.users.where((u) => u.active && u.hash.isNotEmpty).length} akun • diperbarui ${formatDateTime(app.usersSyncedAt)}'),
          _kv('Kunci PC ini', s.deviceKey.isEmpty ? 'Belum terdaftar (otomatis saat admin login online)' : 'Terdaftar (#${s.deviceId})'),
          _kv('Persetujuan PC ini', switch (app.deviceStatus) {
                'approved' => 'DISETUJUI admin — staf bisa login',
                'pending' => 'MENUNGGU persetujuan di menu Perangkat (PC)',
                'rejected' || 'revoked' => 'DITOLAK / DICABUT admin — staf tidak bisa login',
                _ => '-',
              }),
          _kv('Sinkron data terakhir', formatDateTime(app.lastPullAt)),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 260, child: Text(k, style: YmTextStyles.bodySm.copyWith(fontSize: 13))),
            Expanded(child: SelectableText(v, style: YmTextStyles.labelLg.copyWith(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  Widget _bullet(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 6, color: YmColors.primary)),
            const SizedBox(width: 10),
            Expanded(child: Text(t, style: YmTextStyles.bodyMd.copyWith(color: YmColors.textDark))),
          ],
        ),
      );
}

/// Kartu pilihan mode server (dipilih = garis warna utama + latar lembut).
class _ModeCard extends StatelessWidget {
  final bool selected, active, enabled;
  final IconData icon;
  final String title, value, note;
  final String? badge;
  final VoidCallback? onTap;
  const _ModeCard({
    required this.selected,
    required this.active,
    required this.enabled,
    required this.icon,
    required this.title,
    required this.value,
    required this.note,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: HoverCard(
        onTap: onTap,
        color: selected ? YmColors.primaryFixed.withOpacity(YmColors.isDark ? 1 : 0.45) : YmColors.surfaceAlt,
        borderColor: selected ? YmColors.primary : Colors.transparent,
        baseShadowOverride: const [],
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedContainer(
            duration: motion(context, kMotionFast),
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? YmColors.primary : YmColors.outlineVariant, width: selected ? 6 : 2),
              color: YmColors.surface,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 18, color: YmColors.primary),
                const SizedBox(width: 6),
                Flexible(child: Text(title, style: YmTextStyles.labelLg.copyWith(fontWeight: FontWeight.w600))),
                if (badge != null) ...[const SizedBox(width: 8), SoftChip.primary(badge!)],
                if (active) ...[const SizedBox(width: 6), SoftChip.success('Dipakai')],
              ]),
              const SizedBox(height: 6),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelMd.copyWith(color: YmColors.primary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(note, style: YmTextStyles.bodySm),
            ]),
          ),
        ]),
      ),
    );
  }
}
