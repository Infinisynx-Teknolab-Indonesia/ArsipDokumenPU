import 'dart:async';
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../services/nav.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';

// ============================================================================
//  ADMIN SERVER — dulu aplikasi terpisah, sekarang menu khusus admin di
//  aplikasi ini: ringkasan server, persetujuan PC, email SMTP, keamanan.
//  Akun staf ada di "Staf & Admin", log di "Log Aktivitas".
// ============================================================================

String _fmtTime(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}');
  return d == null ? '-' : formatDateTime(d.toLocal());
}

/// Isi halaman admin yang butuh server: memuat data, menampilkan pesan bila
/// offline, dan tombol coba lagi.
class _ServerGate extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Widget Function() builder;
  const _ServerGate({required this.loading, required this.error, required this.onRetry, required this.builder});

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Panel(
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Butuh koneksi ke server',
          message: error!,
          action: OutlinedButton.icon(style: outlineButtonStyle(), onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Coba lagi')),
        ),
      );
    }
    if (loading) {
      return const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()));
    }
    return builder();
  }
}

// ---------------------------------------------------------------- ringkasan

class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({super.key});

  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  Map<String, dynamic>? _o;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final o = await AppState.instance.adminOverview();
      if (mounted) setState(() => _o = o);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            crumbs: const ['Admin Server', 'Ringkasan'],
            title: 'Ringkasan Server',
            subtitle: 'Kesehatan server arsip, perangkat yang terhubung, member, dan status email — langsung dari aplikasi ini.',
            actions: [
              OutlinedButton.icon(style: outlineButtonStyle(), onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Muat ulang')),
              ElevatedButton.icon(
                style: primaryButtonStyle(),
                onPressed: () => Nav.go('devices'),
                icon: const Icon(Icons.devices_outlined, size: 18),
                label: const Text('Kelola perangkat'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _ServerGate(loading: _loading && _o == null, error: _error, onRetry: _load, builder: _body),
        ],
      ),
    );
  }

  Widget _body() {
    final o = _o!;
    final dev = Map<String, dynamic>.from((o['devices'] as Map?) ?? {});
    final pending = (dev['pending'] as num?)?.toInt() ?? 0;
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pending > 0) ...[
          Reveal(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: YmColors.warningSoft, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(Icons.hourglass_top_rounded, color: YmColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('$pending PC baru menunggu persetujuan. Staf belum bisa login di PC tersebut sampai Anda menyetujuinya.',
                      style: YmTextStyles.chatText),
                ),
                ElevatedButton(style: primaryButtonStyle(color: YmColors.warning), onPressed: () => Nav.go('devices'), child: const Text('Tinjau sekarang')),
              ]),
            ),
          ),
          const SizedBox(height: 18),
        ],
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Reveal(
              index: 0,
              child: StatCard(
                label: 'PC menunggu persetujuan',
                value: '$pending',
                number: pending,
                unit: 'PC',
                icon: Icons.hourglass_top_rounded,
                color: YmColors.warning,
                chip: pending > 0 ? SoftChip.warning('Perlu ditinjau') : SoftChip.success('Tidak ada'),
                onTap: () => Nav.go('devices'),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Reveal(
              index: 1,
              child: StatCard(
                label: 'PC disetujui',
                value: '${n(dev['approved'])}',
                number: n(dev['approved']),
                unit: 'PC',
                icon: Icons.verified_outlined,
                color: YmColors.success,
                sub: '${n(dev['rejected']) + n(dev['revoked'])} ditolak / dicabut',
                onTap: () => Nav.go('devices'),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Reveal(
              index: 2,
              child: StatCard(
                label: 'Member',
                value: '${n(o['users'])}',
                number: n(o['users']),
                unit: 'akun',
                icon: Icons.groups_outlined,
                color: YmColors.primary,
                sub: '${n(o['users_active'])} aktif • ${n(o['admins'])} admin',
                onTap: () => Nav.go('users'),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Reveal(
              index: 3,
              child: StatCard(
                label: 'Dokumen di server',
                value: '${n(o['documents'])}',
                number: n(o['documents']),
                unit: 'dokumen',
                icon: Icons.folder_outlined,
                color: YmColors.accent,
                sub: '${formatBytes(n(o['total_bytes']))} • ${n(o['projects'])} proyek • ${n(o['pending_requests'])} permintaan edit',
                onTap: () => Nav.go('docs'),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 22),
        Reveal(
          index: 4,
          child: Panel(
            title: 'Status server',
            subtitle: AppState.instance.settings.activeUrl,
            icon: Icons.dns_outlined,
            child: Column(children: [
              const SizedBox(height: 6),
              _StatusRow(label: 'Instansi', value: '${o['agency'] ?? '-'}', ok: true),
              _StatusRow(label: 'Versi server', value: '${o['server_version'] ?? '-'}', ok: true),
              _StatusRow(
                label: 'Persetujuan PC baru',
                value: o['device_approval'] == true ? 'Aktif — PC baru wajib disetujui admin' : 'Mati — PC baru langsung bisa dipakai',
                ok: o['device_approval'] == true,
                action: ('Atur', () => Nav.go('security')),
              ),
              _StatusRow(
                label: 'Email (SMTP)',
                value: o['email_configured'] == true ? 'Sudah diatur — fitur "Kirim ke email" aktif' : 'Belum diatur — fitur "Kirim ke email" belum bisa dipakai',
                ok: o['email_configured'] == true,
                action: ('Atur', () => Nav.go('email')),
                last: true,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label, value;
  final bool ok;
  final (String, VoidCallback)? action;
  final bool last;
  const _StatusRow({required this.label, required this.value, required this.ok, this.action, this.last = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: YmColors.line))),
        child: Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded, size: 19, color: ok ? YmColors.success : YmColors.warning),
          const SizedBox(width: 12),
          SizedBox(width: 220, child: Text(label, style: YmTextStyles.label.copyWith(fontSize: 13))),
          Expanded(child: Text(value, style: YmTextStyles.username)),
          if (action != null) TextButton(onPressed: action!.$2, child: Text(action!.$1)),
        ]),
      );
}

// ---------------------------------------------------------------- perangkat

/// PERANGKAT (PC): setiap PC yang dihubungkan ke server muncul di sini.
/// PC baru berstatus MENUNGGU: staf belum bisa login di PC itu sampai disetujui.
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  List<Map<String, dynamic>>? _items;
  String? _error;
  String _filter = 'pending';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (Nav.page.value != 'devices' && silent) return; // hemat: hanya saat halaman dibuka
    try {
      final items = await AppState.instance.listDevices();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
          // pertama kali: tidak ada yang menunggu -> tampilkan semua
          if (!silent && _filter == 'pending' && !items.any((d) => d['status'] == 'pending')) _filter = 'all';
        });
      }
      unawaited(AppState.instance.refreshDeviceCount(force: true));
    } catch (e) {
      if (mounted && !silent) setState(() => _error = e.toString());
    }
  }

  Future<void> _act(Future<void> Function() f, String ok) async {
    try {
      await f();
      if (mounted) showSnack(context, ok);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
    await _load();
  }

  Future<void> _rename(Map<String, dynamic> d) async {
    final c = TextEditingController(text: '${d['name']}');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti nama PC'),
        content: SizedBox(
          width: 400,
          child: TextField(controller: c, autofocus: true, decoration: fieldDecoration('Nama PC', hint: 'mis. Laptop Pak Budi — Bidang Bina Marga')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(style: primaryButtonStyle(), onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Simpan')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _act(() => AppState.instance.renameDevice((d['id'] as num).toInt(), name), 'Nama PC diperbarui.');
  }

  @override
  Widget build(BuildContext context) {
    final all = _items ?? const <Map<String, dynamic>>[];
    final counts = <String, int>{};
    for (final d in all) {
      counts['${d['status']}'] = (counts['${d['status']}'] ?? 0) + 1;
    }
    final list = _filter == 'all' ? all : all.where((d) => d['status'] == _filter).toList();
    return PageBody(
      scroll: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            crumbs: const ['Admin Server', 'Perangkat (PC)'],
            badge: (counts['pending'] ?? 0) > 0 ? SoftChip.warning('${counts['pending']} menunggu persetujuan') : null,
            title: 'Perangkat (PC)',
            subtitle: 'Aplikasi boleh dipasang di PC mana saja, tetapi staf baru bisa login setelah PC-nya DISETUJUI di sini. '
                'Akun admin tetap bisa login di PC baru untuk menghubungkannya ke server.',
            actions: [
              OutlinedButton.icon(style: outlineButtonStyle(), onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Muat ulang')),
              OutlinedButton.icon(
                style: outlineButtonStyle(),
                onPressed: () => Nav.go('security'),
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: const Text('Aturan persetujuan'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (code, label) in const [('pending', 'Menunggu'), ('approved', 'Disetujui'), ('rejected', 'Ditolak'), ('revoked', 'Dicabut'), ('all', 'Semua')])
              QuickChip(
                label: code == 'all' ? '$label (${all.length})' : '$label (${counts[code] ?? 0})',
                selected: _filter == code,
                tone: code == 'pending' && (counts['pending'] ?? 0) > 0 ? ChipTone.warning : ChipTone.normal,
                onTap: () => setState(() => _filter = code),
              ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: _error != null || _items == null
                ? _ServerGate(loading: _items == null && _error == null, error: _error, onRetry: _load, builder: () => const SizedBox())
                : list.isEmpty
                    ? Panel(
                        expand: true,
                        child: EmptyState(
                          icon: Icons.devices_outlined,
                          title: _filter == 'pending' ? 'Tidak ada PC yang menunggu' : 'Tidak ada PC',
                          message: 'PC muncul di sini setelah admin login di PC itu dan menghubungkannya ke server (menu Koneksi Server).',
                        ),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Reveal(index: i, child: _deviceCard(list[i])),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _deviceCard(Map<String, dynamic> d) {
    final id = (d['id'] as num).toInt();
    final status = '${d['status']}';
    final thisPc = id == AppState.instance.thisDeviceId;
    final chip = switch (status) {
      'approved' => SoftChip.success('Disetujui', icon: Icons.verified_outlined),
      'pending' => SoftChip.warning('Menunggu persetujuan', icon: Icons.hourglass_top_rounded),
      'rejected' => SoftChip.danger('Ditolak', icon: Icons.block_rounded),
      _ => SoftChip.danger('Dicabut', icon: Icons.link_off_rounded),
    };
    String v(String k) => '${d[k] ?? ''}';
    final os = v('os').toLowerCase();
    final icon = os.contains('mac') ? Icons.laptop_mac_outlined : Icons.desktop_windows_outlined;
    return HoverCard(
      color: status == 'pending' ? Color.alphaBlend(YmColors.warningSoft.withOpacity(0.4), YmColors.surface) : null,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: YmColors.primarySoft.withOpacity(YmColors.isDark ? 1 : 0.6), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: YmColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(v('name'), style: YmTextStyles.headline),
                chip,
                SoftChip('#$id'),
                if (thisPc) SoftChip.primary('PC ini'),
              ]),
              const SizedBox(height: 6),
              Text(
                [
                  'Dihubungkan oleh ${v('registered_by')} • ${_fmtTime(d['created_at'])}',
                  if (v('os').isNotEmpty) '${v('os')}${v('app_version').isEmpty ? '' : ' • aplikasi v${v('app_version')}'}',
                ].join('   •   '),
                style: YmTextStyles.label.copyWith(fontSize: 12.5),
              ),
              Text(
                [
                  'Terakhir aktif ${_fmtTime(d['last_seen'])}',
                  if (v('last_ip').isNotEmpty) 'IP ${v('last_ip')}',
                  if (v('last_user').isNotEmpty) 'login terakhir: ${v('last_user')}',
                  if (v('approved_by').isNotEmpty && status != 'pending') '${status == 'approved' ? 'disetujui' : 'ditinjau'} oleh ${v('approved_by')}',
                ].join('   •   '),
                style: YmTextStyles.label.copyWith(fontSize: 12.5),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          if (status != 'approved')
            ElevatedButton.icon(
              style: primaryButtonStyle(color: YmColors.success),
              onPressed: () => _act(() => AppState.instance.approveDevice(id), 'PC "${v('name')}" disetujui. Staf sudah bisa login di PC itu.'),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Setujui'),
            ),
          if (status == 'pending') ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: outlineButtonStyle().copyWith(foregroundColor: WidgetStatePropertyAll(YmColors.danger)),
              onPressed: () async {
                if (await confirmDialog(context,
                    title: 'Tolak PC "${v('name')}"?', message: 'Staf tidak bisa login di PC ini. Bisa disetujui lagi nanti.', ok: 'Tolak', danger: true)) {
                  await _act(() => AppState.instance.rejectDevice(id), 'PC ditolak.');
                }
              },
              icon: const Icon(Icons.block_rounded, size: 18),
              label: const Text('Tolak'),
            ),
          ],
          if (status == 'approved')
            OutlinedButton.icon(
              style: outlineButtonStyle().copyWith(foregroundColor: WidgetStatePropertyAll(YmColors.danger)),
              onPressed: () async {
                if (await confirmDialog(context,
                    title: 'Cabut PC "${v('name')}"?',
                    message: 'Staf tidak bisa login lagi di PC ini dan akun yang tersimpan di PC itu dihapus otomatis saat terhubung ke server. '
                        'Pakai untuk laptop hilang / PC yang tidak dipakai.',
                    ok: 'Cabut',
                    danger: true)) {
                  await _act(() => AppState.instance.revokeDevice(id), 'PC dicabut.');
                }
              },
              icon: const Icon(Icons.link_off_rounded, size: 18),
              label: const Text('Cabut'),
            ),
          const SizedBox(width: 4),
          IconButton(tooltip: 'Ganti nama', onPressed: () => _rename(d), icon: const Icon(Icons.edit_outlined, size: 19)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- email

/// EMAIL (SMTP): server yang dipakai fitur "Kirim ke email" di aplikasi.
class EmailSettingsPage extends StatefulWidget {
  const EmailSettingsPage({super.key});

  @override
  State<EmailSettingsPage> createState() => _EmailSettingsPageState();
}

class _EmailSettingsPageState extends State<EmailSettingsPage> {
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _fromEmail = TextEditingController();
  final _fromName = TextEditingController();
  final _footer = TextEditingController();
  final _maxMb = TextEditingController();
  final _testTo = TextEditingController();
  String _security = 'starttls';
  bool _passSet = false, _loaded = false, _busy = false, _obscure = true;
  String? _error;

  static const _presets = [
    ('Gmail / Google Workspace', 'smtp.gmail.com', 587, 'starttls', 'Wajib App Password (Akun Google → Keamanan → Sandi aplikasi).'),
    ('Outlook / Microsoft 365', 'smtp.office365.com', 587, 'starttls', 'SMTP AUTH harus diaktifkan admin Microsoft 365.'),
    ('Yahoo Mail', 'smtp.mail.yahoo.com', 465, 'ssl', 'Pakai App Password dari pengaturan keamanan Yahoo.'),
    ('Mail server instansi', '', 587, 'starttls', 'Tanyakan host/port ke pengelola email instansi (mis. mail.batam.go.id).'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_host, _port, _user, _pass, _fromEmail, _fromName, _footer, _maxMb, _testTo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final s = await AppState.instance.adminSettings();
      if (!mounted) return;
      String v(String k) => '${s[k] ?? ''}';
      setState(() {
        _host.text = v('smtp_host');
        _port.text = v('smtp_port');
        _user.text = v('smtp_user');
        _fromEmail.text = v('smtp_from_email');
        _fromName.text = v('smtp_from_name');
        _footer.text = v('email_footer');
        _maxMb.text = v('email_max_mb');
        _security = v('smtp_security').isEmpty ? 'starttls' : v('smtp_security');
        _passSet = s['smtp_password_set'] == true;
        _loaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final r = await AppState.instance.saveAdminSettings({
        'smtp_host': _host.text.trim(),
        'smtp_port': int.tryParse(_port.text.trim()) ?? 587,
        'smtp_security': _security,
        'smtp_user': _user.text.trim(),
        if (_pass.text.isNotEmpty) 'smtp_password': _pass.text,
        'smtp_from_email': _fromEmail.text.trim(),
        'smtp_from_name': _fromName.text.trim(),
        'email_footer': _footer.text.trim(),
        'email_max_mb': int.tryParse(_maxMb.text.trim()) ?? 20,
      });
      _pass.clear();
      if (mounted) {
        setState(() => _passSet = r['smtp_password_set'] == true);
        showSnack(context, 'Pengaturan email disimpan.');
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    final to = _testTo.text.trim();
    if (to.isEmpty) {
      showSnack(context, 'Isi alamat email tujuan tes.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await AppState.instance.testEmail(to);
      if (mounted) showSnack(context, 'Email tes terkirim ke $to. Cek kotak masuk (dan folder spam).');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      maxWidth: 1100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            crumbs: const ['Admin Server', 'Email (SMTP)'],
            title: 'Email (SMTP)',
            subtitle: 'Server email untuk tombol "Kirim ke email" di detail dokumen. File dokumen dikirim oleh SERVER sebagai lampiran dan tercatat di log.',
            actions: [
              ElevatedButton.icon(
                style: primaryButtonStyle(),
                onPressed: _busy || !_loaded ? null : _save,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Simpan'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _ServerGate(loading: !_loaded, error: _error, onRetry: _load, builder: _form),
        ],
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Reveal(
          child: Panel(
            title: 'Server email',
            subtitle: 'Pilih penyedia untuk mengisi host & port otomatis.',
            icon: Icons.mail_outline_rounded,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in _presets)
                  Tooltip(
                    message: p.$5,
                    child: QuickChip(
                      label: p.$1,
                      selected: _host.text == p.$2 && p.$2.isNotEmpty,
                      onTap: () => setState(() {
                        if (p.$2.isNotEmpty) _host.text = p.$2;
                        _port.text = '${p.$3}';
                        _security = p.$4;
                        showSnack(context, p.$5);
                      }),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(flex: 3, child: TextField(controller: _host, decoration: fieldDecoration('Host SMTP', icon: Icons.dns_outlined, hint: 'smtp.gmail.com'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _port, keyboardType: TextInputType.number, decoration: fieldDecoration('Port'))),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_security),
                    initialValue: _security,
                    decoration: fieldDecoration('Keamanan'),
                    items: const [
                      DropdownMenuItem(value: 'starttls', child: Text('STARTTLS (587)')),
                      DropdownMenuItem(value: 'ssl', child: Text('SSL/TLS (465)')),
                      DropdownMenuItem(value: 'none', child: Text('Tanpa enkripsi (25)')),
                    ],
                    onChanged: (v) => setState(() => _security = v ?? 'starttls'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _user, decoration: fieldDecoration('Username SMTP', icon: Icons.person_outline_rounded, hint: 'arsip@pu.go.id'))),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _pass,
                    obscureText: _obscure,
                    decoration: fieldDecoration(
                      _passSet ? 'Password SMTP (tersimpan — isi untuk mengganti)' : 'Password SMTP',
                      icon: Icons.key_outlined,
                      suffix: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        Reveal(
          index: 1,
          child: Panel(
            title: 'Pengirim & isi email',
            icon: Icons.outgoing_mail,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _fromEmail, decoration: fieldDecoration('Email pengirim', icon: Icons.alternate_email_rounded, hint: 'arsip@pu.go.id'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _fromName, decoration: fieldDecoration('Nama pengirim', hint: 'Arsip Dokumen PUPR'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  flex: 3,
                  child: TextField(controller: _footer, decoration: fieldDecoration('Catatan di bawah email (opsional)', hint: 'Dinas PUPR — jangan balas email ini')),
                ),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _maxMb, keyboardType: TextInputType.number, decoration: fieldDecoration('Maks lampiran (MB)'))),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        Reveal(
          index: 2,
          child: Panel(
            title: 'Tes kirim email',
            subtitle: 'Simpan dulu, lalu kirim email tes untuk memastikan pengaturan benar.',
            icon: Icons.send_outlined,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Expanded(child: TextField(controller: _testTo, decoration: fieldDecoration('Kirim email tes ke', icon: Icons.alternate_email_rounded, hint: 'email Anda'))),
                const SizedBox(width: 12),
                OutlinedButton.icon(style: outlineButtonStyle(), onPressed: _busy ? null : _test, icon: const Icon(Icons.send_rounded, size: 18), label: const Text('Kirim tes')),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- keamanan

/// KEAMANAN: aturan pemakaian aplikasi di PC.
class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  bool? _approval;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final s = await AppState.instance.adminSettings();
      if (mounted) setState(() => _approval = s['device_approval'] == true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _set(bool v) async {
    if (!v &&
        !await confirmDialog(context,
            title: 'Matikan persetujuan PC?',
            message: 'PC baru yang dihubungkan ke server langsung bisa dipakai staf tanpa persetujuan. Tidak disarankan untuk data pemerintah.',
            ok: 'Matikan',
            danger: true)) {
      return;
    }
    try {
      final r = await AppState.instance.saveAdminSettings({'device_approval': v});
      if (mounted) {
        setState(() => _approval = r['device_approval'] == true);
        showSnack(context, v ? 'Persetujuan PC baru diaktifkan.' : 'Persetujuan PC baru dimatikan.');
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      maxWidth: 1100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            crumbs: ['Admin Server', 'Keamanan'],
            title: 'Keamanan',
            subtitle: 'Batasi di PC mana saja staf boleh memakai aplikasi. Data arsip pemerintah tidak boleh dibuka dari sembarang komputer.',
          ),
          const SizedBox(height: 24),
          _ServerGate(
            loading: _approval == null,
            error: _error,
            onRetry: _load,
            builder: () => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Reveal(
                child: Panel(
                  title: 'Pembatasan PC',
                  icon: Icons.computer_outlined,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('PC baru wajib disetujui admin', style: YmTextStyles.username.copyWith(fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            'Staf hanya bisa login di PC yang sudah DISETUJUI di menu Perangkat (PC). '
                            'Akun admin tetap bisa login di PC baru (untuk menghubungkan PC ke server).',
                            style: YmTextStyles.label.copyWith(fontSize: 12.5, height: 1.5),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 20),
                      Switch(value: _approval ?? true, onChanged: _set),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Reveal(
                index: 1,
                child: Panel(
                  title: 'Cara kerja',
                  icon: Icons.route_outlined,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _Step(1, 'Pasang aplikasi Arsip Dokumen di PC staf.'),
                      _Step(2, 'Login administrator / administrator → menu Koneksi Server → isi alamat server + akun admin → Simpan & Hubungkan.'),
                      _Step(3, 'PC muncul di menu Perangkat (PC) berstatus MENUNGGU. Staf belum bisa login; layar login menampilkan "menunggu persetujuan".'),
                      _Step(4, 'Klik SETUJUI. Dalam ±10 detik staf bisa login, dan daftar akun tersalin ke PC itu untuk login offline.'),
                      _Step(5, 'Laptop hilang / pegawai pindah: CABUT PC itu. Akun yang tersimpan di sana dihapus otomatis saat terhubung lagi.', last: true),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Langkah bernomor dengan garis penghubung (urutan proses).
class _Step extends StatelessWidget {
  final int n;
  final String text;
  final bool last;
  const _Step(this.n, this.text, {this.last = false});

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Column(children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: YmColors.primary, shape: BoxShape.circle),
              child: Text('$n', style: TextStyle(fontFamily: kFont, color: YmColors.onPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            if (!last) Expanded(child: Container(width: 2, color: YmColors.line)),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3, bottom: last ? 0 : 16),
              child: Text(text, style: YmTextStyles.chatText.copyWith(fontSize: 13.5)),
            ),
          ),
        ]),
      );
}
