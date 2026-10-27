import 'package:flutter/material.dart';
import '../core/file_tools.dart';
import '../core/format.dart';
import '../core/local_db.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../services/nav.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';

/// Pengaturan: tampilan (tema, animasi), penyimpanan lokal, pintasan, tentang.
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

  void _pickTheme(String id) {
    // layar digambar ulang dengan warna baru; tetap di halaman ini
    Nav.keepPage = 'settings';
    ThemeCtl.instance.set(id);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([app, ThemeCtl.instance]),
      builder: (context, _) {
        final all = app.allDocs.toList();
        final unsynced = all.where((d) => d.isUnsynced).length;
        final cached = all.where((d) => d.status == DocStatus.uploaded && d.localPath.isNotEmpty).length;
        final current = ThemeCtl.instance.palette.id;
        return PageBody(
          maxWidth: 1200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageHeader(
                crumbs: ['Akun', 'Pengaturan'],
                title: 'Pengaturan',
                subtitle: 'Tampilan aplikasi di PC ini, penyimpanan lokal untuk kerja offline, dan informasi aplikasi.',
              ),
              const SizedBox(height: 24),
              // ---- tampilan
              Reveal(
                child: Panel(
                  title: 'Tema tampilan',
                  subtitle: 'Berlaku untuk PC ini saja. Pilihan tersimpan otomatis.',
                  icon: Icons.palette_outlined,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: LayoutBuilder(builder: (context, c) {
                      final w = (c.maxWidth - 16 * 2) / 3;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final p in appPalettes)
                            SizedBox(width: w, child: _ThemeCard(p: p, selected: p.id == current, onTap: () => _pickTheme(p.id))),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Reveal(
                index: 1,
                child: Panel(
                  title: 'Animasi',
                  icon: Icons.animation_rounded,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Kurangi animasi', style: YmTextStyles.username.copyWith(fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(
                            'Matikan efek geser, pudar, dan angka berjalan. Cocok untuk PC yang lambat. '
                            'Otomatis aktif juga bila "kurangi animasi" dinyalakan di pengaturan Windows/macOS.',
                            style: YmTextStyles.label.copyWith(fontSize: 12.5, height: 1.5),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 20),
                      Switch(value: ThemeCtl.instance.lessMotion, onChanged: ThemeCtl.instance.setLessMotion),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Reveal(
                index: 2,
                child: Panel(
                  title: 'Penyimpanan lokal (offline)',
                  subtitle: 'Database NoSQL + salinan file di PC ini.',
                  icon: Icons.storage_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _Mini(label: 'Ukuran file lokal', value: _filesSize == null ? '…' : formatBytes(_filesSize!))),
                        const SizedBox(width: 12),
                        Expanded(child: _Mini(label: 'Catatan dokumen', value: '${all.length}')),
                        const SizedBox(width: 12),
                        Expanded(child: _Mini(label: 'Belum terupload', value: '$unsynced', warn: unsynced > 0)),
                        const SizedBox(width: 12),
                        Expanded(child: _Mini(label: 'File server di cache', value: '$cached')),
                        const SizedBox(width: 12),
                        Expanded(child: _Mini(label: 'Akun login offline', value: '${app.users.length}')),
                      ]),
                      const SizedBox(height: 16),
                      _kv('Database', LocalDb.dbPath),
                      _kv('Folder file', '${LocalDb.baseDir.path}${LocalDb.dbPath.contains('\\') ? '\\' : '/'}files'),
                      _kv('Proyek di cache', '${app.projects.length}'),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        OutlinedButton.icon(
                          style: outlineButtonStyle(),
                          onPressed: () => FileTools.open(LocalDb.baseDir.path),
                          icon: const Icon(Icons.folder_open_outlined, size: 18),
                          label: const Text('Buka folder data'),
                        ),
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
                          icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                          label: const Text('Bersihkan cache unduhan'),
                        ),
                        TextButton.icon(onPressed: _measure, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Hitung ulang')),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Reveal(
                    index: 3,
                    child: Panel(
                      title: 'Pintasan keyboard',
                      icon: Icons.keyboard_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          for (final (k, v) in const [
                            ('Ctrl K', 'Cari di seluruh arsip (kolom cari atas)'),
                            ('Ctrl F', 'Cari di halaman ini / di dalam dokumen yang dibuka'),
                            ('Ctrl P', 'Cetak dokumen yang dibuka'),
                            ('F11', 'Masuk / keluar layar penuh'),
                            ('Esc', 'Tutup detail dokumen'),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(children: [SizedBox(width: 90, child: Align(alignment: Alignment.centerLeft, child: KbdHint(k))), Expanded(child: Text(v, style: YmTextStyles.chatText))]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Reveal(
                    index: 4,
                    child: Panel(
                      title: 'Tentang',
                      icon: Icons.info_outline_rounded,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const ArsipLogo(size: 52),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Arsip Dokumen PU', style: YmTextStyles.headline),
                              Text('Versi $appVersion • ${app.agencyName}', style: YmTextStyles.label.copyWith(fontSize: 12.5)),
                              const SizedBox(height: 6),
                              Text(
                                'Arsip digital dokumen proyek jalan, jembatan, gedung, dan infrastruktur. '
                                'Mode offline, unggah otomatis, pencarian isi file, dan fitur admin server dalam satu aplikasi.',
                                style: YmTextStyles.chatText.copyWith(fontSize: 12.5),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
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
            SizedBox(width: 180, child: Text(k, style: YmTextStyles.label.copyWith(fontSize: 12.5))),
            Expanded(child: SelectableText(v, style: YmTextStyles.chatText.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _Mini extends StatelessWidget {
  final String label, value;
  final bool warn;
  const _Mini({required this.label, required this.value, this.warn = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: YmTextStyles.label.copyWith(fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: YmTextStyles.bigNumber.copyWith(fontSize: 20, color: warn ? YmColors.warning : YmColors.textDark)),
        ]),
      );
}

/// Kartu pilihan tema: pratinjau mini (top bar + sidebar + kartu) dengan warna tema itu.
class _ThemeCard extends StatefulWidget {
  final AppPalette p;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeCard({required this.p, required this.selected, required this.onTap});

  @override
  State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final sel = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: motion(context, const Duration(milliseconds: 200)),
          transform: Matrix4.translationValues(0, _hover && !sel && !reduceMotion(context) ? -3 : 0, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: YmColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sel ? YmColors.primary : (_hover ? YmColors.primary.withOpacity(0.4) : YmColors.line), width: sel ? 2 : 1),
            boxShadow: _hover || sel ? hoverShadow : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // pratinjau mini
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 116,
                  color: p.bg,
                  child: Column(children: [
                    Container(
                      height: 18,
                      color: p.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: p.accent == p.primary ? p.primary : p.primary, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 6),
                        Container(width: 60, height: 7, decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(4))),
                        const Spacer(),
                        Container(width: 26, height: 9, decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(4))),
                      ]),
                    ),
                    Expanded(
                      child: Row(children: [
                        Container(
                          width: 44,
                          color: p.sidebar,
                          padding: const EdgeInsets.fromLTRB(5, 8, 5, 0),
                          child: Column(children: [
                            Container(height: 8, decoration: BoxDecoration(color: p.surfaceHigh, borderRadius: BorderRadius.circular(3))),
                            for (var i = 0; i < 4; i++) ...[
                              const SizedBox(height: 5),
                              Container(height: 5, decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(3))),
                            ],
                          ]),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(width: 70, height: 8, decoration: BoxDecoration(color: p.text, borderRadius: BorderRadius.circular(3))),
                              const SizedBox(height: 7),
                              Row(children: [
                                for (final c in [p.primary, p.success, p.warning])
                                  Expanded(
                                    child: Container(
                                      height: 30,
                                      margin: const EdgeInsets.only(right: 5),
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(5), border: Border.all(color: p.line)),
                                      child: Align(
                                        alignment: Alignment.topLeft,
                                        child: Container(width: 9, height: 9, decoration: BoxDecoration(color: c.withOpacity(0.25), borderRadius: BorderRadius.circular(3))),
                                      ),
                                    ),
                                  ),
                              ]),
                              const SizedBox(height: 5),
                              Container(
                                height: 16,
                                decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(5), border: Border.all(color: p.line)),
                              ),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                for (final c in [p.primary, p.accent, p.success, p.bg])
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: YmColors.line)),
                  ),
                const SizedBox(width: 6),
                Expanded(child: Text(p.name, style: YmTextStyles.username.copyWith(fontSize: 13.5))),
                AnimatedScale(
                  scale: sel ? 1 : 0,
                  duration: motion(context, const Duration(milliseconds: 260)),
                  curve: Curves.easeOutBack,
                  child: Icon(Icons.check_circle_rounded, color: YmColors.primary, size: 20),
                ),
              ]),
              const SizedBox(height: 2),
              Text(p.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.label.copyWith(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
