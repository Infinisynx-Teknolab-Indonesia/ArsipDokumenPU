import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/categories.dart';
import '../core/file_tools.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';
import '../core/smart_search.dart';
import 'doc_form.dart';
import 'edit_request_dialog.dart';
import 'email_dialog.dart';
import '../print/print_dialog.dart';
import '../viewer/document_viewer.dart';
import '../viewer/viewer_common.dart';

/// [highlight] = kata/kode yang langsung disorot di isi file (dari hasil pencarian).
Future<void> showDocDetail(BuildContext context, DocRecord doc, {String highlight = ''}) {
  return showDialog(context: context, builder: (_) => _DocDetailDialog(doc: doc, highlight: highlight));
}

class _DocDetailDialog extends StatefulWidget {
  final DocRecord doc;
  final String highlight;
  const _DocDetailDialog({required this.doc, this.highlight = ''});

  @override
  State<_DocDetailDialog> createState() => _DocDetailDialogState();
}

class _DocDetailDialogState extends State<_DocDetailDialog> {
  bool _busy = false;
  final _print = PrintController(); // dipakai tombol Cetak di panel kanan

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
  Future<void> _view() async {
    String? path;
    await _run(() async => path = await AppState.instance.ensureLocalFile(d));
    if (path == null || !mounted) return;
    await openDocumentViewer(
      context,
      path: path!,
      title: d.title,
      fileName: d.fileName,
      initialQuery: widget.highlight,
      subtitle: [if (d.docNumber.isNotEmpty) 'No. ${d.docNumber}', formatIsoDate(d.docDate)].join('  •  '),
      doc: d,
    );
    if (mounted) setState(() {});
  }

