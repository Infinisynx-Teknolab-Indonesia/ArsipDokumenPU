import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import '../theme/ym_theme.dart';
import '../print/pdf_builder.dart';
import '../print/print_dialog.dart';
import 'sheet_parser.dart';
import 'viewer_common.dart';

/// Penampil Excel (.xlsx) dan CSV di dalam aplikasi: tabel dengan kepala
/// kolom A, B, C..., nomor baris, tab sheet, zoom, dan cari isi sel.
class SheetDocView extends StatefulWidget {
  final String path;
  final bool csv;
  final String initialQuery;
  final List<Widget> trailing;
  final List<Widget> errorActions;

  /// Diisi penampil: cara membuat PDF siap cetak (tombol Cetak).
  final PrintController? printController;
  const SheetDocView({super.key, required this.path, this.csv = false, this.initialQuery = '', this.trailing = const [], this.errorActions = const [], this.printController});

  @override
  State<SheetDocView> createState() => _SheetDocViewState();
}

class _SheetDocViewState extends State<SheetDocView> {
  WorkbookData? _wb;
  Object? _error;
  int _sheet = 0;
  double _zoom = 1;
  RegExp? _re;
  String _query = '';
  final _matches = <(int, int)>[]; // (baris, kolom)
  int _active = -1;
  final _v = ScrollController();
  final _h = ScrollController();
  final _findFocus = FocusNode();
  final _searchKey = GlobalKey();

