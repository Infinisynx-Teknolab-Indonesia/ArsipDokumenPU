import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import '../print/pdf_builder.dart';
import '../print/print_dialog.dart';
import 'sheet_parser.dart';
import 'viewer_common.dart';

/// Penampil file teks (.txt, .log, .md, .json, .xml) di dalam aplikasi.
class TextDocView extends StatefulWidget {
  final String path;
  final String initialQuery;
  final List<Widget> trailing;
  final List<Widget> errorActions;

  /// Diisi penampil: cara membuat PDF siap cetak (tombol Cetak).
  final PrintController? printController;
  const TextDocView({super.key, required this.path, this.initialQuery = '', this.trailing = const [], this.errorActions = const [], this.printController});

  @override
  State<TextDocView> createState() => _TextDocViewState();
}

class _TextDocViewState extends State<TextDocView> {
  static const _maxBytes = 5 * 1024 * 1024;
  static const _chunkLines = 120;

  List<String>? _chunks;
  int _lines = 0;
  bool _truncated = false;
  Object? _error;
  double _zoom = 1;
  bool _wrap = true;
  RegExp? _re;
  int _total = 0;
  int _active = -1;
  final _ranges = <(int, int, int)>[]; // (awal, akhir, potongan)
  final _keys = <int, GlobalKey>{};
  final _v = ScrollController();
  final _findFocus = FocusNode();
  final _searchKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.printController?.buildPdf = _buildPdf;
    _load();
  }

  Future<String> _buildPdf() async {
    final ch = _chunks;
    if (ch == null) throw Exception('File teks belum selesai dimuat.');
    final title = widget.path.split(RegExp(r'[\\/]')).last;
    final bytes = await compute(_textPdf, (ch.join('\n'), title));
    return writeTempPdf(bytes, title);
  }

  @override
  void dispose() {
    _v.dispose();
    _findFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final f = File(widget.path);
      final len = await f.length();
      final raf = await f.open();
      final bytes = await raf.read(len > _maxBytes ? _maxBytes : len);
      await raf.close();
      var text = SheetParser.decodeText(Uint8List.fromList(bytes)).replaceAll('\r\n', '\n');
      if (text.startsWith('﻿')) text = text.substring(1);
      final lines = text.split('\n');
      final chunks = <String>[];
      for (var i = 0; i < lines.length; i += _chunkLines) {
        chunks.add(lines.sublist(i, i + _chunkLines > lines.length ? lines.length : i + _chunkLines).join('\n'));
      }
      if (!mounted) return;
      setState(() {
        _chunks = chunks;
        _lines = lines.length;
        _truncated = len > _maxBytes;
      });
      if (widget.initialQuery.trim().isNotEmpty) _search(widget.initialQuery);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _search(String q) {
    _re = buildSearchPattern(q);
    _ranges.clear();
    _total = 0;
    _active = -1;
    final ch = _chunks;
    if (ch != null && _re != null) {
      for (var i = 0; i < ch.length; i++) {
        final n = _re!.allMatches(ch[i]).where((m) => m.end > m.start).length;
        if (n > 0) {
          _ranges.add((_total, _total + n, i));
          _total += n;
        }
      }
      if (_total > 0) _active = 0;
    }
    setState(() {});
    _reveal();
  }

  void _step(int d) {
    if (_total == 0) return;
    setState(() => _active = (_active + d) % _total);
    _reveal();
  }

  void _reveal() {
    if (_active < 0) return;
    int? chunk;
    for (final r in _ranges) {
      if (_active >= r.$1 && _active < r.$2) chunk = r.$3;
    }
    if (chunk == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[chunk]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.2, duration: const Duration(milliseconds: 200));
    });
  }

  void _zoomBy(bool up) => setState(() => _zoom = (up ? zoomStepUp(_zoom) : zoomStepDown(_zoom)).clamp(0.5, 3.0).toDouble());

  @override
  Widget build(BuildContext context) {
    return ViewerShortcuts(
      onFind: () => _findFocus.requestFocus(),
      onZoomIn: () => _zoomBy(true),
      onZoomOut: () => _zoomBy(false),
      onZoomReset: () => setState(() => _zoom = 1),
      child: Column(children: [
        ViewerToolbar(
          leading: [
            const Icon(Icons.article_rounded, size: 18, color: Color(0xFF5F6368)),
            const SizedBox(width: 6),
            ToolLabel(_chunks == null ? 'File teks' : '$_lines baris'),
            const ToolDivider(),
            ZoomControls(zoom: _zoom, onZoomIn: () => _zoomBy(true), onZoomOut: () => _zoomBy(false)),
            ToolButton(icon: Icons.wrap_text_rounded, tooltip: _wrap ? 'Matikan potong baris' : 'Potong baris panjang', selected: _wrap, onPressed: () => setState(() => _wrap = !_wrap)),
          ],
          search: DocSearchBox(
            key: _searchKey,
            initial: widget.initialQuery,
            focusNode: _findFocus,
            onSearch: _search,
            onNext: () => _step(1),
            onPrev: () => _step(-1),
            current: _active,
            total: _total,
          ),
          trailing: widget.trailing,
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_error != null) {
      return ViewerMessage(icon: Icons.article_rounded, title: 'File teks tidak bisa dibaca', message: '$_error', actions: widget.errorActions);
    }
    final ch = _chunks;
    if (ch == null) return Container(color: kViewerBackground, alignment: Alignment.center, child: const CircularProgressIndicator());
    final style = TextStyle(fontFamily: 'Consolas', fontFamilyFallback: const ['Courier New', 'monospace'], fontSize: 13 * _zoom, height: 1.45, color: Colors.black87);
    final counter = MatchCounter(_active);
    final parts = <Widget>[];
    for (var i = 0; i < ch.length; i++) {
      final start = counter.count;
      final spans = highlightSpans(ch[i], style, _re, counter: counter);
      final key = counter.count > start ? _keys.putIfAbsent(i, () => GlobalKey()) : null;
      parts.add(Text.rich(TextSpan(children: spans), key: key, softWrap: _wrap));
    }
    Widget content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: parts);
    if (!_wrap) {
      content = SingleChildScrollView(scrollDirection: Axis.horizontal, child: content);
    }
    return Container(
      color: Colors.white,
      child: Column(children: [
        if (_truncated)
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF4E5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: const Text('File sangat besar: yang ditampilkan hanya 5 MB pertama.', style: TextStyle(fontSize: 12, color: Color(0xFF8A5A00))),
          ),
        Expanded(
          child: Scrollbar(
            controller: _v,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _v,
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: SelectionArea(child: content),
            ),
          ),
        ),
      ]),
    );
  }
}

Future<Uint8List> _textPdf((String, String) job) => pdfFromText(job.$1, job.$2, PdfFonts.load());
