import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';

/// Log aktivitas dari server: login, unggah, ubah, hapus, kelola akun/proyek.
class AuditPage extends StatefulWidget {
  const AuditPage({super.key});

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  final _search = TextEditingController();
  List<AuditEntry>? _items;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await AppState.instance.withToken((a, t) => a.auditLog(t, query: _search.text.trim()));
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  (IconData, Color) _style(String action) {
    if (action.startsWith('login')) return (Icons.login_rounded, YmColors.accentBlue);
    if (action.contains('delete')) return (Icons.delete_outline_rounded, YmColors.buzzRed);
    if (action.contains('upload') || action.contains('create')) return (Icons.add_circle_outline_rounded, YmColors.statusOnline);
    if (action.contains('update')) return (Icons.edit_rounded, YmColors.statusAway);
    if (action.contains('download')) return (Icons.download_rounded, YmColors.accentPurple);
    return (Icons.info_outline_rounded, YmColors.textMuted);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (!app.canUseServer) {
          return EmptyState(
            icon: Icons.cloud_off_rounded,
            title: app.setupMode ? 'Belum terhubung ke server' : 'Server offline',
            message: 'Log aktivitas tersimpan di server dan hanya bisa dilihat saat terhubung.',
          );
        }
        if (_items == null && !_loading && _error == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _items == null && !_loading) _load();
          });
        }
        return PageBody(
          scroll: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onSubmitted: (_) => _load(),
                      decoration: fieldDecoration('Cari username, aksi, atau detail lalu tekan Enter', icon: Icons.search_rounded)
                          .copyWith(fillColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: primaryButtonStyle(),
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Muat'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_error != null) Text(_error!, style: const TextStyle(color: YmColors.buzzRed)),
              Expanded(
                child: Panel(
                  expand: true,
                  padding: EdgeInsets.zero,
                  title: 'Aktivitas terbaru (${_items?.length ?? 0})',
                  icon: Icons.history_rounded,
                  child: _loading && _items == null
                      ? const Center(child: CircularProgressIndicator())
                      : (_items == null || _items!.isEmpty)
                          ? const EmptyState(icon: Icons.history_toggle_off_rounded, title: 'Belum ada aktivitas', message: 'Aktivitas pengguna akan tercatat di sini.')
                          : ListView.separated(
                              itemCount: _items!.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: YmColors.borderLavender),
                              itemBuilder: (context, i) {
                                final e = _items![i];
                                final (icon, color) = _style(e.action);
                                return ListTile(
                                  dense: true,
                                  leading: Icon(icon, color: color, size: 20),
                                  title: Text('${e.username}  •  ${e.action}', style: YmTextStyles.username),
                                  subtitle: Text(e.detail, style: YmTextStyles.chatText.copyWith(fontSize: 12)),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(formatDateTime(DateTime.tryParse(e.at)), style: YmTextStyles.label.copyWith(fontSize: 11.5)),
                                      if (e.ip.isNotEmpty) Text(e.ip, style: YmTextStyles.label.copyWith(fontSize: 10.5)),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
