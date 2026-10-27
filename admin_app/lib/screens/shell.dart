import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../ui.dart';
import 'audit.dart';
import 'dashboard.dart';
import 'devices.dart';
import 'email_settings.dart';
import 'members.dart';
import 'security.dart';

/// Kerangka utama: sidebar kiri + halaman. Badge merah = PC menunggu persetujuan.
class Shell extends StatefulWidget {
  final AdminApi api;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  const Shell({super.key, required this.api, required this.user, required this.onLogout});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  int _pending = 0;
  Timer? _timer;

  static const _items = [
    (Icons.dashboard_rounded, 'Dashboard'),
    (Icons.computer_rounded, 'Perangkat (PC)'),
    (Icons.people_alt_rounded, 'Member'),
    (Icons.mail_rounded, 'Email (SMTP)'),
    (Icons.shield_rounded, 'Keamanan'),
    (Icons.history_rounded, 'Log Aktivitas'),
  ];

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Cek PC yang menunggu persetujuan (badge) tiap 15 detik.
  Future<void> _poll() async {
    try {
      final o = await widget.api.overview();
      final n = ((o['devices'] as Map?)?['pending'] as num?)?.toInt() ?? 0;
      if (mounted && n != _pending) setState(() => _pending = n);
    } on AdminApiException catch (e) {
      if (e.unauthorized) handleUnauthorized();
    } catch (_) {}
  }

  void handleUnauthorized() {
    if (!mounted) return;
    snack(context, 'Sesi berakhir. Silakan login lagi.', error: true);
    widget.onLogout();
  }

  void go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    final pages = [
      DashboardPage(api: api, onOpenDevices: () => go(1), onUnauthorized: handleUnauthorized),
      DevicesPage(api: api, onChanged: _poll, onUnauthorized: handleUnauthorized),
      MembersPage(api: api, me: '${widget.user['username']}', onUnauthorized: handleUnauthorized),
      EmailSettingsPage(api: api, onUnauthorized: handleUnauthorized),
      SecurityPage(api: api, onUnauthorized: handleUnauthorized),
      AuditPage(api: api, onUnauthorized: handleUnauthorized),
    ];
    return Scaffold(
      body: Row(children: [
        Container(
          width: 236,
          color: C.sidebar,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Admin Server', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('Arsip Dokumen PU', style: TextStyle(color: Colors.white54, fontSize: 11.5)),
                  ]),
                ),
              ]),
            ),
            for (var i = 0; i < _items.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Material(
                  color: i == _index ? Colors.white.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: Icon(_items[i].$1, color: i == _index ? Colors.white : Colors.white60, size: 20),
                    title: Text(_items[i].$2,
                        style: TextStyle(color: i == _index ? Colors.white : Colors.white70, fontWeight: i == _index ? FontWeight.w700 : FontWeight.w500)),
                    trailing: i == 1 && _pending > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(10)),
                            child: Text('$_pending', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                          )
                        : null,
                    onTap: () => go(i),
                  ),
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('${widget.user['full_name']} (@${widget.user['username']})',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(api.baseUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout_rounded, size: 17),
                  label: const Text('Logout'),
                ),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: Column(children: [
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: C.border))),
              child: Row(children: [
                Icon(_items[_index].$1, color: C.accent),
                const SizedBox(width: 10),
                Text(_items[_index].$2, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.text)),
              ]),
            ),
            Expanded(child: IndexedStack(index: _index, children: pages)),
          ]),
        ),
      ]),
    );
  }
}
