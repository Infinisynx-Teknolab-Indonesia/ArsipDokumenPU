import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
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
import '../services/shortcuts.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';
import 'doc_detail.dart';
import 'doc_form.dart';
import 'doc_quick_view.dart';

// ============================================================================
//  SEMUA DOKUMEN / DOKUMEN SAYA / TERSIMPAN DI PC INI
//  Persis versi web "All Documents" (DocArchive), plus halaman KATEGORI
//  persis versi web "Shipments & Trade Dossiers": dokumen dikelompokkan per
//  proyek (dosir), kartu statistik, panel "Perlu perhatian" & "Per proyek".
// ============================================================================

enum _Sort { relevance, newest, docDate, title }

/// all = Semua Dokumen, mine = Dokumen Saya, local = Tersimpan di PC Ini (belum di server).
enum DocsMode { all, mine, local }

enum _View { list, grid, table }

const _pageSize = 10; // versi web: "Showing 1 to 10 of 1,420"

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
  String _query = ''; // kata kunci yang sudah "diendapkan" (debounce)
  String _project = ''; // '' = semua, '-' = tanpa proyek
  String _category = '';
  String _owner = ''; // username pengunggah
  int _year = 0; // 0 = semua, -1 = lebih lama
  String _status = ''; // '' | recent | review | draft | unsynced | failed | uploaded | today
  String _kind = '';
  _Sort _sort = _Sort.relevance;
  _View _view = _View.list;
  bool _dossier = true; // halaman kategori: tampilan dosir (true) / tabel (false)
  int _page = 0;
  String _sig = '';
  final Set<String> _selected = {};
  bool _busy = false;

  /// Hasil pencarian pintar terakhir (clientId -> hit), untuk menampilkan alasan cocok.
  Map<String, SearchHit> _hits = {};
  List<String> _extra = [];

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
      _category = '';
    });
    Nav.docsSearch.value = null;
    _publish();
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
      _status = '';
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
      'local' => d.isUnsynced,
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
      if (_owner.isNotEmpty && d.createdBy.toLowerCase() != _owner) return false;
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
      _owner = '';
      _year = 0;
      _status = '';
      _kind = '';
    });
    _publish();
  }

  Future<void> _export(List<DocRecord> list, {String name = 'arsip_dokumen'}) async {
    try {
      final path = await FileTools.exportDocsCsv(list, fileName: '${name}_${isoDate(DateTime.now())}.csv');
      if (path != null && mounted) showSnack(context, 'Ekspor ${list.length} dokumen ke $path');
    } catch (e) {
      if (mounted) showSnack(context, 'Ekspor gagal: $e', error: true);
    }
  }

  /// Simpan salinan file di PC supaya bisa dibuka saat offline (aksi massal).
  Future<void> _cacheOffline(List<DocRecord> docs) async {
    final app = AppState.instance;
    final need = docs.where((d) => d.status == DocStatus.uploaded && (d.localPath.isEmpty || !File(d.localPath).existsSync())).toList();
    if (need.isEmpty) {
      showSnack(context, 'Semua dokumen terpilih sudah tersimpan di PC ini.');
      return;
    }
    if (!app.canUseServer) {
      showSnack(context, 'Butuh koneksi ke server untuk mengunduh file.', error: true);
      return;
    }
    setState(() => _busy = true);
    var ok = 0;
    for (final d in need) {
      try {
        await app.ensureLocalFile(d);
        ok++;
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _busy = false);
      showSnack(context, '$ok dari ${need.length} file disimpan di PC ini untuk dibuka saat offline.');
    }
  }

  (String, String) get _texts => switch (widget.mode) {
        DocsMode.all => (
            'Semua Dokumen',
            'Cari, saring, lihat, dan kelola seluruh arsip proyek — kontrak, laporan, gambar kerja, foto progres, dan berita acara. '
                'Pencarian juga membaca isi PDF, Word, dan Excel.',
          ),
        DocsMode.mine => ('Dokumen Saya', 'Semua dokumen yang Anda input, termasuk draf dan yang masih menunggu internet.'),
        DocsMode.local => (
            'Tersimpan di PC Ini',
            'Dokumen yang belum ada di server: draf yang perlu diperiksa, antrian yang menunggu koneksi, dan yang gagal diunggah. '
                'Semuanya aman di PC ini dan terkirim otomatis saat server online.',
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
        final olderBelow = years.length > 3 ? years[2] : -99999;
        if (_year > 0 && !years.contains(_year)) years.insert(0, _year);
        if (!(_project.isEmpty || _project == '-' || app.projects.any((p) => p.id == _project))) _project = '';

        final list = _filtered(all, olderBelow);
        // kembali ke halaman 1 bila filter berubah
        final sig = '$_query|$_project|$_category|$_owner|$_year|$_status|$_kind|$_sort';
        if (sig != _sig) {
          _sig = sig;
          _page = 0;
        }
        _selected.removeWhere((id) => !list.any((d) => d.clientId == id));

        if (_all && _category.isNotEmpty) return _categoryView(app, all, list);
        return _libraryView(app, all, list, years, olderBelow);
      },
    );
  }

  // ==========================================================================
  //  TAMPILAN PUSTAKA (versi web "All Documents")
  // ==========================================================================
  Widget _libraryView(AppState app, List<DocRecord> all, List<DocRecord> list, List<int> years, int olderBelow) {
    final pages = math.max(1, (list.length / _pageSize).ceil());
    if (_page >= pages) _page = pages - 1;
    final shown = list.skip(_page * _pageSize).take(_pageSize).toList();
    final relations = _relations(app, shown);
    final hasFilter = _search.text.isNotEmpty || _project.isNotEmpty || _category.isNotEmpty || _owner.isNotEmpty || _year != 0 || _status.isNotEmpty || _kind.isNotEmpty;
    int count(String st) => all.where((d) => _matchStatus(d, st)).length;
    final (title, subtitle) = _texts;
    final owners = <String, String>{};
    for (final d in all) {
      owners[d.createdBy.toLowerCase()] = d.createdByName.isEmpty ? d.createdBy : d.createdByName;
    }
    final me = app.session!.username.toLowerCase();
    final topCat = () {
      final m = <String, int>{};
      for (final d in all) {
        m[d.category] = (m[d.category] ?? 0) + 1;
      }
      final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return e.isEmpty ? null : e.first;
    }();

    return PageBody(
      scroll: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- judul (section mb-space-lg)
          PageHeader(
            crumbs: ['Arsip', _year > 0 ? 'Tahun $_year' : (_year == -1 ? 'Lebih lama' : title)],
            badge: SoftChip.success('${CountUp.dots(all.length)} dokumen terindeks • Tersusun otomatis', dot: YmColors.success),
            title: _year > 0 ? 'Dokumen Tahun $_year' : (_year == -1 ? 'Dokumen Lebih Lama' : title),
            subtitle: subtitle,
            actions: [
              OutlinedButton.icon(
                style: outlineButtonStyle(),
                onPressed: list.isEmpty ? null : () => _export(list),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Ekspor daftar (CSV)'),
              ),
              OutlinedButton.icon(
                style: outlineButtonStyle(),
                onPressed: list.isEmpty
                    ? null
                    : () => setState(() {
                          if (_selected.length == list.length) {
                            _selected.clear();
                          } else {
                            _selected.addAll(list.map((d) => d.clientId));
                          }
                        }),
                icon: const Icon(Icons.select_all_rounded),
                label: Text(_selected.isNotEmpty && _selected.length == list.length ? 'Batal pilih' : 'Pilih semua'),
              ),
              ElevatedButton.icon(
                style: primaryButtonStyle().copyWith(elevation: const WidgetStatePropertyAll(3)),
                onPressed: () => _project.isNotEmpty && _project != '-' ? Nav.uploadForProject(_project) : Nav.go('upload'),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Unggah / Pindai'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // ---- kartu saring (bg-surface-container-lowest rounded-xl shadow-sm p-space-md gap-space-md)
          Panel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _searchBox(height: 44, hint: 'Saring judul, nomor dokumen, proyek, atau isi file (OCR)...')),
                    const SizedBox(width: 16),
                    FilterDropdown<String>(
                      width: 196,
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
                    const SizedBox(width: 8),
                    FilterDropdown<int>(
                      width: 156,
                      value: _year,
                      items: [
                        DropdownMenuItem(value: 0, child: Text(years.isEmpty ? 'Tahun: semua' : 'Tahun: ${years.last}–${years.first}')),
                        for (final y in years) DropdownMenuItem(value: y, child: Text(y == DateTime.now().year ? '$y (berjalan)' : '$y')),
                        if (olderBelow > 0) const DropdownMenuItem(value: -1, child: Text('Lebih lama')),
                      ],
                      onChanged: (v) {
                        setState(() => _year = v ?? 0);
                        _publish();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterDropdown<String>(
                      width: 176,
                      value: owners.containsKey(_owner) ? _owner : '',
                      items: [
                        const DropdownMenuItem(value: '', child: Text('Pengunggah: semua')),
                        if (owners.containsKey(me)) DropdownMenuItem(value: me, child: Text('Saya (${owners[me]})', overflow: TextOverflow.ellipsis)),
                        for (final e in owners.entries)
                          if (e.key != me) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => _owner = v ?? ''),
                    ),
                    const SizedBox(width: 8),
                    FilterDropdown<String>(
                      width: 176,
                      value: _project,
                      items: [
                        const DropdownMenuItem(value: '', child: Text('Proyek: semua')),
                        const DropdownMenuItem(value: '-', child: Text('Tanpa proyek / umum')),
                        for (final p in app.projects) DropdownMenuItem(value: p.id, child: Text(p.label, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => _project = v ?? ''),
                    ),
                    const SizedBox(width: 8),
                    _MoreFilters(
                      kind: _kind,
                      sort: _sort,
                      onKind: (v) => setState(() => _kind = v),
                      onSort: (v) => setState(() => _sort = v),
                    ),
                    const SizedBox(width: 8),
                    _ViewSwitch<_View>(
                      value: _view,
                      options: const [
                        (_View.list, Icons.view_list_outlined, 'Daftar'),
                        (_View.grid, Icons.grid_view_outlined, 'Kisi'),
                        (_View.table, Icons.table_rows_outlined, 'Tabel ringkas'),
                      ],
                      onChanged: (v) => setState(() => _view = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [
                            for (final (st, label, tone, icon) in <(String, String, ChipTone, IconData?)>[
                              ('', 'Semua (${CountUp.dots(all.length)})', ChipTone.normal, null),
                              ('recent', 'Baru ditambahkan', ChipTone.normal, null),
                              ('review', 'Perlu ditinjau (${count('review')})', ChipTone.warning, Icons.error_outline_rounded),
                              if (topCat != null && widget.mode != DocsMode.local)
                                ('cat:${topCat.key}', '${categoryOf(topCat.key).label.split(' /').first} (${topCat.value})', ChipTone.normal, null),
                              if (widget.mode != DocsMode.local) ('uploaded', 'Tersimpan di server (${count('uploaded')})', ChipTone.normal, null),
                              ('local', 'Menunggu sinkron offline (${count('local')})', ChipTone.success, null),
                            ]) ...[
                              QuickChip(
                                label: label,
                                selected: st.startsWith('cat:') ? false : _status == st && (st.isNotEmpty || !hasFilter || _status.isEmpty && _query.isEmpty && _category.isEmpty),
                                tone: tone,
                                icon: icon,
                                onTap: () {
                                  if (st.startsWith('cat:')) {
                                    Nav.openCategory(st.substring(4));
                                  } else {
                                    setState(() => _status = st);
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                          ]),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: YmColors.outline,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          textStyle: YmTextStyles.labelSm,
                        ),
                        onPressed: hasFilter ? _reset : null,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Bersihkan'),
                      ),
                    ],
                  ),
                ),
                if (_extra.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Pencarian pintar juga mencari: ${_extra.take(12).join(', ')}  (atur di Kamus Pencarian)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: YmTextStyles.bodySm.copyWith(color: YmColors.primary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // ---- bar aksi massal (muncul saat ada yang dipilih)
          AnimatedSize(
            duration: motion(context, const Duration(milliseconds: 220)),
            curve: Curves.easeOutCubic,
            child: _selected.isEmpty ? const SizedBox(width: double.infinity) : _bulkBar(list),
          ),
          if (_busy) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator(minHeight: 2)),
          if (app.draftCount > 0 && widget.mode != DocsMode.all) ...[
            _DraftBanner(drafts: app.myDrafts, onShow: () => setState(() => _status = 'draft')),
            const SizedBox(height: 16),
          ],
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
                          ? 'Coba kata kunci lain atau bersihkan saringan.'
                          : switch (widget.mode) {
                              DocsMode.mine => 'Semua dokumen yang Anda unggah (termasuk yang masih menunggu internet) akan tampil di sini.',
                              DocsMode.local => 'Tidak ada draf, antrian, atau dokumen gagal di PC ini.',
                              DocsMode.all => 'Dokumen yang diunggah dari PC ini dan dari server akan tampil di sini.',
                            },
                      action: hasFilter ? OutlinedButton(style: outlineButtonStyle(), onPressed: _reset, child: const Text('Bersihkan saringan')) : null,
                    ),
                  )
                : AnimatedSwitcher(
                    duration: motion(context, const Duration(milliseconds: 260)),
                    child: KeyedSubtree(
                      key: ValueKey('$_sig#$_page#$_view'),
                      child: _view == _View.grid ? _grid(shown, list.length, pages) : _list(shown, list.length, pages, relations),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Map<String, List<RelatedDoc>> _relations(AppState app, List<DocRecord> shown) {
    final relations = <String, List<RelatedDoc>>{};
    if (_query.trim().isEmpty) return relations;
    final searcher = app.searcher;
    for (final d in shown) {
      final rel = searcher.related(d, app.visibleDocs, limit: 30)
        ..sort((a, b) {
          if (a.sameSeries != b.sameSeries) return a.sameSeries ? -1 : 1;
          if (a.sameSeries) return a.doc.year.compareTo(b.doc.year);
          return b.score.compareTo(a.score);
        });
      final picked = rel.where((r) => r.sameSeries || r.score >= 8).take(8).toList();
      if (picked.isNotEmpty) relations[d.clientId] = picked;
    }
    return relations;
  }

  Widget _searchBox({required double height, required String hint}) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: _search,
        focusNode: searchFocus,
        style: YmTextStyles.bodyMd.copyWith(color: YmColors.textDark),
        onChanged: (v) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _query = v);
          });
          setState(() {});
        },
        decoration: searchDecoration(
          hint,
          suffix: _search.text.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    for (final (i, part) in ShortcutCtl.instance.label(AppAction.pageFind).split(' ').indexed) ...[
                      if (i > 0) const SizedBox(width: 4),
                      KbdHint(part, small: true),
                    ],
                  ]),
                )
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() {
                    _search.clear();
                    _query = '';
                  }),
                ),
        ).copyWith(contentPadding: EdgeInsets.symmetric(vertical: (height - 22) / 2)),
      ),
    );
  }

  /// Bar aksi massal (versi web: bg-inverse-surface rounded-xl shadow-xl).
  Widget _bulkBar(List<DocRecord> list) {
    final sel = list.where((d) => _selected.contains(d.clientId)).toList();
    final drafts = sel.where((d) => d.status == DocStatus.draft).toList();
    Widget act(IconData icon, String label, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: TextButton.icon(
            style: softButtonStyle(fg: YmColors.onInverseSurface, bg: YmColors.onInverseSurface.withOpacity(0.10), hover: YmColors.onInverseSurface.withOpacity(0.20))
                .copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 32)), padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 6))),
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label),
          ),
        );
    return Reveal(
      offset: const Offset(0, -0.3),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: YmColors.inverseSurface, borderRadius: BorderRadius.circular(12), boxShadow: shadowXl),
        child: Row(children: [
          Icon(Icons.check_circle_rounded, size: 20, color: YmColors.inversePrimary),
          const SizedBox(width: 12),
          Text('${sel.length} dokumen dipilih', style: YmTextStyles.labelLg.copyWith(color: YmColors.onInverseSurface)),
          const SizedBox(width: 12),
          Text('|', style: YmTextStyles.labelSm.copyWith(color: YmColors.outlineVariant)),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Aksi berlaku untuk dokumen yang dicentang', maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.bodySm.copyWith(color: YmColors.outlineVariant)),
          ),
          act(Icons.download_rounded, 'Ekspor CSV', () => _export(sel, name: 'dokumen_terpilih')),
          act(Icons.cloud_sync_outlined, 'Simpan di PC (offline)', () => _cacheOffline(sel)),
          if (drafts.isNotEmpty)
            act(Icons.send_rounded, 'Kirim ${drafts.length} draf', () async {
              await AppState.instance.submitDrafts(drafts);
              if (mounted) showSnack(context, '${drafts.length} draf masuk antrian kirim.');
            }),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Batal pilih',
            onPressed: () => setState(_selected.clear),
            icon: Icon(Icons.close_rounded, size: 18, color: YmColors.onInverseSurface),
          ),
        ]),
      ),
    );
  }

  void _toggle(DocRecord d) => setState(() => _selected.contains(d.clientId) ? _selected.remove(d.clientId) : _selected.add(d.clientId));

  Widget _list(List<DocRecord> shown, int total, int pages, Map<String, List<RelatedDoc>> relations) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: shown.length + 1,
      itemBuilder: (context, i) {
        if (i == shown.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _Pager(page: _page, pages: pages, total: total, onPage: (p) => setState(() => _page = p)),
          );
        }
        final d = shown[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Reveal(
            index: i,
            child: _DocCard(
              doc: d,
              compact: _view == _View.table,
              selected: _selected.contains(d.clientId),
              onSelect: () => _toggle(d),
              hit: _hits[d.clientId],
              relations: relations[d.clientId] ?? const [],
            ),
          ),
        );
      },
    );
  }

  Widget _grid(List<DocRecord> shown, int total, int pages) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 1300 ? 4 : (c.maxWidth > 900 ? 3 : 2);
      final w = (c.maxWidth - 16 * (cols - 1)) / cols;
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 16, runSpacing: 16, children: [
            for (var i = 0; i < shown.length; i++)
              SizedBox(
                width: w,
                child: Reveal(
                  index: i,
                  child: _DocTile(doc: shown[i], selected: _selected.contains(shown[i].clientId), onSelect: () => _toggle(shown[i])),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          _Pager(page: _page, pages: pages, total: total, onPage: (p) => setState(() => _page = p)),
        ]),
      );
    });
  }

  // ==========================================================================
  //  HALAMAN KATEGORI (versi web "Shipments & Trade Dossiers")
  // ==========================================================================
  Widget _categoryView(AppState app, List<DocRecord> all, List<DocRecord> list) {
    final cat = categoryOf(_category);
    final inCat = all.where((d) => d.category == _category).toList();
    final now = DateTime.now();
    final week = inCat.where((d) => now.difference(d.createdAt).inDays < 7).length;
    final onServer = inCat.where((d) => d.status == DocStatus.uploaded).length;
    final attention = inCat.where((d) => d.status == DocStatus.failed || d.status == DocStatus.draft).length;
    final local = inCat.where((d) => d.isUnsynced).length;
    final kinds = <String, int>{};
    for (final d in inCat) {
      final k = fileKind(d.extension);
      kinds[k] = (kinds[k] ?? 0) + 1;
    }
    final topKinds = (kinds.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(3).toList();
    final ratio = inCat.isEmpty ? 0 : (onServer * 100 / inCat.length).round();

    // dosir = dokumen dikelompokkan per proyek
    final byProject = <String, List<DocRecord>>{};
    for (final d in list) {
      byProject.putIfAbsent(d.projectId, () => []).add(d);
    }
    final dossiers = byProject.entries.toList()
      ..sort((a, b) {
        if (a.key.isEmpty != b.key.isEmpty) return a.key.isEmpty ? 1 : -1;
        final la = a.value.map((d) => d.createdAt).reduce((x, y) => x.isAfter(y) ? x : y);
        final lb = b.value.map((d) => d.createdAt).reduce((x, y) => x.isAfter(y) ? x : y);
        return lb.compareTo(la);
      });

    Widget statCard({
      required String label,
      required Color labelColor,
      required int value,
      Color? valueColor,
      Widget? tag,
      required IconData icon,
      required Color tileBg,
      required Color tileFg,
      required Widget footer,
      int index = 0,
    }) =>
        Reveal(
          index: index,
          child: HoverCard(
            radius: 16,
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label.toUpperCase(), style: YmTextStyles.labelSm.copyWith(color: labelColor, letterSpacing: 0.55)),
                    const SizedBox(height: 4),
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      CountUp(value: value, style: YmTextStyles.display.copyWith(color: valueColor ?? YmColors.textDark)),
                      if (tag != null) ...[const SizedBox(width: 8), Flexible(child: tag)],
                    ]),
                  ]),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: tileBg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 24, color: tileFg),
                ),
              ]),
              const SizedBox(height: 16),
              footer,
            ]),
          ),
        );

    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            chevrons: true,
            crumbs: ['Kategori', cat.label],
            badge: SoftChip('${CountUp.dots(inCat.length)} dokumen aktif', fg: YmColors.onSuccessSoft, bg: YmColors.successContainer.withOpacity(0.55), pill: true, bold: true),
            title: cat.label,
            subtitle: 'Semua dokumen ${cat.label.toLowerCase()} dari seluruh proyek, dikelompokkan per paket pekerjaan. '
                'Status kirim, kelengkapan, dan salinan offline diperiksa otomatis.',
            actions: [
              OutlinedButton.icon(
                style: outlineButtonStyle(),
                onPressed: inCat.isEmpty ? null : () => _export(inCat, name: 'laporan_${_category.toLowerCase()}'),
                icon: const Icon(Icons.file_download_outlined, size: 20),
                label: const Text('Ekspor laporan (CSV)'),
              ),
              ElevatedButton.icon(
                style: primaryButtonStyle().copyWith(
                  elevation: const WidgetStatePropertyAll(3),
                  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24, vertical: 10)),
                ),
                onPressed: () => Nav.go('upload'),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                label: Text('Unggah ${cat.label.split(' /').first}'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // ---- 4 kartu statistik
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: statCard(
                index: 0,
                label: 'Total dokumen',
                labelColor: YmColors.textMuted,
                value: inCat.length,
                tag: Text('+$week minggu ini', style: YmTextStyles.labelSm.copyWith(color: YmColors.success, fontWeight: FontWeight.w500)),
                icon: cat.icon,
                tileBg: YmColors.surfaceContainer,
                tileFg: YmColors.primary,
                footer: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    if (topKinds.isEmpty) Text('Belum ada file', style: YmTextStyles.labelSm),
                    for (var i = 0; i < topKinds.length; i++) ...[
                      if (i > 0) Text('•', style: TextStyle(fontSize: 10, color: YmColors.outlineVariant)),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_kindIcon(topKinds[i].key), size: 16, color: [YmColors.primary, YmColors.success, YmColors.warning][i]),
                        const SizedBox(width: 4),
                        Text('${topKinds[i].key} ${topKinds[i].value}',
                            style: YmTextStyles.labelSm.copyWith(color: [YmColors.primary, YmColors.success, YmColors.warning][i], fontWeight: FontWeight.w500)),
                      ]),
                    ],
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: statCard(
                index: 1,
                label: 'Tersimpan di server',
                labelColor: YmColors.success,
                value: onServer,
                tag: SoftChip('$ratio% rasio', fg: YmColors.onSuccessSoft, bg: YmColors.successContainer.withOpacity(0.55), pill: true),
                icon: Icons.verified_outlined,
                tileBg: YmColors.successContainer.withOpacity(0.35),
                tileFg: YmColors.success,
                footer: Row(children: [
                  Icon(Icons.check_circle_outline_rounded, size: 16, color: YmColors.success),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Tercatat & tersalin untuk offline', maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelSm.copyWith(color: YmColors.success, fontWeight: FontWeight.w500))),
                  Text('SHA-256', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: YmColors.textMuted)),
                ]),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: statCard(
                index: 2,
                label: 'Perlu tindakan',
                labelColor: YmColors.danger,
                value: attention,
                valueColor: attention > 0 ? YmColors.danger : null,
                tag: SoftChip(attention > 0 ? 'Perlu tindakan' : 'Beres', fg: YmColors.onDangerSoft, bg: YmColors.dangerSoft, pill: true),
                icon: Icons.warning_amber_rounded,
                tileBg: YmColors.dangerSoft,
                tileFg: YmColors.danger,
                footer: Row(children: [
                  Icon(Icons.rule_rounded, size: 16, color: YmColors.danger),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Gagal unggah & draf belum dikirim', maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelSm.copyWith(color: YmColors.onDangerSoft, fontWeight: FontWeight.w500))),
                ]),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: statCard(
                index: 3,
                label: 'Belum di server',
                labelColor: YmColors.warning,
                value: local,
                tag: SoftChip('Di PC ini', fg: YmColors.onWarningSoft, bg: YmColors.warningSoft, pill: true),
                icon: Icons.pending_actions_outlined,
                tileBg: YmColors.warningSoft.withOpacity(0.6),
                tileFg: YmColors.warning,
                footer: Row(children: [
                  Icon(Icons.schedule_rounded, size: 16, color: YmColors.warning),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Terkirim otomatis saat server online', maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelSm.copyWith(color: YmColors.onWarningSoft, fontWeight: FontWeight.w500))),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          // ---- bar saring (p-3 rounded-2xl)
          Panel(
            radius: 16,
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 576),
                child: SizedBox(width: 576, child: _searchBox(height: 44, hint: 'Cari judul, nomor, proyek, kontraktor, atau isi file...')),
              ),
              const Spacer(),
              FilterDropdown<String>(
                width: 220,
                height: 40,
                value: _status,
                items: [
                  DropdownMenuItem(value: '', child: Text('Status: semua (${inCat.length})')),
                  DropdownMenuItem(value: 'uploaded', child: Text('Tersimpan di server ($onServer)')),
                  DropdownMenuItem(value: 'review', child: Text('Perlu ditinjau ($attention)')),
                  DropdownMenuItem(value: 'local', child: Text('Belum di server ($local)')),
                ],
                onChanged: (v) => setState(() => _status = v ?? ''),
              ),
              const SizedBox(width: 8),
              FilterDropdown<String>(
                width: 220,
                height: 40,
                value: _project,
                items: [
                  const DropdownMenuItem(value: '', child: Text('Proyek: semua paket')),
                  const DropdownMenuItem(value: '-', child: Text('Tanpa proyek / umum')),
                  for (final p in app.projects) DropdownMenuItem(value: p.id, child: Text(p.label, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _project = v ?? ''),
              ),
              const SizedBox(width: 8),
              _ViewSwitch<bool>(
                value: _dossier,
                options: const [(true, Icons.grid_view_outlined, 'Per proyek (dosir)'), (false, Icons.table_rows_outlined, 'Tabel')],
                onChanged: (v) => setState(() => _dossier = v),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 8,
              child: list.isEmpty
                  ? Panel(
                      child: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Tidak ada dokumen',
                        message: 'Belum ada dokumen ${cat.label.toLowerCase()} yang cocok dengan saringan ini.',
                      ),
                    )
                  : _dossier
                      ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          for (var i = 0; i < dossiers.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Reveal(index: i, child: _DossierCard(project: app.projectById(dossiers[i].key), projectId: dossiers[i].key, docs: dossiers[i].value, category: cat)),
                            ),
                        ])
                      : Reveal(child: _DocTable(docs: list)),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Reveal(index: 1, child: _AlertsCard(docs: inCat)),
                const SizedBox(height: 24),
                Reveal(index: 2, child: _ProjectSpread(docs: inCat)),
              ]),
            ),
          ]),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(children: [
              Icon(Icons.cloud_done_outlined, size: 18, color: YmColors.success),
              const SizedBox(width: 8),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Menampilkan '),
                  TextSpan(text: '${list.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const TextSpan(text: ' dari '),
                  TextSpan(text: '${inCat.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: ' dokumen ${cat.label.toLowerCase()} • semua terindeks di cache offline'),
                ]),
                style: YmTextStyles.labelMd.copyWith(color: YmColors.textMuted),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

IconData _kindIcon(String kind) => switch (kind) {
      'PDF' => Icons.picture_as_pdf_outlined,
      'Word' => Icons.description_outlined,
      'Excel' => Icons.table_chart_outlined,
      'Foto' => Icons.image_outlined,
      'CAD' => Icons.architecture_rounded,
      _ => Icons.insert_drive_file_outlined,
    };

IconData _projectIcon(String type) => switch (type) {
      'Jembatan' => Icons.architecture_rounded,
      'Gedung / Bangunan' => Icons.apartment_rounded,
      'Irigasi' || 'Drainase' => Icons.water_rounded,
      'Air Minum / Sanitasi' => Icons.water_drop_outlined,
      _ => Icons.add_road_rounded,
    };

/// Saringan tambahan (jenis file & urutan) dalam satu tombol.
class _MoreFilters extends StatelessWidget {
  final String kind;
  final _Sort sort;
  final ValueChanged<String> onKind;
  final ValueChanged<_Sort> onSort;
  const _MoreFilters({required this.kind, required this.sort, required this.onKind, required this.onSort});

  @override
  Widget build(BuildContext context) {
    final active = kind.isNotEmpty || sort != _Sort.relevance;
    return PopupMenuButton<String>(
      tooltip: 'Jenis file & urutan',
      onSelected: (v) {
        if (v.startsWith('k:')) onKind(v.substring(2));
        if (v.startsWith('s:')) onSort(_Sort.values.byName(v.substring(2)));
      },
      itemBuilder: (_) => [
        PopupMenuItem(enabled: false, child: Text('JENIS FILE', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline))),
        for (final (v, l) in const [('', 'Semua jenis'), ('PDF', 'PDF'), ('Word', 'Word'), ('Excel', 'Excel'), ('Foto', 'Foto'), ('CAD', 'CAD'), ('Arsip', 'ZIP / RAR')])
          CheckedPopupMenuItem(value: 'k:$v', checked: kind == v, child: Text(l)),
        const PopupMenuDivider(),
        PopupMenuItem(enabled: false, child: Text('URUTKAN', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline))),
        for (final (v, l) in const [
          (_Sort.relevance, 'Paling cocok / terbaru'),
          (_Sort.newest, 'Terbaru diinput'),
          (_Sort.docDate, 'Tanggal dokumen'),
          (_Sort.title, 'Judul A–Z'),
        ])
          CheckedPopupMenuItem(value: 's:${v.name}', checked: sort == v, child: Text(l)),
      ],
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(color: active ? YmColors.primaryFixed : YmColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.tune_rounded, size: 20, color: active ? YmColors.primary : YmColors.outline),
      ),
    );
  }
}