  static const _baseRowH = 24.0;
  static const _baseRowNumW = 52.0;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    widget.printController?.buildPdf = _buildPdf;
    _load();
  }

  @override
  void dispose() {
    _v.dispose();
    _h.dispose();
    _findFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      final name = widget.path.split(RegExp(r'[\\/]')).last;
      final csv = widget.csv;
      // Fungsi top-level: tidak membawa halaman (State) ke proses latar.
      final wb = await compute(_parseSheet, (bytes, name, csv));
      if (!mounted) return;
      setState(() => _wb = wb);
      if (_query.trim().isNotEmpty) _search(_query, jumpSheet: true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Cetak sheet yang sedang dibuka sebagai tabel PDF (A4 mendatar).
  Future<String> _buildPdf() async {
    final s = _cur;
    if (s == null) throw Exception('Data belum selesai dimuat.');
    final title = widget.path.split(RegExp(r'[\\/]')).last;
    final bytes = await compute(_sheetPdf, (s, title));
    return writeTempPdf(bytes, s.name == title ? title : '$title - ${s.name}');
  }

  SheetData? get _cur => _wb == null || _wb!.sheets.isEmpty ? null : _wb!.sheets[_sheet];

  void _collect() {
    _matches.clear();
    final s = _cur;
    if (s == null || _re == null) return;
    for (var r = 0; r < s.rows.length; r++) {
      final row = s.rows[r];
      for (var c = 0; c < row.length; c++) {
        final cell = row[c];
        if (cell != null && cell.text.isNotEmpty && _re!.hasMatch(cell.text)) _matches.add((r, c));
      }
    }
  }

  /// Cari di sheet aktif; kalau tidak ada dan [jumpSheet], pindah ke sheet pertama yang cocok.
  void _search(String q, {bool jumpSheet = false}) {
    _query = q;
    _re = buildSearchPattern(q);
    _collect();
    if (_matches.isEmpty && jumpSheet && _re != null && _wb != null) {
      for (var i = 0; i < _wb!.sheets.length; i++) {
        if (i == _sheet) continue;
        _sheet = i;
        _collect();
        if (_matches.isNotEmpty) break;
      }
      if (_matches.isEmpty) {
        _sheet = 0;
        _collect();
      }
    }
    _active = _matches.isEmpty ? -1 : 0;
    setState(() {});
    _reveal();
  }

  void _step(int d) {
    if (_matches.isEmpty) return;
    setState(() => _active = (_active + d) % _matches.length);
    _reveal();
  }

  void _reveal() {
    if (_active < 0 || _active >= _matches.length) return;
    final (r, c) = _matches[_active];
    final s = _cur!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_v.hasClients) {
        final y = r * _baseRowH * _zoom;
        final vp = _v.position.viewportDimension;
        if (y < _v.offset || y > _v.offset + vp - _baseRowH * _zoom * 2) {
          _v.animateTo((y - vp * 0.35).clamp(0.0, _v.position.maxScrollExtent), duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      }
      if (_h.hasClients) {
        var x = _baseRowNumW * _zoom;
        for (var i = 0; i < c && i < s.colWidths.length; i++) {
          x += s.colWidths[i] * _zoom;
        }
        final vp = _h.position.viewportDimension;
        final w = (c < s.colWidths.length ? s.colWidths[c] : 64) * _zoom;
        if (x < _h.offset || x + w > _h.offset + vp) {
          _h.animateTo((x - 80).clamp(0.0, _h.position.maxScrollExtent), duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      }
    });
  }

  void _selectSheet(int i) {
    setState(() {
      _sheet = i;
      _collect();
      _active = _matches.isEmpty ? -1 : 0;
    });
    if (_v.hasClients) _v.jumpTo(0);
    if (_h.hasClients) _h.jumpTo(0);
    _reveal();
  }

  void _zoomBy(bool up) => setState(() => _zoom = (up ? zoomStepUp(_zoom) : zoomStepDown(_zoom)).clamp(0.5, 2.5).toDouble());

  @override
  Widget build(BuildContext context) {
    final s = _cur;
    return ViewerShortcuts(
      onFind: () => _findFocus.requestFocus(),
      onZoomIn: () => _zoomBy(true),
      onZoomOut: () => _zoomBy(false),
      onZoomReset: () => setState(() => _zoom = 1),
      child: Column(children: [
        ViewerToolbar(
          leading: [
            Icon(widget.csv ? Icons.table_rows_rounded : Icons.grid_on_rounded, size: 18, color: const Color(0xFF1D6F42)),
            const SizedBox(width: 6),
            ToolLabel(s == null ? (widget.csv ? 'Data CSV' : 'Lembar kerja Excel') : '${s.rows.length} baris • ${s.colCount} kolom'),
            const ToolDivider(),
            ZoomControls(zoom: _zoom, onZoomIn: () => _zoomBy(true), onZoomOut: () => _zoomBy(false), onFitWidth: () => setState(() => _zoom = 1)),
          ],
          search: DocSearchBox(
            key: _searchKey,
            initial: widget.initialQuery,
            focusNode: _findFocus,
            onSearch: (q) => _search(q, jumpSheet: true),
            onNext: () => _step(1),
            onPrev: () => _step(-1),
            current: _active,
            total: _matches.length,
          ),
          trailing: widget.trailing,
        ),
        Expanded(child: _body(s)),
        if (_wb != null && _wb!.sheets.length > 1) _tabs(),
      ]),
    );
  }

  Widget _tabs() {
    return Container(
      height: 36,
      decoration: const BoxDecoration(color: Color(0xFFF3F3F3), border: Border(top: BorderSide(color: Color(0xFFD0D0D0)))),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _wb!.sheets.length,
        itemBuilder: (context, i) {
          final sel = i == _sheet;
          return InkWell(
            onTap: () => _selectSheet(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? Colors.white : null,
                border: Border(
                  right: const BorderSide(color: Color(0xFFD0D0D0)),
                  bottom: BorderSide(color: sel ? const Color(0xFF1D6F42) : Colors.transparent, width: 3),
                ),
              ),
              child: Text(_wb!.sheets[i].name,
                  style: TextStyle(fontSize: 12.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? const Color(0xFF1D6F42) : YmColors.textDark)),
            ),
          );
        },
      ),
    );
  }

  Widget _body(SheetData? s) {
    if (_error != null) {
      return ViewerMessage(
        icon: Icons.grid_on_rounded,
        title: 'File ${widget.csv ? 'CSV' : 'Excel'} tidak bisa ditampilkan',
        message: 'File mungkin rusak, dikunci password, atau bukan format ${widget.csv ? '.csv' : '.xlsx'}.\n$_error',
        actions: widget.errorActions,
      );
    }
    if (_wb == null) return Container(color: kViewerBackground, alignment: Alignment.center, child: const CircularProgressIndicator());
    if (s == null || s.rows.isEmpty) {
      return const ViewerMessage(icon: Icons.grid_off_rounded, title: 'Sheet kosong', message: 'Tidak ada data di sheet ini.');
    }
    final z = _zoom;
    final rowH = _baseRowH * z;
    final rowNumW = _baseRowNumW * z;
    final fs = 12.5 * z;
    final widths = s.colWidths.map((w) => w * z).toList();
    final total = rowNumW + widths.fold<double>(0, (a, b) => a + b);
    final activeCell = _active >= 0 && _active < _matches.length ? _matches[_active] : null;
    final matchSet = {for (final m in _matches) m.$1 * 100000 + m.$2};
    const grid = BorderSide(color: Color(0xFFDADCE0), width: 0.7);
    const headBg = Color(0xFFF1F3F4);

    Widget headCell(String t, double w, {bool right = false}) => Container(
          width: w,
          height: rowH,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: headBg, border: Border(right: grid, bottom: grid)),
          child: Text(t, style: TextStyle(fontSize: fs * 0.92, color: const Color(0xFF5F6368), fontWeight: FontWeight.w600)),
        );

    return Container(
      color: Colors.white,
      child: Column(children: [
        if (s.truncated)
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF4E5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text('Data sangat besar: ditampilkan maksimal $maxSheetRows baris × $maxSheetCols kolom. Buka dengan Excel untuk melihat semuanya.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A00))),
          ),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            return Scrollbar(
              controller: _h,
              thumbVisibility: true,
              notificationPredicate: (n) => n.depth == 0,
              child: SingleChildScrollView(
                controller: _h,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: total < c.maxWidth ? c.maxWidth : total,
                  height: c.maxHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // kepala kolom A B C ...
                      Row(children: [
                        headCell('', rowNumW),
                        for (var i = 0; i < s.colCount; i++)
                          if (widths[i] > 0) headCell(colName(i), widths[i]),
                      ]),
                      Expanded(
                        child: Scrollbar(
                          controller: _v,
                          thumbVisibility: true,
                          child: SelectionArea(
                            child: ListView.builder(
                              controller: _v,
                              itemExtent: rowH,
                              itemCount: s.rows.length,
                              itemBuilder: (context, r) {
                                final row = s.rows[r];
                                final cells = <Widget>[headCell('${r + 1}', rowNumW)];
                                var skip = 0;
                                for (var col = 0; col < s.colCount; col++) {
                                  if (skip > 0) {
                                    skip--;
                                    continue;
                                  }
                                  if (s.covered.contains(r * 100000 + col)) {
                                    // tertutup sel gabung dari kiri (sudah dilebarkan)
                                    continue;
                                  }
                                  final cell = col < row.length ? row[col] : null;
                                  var w = widths[col];
                                  if (cell != null && cell.colSpan > 1) {
                                    for (var k = 1; k < cell.colSpan && col + k < s.colCount; k++) {
                                      w += widths[col + k];
                                    }
                                    skip = cell.colSpan - 1;
                                  }
                                  if (w <= 0) continue;
                                  final key = r * 100000 + col;
                                  final isMatch = matchSet.contains(key);
                                  final isActive = activeCell != null && activeCell.$1 == r && activeCell.$2 == col;
                                  final style = TextStyle(
                                    fontSize: fs,
                                    fontFamily: 'Calibri',
                                    fontFamilyFallback: const ['Segoe UI', 'Arial'],
                                    fontWeight: cell?.bold == true ? FontWeight.w700 : FontWeight.w400,
                                    color: cell?.color ?? Colors.black,
                                  );
                                  cells.add(Container(
                                    width: w,
                                    height: rowH,
                                    padding: EdgeInsets.symmetric(horizontal: 5 * z),
                                    alignment: cell == null
                                        ? Alignment.centerLeft
                                        : cell.alignCenter
                                            ? Alignment.center
                                            : (cell.alignRight ? Alignment.centerRight : Alignment.centerLeft),
                                    decoration: BoxDecoration(
                                      color: isActive ? kActiveMatchColor.withOpacity(0.35) : (isMatch ? kMatchColor.withOpacity(0.45) : cell?.fill),
                                      border: isActive
                                          ? Border.all(color: kActiveMatchColor, width: 2)
                                          : const Border(right: grid, bottom: grid),
                                    ),
                                    child: cell == null || cell.text.isEmpty
                                        ? null
                                        : _maybeTip(
                                            cell.text,
                                            Text.rich(
                                              TextSpan(children: highlightSpans(cell.text.replaceAll('\n', ' '), style, isMatch ? _re : null)),
                                              maxLines: 1,
                                              overflow: TextOverflow.clip,
                                              softWrap: false,
                                            ),
                                          ),
                                  ));
                                }
                                return Row(children: cells);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }

  /// Isi sel yang panjang ditampilkan lengkap saat mouse diarahkan.
  Widget _maybeTip(String text, Widget child) =>
      text.length > 30 ? Tooltip(message: text, waitDuration: const Duration(milliseconds: 600), child: child) : child;
}

/// Dijalankan di proses latar (isolate). Harus fungsi top-level supaya yang
/// dikirim hanya isi file, bukan widget/halaman.
WorkbookData _parseSheet((Uint8List, String, bool) job) {
  final (bytes, name, csv) = job;
  return csv ? SheetParser.parseCsv(bytes, name) : SheetParser.parseXlsx(bytes);
}

/// Proses latar: tabel -> PDF (fungsi top-level, lihat _parseSheet).
Future<Uint8List> _sheetPdf((SheetData, String) job) => pdfFromSheet(job.$1, job.$2, PdfFonts.load());
