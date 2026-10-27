import 'package:flutter/material.dart';
import '../api.dart';
import '../ui.dart';
import 'common.dart';

/// KEAMANAN: aturan pemakaian aplikasi di PC.
class SecurityPage extends StatefulWidget {
  final AdminApi api;
  final VoidCallback onUnauthorized;
  const SecurityPage({super.key, required this.api, required this.onUnauthorized});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  bool? _approval;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await runApi(context, widget.api.settings, widget.onUnauthorized);
    if (s != null && mounted) setState(() => _approval = s['device_approval'] == true);
  }

  Future<void> _set(bool v) async {
    if (!v &&
        !await confirm(context, 'Matikan persetujuan PC?',
            'PC baru yang dihubungkan ke server langsung bisa dipakai staf tanpa persetujuan. Tidak disarankan untuk data pemerintah.',
            ok: 'Matikan', danger: true)) {
      return;
    }
    if (!mounted) return;
    final r = await runApi(context, () => widget.api.saveSettings({'device_approval': v}), widget.onUnauthorized,
        ok: v ? 'Persetujuan PC baru diaktifkan.' : 'Persetujuan PC baru dimatikan.');
    if (r != null && mounted) setState(() => _approval = r['device_approval'] == true);
  }

  @override
  Widget build(BuildContext context) {
    final a = _approval;
    if (a == null) return const Center(child: CircularProgressIndicator());
    return PagePad(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Panel(
            title: 'Pembatasan PC',
            icon: Icons.computer_rounded,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: a,
                onChanged: _set,
                title: const Text('PC baru wajib disetujui admin', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text(
                    'Aplikasi boleh dipasang di mana saja, tetapi staf hanya bisa login di PC yang sudah DISETUJUI di menu Perangkat (PC). '
                    'Akun admin tetap bisa login di PC baru (untuk menghubungkan PC ke server).'),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const Panel(
            title: 'Cara kerja',
            icon: Icons.info_outline_rounded,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Step('1', 'Pasang aplikasi Arsip Dokumen di PC staf.'),
              _Step('2', 'Login administrator / administrator → menu Server API → isi alamat server + akun admin → Simpan & Hubungkan.'),
              _Step('3', 'PC muncul di menu Perangkat (PC) berstatus MENUNGGU. Staf belum bisa login, layar login menampilkan "menunggu persetujuan".'),
              _Step('4', 'Klik SETUJUI. Dalam ±10 detik staf bisa login, dan daftar akun tersalin ke PC itu untuk login offline.'),
              _Step('5', 'Laptop hilang / pegawai pindah: CABUT PC itu. Akun yang tersimpan di sana dihapus otomatis saat terhubung lagi.'),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n, text;
  const _Step(this.n, this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 11, backgroundColor: C.accent, child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
        ]),
      );
}