/// Pilihan tampilan (versi web: `p-1 rounded-xl bg-surface-container-low`, tombol 36
/// `rounded-lg`; aktif `bg-surface-container-lowest text-primary shadow-sm`). Penanda meluncur.
class _ViewSwitch<T> extends StatelessWidget {
  final T value;
  final List<(T, IconData, String)> options;
  final ValueChanged<T> onChanged;
  const _ViewSwitch({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final idx = math.max(0, options.indexWhere((o) => o.$1 == value));
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 36.0 * options.length,
        height: 36,
        child: Stack(children: [
          AnimatedPositioned(
            duration: motion(context, const Duration(milliseconds: 220)),
            curve: Curves.easeOutCubic,
            left: 36.0 * idx,
            top: 0,
            width: 36,
            height: 36,
            child: Container(decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(8), boxShadow: shadowSm)),
          ),
          Row(children: [
            for (final o in options)
              Tooltip(
                message: o.$3,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onChanged(o.$1),
                  child: SizedBox(width: 36, height: 36, child: Icon(o.$2, size: 20, color: o.$1 == value ? YmColors.primary : YmColors.outline)),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

/// Kotak centang kecil (versi web: w-4 h-4 rounded accent-primary).
class _Check extends StatelessWidget {
  final bool value;
  final VoidCallback onTap;
  const _Check({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: motion(context, const Duration(milliseconds: 120)),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: value ? YmColors.primary : YmColors.surfaceAlt,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: value ? YmColors.primary : YmColors.outlineVariant),
            ),
            child: value ? Icon(Icons.check_rounded, size: 12, color: YmColors.onPrimary) : null,
          ),
        ),
      );
}

/// Tampilan status sinkron di sisi kanan kartu (versi web: "Local & Cloud Synced").
(IconData?, String, Color, bool) _syncInfo(DocRecord d) {
  final app = AppState.instance;
  final hasLocal = d.localPath.isNotEmpty && File(d.localPath).existsSync();
  return switch (d.status) {
    DocStatus.uploaded => hasLocal
        ? (Icons.cloud_done_outlined, 'Lokal & server tersinkron', YmColors.success, false)
        : (null, 'Masuk server ${timeAgo(d.uploadedAt ?? d.createdAt)}', YmColors.textMuted, false),
    DocStatus.failed => (null, 'Perlu tindakan', YmColors.warning, true),
    DocStatus.draft => (null, 'Draf di PC ini', YmColors.primary, true),
    _ => (null, app.isOnline ? 'Sedang dikirim' : 'Salinan lokal siap', YmColors.warning, false),
  };
}

TextStyle get _meta => YmTextStyles.bodySm.copyWith(color: YmColors.outline);

/// Satu dokumen persis versi web (<article>): checkbox, ubin ikon 44,
/// chip kategori + pill status + tanggal, judul headline-sm, baris info,
/// ukuran + status sinkron, tombol Lihat / Detail / ⋮.
class _DocCard extends StatelessWidget {
  final DocRecord doc;
  final bool compact;
  final bool selected;
  final VoidCallback onSelect;
  final SearchHit? hit;
  final List<RelatedDoc> relations;
  const _DocCard({required this.doc, required this.compact, required this.selected, required this.onSelect, this.hit, this.relations = const []});

  @override
  Widget build(BuildContext context) {
    final d = doc;
    final app = AppState.instance;
    final failed = d.status == DocStatus.failed;
    final pending = d.status == DocStatus.pending || d.status == DocStatus.uploading;
    final (syncIcon, syncText, syncColor, syncBold) = _syncInfo(d);
    final highlight = hit == null ? '' : hit!.contentHits.join(' ');
    void open({bool file = false}) => showDocDetail(context, d, highlight: highlight, startOnFile: file);

    final meta = <Widget>[
      if (d.docNumber.isNotEmpty)
        Text('No. ${d.docNumber}', style: YmTextStyles.bodySm.copyWith(color: failed ? YmColors.warning : YmColors.textDark, fontWeight: FontWeight.w600)),
      if (d.docDate.isNotEmpty) Text('Tanggal ${formatIsoDate(d.docDate)}', style: _meta),
      if (d.projectCode.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(4)),
          child: Text('Proyek ${d.projectCode}', style: YmTextStyles.labelSm.copyWith(color: YmColors.primary)),
        ),
      if (d.series.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(4)),
          child: Text('Seri ${d.series}', style: YmTextStyles.labelSm),
        ),
      if (failed)
        Text('Belum masuk server', style: YmTextStyles.bodySm.copyWith(color: YmColors.warning, fontWeight: FontWeight.w500))
      else if (pending)
        Text('Tersimpan aman di PC', style: YmTextStyles.bodySm.copyWith(color: YmColors.success, fontWeight: FontWeight.w500))
      else
        Text('Diunggah ${d.createdByName}', style: _meta),
    ];

    // ubin ikon: gagal = peringatan (tertiary-fixed), menunggu = laptop (tertiary-fixed-dim/30)
    final tile = failed
        ? CategoryTile(code: d.category, icon: Icons.warning_amber_rounded, bg: YmColors.warningSoft, fg: YmColors.warning, size: compact ? 36 : 44)
        : pending
            ? CategoryTile(code: d.category, icon: Icons.laptop_mac_outlined, bg: YmColors.warningDim.withOpacity(0.3), fg: YmColors.warning, size: compact ? 36 : 44)
            : CategoryTile(code: d.category, size: compact ? 36 : 44);

    final card = HoverCard(
      onTap: highlight.isEmpty ? () => showDocQuickView(context, d) : open,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 10 : 16),
      gradient: failed
          ? LinearGradient(colors: [YmColors.warningSoft.withOpacity(0.2), YmColors.surface, YmColors.surface], stops: const [0, 0.5, 1])
          : null,
      borderColor: selected ? YmColors.primary.withOpacity(0.5) : null,
      child: Row(
        crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.center,
        children: [
          // kiri: checkbox + ubin + isi
          Expanded(
            child: Row(
              crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                Padding(padding: EdgeInsets.only(top: compact ? 0 : 4), child: _Check(value: selected, onTap: onSelect)),
                const SizedBox(width: 16),
                tile,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!compact) ...[
                        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          CategoryBadge(code: d.category),
                          DocStatusChip(status: d.status),
                          Text(_when(d.createdAt), style: _meta),
                        ]),
                        const SizedBox(height: 4),
                      ],
                      Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: compact ? YmTextStyles.labelLg.copyWith(fontWeight: FontWeight.w600) : YmTextStyles.headlineSm),
                      const SizedBox(height: 4),
                      if (compact)
                        Text(
                          [categoryOf(d.category).label, if (d.docNumber.isNotEmpty) 'No. ${d.docNumber}', formatIsoDate(d.docDate), if (d.projectCode.isNotEmpty) d.projectCode]
                              .join('  •  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _meta,
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (var i = 0; i < meta.length; i++) ...[
                              if (i > 0) Text('•', style: _meta),
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
                            style: YmTextStyles.labelSm.copyWith(color: YmColors.primary),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // kanan: ukuran + status, tombol (gap-space-lg)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${fileKind(d.extension).toUpperCase()} • ${formatBytes(d.fileSize)}', style: YmTextStyles.bodySm.copyWith(fontWeight: FontWeight.w500)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (syncIcon != null) ...[Icon(syncIcon, size: 14, color: syncColor), const SizedBox(width: 4)],
                Text(syncText, style: YmTextStyles.labelSm.copyWith(color: syncColor, fontWeight: syncBold ? FontWeight.w600 : FontWeight.w500)),
              ]),
            ],
          ),
          const SizedBox(width: 24),
          if (failed)
            TextButton.icon(
              style: softButtonStyle(fg: Colors.white, bg: YmColors.warning).copyWith(elevation: const WidgetStatePropertyAll(1)),
              onPressed: () => app.retryDoc(d),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Upload ulang'),
            )
          else if (pending)
            TextButton.icon(
              style: softButtonStyle(fg: YmColors.primary, bg: YmColors.surfaceContainer, hover: YmColors.surfaceContainerHigh),
              onPressed: app.setupMode || app.syncing ? null : () => app.tick(forcePull: false),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Coba sinkron'),
            )
          else if (d.status == DocStatus.draft)
            TextButton.icon(
              style: softButtonStyle(fg: YmColors.onPrimary, bg: YmColors.primary, hover: YmColors.primaryContainer),
              onPressed: () => open(),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Periksa & kirim'),
            )
          else
            TextButton.icon(
              style: softButtonStyle(),
              onPressed: () => open(file: true),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Lihat file'),
            ),
          const SizedBox(width: 8),
          if (d.isUnsynced && d.status != DocStatus.uploading && _canChange(d))
            TextButton.icon(
              style: softButtonStyle(),
              onPressed: () => _editUnsent(context, d),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            )
          else
            TextButton(style: softButtonStyle(), onPressed: open, child: Text(failed || pending ? 'Pratinjau' : 'Detail')),
          const SizedBox(width: 8),
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
          margin: const EdgeInsets.fromLTRB(92, 6, 0, 0),
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
                Text('Seri:', style: YmTextStyles.labelSm.copyWith(color: YmColors.primary)),
                for (final r in series) _RelChip(r: r, highlight: true),
              ],
              if (others.isNotEmpty) ...[
                if (series.isNotEmpty) const SizedBox(width: 6),
                Text('Terkait:', style: YmTextStyles.labelSm),
                for (final r in others) _RelChip(r: r),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "18 mnt lalu" untuk hari ini, "Kemarin", selain itu tanggal (versi web: "Oct 10, 2024").
String _when(DateTime d) {
  final n = DateTime.now();
  if (n.difference(d).inHours < 24 && n.day == d.day) return timeAgo(d);
  if (n.difference(d).inDays <= 1) return 'Kemarin';
  return formatIsoDate(isoDate(d));
}

/// Kartu dokumen untuk tampilan kisi.
class _DocTile extends StatelessWidget {
  final DocRecord doc;
  final bool selected;
  final VoidCallback onSelect;
  const _DocTile({required this.doc, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final d = doc;
    final (syncIcon, syncText, syncColor, _) = _syncInfo(d);
    return HoverCard(
      onTap: () => showDocQuickView(context, d),
      borderColor: selected ? YmColors.primary.withOpacity(0.5) : null,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Check(value: selected, onTap: onSelect),
          const SizedBox(width: 12),
          CategoryTile(code: d.category, size: 40),
          const Spacer(),
          _MoreMenu(doc: d),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 4, children: [CategoryBadge(code: d.category, compact: true), DocStatusChip(status: d.status)]),
        const SizedBox(height: 8),
        SizedBox(height: 48, child: Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: YmTextStyles.headlineSm)),
        const SizedBox(height: 4),
        Text([if (d.docNumber.isNotEmpty) 'No. ${d.docNumber}', _when(d.createdAt)].join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: _meta),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${fileKind(d.extension).toUpperCase()} • ${formatBytes(d.fileSize)}', style: YmTextStyles.bodySm.copyWith(fontWeight: FontWeight.w500)),
              Row(children: [
                if (syncIcon != null) ...[Icon(syncIcon, size: 13, color: syncColor), const SizedBox(width: 4)],
                Flexible(child: Text(syncText, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelSm.copyWith(color: syncColor, fontWeight: FontWeight.w500))),
              ]),
            ]),
          ),
          TextButton.icon(
            style: softButtonStyle(),
            onPressed: () => showDocDetail(context, d, startOnFile: true),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Lihat'),
          ),
        ]),
      ]),
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
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(fixedSize: const Size(36, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      icon: Icon(Icons.more_vert_rounded, color: YmColors.outline, size: 18),
      onSelected: (v) async {
        switch (v) {
          case 'detail':
            await showDocDetail(context, d);
          case 'file':
            await showDocDetail(context, d, startOnFile: true);
          case 'project':
            Nav.openDocsForProject(d.projectId);
          case 'category':
            Nav.openCategory(d.category);
          case 'series':
            Nav.searchDocs(d.series);
          case 'copy':
            await Clipboard.setData(ClipboardData(text: d.docNumber));
            if (context.mounted) showSnack(context, 'Nomor dokumen disalin.');
          case 'edit':
            if (context.mounted) await _editUnsent(context, d);
          case 'replace':
            if (context.mounted) await _replaceUnsent(context, d);
          case 'delete':
            if (context.mounted) await _deleteUnsent(context, d);
        }
      },
      itemBuilder: (_) => [
        if (d.isUnsynced && _canChange(d)) ...[
          PopupMenuItem(
            value: 'edit',
            enabled: d.status != DocStatus.uploading,
            child: const _MenuLine(icon: Icons.edit_outlined, text: 'Edit data (belum terkirim)'),
          ),
          PopupMenuItem(
            value: 'replace',
            enabled: d.status != DocStatus.uploading,
            child: const _MenuLine(icon: Icons.swap_horiz_rounded, text: 'Ganti file'),
          ),
          PopupMenuItem(
            value: 'delete',
            enabled: d.status != DocStatus.uploading,
            child: _MenuLine(icon: Icons.delete_outline_rounded, text: 'Hapus dari antrian', color: YmColors.danger),
          ),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(value: 'detail', child: Text('Buka detail dokumen')),
        const PopupMenuItem(value: 'file', child: Text('Lihat file asli')),
        PopupMenuItem(value: 'category', child: Text('Kategori ${categoryOf(d.category).label.split(' /').first}')),
        if (d.projectId.isNotEmpty) PopupMenuItem(value: 'project', child: Text('Semua dokumen proyek ${d.projectCode}')),
        if (d.series.isNotEmpty) const PopupMenuItem(value: 'series', child: Text('Cari seri dokumen ini')),
        if (d.docNumber.isNotEmpty) const PopupMenuItem(value: 'copy', child: Text('Salin nomor dokumen')),
      ],
    );
  }
}

