import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../theme/ym_theme.dart';
import 'viewer_common.dart';
import '../print/print_dialog.dart';

/// Penampil PDF di dalam aplikasi (mesin PDFium, sama seperti Chrome).
/// Fitur: gulir halaman, zoom (Ctrl + roda mouse / tombol), lompat halaman,
/// cari teks dengan sorotan (kode 544 juga cocok dengan "5.4.4"), pilih & salin teks.
class PdfDocView extends StatefulWidget {
  final String path;
  final String initialQuery;
  final List<Widget> trailing;
  final List<Widget> errorActions;

  /// Diisi penampil: cara membuat PDF siap cetak (tombol Cetak).
  final PrintController? printController;
  const PdfDocView({super.key, required this.path, this.initialQuery = '', this.trailing = const [], this.errorActions = const [], this.printController});

  @override
  State<PdfDocView> createState() => _PdfDocViewState();
}

class _PdfDocViewState extends State<PdfDocView> {
  final _ctrl = PdfViewerController();
  /// Dibuat SETELAH PDF selesai dimuat: PdfTextSearcher langsung membaca
  /// dokumen saat dibuat (kalau terlalu awal -> "Null check operator ...").
  PdfTextSearcher? _searcher;
  final _findFocus = FocusNode();
  final _searchKey = GlobalKey();
  final _pageCtl = TextEditingController();
  int _page = 1;
  int _pageCount = 0;
  double _zoom = 1;
  bool _ready = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _ctrl.addListener(_onViewChanged);
    widget.printController?.buildPdf = () async => widget.path; // PDF asli langsung dicetak
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onViewChanged);
    _searcher?.removeListener(_onSearchChanged);
    _searcher?.dispose();
    _findFocus.dispose();
    _pageCtl.dispose();
    super.dispose();
  }

  void _onViewChanged() {
    if (!_ctrl.isReady) return;
    final z = _ctrl.currentZoom;
    if ((z - _zoom).abs() > 0.004 && mounted) setState(() => _zoom = z);
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _search(String q) {
    _query = q;
    final s = _searcher;
    if (s == null) return; // dicari otomatis begitu PDF siap
    final re = buildSearchPattern(q);
    if (re == null) {
      s.resetTextSearch();
    } else {
      s.startTextSearch(re, goToFirstMatch: true);
    }
  }

  void _paintMatches(ui.Canvas canvas, Rect pageRect, PdfPage page) {
    _searcher?.pageTextMatchPaintCallback(canvas, pageRect, page);
  }

  Future<void> _goToPage(int n) async {
    if (!_ready || _pageCount == 0) return;
    await _ctrl.goToPage(pageNumber: n.clamp(1, _pageCount));
  }

  Future<void> _zoomIn() async {
    if (_ready) await _ctrl.zoomUp();
  }

  Future<void> _zoomOut() async {
    if (_ready) await _ctrl.zoomDown();
  }

  Future<void> _fit() async {
    if (_ready) await _ctrl.setZoom(_ctrl.centerPosition, _ctrl.coverScale);
  }

  @override
  Widget build(BuildContext context) {
    final matches = _searcher?.matches.length ?? 0;
    final cur = _searcher?.currentIndex ?? -1;
    return ViewerShortcuts(
      onFind: () => _findFocus.requestFocus(),
      onZoomIn: _zoomIn,
      onZoomOut: _zoomOut,
      onZoomReset: _fit,
      child: Column(children: [
        ViewerToolbar(leading: [
          ToolButton(icon: Icons.first_page_rounded, tooltip: 'Halaman pertama', onPressed: _ready && _page > 1 ? () => _goToPage(1) : null),
          ToolButton(icon: Icons.chevron_left_rounded, tooltip: 'Halaman sebelumnya', onPressed: _ready && _page > 1 ? () => _goToPage(_page - 1) : null),
          SizedBox(
            width: 44,
            height: 30,
            child: TextField(
              controller: _pageCtl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 7),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: YmColors.borderLavender)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: YmColors.borderLavender)),
              ),
              onSubmitted: (v) => _goToPage(int.tryParse(v.trim()) ?? _page),
            ),
          ),
          ToolLabel(' / ${_pageCount == 0 ? '-' : _pageCount}', minWidth: 36),
          ToolButton(icon: Icons.chevron_right_rounded, tooltip: 'Halaman berikutnya', onPressed: _ready && _page < _pageCount ? () => _goToPage(_page + 1) : null),
          ToolButton(icon: Icons.last_page_rounded, tooltip: 'Halaman terakhir', onPressed: _ready && _page < _pageCount ? () => _goToPage(_pageCount) : null),
          const ToolDivider(),
          ZoomControls(zoom: _zoom, onZoomIn: _zoomIn, onZoomOut: _zoomOut, onFitWidth: _fit),
        ], search: DocSearchBox(
            key: _searchKey,
            initial: widget.initialQuery,
            focusNode: _findFocus,
            onSearch: _search,
            onNext: () => _searcher?.goToNextMatch(),
            onPrev: () => _searcher?.goToPrevMatch(),
            current: cur,
            total: matches,
            busy: (_searcher?.isSearching ?? false) && matches == 0 && _query.trim().isNotEmpty,
          ), trailing: widget.trailing),
        Expanded(
          child: PdfViewer.file(
            widget.path,
            controller: _ctrl,
            params: PdfViewerParams(
              backgroundColor: kViewerBackground,
              margin: 14,
              pagePaintCallbacks: [_paintMatches],
              onViewerReady: (document, controller) {
                if (!mounted) return;
                _searcher ??= PdfTextSearcher(controller)..addListener(_onSearchChanged);
                setState(() {
                  _ready = true;
                  _pageCount = document.pages.length;
                  _zoom = controller.currentZoom;
                });
                _pageCtl.text = '$_page';
                if (_query.trim().isNotEmpty) _search(_query);
              },
              onPageChanged: (n) {
                if (n != null && mounted && n != _page) {
                  setState(() => _page = n);
                  _pageCtl.text = '$n';
                }
              },
              loadingBannerBuilder: (context, done, total) => const Center(child: CircularProgressIndicator()),
              errorBannerBuilder: (context, error, stackTrace, documentRef) => ViewerMessage(
                icon: Icons.picture_as_pdf_rounded,
                title: 'PDF tidak bisa dibuka',
                message: 'File mungkin rusak atau dilindungi password.\n$error',
                actions: widget.errorActions,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
