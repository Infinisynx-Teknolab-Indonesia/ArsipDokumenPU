import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'docx_parser.dart';
import 'viewer_common.dart';

/// Penampil Word (.docx) di dalam aplikasi: halaman putih seperti di Word,
/// zoom, cari teks dengan sorotan, pilih & salin teks.
class DocxDocView extends StatefulWidget {
  final String path;
  final String initialQuery;
  final List<Widget> trailing;
  final List<Widget> errorActions;
  const DocxDocView({super.key, required this.path, this.initialQuery = '', this.trailing = const [], this.errorActions = const []});

  @override
  State<DocxDocView> createState() => _DocxDocViewState();
}

class _DocxDocViewState extends State<DocxDocView> {
  DocxModel? _model;
  Object? _error;
  double _zoom = 1;
  bool _fit = true;
  RegExp? _re;
  int _active = -1;
  int _total = 0;
  final _ranges = <(int, int, int)>[]; // (hasil awal, hasil akhir, id paragraf)
  final _paraKeys = <int, GlobalKey>{};
  final _v = ScrollController();
  final _h = ScrollController();
  final _findFocus = FocusNode();
  final _searchKey = GlobalKey();
  double _lastFitZoom = 1;

  @override
  void initState() {
    super.initState();
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
      // Fungsi top-level: tidak membawa halaman (State) ke proses latar.
      final model = await compute(_parseDocx, bytes);
      if (!mounted) return;
      setState(() => _model = model);
      if (widget.initialQuery.trim().isNotEmpty) _search(widget.initialQuery);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  // ------------------------------------------------------------ cari

  void _search(String q) {
    final m = _model;
    _re = buildSearchPattern(q);
    _ranges.clear();
    _total = 0;
    _active = -1;
    if (m != null && _re != null) {
      void walk(List<DocxBlock> blocks) {
        for (final b in blocks) {
          if (b is DocxPara) {
            final start = _total;
            for (final r in b.inlines) {
              if (r is DocxRun) _total += _re!.allMatches(_displayText(r)).where((x) => x.end > x.start).length;
            }
            if (_total > start) _ranges.add((start, _total, b.id));
            walk(b.attached);
          } else if (b is DocxTable) {
            for (final row in b.rows) {
              for (final c in row.cells) {
                walk(c.blocks);
              }
            }
          }
        }
      }

      walk(m.blocks);
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
    int? para;
    for (final r in _ranges) {
      if (_active >= r.$1 && _active < r.$2) {
        para = r.$3;
        break;
      }
    }
    if (para == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _paraKeys[para]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  // ------------------------------------------------------------ zoom

  void _zoomBy(bool up) => setState(() {
        final base = _fit ? _lastFitZoom : _zoom;
        _zoom = up ? zoomStepUp(base) : zoomStepDown(base);
        _fit = false;
      });

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent && HardwareKeyboard.instance.isControlPressed) {
      GestureBinding.instance.pointerSignalResolver.register(e, (ev) {
        _zoomBy((ev as PointerScrollEvent).scrollDelta.dy < 0);
      });
    }
  }

  // ------------------------------------------------------------ tampilan

  @override
  Widget build(BuildContext context) {
    final m = _model;
    return ViewerShortcuts(
      onFind: () => _findFocus.requestFocus(),
      onZoomIn: () => _zoomBy(true),
      onZoomOut: () => _zoomBy(false),
      onZoomReset: () => setState(() => _fit = true),
      child: Column(children: [
        ViewerToolbar(
          leading: [
            const Icon(Icons.description_rounded, size: 18, color: Color(0xFF2B579A)),
            const SizedBox(width: 6),
            ToolLabel(m == null ? 'Dokumen Word' : 'Dokumen Word • ${_pageCount(m)} halaman'),
            const ToolDivider(),
            ZoomControls(
              zoom: _fit ? _lastFitZoom : _zoom,
              onZoomIn: () => _zoomBy(true),
              onZoomOut: () => _zoomBy(false),
              onFitWidth: () => setState(() => _fit = true),
              fitSelected: _fit,
            ),
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
        Expanded(child: _body(m)),
      ]),
    );
  }

  int _pageCount(DocxModel m) => 1 + m.blocks.whereType<DocxPageBreak>().length;

  Widget _body(DocxModel? m) {
    if (_error != null) {
      return ViewerMessage(
        icon: Icons.description_rounded,
        title: 'Dokumen Word tidak bisa ditampilkan',
        message: 'File mungkin rusak, dikunci password, atau bukan format .docx.\n$_error',
        actions: widget.errorActions,
      );
    }
    if (m == null) {
      return Container(color: kViewerBackground, alignment: Alignment.center, child: const CircularProgressIndicator());
    }
    // Bagi isi menjadi halaman di setiap pemisah halaman.
    final pages = <List<DocxBlock>>[[]];
    for (final b in m.blocks) {
      if (b is DocxPageBreak) {
        pages.add([]);
      } else {
        pages.last.add(b);
      }
    }
    if (pages.length > 1 && pages.last.isEmpty) pages.removeLast();
    final counter = MatchCounter(_active);
    final sheets = <Widget>[];
    for (var i = 0; i < pages.length; i++) {
      if (i > 0) sheets.add(const SizedBox(height: 18));
      sheets.add(Container(
        width: m.pageWidth,
        constraints: BoxConstraints(minHeight: m.pageHeight),
        padding: EdgeInsets.fromLTRB(m.marginLeft, m.marginTop, m.marginRight, m.marginBottom),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _blockList(pages[i], counter)),
      ));
    }
    final doc = Column(mainAxisSize: MainAxisSize.min, children: sheets);

    return Container(
      color: kViewerBackground,
      child: LayoutBuilder(builder: (context, c) {
        final fitZoom = ((c.maxWidth - 48) / m.pageWidth).clamp(0.3, 2.0).toDouble();
        if ((fitZoom - _lastFitZoom).abs() > 0.001) {
          _lastFitZoom = fitZoom;
          if (_fit) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          }
        }
        final z = _fit ? fitZoom : _zoom;
        return Scrollbar(
          controller: _v,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _v,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Scrollbar(
              controller: _h,
              notificationPredicate: (n) => n.depth == 0,
              child: SingleChildScrollView(
                controller: _h,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: c.maxWidth),
                  child: Center(
                    child: Listener(
                      onPointerSignal: _onPointerSignal,
                      child: SelectionArea(
                        child: SizedBox(
                          width: m.pageWidth * z,
                          child: FittedBox(
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.topCenter,
                            child: SizedBox(width: m.pageWidth, child: doc),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  List<Widget> _blockList(List<DocxBlock> blocks, MatchCounter counter) {
    final out = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (b is DocxPara) {
        // "Jangan beri spasi antar paragraf dengan style yang sama" (daftar).
        var before = b.before, after = b.after;
        if (b.contextualSpacing) {
          final prev = i > 0 ? blocks[i - 1] : null;
          final next = i + 1 < blocks.length ? blocks[i + 1] : null;
          if (prev is DocxPara && prev.styleId == b.styleId) before = 0;
          if (next is DocxPara && next.styleId == b.styleId) after = 0;
        }
        out.add(_para(b, counter, before, after));
        if (b.attached.isNotEmpty) {
          out.add(Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFB0B0B0))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _blockList(b.attached, counter)),
          ));
        }
      } else if (b is DocxTable) {
        out.add(_table(b, counter));
      }
    }
    return out;
  }

  String _displayText(DocxRun r) => r.text.replaceAll('\t', '      ');

  double? _lineHeight(DocxPara p, double fontSize) {
    if (p.lineExactPx != null && fontSize > 0) return (p.lineExactPx! / fontSize).clamp(0.8, 4.0).toDouble();
    final m = p.lineMult;
    if (m == null || (m - 1).abs() < 0.04) return null;
    return (1.2 * m).clamp(0.8, 5.0).toDouble();
  }

  TextStyle _style(DocxRun r, DocxPara p) {
    final deco = <TextDecoration>[
      if (r.underline) TextDecoration.underline,
      if (r.strike) TextDecoration.lineThrough,
    ];
    return TextStyle(
      fontFamily: r.fontFamily,
      fontFamilyFallback: const ['Calibri', 'Arial', 'Segoe UI'],
      fontSize: r.sizePx,
      fontWeight: r.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: r.italic ? FontStyle.italic : FontStyle.normal,
      decoration: deco.isEmpty ? TextDecoration.none : TextDecoration.combine(deco),
      color: r.color ?? Colors.black,
      backgroundColor: r.highlight,
      height: _lineHeight(p, r.sizePx),
    );
  }

  Widget _para(DocxPara p, MatchCounter counter, double before, double after) {
    final startCount = counter.count;
    final spans = <InlineSpan>[];
    if (p.firstLine > 0 && p.numberLabel.isEmpty) spans.add(WidgetSpan(child: SizedBox(width: p.firstLine)));
    var hasText = false;
    for (final inl in p.inlines) {
      if (inl is DocxRun) {
        final t = _displayText(inl);
        if (t.isEmpty) continue;
        hasText = true;
        spans.addAll(highlightSpans(t, _style(inl, p), _re, counter: counter));
      } else if (inl is DocxImage) {
        hasText = true;
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.bottom,
          child: Image.memory(
            inl.bytes,
            width: inl.width,
            height: inl.height,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => Container(
              width: inl.width,
              height: inl.height,
              color: const Color(0xFFF1F1F4),
              alignment: Alignment.center,
              child: Text('[gambar ${inl.name}]', style: const TextStyle(fontSize: 11, color: Colors.black45)),
            ),
          ),
        ));
      }
    }
    if (!hasText) {
      spans.add(TextSpan(
        text: '​',
        style: TextStyle(fontSize: p.fontSizePx, fontFamily: p.fontFamily, height: _lineHeight(p, p.fontSizePx)),
      ));
    }
    final align = switch (p.align) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      'both' => TextAlign.justify,
      _ => TextAlign.left,
    };
    Widget w = Text.rich(TextSpan(children: spans), textAlign: align);
    var left = p.indentLeft;
    if (p.numberLabel.isNotEmpty) {
      final ns = p.numberStyle;
      final labelStyle = ns == null ? const TextStyle(color: Colors.black) : _style(ns, p).copyWith(backgroundColor: null);
      final hang = p.hanging > 0 ? p.hanging : 24.0;
      left = (p.indentLeft - hang) < 0 ? 0 : p.indentLeft - hang;
      w = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: hang),
          child: Padding(padding: const EdgeInsets.only(right: 4), child: Text(p.numberLabel, style: labelStyle)),
        ),
        Expanded(child: w),
      ]);
    }
    if (left < 0) left = 0;
    final key = counter.count > startCount ? _paraKeys.putIfAbsent(p.id, () => GlobalKey()) : null;
    return Container(
      key: key,
      margin: EdgeInsets.only(top: before, bottom: after),
      padding: EdgeInsets.only(left: left, right: p.indentRight, bottom: p.borderBottom ? 3 : 0),
      decoration: p.shading == null && !p.borderBottom
          ? null
          : BoxDecoration(
              color: p.shading,
              border: p.borderBottom ? const Border(bottom: BorderSide(color: Colors.black54, width: 0.8)) : null,
            ),
      child: w,
    );
  }

  Widget _table(DocxTable t, MatchCounter counter) {
    const line = BorderSide(color: Color(0xFF8C8C8C), width: 0.6);
    final rows = <Widget>[];
    for (final r in t.rows) {
      rows.add(IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in r.cells)
              Container(
                width: c.width,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: c.shading,
                  border: t.borders
                      ? Border(
                          left: line,
                          right: line,
                          top: c.mergedFromAbove ? BorderSide.none : line,
                          bottom: c.mergedBelow ? BorderSide.none : line,
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: switch (c.vAlign) {
                    'center' => MainAxisAlignment.center,
                    'bottom' => MainAxisAlignment.end,
                    _ => MainAxisAlignment.start,
                  },
                  children: _blockList(c.blocks, counter),
                ),
              ),
          ],
        ),
      ));
    }
    final table = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: rows);
    return Padding(
      padding: EdgeInsets.only(left: t.indent, top: 2, bottom: 6),
      child: Align(
        alignment: switch (t.align) {
          'center' => Alignment.topCenter,
          'right' => Alignment.topRight,
          _ => Alignment.topLeft,
        },
        child: table,
      ),
    );
  }
}

/// Dijalankan di proses latar (isolate). Harus fungsi top-level supaya yang
/// dikirim hanya isi file, bukan widget/halaman.
DocxModel _parseDocx(Uint8List bytes) => DocxParser.parseBytes(bytes);