/// Dokumen yang belum terkirim boleh diubah/dihapus oleh pembuatnya atau admin.
bool _canChange(DocRecord d) {
  final s = AppState.instance.session;
  if (s == null) return false;
  return s.isAdmin || d.createdBy.toLowerCase() == s.username.toLowerCase();
}

/// Edit data dokumen yang BELUM terkirim (draf / menunggu internet / gagal).
/// Perubahan disimpan di PC dan ikut terkirim saat diunggah.
Future<void> _editUnsent(BuildContext context, DocRecord d) async {
  if (d.status == DocStatus.uploading) {
    showSnack(context, 'Dokumen sedang diunggah. Tunggu sebentar lalu coba lagi.', error: true);
    return;
  }
  final changed = await showDocEditDialog(context, d);
  if (changed == true && context.mounted) showSnack(context, 'Data dokumen diperbarui. Akan terkirim dengan data terbaru.');
}

Future<void> _replaceUnsent(BuildContext context, DocRecord d) async {
  final r = await FilePicker.platform.pickFiles(dialogTitle: 'Pilih file pengganti', type: FileType.custom, allowedExtensions: allowedExtensions);
  final path = r?.files.single.path;
  if (path == null) return;
  try {
    await AppState.instance.replaceUnsentFile(d, path);
    if (context.mounted) showSnack(context, 'File diganti. Akan terkirim dengan file baru.');
  } catch (e) {
    if (context.mounted) showSnack(context, e.toString(), error: true);
  }
}

