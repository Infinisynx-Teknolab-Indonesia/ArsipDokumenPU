import 'package:flutter/material.dart';
import '../api.dart';
import '../ui.dart';
import 'common.dart';

/// MEMBER: staf & admin yang boleh login. Tambah, ubah, reset password,
/// aktif/nonaktif, hapus — plus PC yang dipakai tiap member.
class MembersPage extends StatefulWidget {
  final AdminApi api;
  final String me;
  final VoidCallback onUnauthorized;
  const MembersPage({super.key, required this.api, required this.me, required this.onUnauthorized});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  List<Map<String, dynamic>>? _users;
  List<Map<String, dynamic>> _devices = const [];
  final _q = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await runApi(context, () async => (await widget.api.users(), await widget.api.devices()), widget.onUnauthorized);
    if (r != null && mounted) {
      setState(() {
        _users = r.$1;
        _devices = r.$2;
      });
    }
  }

  Future<void> _edit([Map<String, dynamic>? u]) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _MemberDialog(api: widget.api, user: u, onUnauthorized: widget.onUnauthorized));
    if (saved == true) await _load();
  }

  Future<void> _act(Future<void> Function() f, String ok) async {
    await runApi(context, f, widget.onUnauthorized, ok: ok);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    if (users == null) return const Center(child: CircularProgressIndicator());
    final q = _q.text.trim().toLowerCase();
    final list = q.isEmpty
        ? users
        : users.where((u) => '${u['username']} ${u['full_name']} ${u['nip']} ${u['jabatan']}'.toLowerCase().contains(q)).toList();
    return PagePad(
      scroll: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: field('Cari nama, username, NIP, jabatan', icon: Icons.search_rounded),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(style: outline(), onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Muat ulang')),
          const SizedBox(width: 8),
          ElevatedButton.icon(style: primary(), onPressed: () => _edit(), icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: const Text('Tambah Member')),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: Panel(
            expand: true,
            padding: EdgeInsets.zero,
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: C.border),
              itemBuilder: (context, i) => _tile(list[i]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _tile(Map<String, dynamic> u) {
    final username = '${u['username']}';
    final active = u['active'] == true;
    final admin = u['role'] == 'admin';
    final isMe = username == widget.me;
    final pcs = _devices.where((d) => d['last_user'] == username || d['registered_by'] == username).toList();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: active ? (admin ? C.accent : const Color(0xFF2F3E9E)) : C.muted,
        child: Text('${u['full_name']}'.isEmpty ? '?' : '${u['full_name']}'[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
      ),
      title: Row(children: [
        Flexible(child: Text('${u['full_name']} (@$username)', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        Pill(admin ? 'ADMIN' : 'STAF', admin ? C.accent : const Color(0xFF2F3E9E)),
        if (!active) ...[const SizedBox(width: 6), const Pill('NONAKTIF', C.red)],
        if (isMe) ...[const SizedBox(width: 6), const Pill('ANDA', C.green)],
      ]),
      subtitle: Text(
        [
          if ('${u['nip']}'.isNotEmpty) 'NIP ${u['nip']}',
          if ('${u['jabatan']}'.isNotEmpty) '${u['jabatan']}',
          'login terakhir ${fmtTime(u['last_login'])}',
          if (pcs.isNotEmpty) 'PC: ${pcs.map((d) => '${d['name']} (${deviceStatusInfo('${d['status']}').$1.toLowerCase()})').join(', ')}',
        ].join('  •  '),
        style: const TextStyle(fontSize: 12, color: C.muted),
      ),
      trailing: Wrap(spacing: 2, children: [
        IconButton(tooltip: 'Ubah data / reset password', onPressed: () => _edit(u), icon: const Icon(Icons.edit_rounded, size: 19)),
        if (!isMe)
          IconButton(
            tooltip: active ? 'Nonaktifkan (tidak bisa login, juga di mode offline)' : 'Aktifkan lagi',
            onPressed: () => _act(() => widget.api.updateUser(username, {'active': !active}), active ? 'Member dinonaktifkan.' : 'Member diaktifkan.'),
            icon: Icon(active ? Icons.person_off_rounded : Icons.person_rounded, size: 19, color: active ? C.orange : C.green),
          ),
        if (!isMe)
          IconButton(
            tooltip: 'Hapus member',
            onPressed: () async {
              if (await confirm(context, 'Hapus $username?', 'Akun dihapus dari server dan semua PC. Dokumen yang pernah diunggah tetap ada.', ok: 'Hapus', danger: true)) {
                await _act(() => widget.api.deleteUser(username), 'Member dihapus.');
              }
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 19, color: C.red),
          ),
      ]),
    );
  }
}

class _MemberDialog extends StatefulWidget {
  final AdminApi api;
  final Map<String, dynamic>? user;
  final VoidCallback onUnauthorized;
  const _MemberDialog({required this.api, this.user, required this.onUnauthorized});

  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  late final _username = TextEditingController(text: '${widget.user?['username'] ?? ''}');
  late final _name = TextEditingController(text: '${widget.user?['full_name'] ?? ''}');
  late final _nip = TextEditingController(text: '${widget.user?['nip'] ?? ''}');
  late final _jabatan = TextEditingController(text: '${widget.user?['jabatan'] ?? ''}');
  final _pass = TextEditingController();
  late String _role = '${widget.user?['role'] ?? 'staff'}';
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.user == null;

  @override
  void dispose() {
    for (final c in [_username, _name, _nip, _jabatan, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final pass = _pass.text;
    if (_name.text.trim().isEmpty || (_isNew && _username.text.trim().isEmpty)) {
      setState(() => _error = 'Username dan nama lengkap wajib diisi.');
      return;
    }
    if ((_isNew || pass.isNotEmpty) && pass.length < 8) {
      setState(() => _error = 'Password minimal 8 karakter.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isNew) {
        await widget.api.createUser({
          'username': _username.text.trim().toLowerCase(),
          'full_name': _name.text.trim(),
          'password': pass,
          'role': _role,
          'nip': _nip.text.trim(),
          'jabatan': _jabatan.text.trim(),
        });
      } else {
        await widget.api.updateUser('${widget.user!['username']}', {
          'full_name': _name.text.trim(),
          'role': _role,
          'nip': _nip.text.trim(),
          'jabatan': _jabatan.text.trim(),
          if (pass.isNotEmpty) 'password': pass,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } on AdminApiException catch (e) {
      if (e.unauthorized) widget.onUnauthorized();
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? 'Tambah member' : 'Ubah member @${widget.user!['username']}'),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_isNew) ...[
            TextField(controller: _username, decoration: field('Username *', icon: Icons.alternate_email_rounded, hint: 'huruf kecil, angka, titik, minus')),
            const SizedBox(height: 10),
          ],
          TextField(controller: _name, decoration: field('Nama lengkap *', icon: Icons.badge_rounded)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _nip, decoration: field('NIP'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _jabatan, decoration: field('Jabatan'))),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: field(_isNew ? 'Password * (min 8)' : 'Password baru (kosongkan bila tidak diganti)', icon: Icons.lock_rounded),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'staff', label: Text('Staf'), icon: Icon(Icons.person_rounded)),
              ButtonSegment(value: 'admin', label: Text('Admin'), icon: Icon(Icons.admin_panel_settings_rounded)),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: C.red))],
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(style: primary(), onPressed: _busy ? null : _save, child: Text(_busy ? 'Menyimpan...' : 'Simpan')),
      ],
    );
  }
}
