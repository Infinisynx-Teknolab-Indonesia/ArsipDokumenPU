import 'package:flutter/material.dart';
import '../core/format.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';

/// Pengaturan alamat API (FastAPI / C# .NET). Hanya admin.
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
  bool _editing = false;
  bool _obscure = true;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    _url.text = AppState.instance.settings.apiUrl.isEmpty ? 'http://localhost:8000/api' : AppState.instance.settings.apiUrl;
  }

  @override
  void dispose() {
    _url.dispose();
    _adminUser.dispose();
    _adminPass.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _testResult = null;
    });
    try {
      final (url, info) = await AppState.instance.probe(_url.text);
      _url.text = url;
      _testOk = true;
      _testResult = 'Terhubung ✓  ${info['server'] ?? 'server'} • ${info['app'] ?? ''} '
          '${info['version'] != null ? 'v${info['version']}' : ''}${info['agency'] != null ? ' • ${info['agency']}' : ''}';
    } catch (e) {
      _testOk = false;
      _testResult = 'Gagal: $e';
    }
    if (mounted) setState(() => _busy = false);
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
      if (err == null) {
        _editing = false;
        _adminPass.clear();
      }
    });
    if (err != null) {
      showSnack(context, err, error: true);
    } else {
      showSnack(
        context,
        AppState.instance.deviceStatus == 'pending'
            ? 'Berhasil terhubung. PC ini MENUNGGU PERSETUJUAN di menu Admin Server → Perangkat (PC) sebelum staf bisa login di sini.'
            : 'Berhasil terhubung. Akun default administrator kini nonaktif — gunakan akun dari server.',
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
        final showForm = app.setupMode || _editing;
        return PageBody(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!app.setupMode) _currentServer(app),
                  if (!app.setupMode) const SizedBox(height: 16),
                  if (showForm) _form(app),
                  const SizedBox(height: 16),
                  Panel(
                    title: 'Cara kerja koneksi & mode offline',
                    icon: Icons.help_outline_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bullet('Sebelum terhubung, hanya akun default administrator / administrator yang bisa login. Staf belum bisa ditambahkan.'),
                        _bullet('Backend boleh Python FastAPI atau C# .NET — selama mengikuti kontrak di API.md, aplikasi tidak perlu diubah.'),
                        _bullet('Setelah terhubung, akun default dimatikan. Semua login memakai akun di server.'),
                        _bullet('Semua akun aktif (admin & staf) disalin ke PC ini dalam bentuk hash PBKDF2 (bukan password asli), jadi tetap bisa login saat internet/server mati.'),
                        _bullet('Setiap PC mendapat KUNCI PC saat pertama terhubung. Dengan kunci itu daftar akun diperbarui tiap 5 menit, juga saat belum ada yang login, sehingga staf baru langsung bisa login offline. Laptop hilang? Cabut PC-nya di menu Perangkat (PC) dan akun di PC itu terhapus otomatis.'),
                        _bullet('Dokumen yang disimpan saat offline masuk ke database NoSQL lokal + salinan file, lalu diunggah otomatis begitu server bisa dihubungi (dicek tiap 10 detik).'),
                        _bullet('Metadata seluruh arsip juga disalin ke PC, sehingga pencarian & filter tetap jalan saat offline.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _currentServer(AppState app) {
    return Panel(
      title: 'Server terhubung',
      icon: Icons.dns_rounded,
      trailing: NetStatusPill(status: app.net),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv('Alamat API', app.settings.apiUrl),
          _kv('Jenis server', app.settings.serverName.isEmpty ? '-' : app.settings.serverName),
          _kv('Instansi', app.agencyName),
          _kv('Akun tersimpan untuk login offline', '${app.users.where((u) => u.active && u.hash.isNotEmpty).length} akun (admin & staf) • diperbarui ${formatDateTime(app.usersSyncedAt)}'),
          _kv('Kunci PC ini', app.settings.deviceKey.isEmpty ? 'Belum terdaftar (otomatis saat login online berikutnya)' : 'Terdaftar (#${app.settings.deviceId}) — akun disalin otomatis tiap 5 menit'),
          _kv('Persetujuan PC ini', switch (app.deviceStatus) {
                'approved' => 'DISETUJUI admin — staf bisa login',
                'pending' => 'MENUNGGU persetujuan di menu Perangkat (PC) (staf belum bisa login)',
                'rejected' || 'revoked' => 'DITOLAK / DICABUT admin — staf tidak bisa login',
                _ => '-',
              }),
          _kv('Proyek di cache', '${app.projects.length}'),
          _kv('Sinkron data terakhir', formatDateTime(app.lastPullAt)),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                style: outlineButtonStyle(),
                onPressed: _busy ? null : () => setState(() => _editing = !_editing),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(_editing ? 'Batal ganti server' : 'Ganti server'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: outlineButtonStyle(),
                onPressed: _busy || app.syncing ? null : () => app.tick(forcePull: true),
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const Text('Sinkronkan sekarang'),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: YmColors.buzzRed),
                onPressed: _busy ? null : _disconnect,
                icon: const Icon(Icons.link_off_rounded, size: 18),
                label: const Text('Putuskan koneksi'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _form(AppState app) {
    return Panel(
      title: app.setupMode ? 'Hubungkan ke Server API' : 'Ganti Server API',
      icon: Icons.link_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('1. Alamat API', style: YmTextStyles.username.copyWith(fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _url,
                  decoration: fieldDecoration('Alamat API', icon: Icons.http_rounded, hint: 'http://192.168.1.10:8000/api'),
                  onChanged: (_) => setState(() => _testResult = null),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: outlineButtonStyle(),
                onPressed: _busy ? null : _test,
                icon: const Icon(Icons.network_check_rounded, size: 18),
                label: const Text('Tes Koneksi'),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Text(_testResult!, style: TextStyle(fontSize: 12.5, color: _testOk ? YmColors.statusOnline : YmColors.buzzRed, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 6),
          Text('Contoh: server di PC ini → http://localhost:8000/api • server di jaringan kantor → http://IP-SERVER:8000/api',
              style: YmTextStyles.label.copyWith(fontSize: 11.5)),
          const SizedBox(height: 18),
          Text('2. Akun ADMIN di server', style: YmTextStyles.username.copyWith(fontSize: 13)),
          const SizedBox(height: 4),
          Text('Bukan akun administrator bawaan aplikasi — gunakan akun admin yang dibuat di server (lihat README server).',
              style: YmTextStyles.label.copyWith(fontSize: 11.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(controller: _adminUser, decoration: fieldDecoration('Username admin server', icon: Icons.person_rounded))),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _adminPass,
                  obscureText: _obscure,
                  onSubmitted: (_) => _connect(),
                  decoration: fieldDecoration(
                    'Password',
                    icon: Icons.lock_rounded,
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: primaryButtonStyle(),
              onPressed: _busy ? null : _connect,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.link_rounded, size: 19),
              label: const Text('Simpan & Hubungkan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 260, child: Text(k, style: YmTextStyles.label.copyWith(fontSize: 12.5))),
            Expanded(child: SelectableText(v, style: YmTextStyles.chatText.copyWith(fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
      );

  Widget _bullet(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.circle, size: 6, color: YmColors.accentPurple)),
            const SizedBox(width: 10),
            Expanded(child: Text(t, style: YmTextStyles.chatText.copyWith(fontSize: 12.5, height: 1.4))),
          ],
        ),
      );
}