Future<void> _deleteUnsent(BuildContext context, DocRecord d) async {
  final ok = await confirmDialog(
    context,
    title: 'Hapus dari antrian?',
    message: '"${d.title}" belum terkirim ke server dan akan dihapus dari PC ini (beserta salinan filenya). Tindakan ini tidak bisa dibatalkan.',
    ok: 'Hapus',
    danger: true,
  );
  if (!ok) return;
  try {
    await AppState.instance.deleteDoc(d);
    if (context.mounted) showSnack(context, 'Dokumen dihapus dari antrian.');
  } catch (e) {
    if (context.mounted) showSnack(context, e.toString(), error: true);
  }
}

class _MenuLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _MenuLine({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: color ?? YmColors.textMuted),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(color: color)),
      ]);
}

/// Navigasi halaman persis versi web: "Menampilkan 1 sampai 10 dari 1.420 dokumen terindeks"
/// • "Semua tersimpan untuk pencarian offline" | Sebelumnya 1 2 3 4 … 142 Berikutnya.
class _Pager extends StatelessWidget {
  final int page, pages, total;
  final ValueChanged<int> onPage;
  const _Pager({required this.page, required this.pages, required this.total, required this.onPage});

  @override
  Widget build(BuildContext context) {
    final from = total == 0 ? 0 : page * _pageSize + 1;
    final to = math.min(total, (page + 1) * _pageSize);
    // 1 2 3 4 … terakhir (seperti versi web)
    final nums = <int>{
      for (var i = math.max(0, math.min(page - 1, pages - 4)); i < math.min(pages, math.max(page - 1, 0) + 4); i++) i,
      pages - 1,
    }.where((p) => p >= 0 && p < pages).toList()
      ..sort();
    final items = <Widget>[];
    int? prev;
    for (final p in nums) {
      if (prev != null && p - prev > 1) {
        items.add(SizedBox(width: 32, child: Text('...', textAlign: TextAlign.center, style: YmTextStyles.labelSm.copyWith(color: YmColors.outline))));
      }
      items.add(_PageBtn(label: '${p + 1}', selected: p == page, onTap: () => onPage(p)));
      prev = p;
    }
    final strong = YmTextStyles.bodySm.copyWith(color: YmColors.textDark, fontWeight: FontWeight.w500);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(12), boxShadow: shadowSm),
      child: Row(
        children: [
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Menampilkan '),
              TextSpan(text: '$from', style: strong),
              const TextSpan(text: ' sampai '),
              TextSpan(text: '$to', style: strong),
              const TextSpan(text: ' dari '),
              TextSpan(text: CountUp.dots(total), style: strong),
              const TextSpan(text: ' dokumen terindeks'),
            ]),
            style: YmTextStyles.bodySm,
          ),
          const SizedBox(width: 12),
          Container(width: 4, height: 4, decoration: BoxDecoration(color: YmColors.outlineVariant, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Container(width: 6, height: 6, decoration: BoxDecoration(color: YmColors.success, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('Semua tersimpan untuk pencarian offline', style: YmTextStyles.labelSm.copyWith(color: YmColors.success)),
          const Spacer(),
          _NavBtn(label: 'Sebelumnya', icon: Icons.chevron_left_rounded, leading: true, onTap: page > 0 ? () => onPage(page - 1) : null),
          const SizedBox(width: 4),
          for (final w in items) Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: w),
          const SizedBox(width: 4),
          _NavBtn(label: 'Berikutnya', icon: Icons.chevron_right_rounded, leading: false, onTap: page < pages - 1 ? () => onPage(page + 1) : null),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool leading;
  final VoidCallback? onTap;
  const _NavBtn({required this.label, required this.icon, required this.leading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = onTap == null ? YmColors.outline : YmColors.textDark;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: TextButton(
        style: softButtonStyle(fg: fg).copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
        ),
        onPressed: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (leading) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 4)],
          Text(label),
          if (!leading) ...[const SizedBox(width: 4), Icon(icon, size: 16, color: fg)],
        ]),
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
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: motion(context, kMotionFast),
          constraints: const BoxConstraints(minWidth: 32),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? YmColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(8), boxShadow: selected ? shadowSm : null),
          child: Text(label, style: YmTextStyles.labelSm.copyWith(color: selected ? YmColors.onPrimary : YmColors.textMuted, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
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
        onTap: () => showDocQuickView(context, r.doc),
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
              child: Text(r.doc.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelMd),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: YmColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.edit_note_rounded, color: YmColors.primary, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${drafts.length} draf belum dikirim ke server', style: YmTextStyles.labelLg.copyWith(fontWeight: FontWeight.w600)),
              Text(
                app.canUseServer
                    ? 'Buka tiap draf untuk memeriksa isi file dan datanya, lalu kirim.'
                    : 'Server sedang tidak terhubung: yang dikirim tersimpan di PC dan terkirim otomatis saat server online.',
                style: YmTextStyles.bodySm,
              ),
            ]),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            style: outlineButtonStyle().copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 32)), padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16))),
            onPressed: onShow,
            child: const Text('Lihat draf'),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            style: primaryButtonStyle().copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 32)), padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16))),
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
            child: Text('Kirim semua (${drafts.length})'),
          ),
        ]),
      ),
    );
  }
}

