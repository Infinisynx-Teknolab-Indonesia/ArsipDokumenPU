import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../ui.dart';
import 'common.dart';

/// PERANGKAT (PC): setiap PC yang dihubungkan ke server muncul di sini.
/// PC baru berstatus MENUNGGU: staf belum bisa login di PC itu sampai disetujui.
class DevicesPage extends StatefulWidget {
  final AdminApi api;
  final VoidCallback onChanged, onUnauthorized;
  const DevicesPage({super.key, required this.api, required this.onChanged, required this.onUnauthorized});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  List<Map<String, dynamic>>? _items;
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
    try {
      final items = await widget.api.devices();
      if (mounted) setState(() => _items = items);
    } on AdminApiException catch (e) {
      if (e.unauthorized) {
        widget.onUnauthorized();
      } else if (!silent && mounted) {
        snack(context, e.message, error: true);
      }
    } catch (_) {}
  }

  Future<void> _act(Future<void> Function() f, String ok) async {
    await runApi(context, f, widget.onUnauthorized, ok: ok);
    await _load();
    widget.onChanged();
  }

  Future<void> _rename(Map<String, dynamic> d) async {
    final c = TextEditingController(text: '${d['name']}');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti nama PC'),
        content: SizedBox(width: 380, child: TextField(controller: c, autofocus: true, decoration: field('Nama PC', hint: 'mis. Laptop Pak Budi — Bidang Bina Marga'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(style: primary(), onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Simpan')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _act(() => widget.api.renameDevice((d['id'] as num).toInt(), name), 'Nama PC diperbarui.');
  }

  @override
  Widget build(BuildContext context) {
    final all = _items;
    if (all == null) return const Center(child: CircularProgressIndicator());
    final counts = <String, int>{};
    for (final d in all) {
      counts['${d['status']}'] = (counts['${d['status']}'] ?? 0) + 1;
    }
    final list = _filter == 'all' ? all : all.where((d) => d['status'] == _filter).toList();
    return PagePad(
      scroll: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text(
          'Aplikasi Arsip Dokumen bisa dipasang di PC mana saja, tetapi PC baru baru bisa dipakai staf setelah DISETUJUI di sini. '
          'PC dihubungkan ke server oleh admin (login administrator → menu Server API). Akun admin tetap bisa login di PC yang belum disetujui.',
          style: TextStyle(color: C.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final (code, label) in const [('pending', 'Menunggu'), ('approved', 'Disetujui'), ('rejected', 'Ditolak'), ('revoked', 'Dicabut'), ('all', 'Semua')])
            ChoiceChip(
              label: Text(code == 'all' ? '$label (${all.length})' : '$label (${counts[code] ?? 0})'),
              selected: _filter == code,
              onSelected: (_) => setState(() => _filter = code),
            ),
          IconButton(tooltip: 'Muat ulang', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: Panel(
            expand: true,
            padding: EdgeInsets.zero,
            child: list.isEmpty
                ? Center(
                    child: Text(_filter == 'pending' ? 'Tidak ada PC yang menunggu persetujuan.' : 'Tidak ada PC.',
                        style: const TextStyle(color: C.muted)),
                  )
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: C.border),
                    itemBuilder: (context, i) => _tile(list[i]),
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _tile(Map<String, dynamic> d) {
    final id = (d['id'] as num).toInt();
    final status = '${d['status']}';
    final (label, color, icon) = deviceStatusInfo(status);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(Icons.computer_rounded, color: color, size: 30),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text('${d['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              const SizedBox(width: 8),
              Pill(label, color, icon: icon),
              const SizedBox(width: 6),
              Text('#$id', style: const TextStyle(color: C.muted, fontSize: 11.5)),
            ]),
            const SizedBox(height: 3),
            Text(
              [
                'Dihubungkan oleh ${d['registered_by']} • ${fmtTime(d['created_at'])}',
                if ('${d['os']}'.isNotEmpty) '${d['os']}${'${d['app_version']}'.isEmpty ? '' : ' • aplikasi v${d['app_version']}'}',
              ].join('   •   '),
              style: const TextStyle(color: C.muted, fontSize: 12),
            ),
            Text(
              [
                'Terakhir aktif ${fmtTime(d['last_seen'])}',
                if ('${d['last_ip']}'.isNotEmpty) 'IP ${d['last_ip']}',
                if ('${d['last_user']}'.isNotEmpty) 'login terakhir: ${d['last_user']}',
                if ('${d['approved_by']}'.isNotEmpty && status != 'pending') '${status == 'approved' ? 'disetujui' : 'ditinjau'} oleh ${d['approved_by']}',
              ].join('   •   '),
              style: const TextStyle(color: C.muted, fontSize: 12),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Wrap(spacing: 6, children: [
          if (status != 'approved')
            ElevatedButton.icon(
              style: primary(color: C.green),
              onPressed: () => _act(() => widget.api.approveDevice(id), 'PC "${d['name']}" disetujui. Staf sudah bisa login di PC itu.'),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Setujui'),
            ),
          if (status == 'pending')
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: C.red, side: const BorderSide(color: C.border), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              onPressed: () async {
                if (await confirm(context, 'Tolak PC "${d['name']}"?', 'Staf tidak bisa login di PC ini. Bisa disetujui lagi nanti.', ok: 'Tolak', danger: true)) {
                  await _act(() => widget.api.rejectDevice(id), 'PC ditolak.');
                }
              },
              icon: const Icon(Icons.block_rounded, size: 18),
              label: const Text('Tolak'),
            ),
          if (status == 'approved')
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: C.red, side: const BorderSide(color: C.border), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              onPressed: () async {
                if (await confirm(context, 'Cabut PC "${d['name']}"?',
                    'Staf tidak bisa login lagi di PC ini dan akun yang tersimpan di PC itu dihapus otomatis saat terhubung ke server. Pakai untuk laptop hilang / PC tidak dipakai.',
                    ok: 'Cabut', danger: true)) {
                  await _act(() => widget.api.revokeDevice(id), 'PC dicabut.');
                }
              },
              icon: const Icon(Icons.link_off_rounded, size: 18),
              label: const Text('Cabut'),
            ),
          IconButton(tooltip: 'Ganti nama', onPressed: () => _rename(d), icon: const Icon(Icons.edit_rounded, size: 19)),
        ]),
      ]),
    );
  }
}
