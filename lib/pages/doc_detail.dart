import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/categories.dart';
import '../core/file_tools.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../services/nav.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';
import '../core/smart_search.dart';
import 'doc_form.dart';
import 'edit_request_dialog.dart';
import 'email_dialog.dart';
import '../print/print_dialog.dart';
import '../viewer/document_viewer.dart';
import '../viewer/viewer_common.dart';

/// Buka halaman detail dokumen (gaya "document intelligence" versi web):
/// tampilan DATA DOKUMEN terstruktur + FILE ASLI, berpindah dengan animasi.
/// [highlight] = kata/kode yang langsung disorot di isi file (dari hasil pencarian).
/// [startOnFile] = langsung tampilkan file asli.
Future<void> showDocDetail(BuildContext context, DocRecord doc, {String highlight = '', bool startOnFile = false, int initialTab = 0}) {
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => _DocDetailPage(doc: doc, highlight: highlight, startOnFile: startOnFile, initialTab: initialTab),
  ));
}

enum _View { data, file }

/// Nilai yang sedang dipilih di tampilan data (ditampilkan di panel "Detail nilai").
class _Picked {
  final String label;
  final String value;
  final String source;
  final String group;
  const _Picked(this.label, this.value, this.source, this.group);
}

class _DocDetailPage extends StatefulWidget {
  final DocRecord doc;
  final String highlight;
  final bool startOnFile;
  final int initialTab;
  const _DocDetailPage({required this.doc, this.highlight = '', this.startOnFile = false, this.initialTab = 0});

  @override
  State<_DocDetailPage> createState() => _DocDetailPageState();
}

class _DocDetailPageState extends State<_DocDetailPage> {
  bool _busy = false;
  final _print = PrintController(); // dipakai tombol Cetak
  late _View _view = widget.startOnFile ? _View.file : _View.data;
  late String _query = widget.highlight;
  _Picked? _picked;

  DocRecord get d => widget.doc;
  bool get _hasLocal => d.localPath.isNotEmpty && File(d.localPath).existsSync();