// ============================================================================
//  Bagian halaman kategori
// ============================================================================

/// Dosir per proyek (versi web: kartu "Shipment #SHP-2024-8841"):
/// ubin ikon + judul headline-md + pill status, kotak data proyek 3 kolom,
/// daftar dokumen yang sudah diperiksa (chip), peringatan, dan tombol aksi.
class _DossierCard extends StatelessWidget {
  final Project? project;
  final String projectId;
  final List<DocRecord> docs;
  final DocCategory category;
  const _DossierCard({required this.project, required this.projectId, required this.docs, required this.category});

  @override
  Widget build(BuildContext context) {
    final p = project;
    final failed = docs.where((d) => d.status == DocStatus.failed).toList();
    final drafts = docs.where((d) => d.status == DocStatus.draft).toList();
    final unsynced = docs.where((d) => d.isUnsynced).length;
    final allOk = unsynced == 0;
    final last = docs.map((d) => d.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
    final code = p?.code ?? (docs.first.projectCode.isNotEmpty ? docs.first.projectCode : '');
    final name = p?.name ?? (docs.first.projectName.isNotEmpty ? docs.first.projectName : 'Tanpa proyek / dokumen umum');

    final (Widget statusPill, Color tileBg, Color tileFg, IconData tileIcon) = failed.isNotEmpty
        ? (SoftChip.danger('${failed.length} gagal diunggah', icon: Icons.error_outline_rounded), YmColors.dangerSoft, YmColors.danger, Icons.warning_amber_rounded)
        : !allOk
            ? (SoftChip.warning('$unsynced belum di server', icon: Icons.hourglass_top_rounded), YmColors.warningSoft, YmColors.warning, Icons.pending_actions_outlined)
            : (
                SoftChip('Lengkap • semua di server', icon: Icons.verified_outlined, fg: YmColors.onSuccessSoft, bg: YmColors.successContainer.withOpacity(0.55), pill: true, bold: true),
                YmColors.primaryFixed,
                YmColors.primary,
                p == null ? Icons.folder_outlined : _projectIcon(p.type)
              );

    Widget metaCell(String label, String value, {String? sub, Color? valueColor, bool big = false}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: YmTextStyles.labelSm.copyWith(color: YmColors.textMuted, fontSize: 10.5, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(value.isEmpty ? '—' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: big ? YmTextStyles.headlineSm.copyWith(color: valueColor ?? YmColors.primary, fontWeight: FontWeight.w700) : YmTextStyles.labelMd.copyWith(fontWeight: FontWeight.w600, color: valueColor)),
            if (sub != null && sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.bodySm.copyWith(fontSize: 11)),
          ],
        );

    return HoverCard(
      radius: 16,
      padding: const EdgeInsets.all(24),
      hoverShadowOverride: const [BoxShadow(color: Color(0x1F0F172A), blurRadius: 28, offset: Offset(0, 12))],
      baseShadowOverride: YmColors.isDark ? const [] : const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 16, offset: Offset(0, 4))],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ---- kepala
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: tileBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(tileIcon, size: 22, color: tileFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(code.isEmpty ? name : 'Paket $code', style: YmTextStyles.headlineMd),
                statusPill,
                if (p != null) SoftChip.neutral(p.type),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: allOk ? YmColors.success : YmColors.warning, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    [
                      'Diperbarui ${timeAgo(last)}',
                      if (code.isNotEmpty) name,
                      if (p != null && p.location.isNotEmpty) p.location,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: YmTextStyles.bodySm,
                  ),
                ),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        // ---- data proyek
        if (p != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: metaCell('Jenis & lokasi', p.type, sub: p.location)),
                const SizedBox(width: 16),
                Expanded(child: metaCell('Kontraktor', p.contractor, sub: p.supervisor.isEmpty ? null : 'Pengawas: ${p.supervisor}')),
                const SizedBox(width: 16),
                Expanded(child: metaCell('No. kontrak', p.contractNumber, sub: [formatIsoDate(p.startDate), formatIsoDate(p.endDate)].where((e) => e != '-').join(' s.d. '))),
              ]),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: metaCell('Sumber dana & TA', '${p.fundingSource} • ${p.year}', sub: p.ppk.isEmpty ? null : 'PPK: ${p.ppk}')),
                const SizedBox(width: 16),
                Expanded(child: metaCell('Status & progres', '${p.status} • ${p.progress}%', valueColor: YmColors.textDark)),
                const SizedBox(width: 16),
                Expanded(
                  child: metaCell('Nilai kontrak', p.contractValue > 0 ? formatRupiah(p.contractValue) : '', big: true, sub: '${docs.length} dokumen ${category.label.split(' /').first.toLowerCase()}'),
                ),
              ]),
            ]),
          ),
        if (p != null) const SizedBox(height: 16),
        // ---- dokumen yang diperiksa
        Row(children: [
          Expanded(
            child: Text('Dokumen ${category.label.split(' /').first} (${docs.length - unsynced} dari ${docs.length} di server)'.toUpperCase(),
                style: YmTextStyles.labelSm.copyWith(color: YmColors.textMuted, letterSpacing: 0.5)),
          ),
          if (allOk) Text('Semua sidik jari tercatat', style: YmTextStyles.labelSm.copyWith(color: YmColors.success)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in docs.take(8))
            Tooltip(
              message: d.title,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => showDocQuickView(context, d),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: switch (d.status) {
                      DocStatus.uploaded => YmColors.successContainer.withOpacity(0.35),
                      DocStatus.failed => YmColors.dangerSoft,
                      DocStatus.draft => YmColors.primaryFixed,
                      _ => YmColors.warningSoft,
                    },
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      switch (d.status) {
                        DocStatus.uploaded => Icons.check_circle_outline_rounded,
                        DocStatus.failed => Icons.cancel_outlined,
                        DocStatus.draft => Icons.edit_note_rounded,
                        _ => Icons.hourglass_empty_rounded,
                      },
                      size: 14,
                      color: switch (d.status) {
                        DocStatus.uploaded => YmColors.success,
                        DocStatus.failed => YmColors.danger,
                        DocStatus.draft => YmColors.primary,
                        _ => YmColors.warning,
                      },
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelSm.copyWith(color: YmColors.textDark)),
                    ),
                    if (d.docNumber.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(d.docNumber, style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600, color: YmColors.textMuted)),
                    ],
                  ]),
                ),
              ),
            ),
          if (docs.length > 8) SoftChip('+${docs.length - 8} lainnya', bg: YmColors.surfaceContainer),
        ]),
        // ---- peringatan
        if (failed.isNotEmpty || drafts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: (failed.isNotEmpty ? YmColors.dangerSoft : YmColors.warningSoft).withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(failed.isNotEmpty ? Icons.report_problem_outlined : Icons.info_outline_rounded, size: 18, color: failed.isNotEmpty ? YmColors.danger : YmColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: failed.isNotEmpty ? 'Gagal unggah: ' : 'Belum dikirim: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(
                      text: failed.isNotEmpty
                          ? '${failed.length} dokumen belum masuk server${failed.first.lastError == null ? '' : ' (${failed.first.lastError})'}. Upload ulang supaya tersimpan aman.'
                          : '${drafts.length} draf menunggu diperiksa sebelum dikirim ke server.',
                    ),
                  ]),
                  style: YmTextStyles.bodySm.copyWith(color: failed.isNotEmpty ? YmColors.onDangerSoft : YmColors.onWarningSoft),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        // ---- aksi
        Row(children: [
          TextButton.icon(
            style: softButtonStyle(),
            onPressed: () => projectId.isEmpty ? Nav.go('upload') : Nav.uploadForProject(projectId),
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Unggah ke paket ini'),
          ),
          const SizedBox(width: 8),
          if (failed.isNotEmpty)
            TextButton.icon(
              style: softButtonStyle(fg: Colors.white, bg: YmColors.danger),
              onPressed: () {
                for (final d in failed) {
                  AppState.instance.retryDoc(d);
                }
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Upload ulang ${failed.length}'),
            ),
          const Spacer(),
          if (projectId.isNotEmpty)
            ElevatedButton(
              style: primaryButtonStyle().copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 36)), padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16))),
              onPressed: () => Nav.openDocsForProject(projectId),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Buka semua dokumen proyek'), SizedBox(width: 6), Icon(Icons.arrow_forward_rounded, size: 18)]),
            ),
        ]),
      ]),
    );
  }
}

