import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// all = Semua Dokumen, mine = Dokumen Saya, local = Tersimpan di PC Ini (belum di server).
enum DocsMode { all, mine, local }

const _pageSize = 25;

class DocumentsPage extends StatefulWidget {
  final DocsMode mode;
  const DocumentsPage({super.key, this.mode = DocsMode.all});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> with PageSearchField<DocumentsPage> {
  final _search = TextEditingController();

  @override
  String get searchPageId => switch (widget.mode) { DocsMode.all => 'docs', DocsMode.mine => 'mydocs', DocsMode.local => 'local' };
  @override
  TextEditingController get searchController => _search;

  Timer? _debounce;
  String _query = ''; // kata kunci yang sudah "diendapkan" (debounce) -> hemat CPU untuk arsip besar
  String _project = ''; // '' = semua, '-' = tanpa proyek
  String _category = '';
  int _year = 0; // 0 = semua, -1 = lebih lama
  String _status = ''; // '' | recent | review | draft | unsynced | failed | uploaded | today
  String _kind = '';
  _Sort _sort = _Sort.relevance;
  bool _compact = false;
  int _page = 0;
  String _sig = '';

  /// Hasil pencarian pintar terakhir (clientId -> hit), untuk menampilkan alasan cocok.
  Map<String, SearchHit> _hits = {};
  List<String> _extra = [];

  /// Tampilkan relasi (seri lintas tahun, kode sama, dll.) di bawah hasil pencarian.
  bool _showRelations = true;

  bool get _all => widget.mode == DocsMode.all;

  @override
  void initState() {
    super.initState();
    if (_all) {
      Nav.docsProjectFilter.addListener(_applyNav);
      Nav.docsSearch.addListener(_applySearch);
      Nav.docsCategory.addListener(_applyCategory);
      Nav.docsYear.addListener(_applyYear);
      _applyNav();
      _applySearch();
      _applyCategory();
      _applyYear();
    } else if (widget.mode == DocsMode.mine) {
      Nav.myDocsStatus.addListener(_applyStatus);
      _applyStatus();
    }
  }

  /// Beri tahu sidebar kategori/tahun yang sedang dipilih (penanda menu).
  void _publish() {
    if (!_all) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Nav.activeCategory.value = _category;
      Nav.activeYear.value = _year;
    });
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
      _year = 0;
      _status = '';
    });
    Nav.docsProjectFilter.value = null;
    _publish();
  }

  void _applyCategory() {
    final c = Nav.docsCategory.value;
    if (c == null) return;
    setState(() {
      _category = c;
      _year = 0;
      _project = '';
    });
    Nav.docsCategory.value = null;
    _publish();
  }

  void _applyYear() {
    final y = Nav.docsYear.value;
    if (y == null) return;
    setState(() {
      _year = y;
      _category = '';
      _project = '';
    });
    Nav.docsYear.value = null;
    _publish();
  }

  @override
  void dispose() {
    Nav.docsProjectFilter.removeListener(_applyNav);
    Nav.myDocsStatus.removeListener(_applyStatus);
    Nav.docsSearch.removeListener(_applySearch);
    Nav.docsCategory.removeListener(_applyCategory);
    Nav.docsYear.removeListener(_applyYear);
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  bool _matchStatus(DocRecord d, String st) {
    final n = DateTime.now();
    return switch (st) {
      'today' => d.createdAt.year == n.year && d.createdAt.month == n.month && d.createdAt.day == n.day,
      'recent' => n.difference(d.createdAt).inDays < 7,
      'review' => d.status == DocStatus.draft || d.status == DocStatus.failed,
      'draft' => d.status == DocStatus.draft,
      'unsynced' => d.status == DocStatus.pending || d.status == DocStatus.uploading,
      'failed' => d.status == DocStatus.failed,
      'uploaded' => d.status == DocStatus.uploaded,
      _ => true,
    };
  }

  List<DocRecord> _filtered(List<DocRecord> all, int olderBelow) {
    final query = _query.trim();
    final list = all.where((d) {
      if (_project == '-' && d.projectId.isNotEmpty) return false;
      if (_project.isNotEmpty && _project != '-' && d.projectId != _project) return false;
      if (_category.isNotEmpty && d.category != _category) return false;
      if (_year > 0 && d.year != _year) return false;
      if (_year == -1 && d.year >= olderBelow) return false;
      if (_kind.isNotEmpty && fileKind(d.extension) != _kind) return false;
      return _matchStatus(d, _status);
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

  void _reset() {
    setState(() {
      _search.clear();
      _query = '';
      _project = '';
      _category = '';
      _year = 0;
      _status = '';
      _kind = '';
    });
    _publish();
  }

  Future<void> _export(List<DocRecord> list) async {
    try {
      final path = await FileTools.exportDocsCsv(list, fileName: 'arsip_dokumen_${isoDate(DateTime.now())}.csv');
      if (path != null && mounted) showSnack(context, 'Ekspor ${list.length} dokumen ke $path');
    } catch (e) {
      if (mounted) showSnack(context, 'Ekspor gagal: $e', error: true);
    }
  }

  (String, String, List<String>) get _texts => switch (widget.mode) {
        DocsMode.all => (
            'Semua Dokumen',
            'Cari, saring, lihat, dan kelola seluruh arsip proyek — kontrak, laporan, gambar, foto progres, dan berita acara. '
                'Pencarian juga membaca isi PDF, Word, dan Excel.',
            ['Arsip', 'Semua Dokumen'],
          ),
        DocsMode.mine => (
            'Dokumen Saya',
            'Semua dokumen yang Anda input, termasuk draf dan yang masih menunggu internet.',
            ['Arsip', 'Dokumen Saya'],
          ),
        DocsMode.local => (
            'Tersimpan di PC Ini',
            'Dokumen yang belum ada di server: draf yang perlu diperiksa, antrian yang menunggu koneksi, dan yang gagal diunggah. '
                'Semuanya aman di PC ini dan terkirim otomatis saat server online.',
            ['Arsip', 'Tersimpan di PC Ini'],
          ),
      };

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final me = app.session!.username.toLowerCase();
        final all = switch (widget.mode) {
          DocsMode.all => app.visibleDocs,
          DocsMode.mine => app.visibleDocs.where((d) => d.createdBy.toLowerCase() == me).toList(),
          DocsMode.local => app.visibleDocs.where((d) => d.isUnsynced).toList(),
        };
        final years = all.map((d) => d.year).toSet().toList()..sort((a, b) => b.compareTo(a));
        final olderBelow = years.length > 4 ? years[3] : -99999;
        if (_year > 0 && !years.contains(_year)) years.insert(0, _year);
        final projectValid = _project.isEmpty || _project == '-' || app.projects.any((p) => p.id == _project);
        if (!projectValid) _project = '';

        final list = _filtered(all, olderBelow);
        // kembali ke halaman 1 bila filter berubah
        final sig = '$_query|$_project|$_category|$_year|$_status|$_kind|$_sort';
        if (sig != _sig) {
          _sig = sig;
          _page = 0;
        }
        final pages = math.max(1, (list.length / _pageSize).ceil());
        if (_page >= pages) _page = pages - 1;
        final shown = list.skip(_page * _pageSize).take(_pageSize).toList();

        // Relasi untuk hasil yang tampil: cari "Formula C" -> ikut tampil Formula A (2000) & B (2002)
        final relations = <String, List<RelatedDoc>>{};
        if (_query.trim().isNotEmpty && _showRelations) {
          final searcher = app.searcher;
          for (final d in shown.take(20)) {
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
        final hasFilter = _search.text.isNotEmpty || _project.isNotEmpty || _category.isNotEmpty || _year != 0 || _status.isNotEmpty || _kind.isNotEmpty;
        int count(String st) => all.where((d) => _matchStatus(d, st)).length;
        final (title, subtitle, crumbs) = _texts;
        final failedCount = count('failed');

        return PageBody(
          scroll: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                crumbs: crumbs,
                badge: SoftChip.success('${CountUp.dots(all.length)} dokumen • tersusun otomatis', icon: Icons.circle),
                title: _category.isNotEmpty ? categoryOf(_category).label : (_year > 0 ? 'Dokumen Tahun $_year' : title),
                subtitle: subtitle,
                actions: [
                  if (app.failedCount > 0)
                    OutlinedButton.icon(
                      style: outlineButtonStyle(),
                      onPressed: app.retryAllFailed,
                      icon: Icon(Icons.refresh_rounded, size: 18, color: YmColors.danger),
                      label: Text('Upload ulang ${app.failedCount} gagal'),
                    ),
                  OutlinedButton.icon(
                    style: outlineButtonStyle(),
                    onPressed: list.isEmpty ? null : () => _export(list),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Ekspor daftar (CSV)'),
                  ),
                  OutlinedButton.icon(
                    style: outlineButtonStyle(),
                    onPressed: app.setupMode || app.syncing ? null : () => app.tick(forcePull: true),
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('Sinkronkan'),
                  ),
                  ElevatedButton.icon(
                    style: primaryButtonStyle(),
                    onPressed: () {
                      if (_project.isNotEmpty && _project != '-') {
                        Nav.uploadForProject(_project);
                      } else {
                        Nav.go('upload');
                      }
                    },
                    icon: const Icon(Icons.document_scanner_outlined, size: 18),
                    label: const Text('Unggah dokumen'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // ---- kartu filter
              Panel(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: TextField(
                              controller: _search,
                              focusNode: searchFocus,
                              style: TextStyle(fontFamily: kFont, fontSize: 13.5, color: YmColors.textDark),
                              onChanged: (v) {
                                _debounce?.cancel();
                                _debounce = Timer(const Duration(milliseconds: 300), () {
                                  if (mounted) setState(() => _query = v);
                                });
                                setState(() {});
                              },
                              decoration: searchDecoration(
                                'Saring: judul, nomor, kode (mis. 544), isi file, tag, proyek…',
                                suffix: _search.text.isEmpty
                                    ? const Padding(padding: EdgeInsets.only(right: 8), child: Center(widthFactor: 1, child: KbdHint('Ctrl F')))
                                    : IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 18),
                                        onPressed: () => setState(() {
                                          _search.clear();
                                          _query = '';
                                        }),
                                      ),
                              ).copyWith(contentPadding: const EdgeInsets.symmetric(vertical: 11)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilterDropdown<String>(
                          width: 210,
                          value: _category,
                          items: [
                            DropdownMenuItem(value: '', child: Text('Semua kategori (${docCategories.length})')),
                            for (final c in docCategories) DropdownMenuItem(value: c.code, child: Text(c.label, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) {
                            setState(() => _category = v ?? '');
                            _publish();
                          },
                        ),
                        const SizedBox(width: 10),
                        FilterDropdown<int>(
                          width: 150,
                          value: _year,
                          items: [
                            const DropdownMenuItem(value: 0, child: Text('Semua tahun')),
                            for (final y in years) DropdownMenuItem(value: y, child: Text('Tahun $y')),
                            if (olderBelow > 0) const DropdownMenuItem(value: -1, child: Text('Lebih lama')),
                          ],
                          onChanged: (v) {
                            setState(() => _year = v ?? 0);
                            _publish();
                          },
                        ),
                        const SizedBox(width: 10),
                        FilterDropdown<String>(
                          width: 200,
                          value: _project,
                          items: [
                            const DropdownMenuItem(value: '', child: Text('Proyek: semua')),
                            const DropdownMenuItem(value: '-', child: Text('Tanpa proyek / umum')),
                            for (final p in app.projects) DropdownMenuItem(value: p.id, child: Text(p.label, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) => setState(() => _project = v ?? ''),
                        ),
                        const SizedBox(width: 10),
                        FilterDropdown<String>(
                          width: 130,
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
                        const SizedBox(width: 10),
                        FilterDropdown<_Sort>(
                          width: 168,
                          icon: Icons.sort_rounded,
                          value: _sort,
                          items: const [
                            DropdownMenuItem(value: _Sort.relevance, child: Text('Paling cocok')),
                            DropdownMenuItem(value: _Sort.newest, child: Text('Terbaru diinput')),
                            DropdownMenuItem(value: _Sort.docDate, child: Text('Tanggal dokumen')),
                            DropdownMenuItem(value: _Sort.title, child: Text('Judul A–Z')),
                          ],
                          onChanged: (v) => setState(() => _sort = v ?? _Sort.relevance),
                        ),
                        const SizedBox(width: 10),
                        _ViewToggle(compact: _compact, onChanged: (v) => setState(() => _compact = v)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (st, label, tone, dot) in <(String, String, Color?, Color?)>[
                            ('', 'Semua (${CountUp.dots(all.length)})', null, null),
                            ('recent', 'Baru ditambahkan', null, null),
                            if (widget.mode != DocsMode.local) ('uploaded', 'Tersimpan di server (${count('uploaded')})', null, null),
                            ('review', 'Perlu ditinjau (${count('review')})', YmColors.warning, null),
                            ('unsynced', 'Menunggu sinkron (${count('unsynced')})', YmColors.success, YmColors.success),
                            if (failedCount > 0) ('failed', 'Gagal ($failedCount)', YmColors.danger, null),
                            ('today', 'Hari ini (${count('today')})', null, null),
                          ]) ...[
                            QuickChip(
                              label: label,
                              selected: _status == st,
                              tone: tone,
                              dot: dot,
                              icon: st == 'review' ? Icons.error_outline_rounded : null,
                              onTap: () => setState(() => _status = st),
                            ),
                            const SizedBox(width: 8),
                          ],
                          QuickChip(
                            label: 'Tampilkan relasi',
                            icon: Icons.account_tree_outlined,
                            selected: _showRelations,
                            onTap: () => setState(() => _showRelations = !_showRelations),
                          ),
                          const SizedBox(width: 6),
                          AnimatedSwitcher(
                            duration: motion(context, kMotionFast),
                            child: hasFilter
                                ? TextButton.icon(
                                    key: const ValueKey('clear'),
                                    style: TextButton.styleFrom(foregroundColor: YmColors.outline),
                                    onPressed: _reset,
                                    icon: const Icon(Icons.close_rounded, size: 16),
                                    label: const Text('Bersihkan'),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    if (_extra.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, left: 4),
                        child: Text(
                          'Pencarian pintar juga mencari: ${_extra.take(12).join(', ')}  (atur di Kamus Pencarian)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: YmTextStyles.label.copyWith(fontSize: 12, color: YmColors.primary),
                        ),
                      ),
                  ],
                ),
              ),
              if (app.draftCount > 0 && widget.mode != DocsMode.all) ...[
                const SizedBox(height: 14),
                _DraftBanner(drafts: app.myDrafts, onShow: () => setState(() => _status = 'draft')),
              ],
              const SizedBox(height: 16),
              // ---- daftar
              Expanded(
                child: list.isEmpty
                    ? Panel(
                        expand: true,
                        child: EmptyState(
                          icon: hasFilter ? Icons.search_off_rounded : Icons.folder_off_outlined,
                          title: hasFilter
                              ? 'Tidak ada dokumen yang cocok'
                              : switch (widget.mode) {
                                  DocsMode.mine => 'Anda belum menginput dokumen',
                                  DocsMode.local => 'Semua dokumen sudah aman di server',
                                  DocsMode.all => 'Belum ada dokumen',
                                },
                          message: hasFilter
                              ? 'Coba kata kunci lain atau bersihkan filter.'
                              : switch (widget.mode) {
                                  DocsMode.mine => 'Semua dokumen yang Anda unggah (termasuk yang masih menunggu internet) akan tampil di sini.',
                                  DocsMode.local => 'Tidak ada draf, antrian, atau dokumen gagal di PC ini.',
                                  DocsMode.all => 'Dokumen yang diunggah dari PC ini dan dari server akan tampil di sini.',
                                },
                          action: hasFilter ? OutlinedButton(style: outlineButtonStyle(), onPressed: _reset, child: const Text('Bersihkan filter')) : null,
                        ),
                      )
                    : AnimatedSwitcher(
                        duration: motion(context, const Duration(milliseconds: 260)),
                        child: ListView.builder(
                          key: ValueKey('$_sig#$_page#$_compact'),
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: shown.length + 1,
                          itemBuilder: (context, i) {
                            if (i == shown.length) {
                              return _Pager(page: _page, pages: pages, total: list.length, onPage: (p) => setState(() => _page = p));
                            }
                            final d = shown[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Reveal(
                                index: i,
                                child: _DocCard(doc: d, compact: _compact, hit: _hits[d.clientId], relations: relations[d.clientId] ?? const []),
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

class _ViewToggle extends StatelessWidget {
  final bool compact;
  final ValueChanged<bool> onChanged;
  const _ViewToggle({required this.compact, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget b(bool v, IconData icon, String tip) => Tooltip(
          message: tip,
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: motion(context, kMotionFast),
              width: 36,
              height: 34,
              decoration: BoxDecoration(
                color: compact == v ? YmColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: compact == v ? softShadow : null,
              ),
              child: Icon(icon, size: 19, color: compact == v ? YmColors.primary : YmColors.outline),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        b(false, Icons.view_agenda_outlined, 'Tampilan kartu'),
        b(true, Icons.table_rows_outlined, 'Tampilan ringkas'),
      ]),
    );
  }
}

TextStyle get _metaStyle => TextStyle(fontFamily: kFont, fontSize: 12.5, color: YmColors.outline);

/// Satu dokumen dalam daftar (versi web: <article> dengan ubin ikon, chip,
/// judul, baris info, ukuran + status sinkron, dan tombol aksi).
class _DocCard extends StatelessWidget {
  final DocRecord doc;
  final bool compact;
  final SearchHit? hit;
  final List<RelatedDoc> relations;
  const _DocCard({required this.doc, required this.compact, this.hit, this.relations = const []});

  @override
  Widget build(BuildContext context) {
    final d = doc;
    final app = AppState.instance;
    final failed = d.status == DocStatus.failed;
    final hasLocal = d.localPath.isNotEmpty && File(d.localPath).existsSync();
    final (IconData syncIcon, String syncText, Color syncColor) = switch (d.status) {
      DocStatus.uploaded => hasLocal ? (Icons.cloud_done_outlined, 'Di PC & server', YmColors.success) : (Icons.cloud_outlined, 'Di server', YmColors.success),
      DocStatus.failed => (Icons.error_outline_rounded, 'Perlu tindakan', YmColors.danger),
      DocStatus.draft => (Icons.laptop_mac_outlined, 'Draf di PC ini', YmColors.primary),
      _ => (Icons.sync_problem_outlined, app.isOnline ? 'Sedang dikirim' : 'Di PC, menunggu server', YmColors.warning),
    };
    final highlight = hit == null ? '' : hit!.contentHits.join(' ');
    void open({bool file = false}) => showDocDetail(context, d, highlight: highlight, startOnFile: file);

    final meta = <Widget>[
      if (d.docNumber.isNotEmpty) Text('No. ${d.docNumber}', style: TextStyle(fontFamily: kFont, fontSize: 12.5, fontWeight: FontWeight.w600, color: YmColors.textDark)),
      if (d.docDate.isNotEmpty) Text('Tanggal ${formatIsoDate(d.docDate)}', style: _metaStyle),
      if (d.projectCode.isNotEmpty) SoftChip(d.projectCode, fg: YmColors.primary, bg: YmColors.surfaceAlt),
      if (d.series.isNotEmpty) SoftChip('Seri: ${d.series}', bg: YmColors.surfaceAlt),
      Text('oleh ${d.createdByName}', style: _metaStyle),
    ];

    final card = HoverCard(
      onTap: open,
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: compact ? 10 : 16),
      color: failed ? Color.alphaBlend(YmColors.warningSoft.withOpacity(0.45), YmColors.surface) : null,
      child: Row(
        crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (failed)
            Container(
              width: compact ? 36 : 44,
              height: compact ? 36 : 44,
              decoration: BoxDecoration(color: YmColors.warningSoft, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.warning_amber_rounded, color: YmColors.warning, size: compact ? 19 : 22),
            )
          else
            CategoryTile(code: d.category, size: compact ? 36 : 44),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!compact) ...[
                  Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    CategoryBadge(code: d.category),
                    DocStatusChip(status: d.status),
                    Text(timeAgo(d.createdAt), style: _metaStyle),
                  ]),
                  const SizedBox(height: 6),
                ],
                Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.headline.copyWith(fontSize: compact ? 14 : 16)),
                const SizedBox(height: 4),
                if (compact)
                  Text(
                    [categoryOf(d.category).label, if (d.docNumber.isNotEmpty) 'No. ${d.docNumber}', formatIsoDate(d.docDate), if (d.projectCode.isNotEmpty) d.projectCode]
                        .join('  •  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _metaStyle,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (var i = 0; i < meta.length; i++) ...[
                        if (i > 0) Text('•', style: _metaStyle),
                        meta[i],
                      ],
                    ],
                  ),
                if (hit != null && hit!.matched.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      [
                        'Cocok di: ${hit!.matched.take(4).join(', ')}',
                        if (hit!.contentHits.isNotEmpty) 'isi file memuat "${hit!.contentHits.join('", "')}"',
                        if (hit!.viaKamus.isNotEmpty) 'via kamus: ${hit!.viaKamus.join(', ')}',
                      ].join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: kFont, fontSize: 11.5, color: YmColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (failed && d.lastError != null && !compact)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(d.lastError!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kFont, fontSize: 11.5, color: YmColors.danger)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${fileKind(d.extension).toUpperCase()} • ${formatBytes(d.fileSize)}',
                  style: TextStyle(fontFamily: kFont, fontSize: 12, fontWeight: FontWeight.w500, color: YmColors.textMuted)),
              const SizedBox(height: 3),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(syncIcon, size: 14, color: syncColor),
                const SizedBox(width: 4),
                Text(syncText, style: TextStyle(fontFamily: kFont, fontSize: 11.5, fontWeight: FontWeight.w600, color: syncColor)),
              ]),
            ],
          ),
          const SizedBox(width: 18),
          if (failed)
            TextButton.icon(
              style: softButtonStyle(fg: Colors.white, bg: YmColors.warning),
              onPressed: () => app.retryDoc(d),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Upload ulang'),
            )
          else if (d.status == DocStatus.draft)
            TextButton.icon(
              style: softButtonStyle(fg: YmColors.onPrimary, bg: YmColors.primary),
              onPressed: () => open(),
              icon: const Icon(Icons.fact_check_outlined, size: 16),
              label: const Text('Periksa & kirim'),
            )
          else
            TextButton.icon(
              style: softButtonStyle(),
              onPressed: () => open(file: true),
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('Lihat'),
            ),
          const SizedBox(width: 8),
          TextButton(style: softButtonStyle(), onPressed: open, child: const Text('Detail')),
          const SizedBox(width: 2),
          _MoreMenu(doc: d),
        ],
      ),
    );

    if (relations.isEmpty) return card;
    final series = relations.where((r) => r.sameSeries).toList();
    final others = relations.where((r) => !r.sameSeries).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        Container(
          margin: const EdgeInsets.fromLTRB(78, 6, 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: YmColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: YmColors.primary.withOpacity(0.6), width: 3)),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (series.isNotEmpty) ...[
                Text('Seri:', style: TextStyle(fontFamily: kFont, fontSize: 11.5, fontWeight: FontWeight.w700, color: YmColors.primary)),
                for (final r in series) _RelChip(r: r, highlight: true),
              ],
              if (others.isNotEmpty) ...[
                if (series.isNotEmpty) const SizedBox(width: 6),
                Text('Terkait:', style: TextStyle(fontFamily: kFont, fontSize: 11.5, fontWeight: FontWeight.w700, color: YmColors.textMuted)),
                for (final r in others) _RelChip(r: r),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreMenu extends StatelessWidget {
  final DocRecord doc;
  const _MoreMenu({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc;
    return PopupMenuButton<String>(
      tooltip: 'Lainnya',
      icon: Icon(Icons.more_vert_rounded, color: YmColors.outline, size: 20),
      onSelected: (v) async {
        switch (v) {
          case 'detail':
            await showDocDetail(context, d);
          case 'file':
            await showDocDetail(context, d, startOnFile: true);
          case 'project':
            Nav.openDocsForProject(d.projectId);
          case 'series':
            Nav.searchDocs(d.series);
          case 'copy':
            await Clipboard.setData(ClipboardData(text: d.docNumber));
            if (context.mounted) showSnack(context, 'Nomor dokumen disalin.');
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'detail', child: Text('Buka detail dokumen')),
        const PopupMenuItem(value: 'file', child: Text('Lihat file asli')),
        if (d.projectId.isNotEmpty) PopupMenuItem(value: 'project', child: Text('Semua dokumen proyek ${d.projectCode}')),
        if (d.series.isNotEmpty) const PopupMenuItem(value: 'series', child: Text('Cari seri dokumen ini')),
        if (d.docNumber.isNotEmpty) const PopupMenuItem(value: 'copy', child: Text('Salin nomor dokumen')),
      ],
    );
  }
}

/// Navigasi halaman (versi web: "Showing 1 to 10 of 1,420" + 1 2 3 … 142 Next).
class _Pager extends StatelessWidget {
  final int page, pages, total;
  final ValueChanged<int> onPage;
  const _Pager({required this.page, required this.pages, required this.total, required this.onPage});

  @override
  Widget build(BuildContext context) {
    final from = total == 0 ? 0 : page * _pageSize + 1;
    final to = math.min(total, (page + 1) * _pageSize);
    final nums = <int>{0, pages - 1, page - 1, page, page + 1}.where((p) => p >= 0 && p < pages).toList()..sort();
    final items = <Widget>[];
    int? prev;
    for (final p in nums) {
      if (prev != null && p - prev > 1) items.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('…', style: _metaStyle)));
      items.add(_PageBtn(label: '${p + 1}', selected: p == page, onTap: () => onPage(p)));
      prev = p;
    }
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(14), boxShadow: softShadow),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Menampilkan '),
                TextSpan(text: '$from–$to', style: TextStyle(fontWeight: FontWeight.w700, color: YmColors.textDark)),
                const TextSpan(text: ' dari '),
                TextSpan(text: CountUp.dots(total), style: TextStyle(fontWeight: FontWeight.w700, color: YmColors.textDark)),
                const TextSpan(text: ' dokumen'),
              ]),
              style: TextStyle(fontFamily: kFont, fontSize: 13, color: YmColors.textMuted),
            ),
          ),
          Icon(Icons.circle, size: 7, color: YmColors.success),
          const SizedBox(width: 6),
          Text('Tersimpan untuk pencarian offline', style: TextStyle(fontFamily: kFont, fontSize: 12, fontWeight: FontWeight.w600, color: YmColors.success)),
          const SizedBox(width: 20),
          TextButton.icon(
            onPressed: page > 0 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 18),
            label: const Text('Sebelumnya'),
          ),
          ...items,
          TextButton(
            onPressed: page < pages - 1 ? () => onPage(page + 1) : null,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Berikutnya'), Icon(Icons.chevron_right_rounded, size: 18)]),
          ),
        ],
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PageBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: AnimatedContainer(
            duration: motion(context, kMotionFast),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: selected ? YmColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(9)),
            child: Text(label, style: TextStyle(fontFamily: kFont, fontSize: 13, fontWeight: FontWeight.w600, color: selected ? YmColors.onPrimary : YmColors.textMuted)),
          ),
        ),
      );
}

class _RelChip extends StatelessWidget {
  final RelatedDoc r;
  final bool highlight;
  const _RelChip({required this.r, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${r.doc.title}\n${r.reasons.join(' • ')}',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showDocDetail(context, r.doc),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
          decoration: BoxDecoration(
            color: YmColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: highlight ? YmColors.primary.withOpacity(0.4) : YmColors.line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: highlight ? YmColors.primary : YmColors.outline, borderRadius: BorderRadius.circular(5)),
              child: Text('${r.doc.year}', style: const TextStyle(fontFamily: kFont, fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(r.doc.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kFont, fontSize: 11.5, color: YmColors.textDark)),
            ),
          ]),
        ),
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
    return Reveal(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(color: YmColors.primarySoft.withOpacity(YmColors.isDark ? 1 : 0.55), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.edit_note_rounded, color: YmColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${drafts.length} draf belum dikirim ke server. Buka tiap draf untuk memeriksa isi file dan datanya, lalu kirim. '
              '${app.canUseServer ? '' : 'Server sedang tidak terhubung: dokumen yang dikirim akan tersimpan di PC dan terkirim otomatis saat server online.'}',
              style: YmTextStyles.chatText.copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
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
      ),
    );
  }
}
