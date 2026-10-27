import 'package:flutter/material.dart';
import '../api.dart';
import '../ui.dart';
import 'common.dart';

class DashboardPage extends StatefulWidget {
  final AdminApi api;
  final VoidCallback onOpenDevices, onUnauthorized;
  const DashboardPage({super.key, required this.api, required this.onOpenDevices, required this.onUnauthorized});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _o;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final o = await runApi(context, widget.api.overview, widget.onUnauthorized);
    if (o != null && mounted) setState(() => _o = o);
  }

  Widget _stat(String label, String value, IconData icon, Color color, {String? sub, VoidCallback? onTap}) => SizedBox(
        width: 250,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Panel(
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.text)),
                  Text(label, style: const TextStyle(fontSize: 12, color: C.muted)),
                  if (sub != null) Text(sub, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final o = _o;
    if (o == null) return const Center(child: CircularProgressIndicator());
    final dev = Map<String, dynamic>.from((o['devices'] as Map?) ?? {});
    final pending = (dev['pending'] as num?)?.toInt() ?? 0;
    return RefreshIndicator(
      onRefresh: _load,
      child: PagePad(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (pending > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.orange)),
              child: Row(children: [
                const Icon(Icons.hourglass_top_rounded, color: C.orange),
                const SizedBox(width: 10),
                Expanded(child: Text('$pending PC baru menunggu persetujuan. Staf belum bisa login di PC tersebut sampai Anda menyetujuinya.')),
                ElevatedButton(style: primary(color: C.orange), onPressed: widget.onOpenDevices, child: const Text('Tinjau sekarang')),
              ]),
            ),
          Wrap(spacing: 14, runSpacing: 14, children: [
            _stat('PC menunggu persetujuan', '$pending', Icons.hourglass_top_rounded, C.orange, onTap: widget.onOpenDevices),
            _stat('PC disetujui', '${dev['approved'] ?? 0}', Icons.verified_rounded, C.green,
                sub: '${(dev['rejected'] ?? 0) + (dev['revoked'] ?? 0)} ditolak/dicabut', onTap: widget.onOpenDevices),
            _stat('Member', '${o['users']}', Icons.people_alt_rounded, C.accent, sub: '${o['users_active']} aktif • ${o['admins']} admin'),
            _stat('Dokumen', '${o['documents']}', Icons.folder_rounded, const Color(0xFF2F3E9E), sub: fmtBytes((o['total_bytes'] as num?) ?? 0)),
            _stat('Proyek', '${o['projects']}', Icons.account_tree_rounded, const Color(0xFF8E44AD)),
            _stat('Permintaan edit', '${o['pending_requests']}', Icons.rate_review_rounded, C.red, sub: 'menunggu admin'),
          ]),
          const SizedBox(height: 16),
          Panel(
            title: 'Status server',
            icon: Icons.dns_rounded,
            trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _row('Instansi', '${o['agency']}'),
              _row('Versi server', '${o['server_version']}'),
              _row('Persetujuan PC baru', o['device_approval'] == true ? 'AKTIF — PC baru wajib disetujui' : 'MATI — PC baru langsung bisa dipakai'),
              _row('Email (SMTP)', o['email_configured'] == true ? 'Sudah diatur' : 'BELUM diatur — fitur "Kirim Email" di aplikasi belum bisa dipakai'),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 200, child: Text(k, style: const TextStyle(color: C.muted, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      );
}