/// Tampilan tabel di halaman kategori.
class _DocTable extends StatelessWidget {
  final List<DocRecord> docs;
  const _DocTable({required this.docs});

  @override
  Widget build(BuildContext context) {
    final head = YmTextStyles.labelSm.copyWith(color: YmColors.textMuted, letterSpacing: 0.5);
    return Panel(
      radius: 16,
      padding: EdgeInsets.zero,
      child: Column(children: [
        Container(
          color: YmColors.surfaceAlt,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(flex: 5, child: Text('DOKUMEN', style: head)),
            Expanded(flex: 2, child: Text('PROYEK', style: head)),
            Expanded(flex: 2, child: Text('TANGGAL', style: head)),
            Expanded(flex: 2, child: Text('STATUS', style: head)),
            const SizedBox(width: 60),
          ]),
        ),
        for (final d in docs.take(100))
          InkWell(
            onTap: () => showDocQuickView(context, d),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: YmColors.surfaceAlt))),
              child: Row(children: [
                Expanded(
                  flex: 5,
                  child: Row(children: [
                    FileTypeIcon(ext: d.extension, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelLg.copyWith(fontWeight: FontWeight.w600)),
                        if (d.docNumber.isNotEmpty) Text(d.docNumber, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: YmColors.textMuted)),
                      ]),
                    ),
                  ]),
                ),
                Expanded(flex: 2, child: Text(d.projectCode.isEmpty ? '—' : d.projectCode, style: YmTextStyles.labelMd)),
                Expanded(flex: 2, child: Text(formatIsoDate(d.docDate), style: YmTextStyles.bodySm)),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: DocStatusChip(status: d.status))),
                SizedBox(width: 60, child: Text('Buka →', textAlign: TextAlign.right, style: YmTextStyles.labelMd.copyWith(color: YmColors.primary, fontWeight: FontWeight.w600))),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Panel "Perlu perhatian" (versi web: "Active Trade Alerts").
