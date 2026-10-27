import 'package:flutter/material.dart';
import '../api.dart';
import '../ui.dart';
import 'common.dart';

/// LOG AKTIVITAS: login, upload, unduh, email, persetujuan PC, perubahan pengaturan.
class AuditPage extends StatefulWidget {
  final AdminApi api;
  final VoidCallback onUnauthorized;
  const AuditPage({super.key, required this.api, required this.onUnauthorized});

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  List<Map<String, dynamic>>? _items;
  final _q = TextEditingController();

  static const _quick = [
    ('', 'Semua'),
    ('device', 'PC'),
    ('login', 'Login'),
    ('email', 'Email'),
    ('document', 'Dokumen'),
    ('user', 'Member'),
    ('settings', 'Pengaturan'),
  ];

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
    final r = await runApi(context, () => widget.api.audit(q: _q.text.trim()), widget.onUnauthorized);
    if (r != null && mounted) setState(() => _items = r);
  }

  (IconData, Color) _icon(String action) {
    if (action.startsWith('login_failed')) return (Icons.gpp_bad_rounded, C.red);
    if (action.startsWith('login')) return (Icons.login_rounded, C.green);
    if (action.startsWith('device')) return (Icons.computer_rounded, C.orange);
    if (action.contains('email')) return (Icons.mail_rounded, C.accent);
    if (action.startsWith('settings')) return (Icons.settings_rounded, const Color(0xFF8E44AD));
    if (action.startsWith('user')) return (Icons.person_rounded, const Color(0xFF2F3E9E));
    if (action.contains('delete')) return (Icons.delete_outline_rounded, C.red);
    return (Icons.description_rounded, C.muted);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return PagePad(
      scroll: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _q,
              onSubmitted: (_) => _load(),
              decoration: field('Cari username, aksi, atau detail lalu Enter', icon: Icons.search_rounded),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(style: outline(), onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Muat ulang')),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final (q, label) in _quick)
            ChoiceChip(
              label: Text(label),
              selected: _q.text.trim() == q,
              onSelected: (_) {
                _q.text = q;
                _load();
              },
            ),
        ]),
        const SizedBox(height: 10),
        Expanded(
          child: Panel(
            expand: true,
            padding: EdgeInsets.zero,
            child: items == null
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? const Center(child: Text('Tidak ada catatan.', style: TextStyle(color: C.muted)))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: C.border),
                        itemBuilder: (context, i) {
                          final e = items[i];
                          final (icon, color) = _icon('${e['action']}');
                          return ListTile(
                            dense: true,
                            leading: Icon(icon, color: color, size: 20),
                            title: Text('${e['detail']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${fmtTime(e['at'])}  •  ${e['username']}  •  ${e['action']}${'${e['ip']}'.isEmpty ? '' : '  •  IP ${e['ip']}'}',
                                style: const TextStyle(fontSize: 11.5, color: C.muted)),
                          );
                        },
                      ),
          ),
        ),
      ]),
    );
  }
}
