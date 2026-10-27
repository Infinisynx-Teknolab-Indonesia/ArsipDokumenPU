import 'dart:async';
import 'package:flutter/material.dart';
import '../core/categories.dart';
import '../core/file_tools.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/smart_search.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../services/nav.dart';
import '../services/find_shortcut.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';
import 'doc_detail.dart';

enum _Sort { relevance, newest, docDate, title }

class DocumentsPage extends StatefulWidget {
  /// true = halaman "Dokumen Saya": hanya dokumen yang diinput user ini.
  final bool mineOnly;
  const DocumentsPage({super.key, this.mineOnly = false});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> with PageSearchField<DocumentsPage> {
  final _search = TextEditingController();

  @override
  String get searchPageId => widget.mineOnly ? 'mydocs' : 'docs';
  @override
  TextEditingController get searchController => _search;
  Timer? _debounce;
  String _query = ''; // kata kunci yang sudah "diendapkan" (debounce) -> hemat CPU untuk arsip besar
  String _project = ''; // '' = semua, '-' = tanpa proyek
  String _category = '';
  int _year = 0;
  String _status = ''; // '' | unsynced | failed | uploaded
  String _kind = '';
  _Sort _sort = _Sort.relevance;

  /// Hasil pencarian pintar terakhir (clientId -> hit), untuk menampilkan alasan cocok.
  Map<String, SearchHit> _hits = {};
  List<String> _extra = [];

  /// Tampilkan relasi (seri lintas tahun, kode sama, dll.) di bawah hasil pencarian.
  bool _showRelations = true;

  @override
  void initState() {
    super.initState();
    if (!widget.mineOnly) {
      Nav.docsProjectFilter.addListener(_applyNav);
      Nav.docsSearch.addListener(_applySearch);
      _applyNav();
      _applySearch();
    } else {
      Nav.myDocsStatus.addListener(_applyStatus);
      _applyStatus();
    }
  }

  void _applySearch() {
    final q = Nav.docsSearch.value;
    if (q == null) return;
    setState(() {
      _search.text = q;
      _query = q;
    });
    Nav.docsSearch.value = null;
  }

  void _applyStatus() {
    final st = Nav.myDocsStatus.value;
    if (st == null) return;
    setState(() => _status = st);
    Nav.myDocsStatus.value = null;
  }

  void _applyNav() {
    final id = Nav.docsProjectFilter.value;
    if (id == null) return;
    setState(() {
      _project = id;
      _category = '';
      _status = '';
    });
    Nav.docsProjectFilter.value = null;
  }

  @override
  void dispose() {
    Nav.docsProjectFilter.removeListener(_applyNav);
    Nav.myDocsStatus.removeListener(_applyStatus);
    Nav.docsSearch.removeListener(_applySearch);
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  List<DocRecord> _filtered(List<DocRecord> all) {
    final query = _query.trim();
    final list = all.where((d) {
      if (_project == '-' && d.projectId.isNotEmpty) return false;
      if (_project.isNotEmpty && _project != '-' && d.projectId != _project) return false;
      if (_category.isNotEmpty && d.category != _category) return false;
      if (_year != 0 && d.year != _year) return false;
      if (_kind.isNotEmpty && fileKind(d.extension) != _kind) return false;
      switch (_status) {
        case 'today':
          final n = DateTime.now();
          if (!(d.createdAt.year == n.year && d.createdAt.month == n.month && d.createdAt.day == n.day)) return false;
        case 'draft':
          if (d.status != DocStatus.draft) return false;
        case 'unsynced':
          if (!(d.status == DocStatus.pending || d.status == DocStatus.uploading)) return false;
        case 'failed':
          if (d.status != DocStatus.failed) return false;
        case 'uploaded':
          if (d.status != DocStatus.uploaded) return false;
      }
      return true;
    }).toList();

    // Pencarian pintar: metadata + isi file + kamus (lihat core/smart_search.dart)
    if (query.isEmpty) {
      _hits = {};
      _extra = [];
    } else {
      final searcher = AppState.instance.searcher;
      final hits = searcher.search(query, list);
      _hits = {for (final h in hits) h.doc.clientId: h};
      _extra = searcher.extraTerms(query);
      if (_sort == _Sort.relevance) return hits.map((h) => h.doc).toList();
      list
        ..clear()
        ..addAll(hits.map((h) => h.doc));
    }
    switch (_sort) {
      case _Sort.relevance:
      case _Sort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _Sort.docDate:
        list.sort((a, b) => b.docDate.compareTo(a.docDate));
      case _Sort.title:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return list;
  }

  void _reset() => setState(() {
        _search.clear();
        _query = '';
        _project = '';
        _category = '';
        _year = 0;
        _status = '';
        _kind = '';
      });

  Future<void> _export(List<DocRecord> list) async {
    try {
      final path = await FileTools.exportDocsCsv(list, fileName: 'arsip_dokumen_${isoDate(DateTime.now())}.csv');
      if (path != null && mounted) showSnack(context, 'Export ${list.length} dokumen ke $path');
    } catch (e) {
      if (mounted) showSnack(context, 'Export gagal: $e', error: true);
    }
  }

  /// Ringkasan + tab cepat untuk halaman Dokumen Saya.
  Widget _mySummary(List<DocRecord> mine) {
    final n = DateTime.now();
    final counts = <String, int>{
      '': mine.length,
      'draft': mine.where((d) => d.status == DocStatus.draft).length,
      'unsynced': mine.where((d) => d.status == DocStatus.pending || d.status == DocStatus.uploading).length,
      'failed': mine.where((d) => d.status == DocStatus.failed).length,
      'uploaded': mine.where((d) => d.status == DocStatus.uploaded).length,
      'today': mine.where((d) => d.createdAt.year == n.year && d.createdAt.month == n.month && d.createdAt.day == n.day).length,
    };
    const labels = {
      '': ('Semua', Icons.folder_rounded, YmColors.accentPurple),
      'today': ('Hari ini', Icons.today_rounded, YmColors.accentBlue),
      'draft': ('Draf (periksa dulu)', Icons.edit_note_rounded, YmColors.accentPurple),
      'unsynced': ('Menunggu upload', Icons.schedule_rounded, YmColors.statusAway),
      'failed': ('Gagal', Icons.error_outline_rounded, YmColors.buzzRed),
      'uploaded': ('Tersimpan di server', Icons.cloud_done_rounded, YmColors.statusOnline),
    };
    return Row(
      children: [
        for (final e in labels.entries) ...[
          Expanded(
            child: _SummaryTab(
              label: e.value.$1,
              icon: e.value.$2,
              color: e.value.$3,
              count: counts[e.key] ?? 0,
              selected: _status == e.key,
              onTap: () => setState(() => _status = e.key),
            ),
          ),
          if (e.key != 'uploaded') const SizedBox(width: 10),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final me = app.session!.username.toLowerCase();
        final all = widget.mineOnly ? app.visibleDocs.where((d) => d.createdBy.toLowerCase() == me).toList() : app.visibleDocs;
        final list = _filtered(all);
        // Relasi untuk 20 hasil teratas: cari "Formula C" -> ikut tampil Formula A (2000) & B (2002)
        final relations = <String, List<RelatedDoc>>{};
        if (_query.trim().isNotEmpty && _showRelations) {
          final searcher = app.searcher;
          for (final d in list.take(20)) {
            final rel = searcher.related(d, app.visibleDocs, limit: 30)
              ..sort((a, b) {
                if (a.sameSeries != b.sameSeries) return a.sameSeries ? -1 : 1;
                if (a.sameSeries) return a.doc.year.compareTo(b.doc.year);
                return b.score.compareTo(a.score);
              });
            final picked = rel.where((r) => r.sameSeries || r.score >= 8).take(8).toList();
            if (picked.isNotEmpty) relations[d.clientId] = picked;
          }
        }
        final years = all.map((d) => d.year).toSet().toList()..sort((a, b) => b.compareTo(a));
        if (_year != 0 && !years.contains(_year)) years.insert(0, _year);
        final projectValid = _project.isEmpty || _project == '-' || app.projects.any((p) => p.id == _project);
        if (!projectValid) _project = '';
        final hasFilter = _search.text.isNotEmpty || _project.isNotEmpty || _category.isNotEmpty || _year != 0 || _status.isNotEmpty || _kind.isNotEmpty;

        return PageBody(
          scroll: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Baris 1: cari + aksi
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      focusNode: searchFocus,
                      onChanged: (v) {
                        _debounce?.cancel();
                        _debounce = Timer(const Duration(milliseconds: 300), () {
                          if (mounted) setState(() => _query = v);
                        });
                        setState(() {});
                      },
                      decoration: fieldDecoration(
                        'Cari apa saja (Ctrl+F): judul, nomor, kode (mis. 544), isi PDF/Word/Excel, tag, proyek, pengunggah...',
                        icon: Icons.search_rounded,
                        suffix: _search.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => setState(() {
                                  _search.clear();
                                  _query = '';
                                }),
                              ),
                      ).copyWith(fillColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (app.failedCount > 0) ...[
                    OutlinedButton.icon(
                      style: outlineButtonStyle(),
                      onPressed: app.retryAllFailed,
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: YmColors.buzzRed),
                      label: Text('Upload ulang ${app.failedCount} gagal'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  OutlinedButton.icon(
                    style: outlineButtonStyle(),
                    onPressed: app.setupMode || app.syncing ? null : () => app.tick(forcePull: true),
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('Sinkronkan'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: outlineButtonStyle(),
                    onPressed: list.isEmpty ? null : () => _export(list),
                    icon: const Icon(Icons.file_download_rounded, size: 18),
                    label: const Text('Export Excel (CSV)'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: primaryButtonStyle(),
                    onPressed: () {
                      if (_project.isNotEmpty && _project != '-') {
                        Nav.uploadForProject(_project);
                      } else {
                        Nav.go('upload');
                      }
                    },
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: const Text('Unggah'),
                  ),
                ],
              ),
              if (_extra.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Pencarian pintar juga mencari: ${_extra.take(12).join(', ')}  (atur di Kamus Pencarian)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: YmTextStyles.label.copyWith(fontSize: 11.5),
                  ),
                ),
              const SizedBox(height: 10),
              // Baris 2: filter
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterDropdown<String>(
                    width: 300,
                    icon: Icons.engineering_rounded,
                    value: _project,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Semua proyek')),
                      const DropdownMenuItem(value: '-', child: Text('Tanpa proyek / umum')),
                      for (final p in app.projects) DropdownMenuItem(value: p.id, child: Text(p.label, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _project = v ?? ''),
                  ),
                  FilterDropdown<String>(
                    width: 250,
                    icon: Icons.category_rounded,
                    value: _category,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Semua kategori')),
                      for (final c in docCategories) DropdownMenuItem(value: c.code, child: Text(c.label, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? ''),
                  ),
                  FilterDropdown<int>(
                    width: 150,
                    icon: Icons.event_rounded,
                    value: _year,
                    items: [
                      const DropdownMenuItem(value: 0, child: Text('Semua tahun')),
                      for (final y in years) DropdownMenuItem(value: y, child: Text('Tahun $y')),
                    ],
                    onChanged: (v) => setState(() => _year = v ?? 0),
                  ),
                  FilterDropdown<String>(
                    width: 150,
                    icon: Icons.insert_drive_file_rounded,
                    value: _kind,
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Semua jenis')),
                      DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                      DropdownMenuItem(value: 'Word', child: Text('Word')),
                      DropdownMenuItem(value: 'Excel', child: Text('Excel')),
                      DropdownMenuItem(value: 'Foto', child: Text('Foto')),
                      DropdownMenuItem(value: 'Teks', child: Text('Teks')),
                      DropdownMenuItem(value: 'CAD', child: Text('CAD')),
                      DropdownMenuItem(value: 'Arsip', child: Text('ZIP / RAR')),
                    ],
                    onChanged: (v) => setState(() => _kind = v ?? ''),
                  ),
                  FilterDropdown<String>(
                    width: 190,
                    icon: Icons.cloud_queue_rounded,
                    value: _status,
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Semua status')),
                      DropdownMenuItem(value: 'draft', child: Text('Draf (belum dikirim)')),
                      DropdownMenuItem(value: 'unsynced', child: Text('Menunggu upload')),
                      DropdownMenuItem(value: 'failed', child: Text('Gagal upload')),
                      DropdownMenuItem(value: 'uploaded', child: Text('Tersimpan di server')),
                      DropdownMenuItem(value: 'today', child: Text('Diinput hari ini')),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? ''),
                  ),
                  FilterDropdown<_Sort>(
                    width: 190,
                    icon: Icons.sort_rounded,
                    value: _sort,
                    items: const [
                      DropdownMenuItem(value: _Sort.relevance, child: Text('Paling cocok / terbaru')),
                      DropdownMenuItem(value: _Sort.newest, child: Text('Terbaru diinput')),
                      DropdownMenuItem(value: _Sort.docDate, child: Text('Tanggal dokumen')),
                      DropdownMenuItem(value: _Sort.title, child: Text('Judul A–Z')),
                    ],
                    onChanged: (v) => setState(() => _sort = v ?? _Sort.relevance),
                  ),
                  FilterChip(
                    label: const Text('Tampilkan relasi'),
                    avatar: const Icon(Icons.account_tree_rounded, size: 16),
                    selected: _showRelations,
                    onSelected: (v) => setState(() => _showRelations = v),
                  ),
                  if (hasFilter) TextButton.icon(onPressed: _reset, icon: const Icon(Icons.filter_alt_off_rounded, size: 17), label: const Text('Reset filter')),
                ],
              ),
              if (widget.mineOnly) ...[const SizedBox(height: 12), _mySummary(all)],
              if (app.draftCount > 0) ...[const SizedBox(height: 12), _DraftBanner(drafts: app.myDrafts, onShow: () => setState(() => _status = 'draft'))],
              const SizedBox(height: 12),
              Expanded(
                child: Panel(
                  expand: true,
                  padding: EdgeInsets.zero,
                  title: widget.mineOnly
                      ? 'Dokumen yang saya input: ${list.length} dari ${all.length}'
                      : 'Menampilkan ${list.length} dari ${all.length} dokumen',
                  icon: Icons.folder_open_rounded,
                  trailing: app.lastPullAt == null
                      ? null
                      : Text('Data server diperbarui ${formatDateTime(app.lastPullAt)}', style: YmTextStyles.label),
                  child: list.isEmpty
                      ? EmptyState(
                          icon: hasFilter ? Icons.search_off_rounded : Icons.folder_off_rounded,
                          title: hasFilter ? 'Tidak ada dokumen yang cocok' : (widget.mineOnly ? 'Anda belum menginput dokumen' : 'Belum ada dokumen'),
                          message: hasFilter
                              ? 'Coba kata kunci lain atau reset filter.'
                              : widget.mineOnly
                                  ? 'Semua dokumen yang Anda unggah (termasuk yang masih menunggu internet) akan tampil di sini.'
                                  : 'Dokumen yang diunggah dari PC ini dan dari server akan tampil di sini.',
                        )
                      : Column(
                          children: [
                            const _TableHeader(),
                            Expanded(
                              child: ListView.separated(
                                itemCount: list.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: YmColors.borderLavender),
                                itemBuilder: (context, i) => _DocRow(
                                  doc: list[i],
                                  hit: _hits[list[i].clientId],
                                  relations: relations[list[i].clientId] ?? const [],
                                ),
                              ),
                            ),
                          ],
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

const _colProject = 150.0;
const _colCategory = 170.0;
const _colDate = 100.0;
const _colSize = 70.0;
const _colBy = 120.0;
const _colStatus = 150.0;

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    TextStyle st = YmTextStyles.label.copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3);
    return Container(
      color: YmColors.panelBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          Expanded(child: Text('DOKUMEN', style: st)),
          SizedBox(width: _colProject, child: Text('PROYEK', style: st)),
          SizedBox(width: _colCategory, child: Text('KATEGORI', style: st)),
          SizedBox(width: _colDate, child: Text('TGL DOKUMEN', style: st)),
          SizedBox(width: _colSize, child: Text('UKURAN', style: st)),
          SizedBox(width: _colBy, child: Text('DIUNGGAH OLEH', style: st)),
          SizedBox(width: _colStatus, child: Text('STATUS', style: st)),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final DocRecord doc;
  final SearchHit? hit;
  final List<RelatedDoc> relations;
  const _DocRow({required this.doc, this.hit, this.relations = const []});

  @override
  Widget build(BuildContext context) {
    final row = _mainRow(context);
    if (relations.isEmpty) return row;
    final series = relations.where((r) => r.sameSeries).toList();
    final others = relations.where((r) => !r.sameSeries).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        Container(
          margin: const EdgeInsets.fromLTRB(62, 0, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: YmColors.accentPurple.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: YmColors.accentPurple.withOpacity(0.5), width: 3)),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (series.isNotEmpty) ...[
                const Text('Seri:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: YmColors.accentPurple)),
                for (final r in series) _RelChip(r: r, highlight: true),
              ],
              if (others.isNotEmpty) ...[
                if (series.isNotEmpty) const SizedBox(width: 6),
                const Text('Relasi:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: YmColors.textMuted)),
                for (final r in others) _RelChip(r: r),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _mainRow(BuildContext context) {
    final d = doc;
    return InkWell(
      onTap: () => showDocDetail(context, d, highlight: hit == null ? '' : hit!.contentHits.join(' ')),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  FileTypeIcon(ext: d.extension),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.username.copyWith(fontSize: 12.5)),
                        const SizedBox(height: 2),
                        Text(
                          [if (d.docNumber.isNotEmpty) 'No. ${d.docNumber}', d.fileName].join('  •  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: YmTextStyles.label.copyWith(fontSize: 11),
                        ),
                        if (hit != null && hit!.matched.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              [
                                'Cocok di: ${hit!.matched.take(4).join(', ')}',
                                if (hit!.contentHits.isNotEmpty) 'isi file memuat "${hit!.contentHits.join('", "')}"',
                                if (hit!.viaKamus.isNotEmpty) 'via kamus: ${hit!.viaKamus.join(', ')}',
                              ].join('  •  '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5, color: YmColors.accentPurple, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: _colProject,
              child: Tooltip(
                message: d.projectName,
                child: Text(d.projectCode.isEmpty ? '—' : d.projectCode, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.chatText.copyWith(fontSize: 12)),
              ),
            ),
            SizedBox(width: _colCategory, child: Align(alignment: Alignment.centerLeft, child: CategoryBadge(code: d.category))),
            SizedBox(width: _colDate, child: Text(formatIsoDate(d.docDate), style: YmTextStyles.chatText.copyWith(fontSize: 12))),
            SizedBox(width: _colSize, child: Text(formatBytes(d.fileSize), style: YmTextStyles.label.copyWith(fontSize: 11.5))),
            SizedBox(width: _colBy, child: Text(d.createdByName, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.chatText.copyWith(fontSize: 12))),
            SizedBox(width: _colStatus, child: DocStatusChip(status: d.status)),
          ],
        ),
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _SummaryTab({required this.label, required this.icon, required this.color, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withOpacity(0.10) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : YmColors.borderLavender, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.chatText.copyWith(fontSize: 12.5))),
              Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}


class _RelChip extends StatelessWidget {
  final RelatedDoc r;
  final bool highlight;
  const _RelChip({required this.r, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${r.doc.title}\n${r.reasons.join(' • ')}',
      child: ActionChip(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Colors.white,
        side: BorderSide(color: highlight ? YmColors.accentPurple.withOpacity(0.5) : YmColors.borderLavender),
        avatar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(color: highlight ? YmColors.accentPurple : YmColors.textMuted, borderRadius: BorderRadius.circular(4)),
          child: Text('${r.doc.year}', style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w800)),
        ),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(r.doc.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
        ),
        onPressed: () => showDocDetail(context, r.doc),
      ),
    );
  }
}

/// Pengingat draf: dokumen yang disimpan di PC dan menunggu diperiksa sebelum dikirim.
class _DraftBanner extends StatelessWidget {
  final List<DocRecord> drafts;
  final VoidCallback onShow;
  const _DraftBanner({required this.drafts, required this.onShow});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: YmColors.accentPurple.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: YmColors.accentPurple.withOpacity(0.35)),
      ),
      child: Row(children: [
        const Icon(Icons.edit_note_rounded, color: YmColors.accentPurple),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${drafts.length} draf belum dikirim ke server. Buka tiap draf untuk memeriksa isi file dan datanya, lalu kirim. '
            '${app.canUseServer ? '' : 'Server sedang tidak terhubung: dokumen yang dikirim akan tersimpan di PC dan terkirim otomatis saat server online.'}',
            style: YmTextStyles.chatText.copyWith(fontSize: 12.5),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(style: outlineButtonStyle(), onPressed: onShow, child: const Text('Lihat draf')),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          style: primaryButtonStyle(),
          onPressed: () async {
            final ok = await confirmDialog(
              context,
              title: 'Kirim ${drafts.length} draf?',
              message: 'Semua draf masuk antrian kirim ke server. '
                  'Kalau server mati / offline, dokumen tetap tersimpan di PC ini dan terkirim otomatis begitu server online.',
              ok: 'Kirim semua',
            );
            if (!ok) return;
            await app.submitDrafts(drafts);
            if (context.mounted) showSnack(context, '${drafts.length} dokumen masuk antrian kirim.');
          },
          icon: const Icon(Icons.send_rounded, size: 17),
          label: Text('Kirim semua (${drafts.length})'),
        ),
      ]),
    );
  }
}