class _AlertsCard extends StatelessWidget {
  final List<DocRecord> docs;
  const _AlertsCard({required this.docs});

  @override
  Widget build(BuildContext context) {
    final items = [
      ...docs.where((d) => d.status == DocStatus.failed).map((d) => (d, 'Gagal unggah', YmColors.danger, d.lastError ?? 'Dokumen belum masuk server.')),
      ...docs.where((d) => d.status == DocStatus.draft).map((d) => (d, 'Draf belum dikirim', YmColors.warning, 'Periksa isi file lalu kirim ke server.')),
      ...docs
          .where((d) => d.status == DocStatus.pending || d.status == DocStatus.uploading)
          .map((d) => (d, 'Menunggu sinkron', YmColors.primary, 'Tersimpan di PC, terkirim otomatis saat server online.')),
    ].take(5).toList();
    return Panel(
      radius: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.notification_important_outlined, size: 20, color: YmColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text('Perlu perhatian', style: YmTextStyles.headlineSm)),
          Text('${items.length} item', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: YmColors.textMuted)),
        ]),
        const SizedBox(height: 16),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.task_alt_rounded, size: 18, color: YmColors.success),
              const SizedBox(width: 8),
              Expanded(child: Text('Semua dokumen di kategori ini sudah aman di server.', style: YmTextStyles.bodySm.copyWith(color: YmColors.textDark))),
            ]),
          ),
        for (final (d, label, color, desc) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: HoverCard(
              color: YmColors.surfaceAlt,
              radius: 12,
              padding: const EdgeInsets.all(12),
              baseShadowOverride: const [],
              hoverShadowOverride: const [],
              hoverColor: YmColors.surfaceContainer,
              onTap: () => showDocQuickView(context, d),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Expanded(child: Text(label, style: YmTextStyles.labelSm.copyWith(color: color))),
                  Text(d.projectCode.isEmpty ? '—' : d.projectCode, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: YmColors.textMuted)),
                ]),
                const SizedBox(height: 4),
                Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.bodySm.copyWith(color: YmColors.textDark, fontWeight: FontWeight.w500)),
                Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kFont, fontSize: 11, color: YmColors.textMuted)),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Panel "Per proyek" (versi web: "Trade Corridors").
