import 'package:flutter/material.dart';
import '../core/file_tools.dart';
import '../core/format.dart';
import '../core/local_db.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';

const appVersion = '1.0.0';

/// Info penyimpanan lokal (NoSQL) + alat perawatan.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int? _filesSize;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    final s = await LocalDb.filesSize();
    if (mounted) setState(() => _filesSize = s);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final all = app.allDocs.toList();
        final unsynced = all.where((d) => d.isUnsynced).length;
        final cached = all.where((d) => d.status == DocStatus.uploaded && d.localPath.isNotEmpty).length;
        return PageBody(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Panel(
                    title: 'Penyimpanan lokal (NoSQL offline)',
                    icon: Icons.storage_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _kv('Database', LocalDb.dbPath),
                        _kv('Folder file', '${LocalDb.baseDir.path}\\files'),
                        _kv('Ukuran file lokal', _filesSize == null ? 'menghitung...' : formatBytes(_filesSize!)),
                        _kv('Catatan dokumen di PC ini', '${all.length} dokumen'),
                        _kv('Belum terupload', '$unsynced dokumen'),
                        _kv('File server yang sudah diunduh (cache)', '$cached dokumen'),
                        _kv('Akun untuk login offline', '${app.users.length}'),
                        _kv('Proyek di cache', '${app.projects.length}'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              style: outlineButtonStyle(),
                              onPressed: () => FileTools.open(LocalDb.baseDir.path),
                              icon: const Icon(Icons.folder_open_rounded, size: 18),
                              label: const Text('Buka folder data'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: outlineButtonStyle(),
                              onPressed: cached == 0
                                  ? null
                                  : () async {
                                      final ok = await confirmDialog(context,
                                          title: 'Bersihkan cache unduhan?',
                                          message: 'Menghapus $cached file yang sudah aman di server dari PC ini untuk menghemat ruang disk. '
                                              'File bisa diunduh lagi kapan saja. Dokumen yang belum terupload TIDAK dihapus.',
                                          ok: 'Bersihkan');
                                      if (!ok) return;
                                      final n = await app.clearDownloadedCache();
                                      await _measure();
                                      if (context.mounted) showSnack(context, '$n file cache dihapus.');
                                    },
                              icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                              label: const Text('Bersihkan cache unduhan'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(onPressed: _measure, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Hitung ulang')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    title: 'Pintasan',
                    icon: Icons.keyboard_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _kv('F11', 'Keluar / masuk mode full screen'),
                        _kv('Enter (di kolom password)', 'Login'),
                        _kv('Tombol "Keluar Aplikasi"', 'Menutup aplikasi (di mode full screen tidak ada tombol X)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    title: 'Tentang',
                    icon: Icons.info_outline_rounded,
                    child: Row(
                      children: [
                        const ArsipLogo(size: 56),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Arsip Dokumen PU', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: YmColors.textDark)),
                              Text('Versi $appVersion • ${app.agencyName}', style: YmTextStyles.label.copyWith(fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                'Arsip digital dokumen proyek pembangunan jalan, jembatan, gedung, dan infrastruktur. '
                                'Mendukung mode offline, upload otomatis, dan backend FastAPI / C# .NET.',
                                style: YmTextStyles.chatText.copyWith(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
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

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 280, child: Text(k, style: YmTextStyles.label.copyWith(fontSize: 12.5))),
            Expanded(child: SelectableText(v, style: YmTextStyles.chatText.copyWith(fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
