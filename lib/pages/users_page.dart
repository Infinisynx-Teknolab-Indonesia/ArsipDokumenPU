import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../services/nav.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<ServerUser>? _users;
  bool _loading = false;
  String? _error;
  bool _wasOnline = false;

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onApp);
    _load();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onApp);
    super.dispose();
  }

  /// Muat ulang otomatis saat server kembali online.
  void _onApp() {
    final online = AppState.instance.canUseServer;
    if (online && !_wasOnline) _load();
    _wasOnline = online;
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final app = AppState.instance;
    if (!app.canUseServer) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final u = await app.withToken((a, t) => a.listUsers(t));
      if (mounted) setState(() => _users = u);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(Future<void> Function() f, String okMsg) async {
    try {
      await f();
      if (mounted) showSnack(context, okMsg);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _add() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _UserDialog());
    if (ok == true) {
      if (mounted) showSnack(context, 'Akun ditambahkan. Akun ini otomatis bisa login offline di semua PC setelah sinkron.');
      await _load();
    }
  }

  Future<void> _editUser(ServerUser u) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _UserDialog(user: u));
    if (ok == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    if (app.setupMode) {
      return EmptyState(
        icon: Icons.link_off_rounded,
        title: 'Belum terhubung ke server',
        message: 'Akun staf & admin disimpan di server. Hubungkan aplikasi ke API terlebih dahulu — '
            'setelah itu akun default administrator tidak dipakai lagi.',
        action: ElevatedButton.icon(
          style: primaryButtonStyle(),
          onPressed: () => Nav.go('server'),
          icon: const Icon(Icons.dns_rounded, size: 18),
          label: const Text('Atur Server API'),
        ),
      );
    }
    final me = app.session!.username.toLowerCase();
    final online = app.canUseServer;

    return PageBody(
      scroll: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  online
                      ? 'Kelola akun yang boleh login. Akun aktif otomatis tersimpan di setiap PC (hash terenkripsi) supaya tetap bisa login saat internet mati.'
                      : 'Offline — menampilkan ${app.users.length} akun yang tersimpan di PC ini untuk login offline. Tambah/ubah akun butuh koneksi server.',
                  style: YmTextStyles.label.copyWith(fontSize: 12.5),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: outlineButtonStyle(),
                onPressed: online && !_loading ? _load : null,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Muat ulang'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: primaryButtonStyle(),
                onPressed: online ? _add : null,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Tambah Staf / Admin'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: TextStyle(color: YmColors.buzzRed))),
          Expanded(
            child: Panel(
              expand: true,
              padding: EdgeInsets.zero,
              title: online ? 'Akun di server (${_users?.length ?? 0})' : 'Akun tersimpan di PC ini (${app.users.length})',
              icon: Icons.groups_rounded,
              child: _loading && _users == null
                  ? const Center(child: CircularProgressIndicator())
                  : online && _users != null
                      ? ListView.separated(
                          itemCount: _users!.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: YmColors.borderLavender),
                          itemBuilder: (context, i) {
                            final u = _users![i];
                            final isMe = u.username.toLowerCase() == me;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: u.active ? (u.role == 'admin' ? YmColors.accentPurple : YmColors.accentBlue) : YmColors.statusOffline,
                                child: Text(u.fullName.isEmpty ? '?' : u.fullName[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                              ),
                              title: Row(children: [
                                Text(u.fullName, style: YmTextStyles.username.copyWith(fontSize: 13)),
                                const SizedBox(width: 8),
                                _Tag(text: u.role == 'admin' ? 'ADMIN' : 'STAF', color: u.role == 'admin' ? YmColors.accentPurple : YmColors.accentBlue),
                                if (!u.active) ...[const SizedBox(width: 6), _Tag(text: 'NONAKTIF', color: YmColors.buzzRed)],
                                if (isMe) ...[const SizedBox(width: 6), _Tag(text: 'ANDA', color: YmColors.statusOnline)],
                              ]),
                              subtitle: Text(
                                [
                                  '@${u.username}',
                                  if (u.nip.isNotEmpty) 'NIP ${u.nip}',
                                  if (u.jabatan.isNotEmpty) u.jabatan,
                                  'login terakhir: ${u.lastLogin == null ? '-' : formatDateTime(DateTime.tryParse(u.lastLogin!))}',
                                ].join('  •  '),
                                style: YmTextStyles.label.copyWith(fontSize: 11.5),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(tooltip: 'Edit / reset password', onPressed: () => _editUser(u), icon: const Icon(Icons.edit_rounded, size: 19)),
                                  if (!isMe)
                                    IconButton(
                                      tooltip: u.active ? 'Nonaktifkan' : 'Aktifkan',
                                      onPressed: () => _act(
                                        () => app.withToken((a, t) => a.updateUser(t, u.username, {'active': !u.active})),
                                        u.active ? '${u.username} dinonaktifkan.' : '${u.username} diaktifkan.',
                                      ),
                                      icon: Icon(u.active ? Icons.block_rounded : Icons.check_circle_outline_rounded, size: 19,
                                          color: u.active ? YmColors.statusAway : YmColors.statusOnline),
                                    ),
                                  if (!isMe)
                                    IconButton(
                                      tooltip: 'Hapus akun',
                                      onPressed: () async {
                                        final ok = await confirmDialog(context,
                                            title: 'Hapus akun?',
                                            message: 'Akun @${u.username} akan dihapus dari server dan tidak bisa login lagi (juga secara offline setelah sinkron). '
                                                'Dokumen yang pernah diunggah tetap ada.',
                                            ok: 'Hapus',
                                            danger: true);
                                        if (ok) await _act(() => app.withToken((a, t) => a.deleteUser(t, u.username)), 'Akun dihapus.');
                                      },
                                      icon: Icon(Icons.delete_outline_rounded, size: 19, color: YmColors.buzzRed),
                                    ),
                                ],
                              ),
                            );
                          },
                        )
                      : ListView(
                          children: [
                            for (final u in app.users)
                              ListTile(
                                leading: Icon(Icons.person_rounded, color: YmColors.textMuted),
                                title: Text('${u.fullName} (@${u.username})', style: YmTextStyles.username),
                                subtitle: Text('${u.role == 'admin' ? 'Admin' : 'Staf'} • ${u.active ? 'aktif' : 'nonaktif'} • '
                                    '${u.hash.isEmpty ? 'belum bisa login offline' : 'bisa login offline'}', style: YmTextStyles.label),
                              ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
      );
}

class _UserDialog extends StatefulWidget {
  final ServerUser? user;
  const _UserDialog({this.user});

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  late final TextEditingController _username, _name, _nip, _jabatan;
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  late String _role;
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _username = TextEditingController(text: u?.username ?? '');
    _name = TextEditingController(text: u?.fullName ?? '');
    _nip = TextEditingController(text: u?.nip ?? '');
    _jabatan = TextEditingController(text: u?.jabatan ?? '');
    _role = u?.role ?? 'staff';
  }

  @override
  void dispose() {
    for (final c in [_username, _name, _nip, _jabatan, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final username = _username.text.trim().toLowerCase();
    final pass = _pass.text;
    String? err;
    if (!RegExp(r'^[a-z0-9._-]{3,40}$').hasMatch(username)) {
      err = 'Username 3–40 karakter: huruf kecil, angka, titik, minus, garis bawah.';
    } else if (_name.text.trim().isEmpty) {
      err = 'Nama lengkap wajib diisi.';
    } else if (!_isEdit && pass.length < 8) {
      err = 'Password minimal 8 karakter.';
    } else if (_isEdit && pass.isNotEmpty && pass.length < 8) {
      err = 'Password baru minimal 8 karakter.';
    } else if (pass != _pass2.text) {
      err = 'Konfirmasi password tidak sama.';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final app = AppState.instance;
      final data = <String, Object?>{
        'full_name': _name.text.trim(),
        'nip': _nip.text.trim(),
        'jabatan': _jabatan.text.trim(),
        'role': _role,
        if (pass.isNotEmpty) 'password': pass,
      };
      if (_isEdit) {
        await app.withToken((a, t) => a.updateUser(t, widget.user!.username, data));
      } else {
        await app.withToken((a, t) => a.createUser(t, {...data, 'username': username}));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Akun @${widget.user!.username}' : 'Tambah Staf / Admin'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: _username, enabled: !_isEdit, decoration: fieldDecoration('Username *', icon: Icons.alternate_email_rounded)),
              gap,
              TextField(controller: _name, decoration: fieldDecoration('Nama Lengkap *', icon: Icons.person_rounded)),
              gap,
              Row(children: [
                Expanded(child: TextField(controller: _nip, decoration: fieldDecoration('NIP', icon: Icons.badge_rounded))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _jabatan, decoration: fieldDecoration('Jabatan / Bidang', icon: Icons.work_rounded))),
              ]),
              gap,
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'staff', label: Text('Staf'), icon: Icon(Icons.person_rounded)),
                  ButtonSegment(value: 'admin', label: Text('Admin'), icon: Icon(Icons.admin_panel_settings_rounded)),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 4),
              Text(
                _role == 'admin'
                    ? 'Admin: kelola staf, proyek, server API, hapus dokumen, lihat log aktivitas.'
                    : 'Staf: unggah dokumen, cari & buka arsip, edit info dokumen miliknya.',
                style: YmTextStyles.label.copyWith(fontSize: 11.5),
              ),
              gap,
              TextField(
                controller: _pass,
                obscureText: _obscure,
                decoration: fieldDecoration(
                  _isEdit ? 'Password baru (kosongkan bila tidak diubah)' : 'Password * (min. 8 karakter)',
                  icon: Icons.lock_rounded,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              gap,
              TextField(controller: _pass2, obscureText: _obscure, decoration: fieldDecoration('Ulangi password', icon: Icons.lock_outline_rounded)),
              if (_error != null) ...[gap, Text(_error!, style: TextStyle(color: YmColors.buzzRed, fontSize: 12.5))],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(style: primaryButtonStyle(), onPressed: _saving ? null : _save, child: Text(_saving ? 'Menyimpan...' : 'Simpan')),
      ],
    );
  }
}