class _ProjectSpread extends StatelessWidget {
  final List<DocRecord> docs;
  const _ProjectSpread({required this.docs});

  @override
  Widget build(BuildContext context) {
    final by = <String, List<DocRecord>>{};
    for (final d in docs) {
      by.putIfAbsent(d.projectCode.isEmpty ? 'Tanpa proyek' : d.projectCode, () => []).add(d);
    }
    final rows = by.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    final top = rows.take(4).toList();
    final maxN = top.isEmpty ? 1 : top.first.value.length;
    final colors = [YmColors.primary, YmColors.success, YmColors.warning, YmColors.outline];
    final onServer = docs.where((d) => d.status == DocStatus.uploaded).length;
    final pct = docs.isEmpty ? 100.0 : onServer * 100 / docs.length;
    return Panel(
      radius: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.route_outlined, size: 20, color: YmColors.textDark),
          const SizedBox(width: 8),
          Expanded(child: Text('Per proyek / paket', style: YmTextStyles.headlineSm)),
          InkWell(onTap: () => Nav.go('projects'), child: Text('Semua proyek', style: YmTextStyles.labelSm.copyWith(color: YmColors.primary, fontWeight: FontWeight.w500))),
        ]),
        const SizedBox(height: 16),
        if (top.isEmpty) Text('Belum ada dokumen.', style: YmTextStyles.bodySm),
        for (var i = 0; i < top.length; i++) ...[
          Row(children: [
            Expanded(child: Text(top[i].key, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelSm.copyWith(color: YmColors.textDark, fontWeight: FontWeight.w500))),
            Text('${top[i].value.length} dokumen', style: YmTextStyles.labelSm.copyWith(color: colors[i % colors.length])),
          ]),
          const SizedBox(height: 4),
          ProgressBar(value: top[i].value.length / maxN, height: 8, color: colors[i % colors.length]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: Text('${top[i].value.where((d) => d.status == DocStatus.uploaded).length} di server',
                  style: TextStyle(fontFamily: kFont, fontSize: 11, color: YmColors.textMuted)),
            ),
            Text('${top[i].value.where((d) => d.isUnsynced).length} belum', style: TextStyle(fontFamily: kFont, fontSize: 11, color: YmColors.textMuted)),
          ]),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: YmColors.success, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Tersalin untuk pencarian offline',
                  style: TextStyle(fontFamily: kFont, fontSize: 11, fontWeight: FontWeight.w500, color: YmColors.success)),
            ),
            Text('Sinkron ${pct.toStringAsFixed(1)}%', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: YmColors.textMuted)),
          ]),
        ),
      ]),
    );
  }
}