  Future<void> _open() => _run(() async {
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
    final r = await FilePicker.platform.pickFiles(
      dialogTitle: 'Pilih file pengganti',
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
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

  @override
  Widget build(BuildContext context) {
    // Ikut diperbarui saat status kirim berubah (draf -> antrian -> terkirim).
    return ListenableBuilder(listenable: AppState.instance, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final app = AppState.instance;
    final s = app.session!;
    final canDelete = s.isAdmin || (d.isUnsynced && d.createdBy.toLowerCase() == s.username.toLowerCase());
    final own = d.createdBy.toLowerCase() == s.username.toLowerCase();
    // Admin: edit langsung. Staf: dokumen miliknya yang BELUM terupload boleh diedit langsung;
    // yang sudah diarsipkan harus lewat permintaan perubahan ke admin.
    final canEdit = s.isAdmin || (d.isUnsynced && own);
    final canRequest = !s.isAdmin && !d.isUnsynced && d.serverId != null && !s.isSetupAdmin;
    final searcher = app.searcher;
    final related = searcher.related(d, app.visibleDocs);
    final series = searcher.seriesOf(d, app.visibleDocs);
    final needServer = !_hasLocal;
    final size = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: size.width * 0.92,
        height: size.height * 0.9,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [YmColors.titleBarStart, YmColors.titleBarEnd]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  FileTypeIcon(ext: d.extension, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white)),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Preview
                  Expanded(
                    flex: 3,
                    child: Container(
                      color: const Color(0xFFF7F8FD),
                      child: _preview(needServer),
                    ),
                  ),
                  // Info
                  Container(
                    width: 400,
                    decoration: const BoxDecoration(border: Border(left: BorderSide(color: YmColors.borderLavender))),
                    child: DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: YmColors.accentPurple,
                            unselectedLabelColor: YmColors.textMuted,
                            indicatorColor: YmColors.accentPurple,
                            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                            tabs: [
                              const Tab(text: 'Info'),
                              Tab(text: 'Terkait (${related.length})'),
                              const Tab(text: 'Riwayat Versi'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                    ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Row(children: [CategoryBadge(code: d.category), const Spacer(), DocStatusChip(status: d.status)]),
                        if (series.length > 1) ...[
                          const SizedBox(height: 12),
                          _SeriesStrip(current: d, series: series),
                        ],
                        if (d.lastError != null && d.isUnsynced) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: YmColors.buzzRed.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                            child: Text(d.lastError!, style: const TextStyle(fontSize: 11.5, color: YmColors.buzzRed)),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _info('Nomor Dokumen', d.docNumber),
                        _info('Tanggal Dokumen', formatIsoDate(d.docDate)),
                        _info('Proyek / Paket', d.projectCode.isEmpty ? '-' : '${d.projectCode}\n${d.projectName}'),
                        _info('Kategori', categoryOf(d.category).label),
                        _info('Keterangan', d.description),
                        _info('Tag', d.tags),
                        _info('Seri / Kelompok', d.series),
                        const Divider(height: 24),
                        _info('Nama File', d.fileName),
                        _info('Ukuran', '${formatBytes(d.fileSize)} • ${fileKind(d.extension)}'),
                        _info('Diunggah oleh', '${d.createdByName} (@${d.createdBy})'),
                        _info('Tanggal input', formatDateTime(d.createdAt)),
                        if (d.uploadedAt != null) _info('Masuk server', formatDateTime(d.uploadedAt)),
                        _info('Salinan di PC ini', _hasLocal ? 'Ada' : 'Belum diunduh'),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          style: primaryButtonStyle(),
                          onPressed: _busy || (needServer && !app.canUseServer) ? null : _view,
                          icon: const Icon(Icons.chrome_reader_mode_rounded, size: 18),
                          label: Text(canViewInApp(d.extension) ? 'Buka dokumen (layar penuh)' : 'Buka dokumen'),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: outlineButtonStyle(),
                                onPressed: _busy || needServer || !canViewInApp(d.extension)
                                    ? null
                                    : () => showPrintDialog(context, controller: _print, title: d.title, fileName: d.fileName),
                                icon: const Icon(Icons.print_rounded, size: 17),
                                label: const Text('Cetak'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: outlineButtonStyle(),
                                onPressed: _busy || d.serverId == null || !app.canUseServer ? null : () => showEmailDialog(context, d),
                                icon: const Icon(Icons.forward_to_inbox_rounded, size: 17),
                                label: const Text('Kirim Email'),
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: YmColors.textMuted, textStyle: const TextStyle(fontSize: 12)),
                            onPressed: _busy || (needServer && !app.canUseServer) ? null : _open,
                            icon: const Icon(Icons.open_in_new_rounded, size: 15),
                            label: const Text('Buka dengan aplikasi lain (Office / WPS)'),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: outlineButtonStyle(),
                                onPressed: _busy || (needServer && !app.canUseServer) ? null : _saveCopy,
                                icon: const Icon(Icons.save_alt_rounded, size: 17),
                                label: const Text('Simpan salinan'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: outlineButtonStyle(),
                                onPressed: _busy || (needServer && !app.canUseServer) ? null : _showInFolder,
                                icon: const Icon(Icons.folder_open_rounded, size: 17),
                                label: const Text('Lihat di folder'),
                              ),
                            ),
                          ],
                        ),
                        if (needServer && !app.canUseServer)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('File belum ada di PC ini. Butuh koneksi ke server untuk mengunduh.',
                                style: YmTextStyles.label.copyWith(fontSize: 11.5)),
                          ),
                        if (own && d.isUnsynced && d.status != DocStatus.uploading) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: YmColors.accentPurple.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: YmColors.accentPurple.withOpacity(0.3)),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Text(
                                d.status == DocStatus.draft
                                    ? 'DRAF — belum dikirim. Periksa isi file di kiri dan data di atas. Kalau sudah benar, kirim ke server.'
                                    : 'Belum terkirim ke server. Masih bisa diperbaiki atau ditahan dulu sebagai draf.',
                                style: YmTextStyles.chatText.copyWith(fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              if (d.status == DocStatus.draft)
                                ElevatedButton.icon(
                                  style: primaryButtonStyle(color: YmColors.statusOnline),
                                  onPressed: _busy ? null : _submit,
                                  icon: const Icon(Icons.send_rounded, size: 17),
                                  label: Text(app.canUseServer ? 'Sudah benar — kirim ke server' : 'Sudah benar — kirim saat server online'),
                                ),
                              const SizedBox(height: 6),
                              Row(children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: outlineButtonStyle(),
                                    onPressed: _busy ? null : _replaceFile,
                                    icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                                    label: const Text('Ganti file'),
                                  ),
                                ),
                                if (d.status == DocStatus.pending || d.status == DocStatus.failed) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: outlineButtonStyle(),
                                      onPressed: _busy
                                          ? null
                                          : () async {
                                              await AppState.instance.holdAsDraft(d);
                                              if (mounted) setState(() {});
                                            },
                                      icon: const Icon(Icons.pause_circle_outline_rounded, size: 17),
                                      label: const Text('Tahan (draf)'),
                                    ),
                                  ),
                                ],
                              ]),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (canEdit)
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: outlineButtonStyle(),
                                  onPressed: _busy || (!d.isUnsynced && !app.canUseServer) ? null : _edit,
                                  icon: const Icon(Icons.edit_rounded, size: 17),
                                  label: const Text('Edit info'),
                                ),
                              ),
                            if (canRequest)
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: outlineButtonStyle(),
                                  onPressed: _busy || !app.canUseServer
                                      ? null
                                      : () async {
                                          final sent = await showEditRequestDialog(context, d);
                                          if (sent == true && mounted) {
                                            showSnack(context, 'Permintaan perubahan terkirim ke admin. Pantau statusnya di menu Permintaan Edit.');
                                          }
                                        },
                                  icon: const Icon(Icons.rate_review_rounded, size: 17),
                                  label: const Text('Ajukan Perubahan'),
                                ),
                              ),
                            if (canEdit && d.status == DocStatus.failed) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: outlineButtonStyle(),
                                  onPressed: () async {
                                    await app.retryDoc(d);
                                    if (mounted) setState(() {});
                                  },
                                  icon: const Icon(Icons.refresh_rounded, size: 17),
                                  label: const Text('Upload ulang'),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (canDelete) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: YmColors.buzzRed),
                            onPressed: _busy || (!d.isUnsynced && !app.canUseServer) ? null : _delete,
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            label: Text(d.isUnsynced ? 'Hapus dari antrian' : 'Hapus dari arsip'),
                          ),
                        ],
                        if (canRequest && !app.canUseServer)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Ajukan perubahan butuh koneksi ke server.', style: YmTextStyles.label.copyWith(fontSize: 11.5)),
                          ),
                        if (canRequest)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Dokumen yang sudah diarsipkan hanya bisa diubah dengan persetujuan admin.',
                                style: YmTextStyles.label.copyWith(fontSize: 11)),
                          ),
                      ],
                    ),
                                _RelatedTab(doc: d, related: related, series: series),
                                _VersionsTab(doc: d),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(bool needServer) {
    final app = AppState.instance;
    if (needServer) {
      return EmptyState(
        icon: Icons.cloud_download_rounded,
        title: 'File tersimpan di server',
        message: app.canUseServer
            ? 'Unduh file ke PC ini untuk melihat pratinjau. Setelah diunduh, file juga bisa dibuka saat offline.'
            : 'Saat ini offline. Data dokumen tetap bisa dilihat, file bisa diunduh saat terhubung lagi.',
        action: app.canUseServer
            ? ElevatedButton.icon(
                style: primaryButtonStyle(),
                onPressed: _busy ? null : _download,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text('Unduh (${formatBytes(d.fileSize)})'),
              )
            : null,
      );
    }
    return DocumentViewer(
      path: d.localPath,
      fileName: d.fileName,
      initialQuery: widget.highlight,
      title: d.title,
      printController: _print,
      trailing: [
        ToolButton(icon: Icons.open_in_full_rounded, tooltip: 'Layar penuh', onPressed: _busy ? null : _view),
      ],
      fallbackActions: externalFileActions(context, d.localPath, d.fileName),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: YmTextStyles.label.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
          SelectableText(value.isEmpty ? '-' : value, style: YmTextStyles.chatText.copyWith(fontSize: 13)),
        ],
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: YmColors.borderLavender)),
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
                        style: const TextStyle(fontSize: 10.5, color: YmColors.accentPurple, fontWeight: FontWeight.w600)),
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
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: YmColors.buzzRed)));
    final items = _items ?? const <DocVersion>[];
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        ListTile(
          leading: const Icon(Icons.verified_rounded, color: YmColors.statusOnline),
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
            leading: const Icon(Icons.history_rounded, color: YmColors.textMuted),
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
            const Icon(Icons.account_tree_rounded, size: 16, color: YmColors.accentPurple),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                current.series.isNotEmpty ? 'Seri "${current.series}" — ${series.length} versi' : 'Bagian dari seri — ${series.length} versi',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: YmColors.accentPurple),
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
                if (i > 0) const Icon(Icons.arrow_forward_rounded, size: 13, color: YmColors.textMuted),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: series[i].clientId == current.clientId ? YmColors.accentPurple : Colors.white,
                  side: const BorderSide(color: YmColors.borderLavender),
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
                  decoration: BoxDecoration(color: isCurrent ? color : Colors.white, shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: YmColors.borderLavender)),
              ],
            ),
          ),
          Expanded(
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              color: isCurrent ? YmColors.accentPurple.withOpacity(0.07) : Colors.white,
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