  @override
  void initState() {
    super.initState();
    // Pratinjau langsung: unduh otomatis file yang belum ada di PC (maks 25 MB).
    if (!_hasLocal && AppState.instance.canUseServer && d.fileSize <= 25 * 1024 * 1024) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _download();
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() => _run(() async {
        await AppState.instance.ensureLocalFile(d);
      });

  /// Buka di dalam aplikasi (layar penuh) — tanpa WPS / Office.
  Future<void> _fullScreen() async {
    String? path;
    await _run(() async => path = await AppState.instance.ensureLocalFile(d));
    if (path == null || !mounted) return;
    await openDocumentViewer(
      context,
      path: path!,
      title: d.title,
      fileName: d.fileName,
      initialQuery: _query,
      subtitle: [if (d.docNumber.isNotEmpty) 'No. ${d.docNumber}', formatIsoDate(d.docDate)].join('  •  '),
      doc: d,
    );
    if (mounted) setState(() {});
  }

  Future<void> _openExternal() => _run(() async {
        final path = await AppState.instance.ensureLocalFile(d);
        await FileTools.open(path);
      });

  Future<void> _saveCopy() => _run(() async {
        final path = await AppState.instance.ensureLocalFile(d);
        final target = await FileTools.saveCopy(path, d.fileName);
        if (target != null && mounted) showSnack(context, 'Tersimpan ke $target');
      });

  Future<void> _showInFolder() => _run(() async {
        final path = await AppState.instance.ensureLocalFile(d);
        await FileTools.showInFolder(path);
      });

  Future<void> _submit() => _run(() async {
        await AppState.instance.submitDrafts([d]);
        if (mounted) {
          showSnack(
            context,
            AppState.instance.canUseServer
                ? 'Dokumen masuk antrian dan sedang dikirim ke server.'
                : 'Server belum terhubung: dokumen aman di PC ini dan terkirim otomatis saat server online.',
          );
        }
      });

  Future<void> _replaceFile() async {
    final r = await FilePicker.platform.pickFiles(dialogTitle: 'Pilih file pengganti', type: FileType.custom, allowedExtensions: allowedExtensions);
    final path = r?.files.single.path;
    if (path == null) return;
    await _run(() async {
      await AppState.instance.replaceUnsentFile(d, path);
      if (mounted) showSnack(context, 'File diganti. Periksa lagi pratinjaunya sebelum dikirim.');
    });
  }

  Future<void> _edit() async {
    final changed = await showDocEditDialog(context, d);
    if (changed == true && mounted) setState(() {});
  }

  Future<void> _delete() async {
    final onServer = !d.isUnsynced;
    final ok = await confirmDialog(
      context,
      title: 'Hapus dokumen?',
      message: onServer
          ? '"${d.title}" akan dihapus PERMANEN dari server dan semua PC. Tindakan ini tercatat di log aktivitas.'
          : '"${d.title}" belum terupload dan akan dihapus dari antrian PC ini.',
      ok: 'Hapus',
      danger: true,
    );
    if (!ok) return;
    await _run(() async {
      await AppState.instance.deleteDoc(d);
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'Dokumen dihapus.');
      }
    });
  }

  void _print_() => showPrintDialog(context, controller: _print, title: d.title, fileName: d.fileName);

  /// Lihat file asli dan langsung cari nilai yang dipilih (versi web: "View original source").
  void _showSource(String value) {
    setState(() {
      _query = value;
      _view = _View.file;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ikut diperbarui saat status kirim berubah (draf -> antrian -> terkirim).
    return ListenableBuilder(listenable: AppState.instance, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final app = AppState.instance;
    final cat = categoryOf(d.category);
    final needServer = !_hasLocal;
    _picked ??= d.docNumber.isNotEmpty
        ? _Picked('Nomor dokumen', d.docNumber, 'Data dokumen', 'Referensi')
        : _Picked('Judul', d.title, 'Data dokumen', 'Dokumen');

    return Scaffold(
      backgroundColor: YmColors.paper,
      body: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context)},
        child: Focus(
          autofocus: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 18, 32, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---- baris atas: kembali + jejak
                Row(children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: YmColors.textMuted),
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Kembali (Esc)'),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, size: 16, color: YmColors.outline),
                  Text('Arsip', style: TextStyle(fontFamily: kFont, fontSize: 12.5, color: YmColors.outline)),
                  Icon(Icons.chevron_right_rounded, size: 16, color: YmColors.outline),
                  Text(cat.label, style: TextStyle(fontFamily: kFont, fontSize: 12.5, color: YmColors.outline)),
                  Icon(Icons.chevron_right_rounded, size: 16, color: YmColors.outline),
                  Flexible(
                    child: Text(d.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: kFont, fontSize: 12.5, fontWeight: FontWeight.w600, color: YmColors.textDark)),
                  ),
                  const SizedBox(width: 16),
                  NetStatusPill(status: app.net),
                ]),
                const SizedBox(height: 12),
                Reveal(child: _headerCard(app)),
                AnimatedSize(
                  duration: motion(context, kMotionFast),
                  child: _busy
                      ? const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator(minHeight: 2))
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: motion(context, const Duration(milliseconds: 340)),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, a) {
                      final fromRight = child.key == const ValueKey(_View.file);
                      return FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(begin: Offset(fromRight ? 0.04 : -0.04, 0), end: Offset.zero).animate(a),
                          child: child,
                        ),
                      );
                    },
                    child: _view == _View.data
                        ? KeyedSubtree(key: const ValueKey(_View.data), child: _dataView(app))
                        : KeyedSubtree(key: const ValueKey(_View.file), child: _fileView(needServer)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- kartu judul
  Widget _headerCard(AppState app) {
    final needServer = !_hasLocal;
    final canFile = !(needServer && !app.canUseServer);
    Widget meta(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: YmColors.outline),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontFamily: kFont, fontSize: 12.5, color: YmColors.outline)),
        ]);
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Row(
        children: [
          FileTypeIcon(ext: d.extension, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(d.title, style: YmTextStyles.headline.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
                  SoftChip(categoryOf(d.category).label, fg: YmColors.primary, bg: YmColors.primarySoft, bold: true),
                  DocStatusChip(status: d.status),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 18, runSpacing: 6, children: [
                  if (d.docNumber.isNotEmpty) meta(Icons.tag_rounded, d.docNumber),
                  if (d.docDate.isNotEmpty) meta(Icons.event_outlined, formatIsoDate(d.docDate)),
                  meta(Icons.insert_drive_file_outlined, '${d.fileName} • ${formatBytes(d.fileSize)}'),
                  meta(Icons.person_outline_rounded, d.createdByName),
                  meta(Icons.schedule_rounded, d.uploadedAt != null ? 'Masuk server ${timeAgo(d.uploadedAt)}' : 'Diinput ${timeAgo(d.createdAt)}'),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SegmentedToggle<_View>(
            segmentWidth: 140,
            value: _view,
            onChanged: (v) => setState(() => _view = v),
            options: const [(_View.data, 'Data dokumen', Icons.dataset_outlined), (_View.file, 'File asli', Icons.description_outlined)],
          ),
          const SizedBox(width: 10),
          _IconAction(
            icon: Icons.print_outlined,
            tooltip: 'Cetak (Ctrl+P)',
            onTap: _busy || needServer || !canViewInApp(d.extension) ? null : _print_,
          ),
          _IconAction(
            icon: Icons.forward_to_inbox_outlined,
            tooltip: 'Kirim ke email',
            onTap: _busy || d.serverId == null || !app.canUseServer ? null : () => showEmailDialog(context, d),
          ),
          _IconAction(icon: Icons.open_in_full_rounded, tooltip: 'Layar penuh', onTap: _busy || !canFile ? null : _fullScreen),
          PopupMenuButton<String>(
            tooltip: 'Lainnya',
            icon: Icon(Icons.more_vert_rounded, color: YmColors.textMuted),
            enabled: !_busy,
            onSelected: (v) {
              switch (v) {
                case 'open':
                  _openExternal();
                case 'save':
                  _saveCopy();
                case 'folder':
                  _showInFolder();
                case 'project':
                  Navigator.pop(context);
                  Nav.openDocsForProject(d.projectId);
                case 'delete':
                  _delete();
              }
            },
            itemBuilder: (_) {
              final s = app.session!;
              final canDelete = s.isAdmin || (d.isUnsynced && d.createdBy.toLowerCase() == s.username.toLowerCase());
              return [
                PopupMenuItem(value: 'open', enabled: canFile, child: const Text('Buka dengan aplikasi lain (Office / WPS)')),
                PopupMenuItem(value: 'save', enabled: canFile, child: const Text('Simpan salinan…')),
                PopupMenuItem(value: 'folder', enabled: canFile, child: const Text('Lihat di folder')),
                if (d.projectId.isNotEmpty) PopupMenuItem(value: 'project', child: Text('Semua dokumen proyek ${d.projectCode}')),
                if (canDelete) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    enabled: d.isUnsynced || app.canUseServer,
                    child: Text(d.isUnsynced ? 'Hapus dari antrian' : 'Hapus dari arsip', style: TextStyle(color: YmColors.danger)),
                  ),
                ],
              ];
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- data dokumen
  Widget _dataView(AppState app) {
    final searcher = app.searcher;
    final related = searcher.related(d, app.visibleDocs);
    final series = searcher.seriesOf(d, app.visibleDocs);
    final project = d.projectId.isEmpty ? null : app.projectById(d.projectId);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Panel(
            expand: true,
            padding: EdgeInsets.zero,
            child: DefaultTabController(
              length: 4,
              initialIndex: widget.initialTab.clamp(0, 3).toInt(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // judul terstruktur
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('DOKUMEN TERSTRUKTUR', style: YmTextStyles.overline.copyWith(letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: YmTextStyles.pageTitle.copyWith(fontSize: 28, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Text(
                              d.description.isNotEmpty
                                  ? d.description
                                  : 'Data dokumen dikelompokkan per bagian. Klik nilai mana saja untuk melihat detailnya, menyalin, atau mencarinya di file asli.',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: kFont, fontSize: 14, height: 1.6, color: YmColors.textMuted),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 24),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('TANGGAL DOKUMEN', style: YmTextStyles.overline.copyWith(letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(formatIsoDate(d.docDate), style: YmTextStyles.headline.copyWith(fontSize: 17)),
                          const SizedBox(height: 4),
                          Text('Tahun anggaran ${d.year}', style: YmTextStyles.label.copyWith(fontSize: 12)),
                        ]),
                      ],
                    ),
                  ),
                  if (series.length > 1)
                    Padding(padding: const EdgeInsets.fromLTRB(28, 0, 28, 14), child: _SeriesStrip(current: d, series: series)),
                  // referensi
                  Container(
                    color: YmColors.surfaceAlt.withOpacity(0.55),
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('REFERENSI', style: YmTextStyles.overline.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _field('Nomor dokumen', d.docNumber, 'Data dokumen', 'Referensi', link: true)),
                        const SizedBox(width: 24),
                        Expanded(child: _field('Proyek / paket', d.projectCode.isEmpty ? '' : '${d.projectCode} — ${d.projectName}', 'Data proyek', 'Referensi', link: true)),
                        const SizedBox(width: 24),
                        Expanded(child: _field('Seri / kelompok', d.series, 'Data dokumen', 'Referensi', link: true)),
                      ]),
                    ]),
                  ),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                    tabs: [
                      const Tab(text: 'DATA'),
                      const Tab(text: 'PROYEK'),
                      Tab(text: 'TERKAIT (${related.length})'),
                      const Tab(text: 'RIWAYAT VERSI'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _dataTab(),
                        _projectTab(project),
                        _RelatedTab(doc: d, related: related, series: series),
                        _VersionsTab(doc: d),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 340,
          child: ListView(
            children: [
              Reveal(index: 1, child: _evidencePanel(app)),
              const SizedBox(height: 14),
              Reveal(index: 2, child: _actionsPanel(app)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dataTab() {
    final rows = <(String, String)>[
      ('Kategori', categoryOf(d.category).label),
      ('Tag', d.tags),
      ('Keterangan', d.description),
      ('Nama file', d.fileName),
      ('Ukuran / jenis', '${formatBytes(d.fileSize)} • ${fileKind(d.extension)}'),
      ('Diunggah oleh', '${d.createdByName} (@${d.createdBy})'),
      ('Tanggal input', formatDateTime(d.createdAt)),
      ('Masuk server', d.uploadedAt == null ? '' : formatDateTime(d.uploadedAt)),
      ('Salinan di PC ini', _hasLocal ? 'Ada — bisa dibuka saat offline' : 'Belum diunduh'),
      ('Sidik jari file (SHA-256)', d.sha256),
    ];
    return _twoColumns([for (final r in rows) _field(r.$1, r.$2, 'Data dokumen', 'Data')]);
  }

  Widget _projectTab(Project? p) {
    if (p == null) {
      return EmptyState(
        icon: Icons.engineering_outlined,
        title: d.projectCode.isEmpty ? 'Tanpa proyek' : 'Data proyek belum tersedia',
        message: d.projectCode.isEmpty
            ? 'Dokumen ini tidak terhubung ke paket pekerjaan tertentu.'
            : 'Detail proyek ${d.projectCode} akan muncul setelah daftar proyek disinkronkan dari server.',
      );
    }
    final rows = <(String, String)>[
      ('Kode paket', p.code),
      ('Nama paket', p.name),
      ('Jenis pekerjaan', p.type),
      ('Lokasi', p.location),
      ('Tahun anggaran', '${p.year}'),
      ('Sumber dana', p.fundingSource),
      ('Nilai kontrak', p.contractValue > 0 ? formatRupiah(p.contractValue) : ''),
      ('Nomor kontrak', p.contractNumber),
      ('Kontraktor', p.contractor),
      ('Konsultan pengawas', p.supervisor),
      ('PPK', p.ppk),
      ('Masa pelaksanaan', [formatIsoDate(p.startDate), formatIsoDate(p.endDate)].where((e) => e != '-').join(' s.d. ')),
      ('Status', '${p.status} • progres ${p.progress}%'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
      children: [
        Row(children: [
          Expanded(child: Text('Progres fisik', style: YmTextStyles.fieldLabel)),
          Text('${p.progress}%', style: YmTextStyles.username.copyWith(color: YmColors.primary)),
        ]),
        const SizedBox(height: 6),
        ProgressBar(value: p.progress / 100, height: 8, color: YmColors.success),
        const SizedBox(height: 18),
        _twoColumns([for (final r in rows) _field(r.$1, r.$2, 'Data proyek', 'Proyek')], shrink: true),
      ],
    );
  }

  Widget _twoColumns(List<Widget> fields, {bool shrink = false}) {
    final left = <Widget>[], right = <Widget>[];
    for (var i = 0; i < fields.length; i++) {
      (i.isEven ? left : right).add(fields[i]);
    }
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
        Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 24), color: YmColors.line, height: 40.0 * left.length),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
      ],
    );
    if (shrink) return body;
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(28, 18, 28, 24), child: body);
  }

  /// Satu nilai yang bisa diklik (versi web: label kecil + nilai, garis bawah tipis).
  Widget _field(String label, String value, String source, String group, {bool link = false}) {
    final picked = _picked?.label == label;
    final empty = value.trim().isEmpty;
    return _ValueTile(
      label: label,
      value: empty ? '—' : value,
      selected: picked,
      link: link && !empty,
      onTap: empty ? null : () => setState(() => _picked = _Picked(label, value, source, group)),
    );
  }

  /// Panel kanan "Detail nilai" (versi web: Source evidence).
  Widget _evidencePanel(AppState app) {
    final p = _picked!;
    final inContent = (app.tokens[d.clientId] ?? '').toLowerCase().contains(p.value.toLowerCase().split(RegExp(r'\s+')).first);
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Expanded(child: Text(k, style: YmTextStyles.label.copyWith(fontSize: 12.5))),
            Flexible(child: Text(v, textAlign: TextAlign.right, style: YmTextStyles.username.copyWith(fontSize: 12.5))),
          ]),
        );
    return Panel(
      padding: const EdgeInsets.all(20),
      child: AnimatedSwitcher(
        duration: motion(context, const Duration(milliseconds: 260)),
        transitionBuilder: (c, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a), child: c),
        ),
        child: Column(
          key: ValueKey(p.label),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text('DETAIL NILAI', style: YmTextStyles.overline.copyWith(color: YmColors.primary, letterSpacing: 1.4, fontWeight: FontWeight.w700))),
              Icon(Icons.center_focus_strong_outlined, size: 18, color: YmColors.primary),
            ]),
            const SizedBox(height: 6),
            Text(p.label, style: YmTextStyles.headline),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: YmColors.line)),
              child: SelectableText(p.value, style: TextStyle(fontFamily: kFont, fontSize: 14, fontWeight: FontWeight.w600, color: YmColors.textDark, height: 1.45)),
            ),
            const SizedBox(height: 16),
            row('Sumber', p.source),
            row('Bagian', p.group),
            row('Ditemukan di isi file', inContent ? 'Ya' : 'Tidak / belum terbaca'),
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 16),
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: YmColors.primary, width: 2))),
              child: Text('"${p.label}: ${p.value}"',
                  maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kFont, fontSize: 12.5, fontStyle: FontStyle.italic, color: YmColors.textMuted)),
            ),
            ElevatedButton.icon(
              style: primaryButtonStyle(color: YmColors.isDark ? null : const Color(0xFF0B1C30)),
              onPressed: () => _showSource(p.value.split(' — ').first),
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('Cari di file asli'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: outlineButtonStyle(),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: p.value));
                if (mounted) showSnack(context, '"${p.label}" disalin.');
              },
              icon: const Icon(Icons.content_copy_rounded, size: 16),
              label: const Text('Salin nilai'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Nav.searchDocs(p.value.split(' — ').first);
              },
              child: const Text('Cari dokumen lain dengan nilai ini'),
            ),
          ],
        ),
      ),
    );
  }

  /// Panel kanan "Tindakan": kirim draf, edit, ajukan perubahan, upload ulang.
  Widget _actionsPanel(AppState app) {
    final s = app.session!;
    final own = d.createdBy.toLowerCase() == s.username.toLowerCase();
    // Admin: edit langsung. Staf: dokumen miliknya yang BELUM terupload boleh diedit langsung;
    // yang sudah diarsipkan harus lewat permintaan perubahan ke admin.
    final canEdit = s.isAdmin || (d.isUnsynced && own);
    final canRequest = !s.isAdmin && !d.isUnsynced && d.serverId != null && !s.isSetupAdmin;
    return Panel(
      title: 'Tindakan',
      icon: Icons.bolt_rounded,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (d.lastError != null && d.isUnsynced) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: YmColors.dangerSoft, borderRadius: BorderRadius.circular(10)),
              child: Text(d.lastError!, style: TextStyle(fontFamily: kFont, fontSize: 12, color: YmColors.danger)),
            ),
            const SizedBox(height: 10),
          ],
          if (own && d.isUnsynced && d.status != DocStatus.uploading) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: YmColors.primarySoft.withOpacity(YmColors.isDark ? 1 : 0.5), borderRadius: BorderRadius.circular(10)),
              child: Text(
                d.status == DocStatus.draft
                    ? 'Draf — belum dikirim. Periksa isi file (tab File asli) dan data di kiri. Kalau sudah benar, kirim ke server.'
                    : 'Belum terkirim ke server. Masih bisa diperbaiki atau ditahan dulu sebagai draf.',
                style: YmTextStyles.chatText.copyWith(fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 10),
            if (d.status == DocStatus.draft) ...[
              ElevatedButton.icon(
                style: primaryButtonStyle(color: YmColors.success),
                onPressed: _busy ? null : _submit,
                icon: const Icon(Icons.send_rounded, size: 17),
                label: Text(app.canUseServer ? 'Sudah benar — kirim ke server' : 'Kirim saat server online'),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              style: outlineButtonStyle(),
              onPressed: _busy ? null : _replaceFile,
              icon: const Icon(Icons.swap_horiz_rounded, size: 17),
              label: const Text('Ganti file'),
            ),
            if (d.status == DocStatus.pending || d.status == DocStatus.failed) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: outlineButtonStyle(),
                onPressed: _busy
                    ? null
                    : () async {
                        await AppState.instance.holdAsDraft(d);
                        if (mounted) setState(() {});
                      },
                icon: const Icon(Icons.pause_circle_outline_rounded, size: 17),
                label: const Text('Tahan sebagai draf'),
              ),
            ],
            const SizedBox(height: 8),
          ],
          if (canEdit)
            OutlinedButton.icon(
              style: outlineButtonStyle(),
              onPressed: _busy || d.status == DocStatus.uploading || (!d.isUnsynced && !app.canUseServer) ? null : _edit,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: Text(d.isUnsynced ? 'Edit data (belum terkirim)' : 'Edit data dokumen'),
            ),
          // belum terkirim (draf / tertunda internet / gagal): boleh dihapus dari antrian
          if (canEdit && d.isUnsynced) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: outlineButtonStyle().copyWith(foregroundColor: WidgetStatePropertyAll(YmColors.danger), iconColor: WidgetStatePropertyAll(YmColors.danger)),
              onPressed: _busy || d.status == DocStatus.uploading ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              label: const Text('Hapus dari antrian'),
            ),
          ],
          if (canRequest) ...[
            OutlinedButton.icon(
              style: outlineButtonStyle(),
              onPressed: _busy || !app.canUseServer
                  ? null
                  : () async {
                      final sent = await showEditRequestDialog(context, d);
                      if (sent == true && mounted) {
                        showSnack(context, 'Permintaan perubahan terkirim ke admin. Pantau statusnya di menu Permintaan Edit.');
                      }
                    },
              icon: const Icon(Icons.rate_review_outlined, size: 17),
              label: const Text('Ajukan perubahan'),
            ),
            const SizedBox(height: 6),
            Text(
              app.canUseServer
                  ? 'Dokumen yang sudah diarsipkan hanya bisa diubah dengan persetujuan admin.'
                  : 'Ajukan perubahan butuh koneksi ke server.',
              style: YmTextStyles.label,
            ),
          ],
          if (canEdit && d.status == DocStatus.failed) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: primaryButtonStyle(color: YmColors.warning),
              onPressed: () async {
                await app.retryDoc(d);
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Upload ulang'),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: outlineButtonStyle(),
            onPressed: _busy || d.serverId == null || !app.canUseServer ? null : () => showEmailDialog(context, d),
            icon: const Icon(Icons.forward_to_inbox_outlined, size: 17),
            label: const Text('Kirim ke email'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- file asli
  Widget _fileView(bool needServer) {
    final app = AppState.instance;
    return Panel(
      expand: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('BUKTI ASLI', style: YmTextStyles.overline.copyWith(color: YmColors.primary, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.username.copyWith(fontSize: 14)),
                  if (_query.trim().isNotEmpty) Text('Menyorot: "$_query"', style: YmTextStyles.label.copyWith(fontSize: 12)),
                ]),
              ),
              OutlinedButton(style: outlineButtonStyle(), onPressed: () => setState(() => _view = _View.data), child: const Text('Kembali ke data dokumen')),
            ]),
          ),
          Divider(height: 1, color: YmColors.line),
          Expanded(
            child: needServer
                ? EmptyState(
                    icon: Icons.cloud_download_outlined,
                    title: 'File tersimpan di server',
                    message: app.canUseServer
                        ? 'Unduh file ke PC ini untuk melihatnya. Setelah diunduh, file juga bisa dibuka saat offline.'
                        : 'Saat ini offline. Data dokumen tetap bisa dilihat, file bisa diunduh saat terhubung lagi.',
                    action: app.canUseServer
                        ? ElevatedButton.icon(
                            style: primaryButtonStyle(),
                            onPressed: _busy ? null : _download,
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: Text('Unduh (${formatBytes(d.fileSize)})'),
                          )
                        : null,
                  )
                : DocumentViewer(
                    key: ValueKey('viewer#$_query'),
                    path: d.localPath,
                    fileName: d.fileName,
                    initialQuery: _query,
                    title: d.title,
                    printController: _print,
                    trailing: [ToolButton(icon: Icons.open_in_full_rounded, tooltip: 'Layar penuh', onPressed: _busy ? null : _fullScreen)],
                    fallbackActions: externalFileActions(context, d.localPath, d.fileName),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Tombol ikon bulat kecil di kartu judul.
class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _IconAction({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          style: IconButton.styleFrom(backgroundColor: YmColors.surfaceAlt, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          icon: Icon(icon, size: 19, color: onTap == null ? YmColors.outline.withOpacity(0.5) : YmColors.textMuted),
        ),
      );
}

/// Satu nilai di tampilan data: label kecil + nilai; terpilih = latar lembut.
class _ValueTile extends StatefulWidget {
  final String label;
  final String value;
  final bool selected;
  final bool link;
  final VoidCallback? onTap;
  const _ValueTile({required this.label, required this.value, required this.selected, required this.link, this.onTap});

  @override
  State<_ValueTile> createState() => _ValueTileState();
}

class _ValueTileState extends State<_ValueTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return MouseRegion(
      cursor: w.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: w.onTap,
        child: AnimatedContainer(
          duration: motion(context, const Duration(milliseconds: 180)),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            color: w.selected ? YmColors.primarySoft.withOpacity(YmColors.isDark ? 1 : 0.6) : (_hover && w.onTap != null ? YmColors.surfaceAlt : Colors.transparent),
            borderRadius: BorderRadius.circular(9),
            border: Border(bottom: BorderSide(color: w.selected ? YmColors.primary : YmColors.line, width: w.selected ? 1.5 : 1)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w.label.toUpperCase(), style: YmTextStyles.overline.copyWith(fontSize: 10.5, letterSpacing: 0.9)),
            const SizedBox(height: 4),
            Text(
              w.value,
              style: YmTextStyles.fieldValue.copyWith(color: w.link ? YmColors.link : (w.value == '—' ? YmColors.outline : YmColors.textDark)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Dokumen yang berhubungan (kode/nomor sama, proyek, tag, judul mirip), dikelompokkan per tahun.
class _RelatedTab extends StatelessWidget {
  final DocRecord doc;
  final List<RelatedDoc> related;
  final List<DocRecord> series;
  const _RelatedTab({required this.doc, required this.related, required this.series});

  @override
  Widget build(BuildContext context) {
    final seriesIds = series.map((e) => e.clientId).toSet();
    final others = related.where((r) => !seriesIds.contains(r.doc.clientId)).toList();
    if (series.length > 1) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        children: [
          Text('SERI DOKUMEN (${series.length} versi, dari yang paling lama)',
              style: YmTextStyles.label.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.3)),
          const SizedBox(height: 8),
          for (var i = 0; i < series.length; i++) _SeriesItem(doc: series[i], isCurrent: series[i].clientId == doc.clientId, isLast: i == series.length - 1),
          if (others.isNotEmpty) ...[
            const Divider(height: 28),
            Text('RELASI LAIN', style: YmTextStyles.label.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.3)),
            _RelatedTab(doc: doc, related: others, series: const []),
          ],
        ],
      );
    }
    if (related.isEmpty) {
      return const EmptyState(
        icon: Icons.link_off_rounded,
        title: 'Belum ada dokumen terkait',
        message: 'Dokumen terkait dicari dari kode/nomor yang sama (di data maupun isi file), proyek, tag, dan judul yang mirip.',
      );
    }
    final byYear = <int, List<RelatedDoc>>{};
    for (final r in related) {
      byYear.putIfAbsent(r.doc.year, () => []).add(r);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
    final codes = SmartSearch.metaCodes(doc);
    final nested = series.isEmpty && related.isNotEmpty && context.findAncestorWidgetOfExactType<_RelatedTab>() != null;
    return ListView(
      shrinkWrap: nested,
      physics: nested ? const NeverScrollableScrollPhysics() : null,
      padding: nested ? const EdgeInsets.only(top: 6) : const EdgeInsets.fromLTRB(14, 12, 14, 16),
      children: [
        if (codes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text('Kode/nomor di dokumen ini: ${codes.take(8).join(', ')}', style: YmTextStyles.label.copyWith(fontSize: 11.5)),
          ),
        for (final y in years) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: YmColors.accentPurple, borderRadius: BorderRadius.circular(6)),
                child: Text('$y', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Text('${byYear[y]!.length} dokumen', style: YmTextStyles.label),
              if (y < doc.year) ...[const SizedBox(width: 6), Text('• tahun lampau', style: YmTextStyles.label.copyWith(fontSize: 11))],
            ]),
          ),
          for (final r in byYear[y]!)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: YmColors.borderLavender)),
              child: ListTile(
                dense: true,
                onTap: () => showDocDetail(context, r.doc),
                leading: FileTypeIcon(ext: r.doc.extension, size: 30),
                title: Text(r.doc.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: YmTextStyles.username),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [if (r.doc.docNumber.isNotEmpty) 'No. ${r.doc.docNumber}', formatIsoDate(r.doc.docDate), categoryOf(r.doc.category).label].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: YmTextStyles.label.copyWith(fontSize: 11),
                    ),
                    Text(r.reasons.join(' • '),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: YmColors.accentPurple, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Riwayat versi file (file lama yang diganti lewat permintaan edit yang disetujui).
class _VersionsTab extends StatefulWidget {
  final DocRecord doc;
  const _VersionsTab({required this.doc});

  @override
  State<_VersionsTab> createState() => _VersionsTabState();
}

class _VersionsTabState extends State<_VersionsTab> {
  List<DocVersion>? _items;
  int _current = 1;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = AppState.instance;
    final id = widget.doc.serverId;
    if (id == null || !app.canUseServer) return;
    setState(() => _loading = true);
    try {
      final (cur, items) = await app.withToken((a, t) => a.listVersions(t, id));
      if (mounted) setState(() {
        _current = cur;
        _items = items;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(DocVersion v) async {
    try {
      final path = await AppState.instance.downloadTemp(
        '/documents/${widget.doc.serverId}/versions/${v.id}/file',
        'versi_${widget.doc.serverId}_${v.versionNo}',
        v.fileName,
      );
      if (!mounted) return;
      await openDocumentViewer(context,
          path: path, title: '${widget.doc.title} — versi ${v.versionNo}', fileName: v.fileName, subtitle: 'File lama (riwayat versi)');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    if (widget.doc.serverId == null) {
      return const EmptyState(icon: Icons.history_rounded, title: 'Belum di server', message: 'Riwayat versi tersedia setelah dokumen terupload.');
    }
    if (!app.canUseServer) {
      return const EmptyState(icon: Icons.cloud_off_rounded, title: 'Offline', message: 'Riwayat versi file disimpan di server.');
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: YmColors.buzzRed)));
    final items = _items ?? const <DocVersion>[];
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        ListTile(
          leading: Icon(Icons.verified_rounded, color: YmColors.statusOnline),
          title: Text('Versi $_current (sekarang)', style: YmTextStyles.username),
          subtitle: Text(widget.doc.fileName, style: YmTextStyles.label),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Belum pernah diganti. File pengganti dari permintaan edit yang disetujui admin akan tercatat di sini, '
                'dan file lama tetap tersimpan.', style: YmTextStyles.label.copyWith(fontSize: 12)),
          ),
        for (final v in items)
          ListTile(
            leading: Icon(Icons.history_rounded, color: YmColors.textMuted),
            title: Text('Versi ${v.versionNo} • ${v.fileName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.username),
            subtitle: Text('Diganti ${formatDateTime(v.replacedAt)} oleh ${v.replacedBy}${v.note.isEmpty ? '' : '\nAlasan: ${v.note}'}',
                style: YmTextStyles.label.copyWith(fontSize: 11)),
            trailing: IconButton(tooltip: 'Buka versi ini', icon: const Icon(Icons.open_in_new_rounded, size: 18), onPressed: () => _open(v)),
          ),
      ],
    );
  }
}


/// Ringkasan seri di tab Info: Formula A (2000) → Formula B (2002) → [ini].
class _SeriesStrip extends StatelessWidget {
  final DocRecord current;
  final List<DocRecord> series;
  const _SeriesStrip({required this.current, required this.series});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: YmColors.accentPurple.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: YmColors.accentPurple.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.account_tree_rounded, size: 16, color: YmColors.accentPurple),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                current.series.isNotEmpty ? 'Seri "${current.series}" — ${series.length} versi' : 'Bagian dari seri — ${series.length} versi',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: YmColors.accentPurple),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < series.length; i++) ...[
                if (i > 0) Icon(Icons.arrow_forward_rounded, size: 13, color: YmColors.textMuted),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: series[i].clientId == current.clientId ? YmColors.accentPurple : YmColors.surface,
                  side: BorderSide(color: YmColors.borderLavender),
                  label: Text(
                    '${series[i].title}  •  ${series[i].year}',
                    style: TextStyle(
                      fontSize: 11,
                      color: series[i].clientId == current.clientId ? Colors.white : YmColors.textDark,
                      fontWeight: series[i].clientId == current.clientId ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  onPressed: series[i].clientId == current.clientId ? null : () => showDocDetail(context, series[i]),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Satu baris di linimasa seri.
class _SeriesItem extends StatelessWidget {
  final DocRecord doc;
  final bool isCurrent;
  final bool isLast;
  const _SeriesItem({required this.doc, required this.isCurrent, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = isCurrent ? YmColors.accentPurple : YmColors.accentBlue;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(color: isCurrent ? color : YmColors.surface, shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: YmColors.borderLavender)),
              ],
            ),
          ),
          Expanded(
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              color: isCurrent ? YmColors.accentPurple.withOpacity(0.07) : YmColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isCurrent ? color : YmColors.borderLavender)),
              child: ListTile(
                dense: true,
                onTap: isCurrent ? null : () => showDocDetail(context, doc),
                leading: FileTypeIcon(ext: doc.extension, size: 30),
                title: Text(doc.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: YmTextStyles.username),
                subtitle: Text(
                  [
                    '${doc.year}',
                    if (doc.docNumber.isNotEmpty) 'No. ${doc.docNumber}',
                    formatIsoDate(doc.docDate),
                    if (isCurrent) 'DOKUMEN INI',
                  ].join(' • '),
                  style: YmTextStyles.label.copyWith(fontSize: 11, fontWeight: isCurrent ? FontWeight.w700 : null),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
