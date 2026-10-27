import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Pembaca file Word (.docx) menjadi model sederhana untuk ditampilkan di
/// aplikasi tanpa Microsoft Word / WPS. Murni Dart, berjalan di isolate.
///
/// Yang didukung: paragraf + style (Judul/Heading, Normal, dst.), tebal,
/// miring, garis bawah, coret, ukuran & jenis huruf, warna, stabilo, rata
/// kiri/tengah/kanan/justify, indentasi, spasi, daftar bernomor/berpoin,
/// tabel (gabung kolom, gabung baris, warna sel, tabel di dalam tabel),
/// gambar, kotak teks, rumus (sebagai teks), pemisah halaman.

// ---------------------------------------------------------------- model

class DocxModel {
  final List<DocxBlock> blocks;
  final double pageWidth; // px (96 dpi)
  final double pageHeight;
  final double marginLeft, marginRight, marginTop, marginBottom;
  final int paragraphCount;
  final List<String> warnings;
  DocxModel({
    required this.blocks,
    required this.pageWidth,
    required this.pageHeight,
    required this.marginLeft,
    required this.marginRight,
    required this.marginTop,
    required this.marginBottom,
    required this.paragraphCount,
    required this.warnings,
  });

  double get contentWidth => pageWidth - marginLeft - marginRight;
}

abstract class DocxBlock {}

class DocxPageBreak extends DocxBlock {}

class DocxPara extends DocxBlock {
  final int id; // urutan paragraf (untuk lompat ke hasil pencarian)
  final List<DocxInline> inlines;
  final String align; // left|center|right|both
  final double before, after; // px
  final double? lineMult; // pengali spasi baris (1 = tunggal)
  final double? lineExactPx;
  final double indentLeft, indentRight, firstLine, hanging; // px
  final String numberLabel; // "1.", "a)", "•" ...
  final DocxRun? numberStyle;
  final Color? shading;
  final bool borderBottom;
  final String styleId;
  final bool contextualSpacing;
  final double fontSizePx; // ukuran huruf dasar (untuk paragraf kosong)
  final String fontFamily;
  final List<DocxBlock> attached; // isi kotak teks yang menempel di paragraf ini
  DocxPara({
    required this.id,
    required this.inlines,
    required this.align,
    required this.before,
    required this.after,
    required this.lineMult,
    required this.lineExactPx,
    required this.indentLeft,
    required this.indentRight,
    required this.firstLine,
    required this.hanging,
    required this.numberLabel,
    required this.numberStyle,
    required this.shading,
    required this.borderBottom,
    required this.styleId,
    required this.contextualSpacing,
    required this.fontSizePx,
    required this.fontFamily,
    required this.attached,
  });

  String get plainText => inlines.whereType<DocxRun>().map((r) => r.text).join();
}

abstract class DocxInline {}

class DocxRun extends DocxInline {
  final String text;
  final bool bold, italic, underline, strike;
  final double sizePx;
  final Color? color;
  final Color? highlight;
  final String fontFamily;
  final int vert; // 1 = superscript, -1 = subscript
  final bool link;
  DocxRun({
    required this.text,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strike,
    required this.sizePx,
    required this.color,
    required this.highlight,
    required this.fontFamily,
    required this.vert,
    this.link = false,
  });
}

class DocxImage extends DocxInline {
  final Uint8List bytes;
  final double width, height; // px
  final String name;
  DocxImage(this.bytes, this.width, this.height, this.name);
}

class DocxTable extends DocxBlock {
  final List<DocxRow> rows;
  final bool borders;
  final String align; // left|center|right
  final double indent;
  DocxTable(this.rows, this.borders, this.align, this.indent);
}

class DocxRow {
  final List<DocxCell> cells;
  DocxRow(this.cells);
}

class DocxCell {
  final List<DocxBlock> blocks;
  final double width; // px, sudah diskalakan
  final Color? shading;
  final String vAlign; // top|center|bottom
  final bool mergedFromAbove; // lanjutan gabung baris (isi kosong, tanpa garis atas)
  bool mergedBelow = false; // sel di bawahnya adalah lanjutan
  DocxCell({required this.blocks, required this.width, required this.shading, required this.vAlign, required this.mergedFromAbove});
}

// ---------------------------------------------------------------- helpers

String? _attr(XmlElement? e, String local) {
  if (e == null) return null;
  for (final a in e.attributes) {
    if (a.name.local == local) return a.value;
  }
  return null;
}

XmlElement? _child(XmlElement? e, String local) {
  if (e == null) return null;
  for (final c in e.childElements) {
    if (c.name.local == local) return c;
  }
  return null;
}

Iterable<XmlElement> _children(XmlElement? e, String local) =>
    e == null ? const <XmlElement>[] : e.childElements.where((c) => c.name.local == local);

Iterable<XmlElement> _descendants(XmlElement e, String local) =>
    e.descendants.whereType<XmlElement>().where((c) => c.name.local == local);

/// Nilai on/off Word: <w:b/> = true, <w:b w:val="0"/> = false.
bool? _onOff(XmlElement? e) {
  if (e == null) return null;
  final v = _attr(e, 'val');
  if (v == null) return true;
  return !(v == '0' || v == 'false' || v == 'off' || v == 'none');
}

double? _num(String? v) => v == null ? null : double.tryParse(v.trim());
double _twipsToPx(double t) => t / 15.0; // 1440 twips = 1 inch = 96 px
double _halfPtToPx(double hp) => hp * 2 / 3; // (hp/2) pt * 96/72

Color? _hexColor(String? v) {
  if (v == null) return null;
  final h = v.trim();
  if (h.isEmpty || h.toLowerCase() == 'auto') return null;
  final n = int.tryParse(h, radix: 16);
  if (n == null || h.length != 6) return null;
  return Color(0xFF000000 | n);
}

const _highlightColors = <String, int>{
  'yellow': 0xFFFFFF00,
  'green': 0xFF00FF00,
  'cyan': 0xFF00FFFF,
  'magenta': 0xFFFF00FF,
  'blue': 0xFF0000FF,
  'red': 0xFFFF0000,
  'darkBlue': 0xFF000080,
  'darkCyan': 0xFF008080,
  'darkGreen': 0xFF008000,
  'darkMagenta': 0xFF800080,
  'darkRed': 0xFF800000,
  'darkYellow': 0xFF808000,
  'darkGray': 0xFF808080,
  'lightGray': 0xFFC0C0C0,
  'black': 0xFF000000,
  'white': 0xFFFFFFFF,
};

List<int> _fileBytes(ArchiveFile f) => (f.content as List).cast<int>();

String _bytesToString(List<int> b) => utf8.decode(b, allowMalformed: true);

// ---------------------------------------------------------------- properti

class _RP {
  bool? b, i, u, strike, caps, vanish;
  double? sz; // half-points
  Color? color, hl;
  String? font;
  int? vert;

  _RP merged(_RP? o) {
    if (o == null) return this;
    return _RP()
      ..b = o.b ?? b
      ..i = o.i ?? i
      ..u = o.u ?? u
      ..strike = o.strike ?? strike
      ..caps = o.caps ?? caps
      ..vanish = o.vanish ?? vanish
      ..sz = o.sz ?? sz
      ..color = o.color ?? color
      ..hl = o.hl ?? hl
      ..font = o.font ?? font
      ..vert = o.vert ?? vert;
  }
}

class _PP {
  String? jc;
  double? before, after, line;
  String? lineRule;
  double? indL, indR, first, hanging;
  String? numId;
  int? ilvl;
  Color? shd;
  bool? borderBottom, pageBreakBefore, contextual;

  _PP merged(_PP? o) {
    if (o == null) return this;
    return _PP()
      ..jc = o.jc ?? jc
      ..before = o.before ?? before
      ..after = o.after ?? after
      ..line = o.line ?? line
      ..lineRule = o.line != null ? o.lineRule : lineRule
      ..indL = o.indL ?? indL
      ..indR = o.indR ?? indR
      ..first = o.first ?? (o.hanging != null ? null : first)
      ..hanging = o.hanging ?? (o.first != null ? null : hanging)
      ..numId = o.numId ?? numId
      ..ilvl = o.ilvl ?? ilvl
      ..shd = o.shd ?? shd
      ..borderBottom = o.borderBottom ?? borderBottom
      ..pageBreakBefore = o.pageBreakBefore ?? pageBreakBefore
      ..contextual = o.contextual ?? contextual;
  }
}

class _Style {
  final String id, type;
  final String? basedOn;
  final _PP? pp;
  final _RP? rp;
  final bool? tblBorders; // true = ada garis, false = tanpa garis, null = tidak diatur
  _Style(this.id, this.type, this.basedOn, this.pp, this.rp, this.tblBorders);
}

class _Lvl {
  final String fmt, text;
  final int start;
  final _PP? pp;
  final _RP? rp;
  _Lvl(this.fmt, this.text, this.start, this.pp, this.rp);
}

// ---------------------------------------------------------------- parser

class DocxParser {
  final Archive _zip;
  final _rels = <String, String>{};
  final _styles = <String, _Style>{};
  final _abstract = <String, Map<int, _Lvl>>{};
  final _numToAbstract = <String, String>{};
  final _counters = <String, List<int>>{};
  final _warnings = <String>[];
  String _defaultParaStyle = '';
  String _defaultTableStyle = '';
  _RP _defRP = _RP();
  _PP _defPP = _PP();
  String _minorFont = 'Calibri';
  String _majorFont = 'Calibri Light';
  int _paraId = 0;
  final _rpCache = <String, _RP>{};
  final _ppCache = <String, _PP>{};

  double _pageW = 794, _pageH = 1123, _mL = 96, _mR = 96, _mT = 96, _mB = 96;

  DocxParser._(this._zip);

  /// Dipanggil di isolate: bytes file .docx -> model.
  static DocxModel parseBytes(Uint8List bytes) {
    final zip = ZipDecoder().decodeBytes(bytes);
    return DocxParser._(zip)._parse();
  }

  XmlDocument? _xml(String path) {
    final f = _zip.findFile(path);
    if (f == null) return null;
    try {
      return XmlDocument.parse(_bytesToString(_fileBytes(f)));
    } catch (_) {
      _warnings.add('Bagian $path tidak terbaca.');
      return null;
    }
  }

  DocxModel _parse() {
    final doc = _xml('word/document.xml');
    if (doc == null) throw const FormatException('Bukan file Word (.docx) yang valid: word/document.xml tidak ada.');
    _loadRels();
    _loadTheme();
    _loadStyles();
    _loadNumbering();
    final body = _child(doc.rootElement, 'body');
    if (body == null) throw const FormatException('Isi dokumen kosong.');
    final sect = _child(body, 'sectPr');
    if (sect != null) _readSection(sect);
    final blocks = _blocks(body, _pageW - _mL - _mR);
    return DocxModel(
      blocks: blocks,
      pageWidth: _pageW,
      pageHeight: _pageH,
      marginLeft: _mL,
      marginRight: _mR,
      marginTop: _mT,
      marginBottom: _mB,
      paragraphCount: _paraId,
      warnings: _warnings,
    );
  }

  void _readSection(XmlElement sect) {
    final sz = _child(sect, 'pgSz');
    final w = _num(_attr(sz, 'w')), h = _num(_attr(sz, 'h'));
    if (w != null && w > 1000) _pageW = _twipsToPx(w);
    if (h != null && h > 1000) _pageH = _twipsToPx(h);
    final m = _child(sect, 'pgMar');
    double mm(String k, double def) {
      final v = _num(_attr(m, k));
      return v == null ? def : _twipsToPx(v).clamp(0, _pageW / 3).toDouble();
    }

    _mL = mm('left', _mL);
    _mR = mm('right', _mR);
    _mT = mm('top', _mT);
    _mB = mm('bottom', _mB);
  }

  void _loadRels() {
    final x = _xml('word/_rels/document.xml.rels');
    if (x == null) return;
    for (final r in x.rootElement.childElements) {
      final id = _attr(r, 'Id');
      final t = _attr(r, 'Target');
      final mode = _attr(r, 'TargetMode');
      if (id == null || t == null || mode == 'External') continue;
      _rels[id] = _resolvePath(t);
    }
  }

  String _resolvePath(String target) {
    if (target.startsWith('/')) return target.substring(1);
    final parts = <String>['word'];
    for (final p in target.split('/')) {
      if (p == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else if (p != '.' && p.isNotEmpty) {
        parts.add(p);
      }
    }
    return parts.join('/');
  }

  void _loadTheme() {
    final x = _xml('word/theme/theme1.xml');
    if (x == null) return;
    for (final e in _descendants(x.rootElement, 'majorFont')) {
      final latin = _child(e, 'latin');
      final tf = _attr(latin, 'typeface');
      if (tf != null && tf.isNotEmpty) _majorFont = tf;
    }
    for (final e in _descendants(x.rootElement, 'minorFont')) {
      final latin = _child(e, 'latin');
      final tf = _attr(latin, 'typeface');
      if (tf != null && tf.isNotEmpty) _minorFont = tf;
    }
  }

  _RP? _readRP(XmlElement? rPr) {
    if (rPr == null) return null;
    final r = _RP();
    for (final c in rPr.childElements) {
      switch (c.name.local) {
        case 'b':
          r.b = _onOff(c);
        case 'i':
          r.i = _onOff(c);
        case 'u':
          final v = _attr(c, 'val');
          r.u = v == null ? true : v != 'none';
        case 'strike':
        case 'dstrike':
          r.strike = _onOff(c);
        case 'caps':
          r.caps = _onOff(c);
        case 'vanish':
          r.vanish = _onOff(c);
        case 'sz':
          r.sz = _num(_attr(c, 'val'));
        case 'color':
          r.color = _hexColor(_attr(c, 'val'));
        case 'highlight':
          final v = _attr(c, 'val');
          final hc = v == null ? null : _highlightColors[v];
          if (hc != null) r.hl = Color(hc);
        case 'shd':
          r.hl ??= _hexColor(_attr(c, 'fill'));
        case 'vertAlign':
          final v = _attr(c, 'val');
          r.vert = v == 'superscript' ? 1 : (v == 'subscript' ? -1 : 0);
        case 'rFonts':
          final f = _attr(c, 'ascii') ?? _attr(c, 'hAnsi');
          if (f != null && f.isNotEmpty) {
            r.font = f;
          } else {
            final th = _attr(c, 'asciiTheme') ?? _attr(c, 'hAnsiTheme');
            if (th != null) r.font = th.startsWith('major') ? _majorFont : _minorFont;
          }
      }
    }
    return r;
  }

  _PP? _readPP(XmlElement? pPr) {
    if (pPr == null) return null;
    final p = _PP();
    for (final c in pPr.childElements) {
      switch (c.name.local) {
        case 'jc':
          final v = _attr(c, 'val');
          p.jc = switch (v) {
            'center' => 'center',
            'right' || 'end' => 'right',
            'both' || 'distribute' => 'both',
            _ => 'left',
          };
        case 'spacing':
          p.before = _num(_attr(c, 'before'));
          p.after = _num(_attr(c, 'after'));
          final line = _num(_attr(c, 'line'));
          if (line != null) {
            p.line = line;
            p.lineRule = _attr(c, 'lineRule') ?? 'auto';
          }
          if (_attr(c, 'beforeAutospacing') == '1') p.before ??= 280;
          if (_attr(c, 'afterAutospacing') == '1') p.after ??= 280;
        case 'ind':
          p.indL = _num(_attr(c, 'left') ?? _attr(c, 'start'));
          p.indR = _num(_attr(c, 'right') ?? _attr(c, 'end'));
          p.first = _num(_attr(c, 'firstLine'));
          p.hanging = _num(_attr(c, 'hanging'));
        case 'numPr':
          p.numId = _attr(_child(c, 'numId'), 'val');
          final l = _attr(_child(c, 'ilvl'), 'val');
          p.ilvl = l == null ? null : int.tryParse(l);
        case 'shd':
          p.shd = _hexColor(_attr(c, 'fill'));
        case 'pBdr':
          final b = _child(c, 'bottom');
          if (b != null) p.borderBottom = (_attr(b, 'val') ?? 'none') != 'none' && _attr(b, 'val') != 'nil';
        case 'pageBreakBefore':
          p.pageBreakBefore = _onOff(c);
        case 'contextualSpacing':
          p.contextual = _onOff(c);
      }
    }
    return p;
  }

  bool? _readBorders(XmlElement? tblBorders) {
    if (tblBorders == null) return null;
    var any = false;
    for (final b in tblBorders.childElements) {
      final v = _attr(b, 'val');
      if (v != null && v != 'none' && v != 'nil') any = true;
    }
    return any;
  }

  void _loadStyles() {
    final x = _xml('word/styles.xml');
    if (x == null) return;
    final root = x.rootElement;
    final dd = _child(root, 'docDefaults');
    if (dd != null) {
      _defRP = _readRP(_child(_child(dd, 'rPrDefault'), 'rPr')) ?? _RP();
      _defPP = _readPP(_child(_child(dd, 'pPrDefault'), 'pPr')) ?? _PP();
    }
    for (final s in _children(root, 'style')) {
      final id = _attr(s, 'styleId');
      if (id == null) continue;
      final type = _attr(s, 'type') ?? 'paragraph';
      if (_attr(s, 'default') == '1' || _attr(s, 'default') == 'true') {
        if (type == 'paragraph') _defaultParaStyle = id;
        if (type == 'table') _defaultTableStyle = id;
      }
      _styles[id] = _Style(
        id,
        type,
        _attr(_child(s, 'basedOn'), 'val'),
        _readPP(_child(s, 'pPr')),
        _readRP(_child(s, 'rPr')),
        _readBorders(_child(_child(s, 'tblPr'), 'tblBorders')),
      );
    }
  }

  _RP _styleRP(String? id, [int depth = 0]) {
    if (id == null || id.isEmpty || depth > 12) return _RP();
    final cached = _rpCache[id];
    if (cached != null) return cached;
    final s = _styles[id];
    if (s == null) return _RP();
    final r = _styleRP(s.basedOn, depth + 1).merged(s.rp);
    _rpCache[id] = r;
    return r;
  }

  _PP _stylePP(String? id, [int depth = 0]) {
    if (id == null || id.isEmpty || depth > 12) return _PP();
    final cached = _ppCache[id];
    if (cached != null) return cached;
    final s = _styles[id];
    if (s == null) return _PP();
    final p = _stylePP(s.basedOn, depth + 1).merged(s.pp);
    _ppCache[id] = p;
    return p;
  }

  bool? _styleBorders(String? id, [int depth = 0]) {
    if (id == null || id.isEmpty || depth > 12) return null;
    final s = _styles[id];
    if (s == null) return null;
    return s.tblBorders ?? _styleBorders(s.basedOn, depth + 1);
  }

  void _loadNumbering() {
    final x = _xml('word/numbering.xml');
    if (x == null) return;
    final root = x.rootElement;
    for (final a in _children(root, 'abstractNum')) {
      final id = _attr(a, 'abstractNumId');
      if (id == null) continue;
      final lv = <int, _Lvl>{};
      for (final l in _children(a, 'lvl')) {
        final il = int.tryParse(_attr(l, 'ilvl') ?? '') ?? 0;
        lv[il] = _Lvl(
          _attr(_child(l, 'numFmt'), 'val') ?? 'decimal',
          _attr(_child(l, 'lvlText'), 'val') ?? '',
          int.tryParse(_attr(_child(l, 'start'), 'val') ?? '') ?? 1,
          _readPP(_child(l, 'pPr')),
          _readRP(_child(l, 'rPr')),
        );
      }
      _abstract[id] = lv;
    }
    for (final n in _children(root, 'num')) {
      final id = _attr(n, 'numId');
      final abs = _attr(_child(n, 'abstractNumId'), 'val');
      if (id != null && abs != null) _numToAbstract[id] = abs;
    }
  }

  static String _roman(int n) {
    if (n <= 0 || n > 3999) return '$n';
    const v = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const s = ['m', 'cm', 'd', 'cd', 'c', 'xc', 'l', 'xl', 'x', 'ix', 'v', 'iv', 'i'];
    final b = StringBuffer();
    var x = n;
    for (var i = 0; i < v.length; i++) {
      while (x >= v[i]) {
        b.write(s[i]);
        x -= v[i];
      }
    }
    return b.toString();
  }

  static String _letter(int n) {
    if (n <= 0) return '$n';
    final b = StringBuffer();
    var x = n;
    while (x > 0) {
      x--;
      b.write(String.fromCharCode(97 + x % 26));
      x ~/= 26;
    }
    return b.toString().split('').reversed.join();
  }

  static String _fmtNum(int n, String fmt) => switch (fmt) {
        'lowerLetter' => _letter(n),
        'upperLetter' => _letter(n).toUpperCase(),
        'lowerRoman' => _roman(n),
        'upperRoman' => _roman(n).toUpperCase(),
        'decimalZero' => n < 10 ? '0$n' : '$n',
        'none' => '',
        _ => '$n',
      };

  static String _bulletChar(String t) {
    if (t.isEmpty) return '•';
    final c = t.runes.first;
    // Simbol dari font Symbol/Wingdings (area Unicode privat) -> karakter biasa.
    if (c == 0xF0B7 || c == 0xB7) return '•';
    if (c == 0xF0A7 || c == 0xA7) return '▪';
    if (c == 0xF076) return '❖';
    if (c == 0xF0D8) return '➢';
    if (c == 0xF0FC) return '✓';
    if (c == 0xF06E) return '■';
    if (c == 0xF071) return '❑';
    if (t == 'o') return '◦';
    if (c >= 0xF000 && c <= 0xF0FF) return '•';
    return t;
  }

  /// Label nomor/poin untuk paragraf daftar + pengaturan level.
  (String, _Lvl?) _numberLabel(String numId, int ilvl) {
    final abs = _numToAbstract[numId];
    final levels = abs == null ? null : _abstract[abs];
    final lvl = levels?[ilvl];
    if (lvl == null) return ('', null);
    if (lvl.fmt == 'bullet') return (_bulletChar(lvl.text), lvl);
    final c = _counters.putIfAbsent(numId, () => List<int>.filled(9, 0));
    final lv = ilvl < 0 ? 0 : (ilvl > 8 ? 8 : ilvl);
    if (c[lv] == 0) {
      c[lv] = lvl.start;
    } else {
      c[lv]++;
    }
    for (var i = lv + 1; i < 9; i++) {
      c[i] = 0;
    }
    var text = lvl.text;
    for (var i = 0; i <= lv; i++) {
      final li = levels![i];
      final val = c[i] == 0 ? (li?.start ?? 1) : c[i];
      text = text.replaceAll('%${i + 1}', _fmtNum(val, li?.fmt ?? 'decimal'));
    }
    return (text, lvl);
  }

  // ------------------------------------------------------------ isi

  List<DocxBlock> _blocks(XmlElement parent, double avail) {
    if (avail < 40) avail = 40; // sel tabel yang sangat sempit
    final out = <DocxBlock>[];
    for (final c in parent.childElements) {
      switch (c.name.local) {
        case 'p':
          _para(c, avail, out);
        case 'tbl':
          final t = _table(c, avail);
          if (t != null) out.add(t);
        case 'sdt':
          final content = _child(c, 'sdtContent');
          if (content != null) out.addAll(_blocks(content, avail));
        case 'customXml':
        case 'ins':
        case 'smartTag':
          out.addAll(_blocks(c, avail));
        case 'AlternateContent':
          final choice = _child(c, 'Choice') ?? _child(c, 'Fallback');
          if (choice != null) out.addAll(_blocks(choice, avail));
      }
    }
    return out;
  }

  void _para(XmlElement p, double avail, List<DocxBlock> out) {
    final pPr = _child(p, 'pPr');
    final styleId = _attr(_child(pPr, 'pStyle'), 'val') ?? _defaultParaStyle;
    final direct = _readPP(pPr);
    var pp = _defPP.merged(_stylePP(styleId));
    final numId = direct?.numId ?? pp.numId;
    final ilvl = direct?.ilvl ?? pp.ilvl ?? 0;
    var label = '';
    _Lvl? lvl;
    if (numId != null && numId != '0') {
      (label, lvl) = _numberLabel(numId, ilvl);
      pp = pp.merged(lvl?.pp);
    }
    pp = pp.merged(direct);
    final baseRP = _defRP.merged(_styleRP(styleId)).merged(_readRP(_child(pPr, 'rPr'))?..vanish = null);
    // Catatan: rPr di pPr adalah format tanda paragraf; dipakai sebagai dasar
    // untuk paragraf kosong saja (ukuran tinggi baris).

    if (pp.pageBreakBefore == true && out.isNotEmpty) out.add(DocxPageBreak());

    final inlines = <DocxInline>[];
    final attached = <DocxBlock>[];
    var breakAfter = false;
    final runBase = _defRP.merged(_styleRP(styleId));

    void runs(XmlElement parent, {bool link = false}) {
      for (final c in parent.childElements) {
        switch (c.name.local) {
          case 'r':
            breakAfter = _run(c, runBase, inlines, attached, avail, link: link) || breakAfter;
          case 'hyperlink':
            runs(c, link: true);
          case 'smartTag':
          case 'ins':
          case 'fldSimple':
          case 'customXml':
          case 'bdo':
          case 'dir':
          case 'moveTo':
            runs(c, link: link);
          case 'sdt':
            final content = _child(c, 'sdtContent');
            if (content != null) runs(content, link: link);
          case 'oMath':
          case 'oMathPara':
            final t = _descendants(c, 't').map((e) => e.innerText).join();
            if (t.isNotEmpty) inlines.add(_mkRun(t, runBase.merged(_RP()..i = true)));
          case 'AlternateContent':
            final choice = _child(c, 'Choice') ?? _child(c, 'Fallback');
            if (choice != null) runs(choice, link: link);
        }
      }
    }

    runs(p);

    final sz = _halfPtToPx(baseRP.sz ?? _defRP.sz ?? 22);
    double? lineMult, lineExact;
    if (pp.line != null) {
      if (pp.lineRule == 'auto' || pp.lineRule == null) {
        lineMult = pp.line! / 240.0;
      } else {
        lineExact = _twipsToPx(pp.line!);
      }
    }
    final numRP = lvl?.rp == null ? null : baseRP.merged(lvl!.rp);
    out.add(DocxPara(
      id: _paraId++,
      inlines: inlines,
      align: pp.jc ?? 'left',
      before: _twipsToPx(pp.before ?? 0),
      after: _twipsToPx(pp.after ?? 0),
      lineMult: lineMult,
      lineExactPx: lineExact,
      indentLeft: _twipsToPx(pp.indL ?? 0).clamp(-avail / 3, avail * 0.7).toDouble(),
      indentRight: _twipsToPx(pp.indR ?? 0).clamp(0, avail * 0.5).toDouble(),
      firstLine: _twipsToPx(pp.first ?? 0).clamp(0, avail * 0.5).toDouble(),
      hanging: _twipsToPx(pp.hanging ?? 0).clamp(0, avail * 0.5).toDouble(),
      numberLabel: label,
      numberStyle: label.isEmpty ? null : _mkRun(label, numRP ?? baseRP),
      shading: pp.shd,
      borderBottom: pp.borderBottom ?? false,
      styleId: styleId,
      contextualSpacing: pp.contextual ?? false,
      fontSizePx: sz,
      fontFamily: baseRP.font ?? _minorFont,
      attached: attached,
    ));
    // Pemisah bagian (section break) di dalam paragraf.
    final sect = _child(pPr, 'sectPr');
    if (sect != null) {
      final type = _attr(_child(sect, 'type'), 'val');
      if (type != 'continuous') breakAfter = true;
    }
    if (breakAfter) out.add(DocxPageBreak());
  }

  DocxRun _mkRun(String text, _RP rp, {bool link = false}) {
    var sizePx = _halfPtToPx(rp.sz ?? 22);
    final vert = rp.vert ?? 0;
    if (vert != 0) sizePx *= 0.68;
    return DocxRun(
      text: rp.caps == true ? text.toUpperCase() : text,
      bold: rp.b ?? false,
      italic: rp.i ?? false,
      underline: (rp.u ?? false) || link,
      strike: rp.strike ?? false,
      sizePx: sizePx,
      color: rp.color ?? (link ? const Color(0xFF0563C1) : null),
      highlight: rp.hl,
      fontFamily: rp.font ?? _minorFont,
      vert: vert,
      link: link,
    );
  }

  /// Mengembalikan true bila run berisi pemisah halaman.
  bool _run(XmlElement r, _RP base, List<DocxInline> out, List<DocxBlock> attached, double avail, {bool link = false}) {
    final rPr = _child(r, 'rPr');
    final rStyle = _attr(_child(rPr, 'rStyle'), 'val');
    final rp = base.merged(_styleRP(rStyle)).merged(_readRP(rPr));
    if (rp.vanish == true) return false;
    var pageBreak = false;
    final buf = StringBuffer();

    void flush() {
      if (buf.isEmpty) return;
      out.add(_mkRun(buf.toString(), rp, link: link));
      buf.clear();
    }

    void walk(XmlElement parent) {
      for (final c in parent.childElements) {
        switch (c.name.local) {
          case 't':
            buf.write(c.innerText);
          case 'tab':
          case 'ptab':
            buf.write('\t');
          case 'br':
            final type = _attr(c, 'type');
            if (type == 'page') {
              pageBreak = true;
            } else {
              buf.write('\n');
            }
          case 'cr':
            buf.write('\n');
          case 'noBreakHyphen':
            buf.write('-');
          case 'sym':
            final ch = int.tryParse(_attr(c, 'char') ?? '', radix: 16);
            if (ch != null) buf.write(_bulletChar(String.fromCharCode(ch)));
          case 'drawing':
          case 'pict':
          case 'object':
            flush();
            _drawing(c, out, attached, avail);
          case 'AlternateContent':
            final choice = _child(c, 'Choice') ?? _child(c, 'Fallback');
            if (choice != null) walk(choice);
        }
      }
    }

    walk(r);
    flush();
    return pageBreak;
  }

  void _drawing(XmlElement d, List<DocxInline> out, List<DocxBlock> attached, double avail) {
    // Kotak teks
    final boxes = _descendants(d, 'txbxContent').toList();
    if (boxes.isNotEmpty) {
      for (final b in boxes) {
        attached.addAll(_blocks(b, avail - 24));
      }
      return;
    }
    // Gambar: <a:blip r:embed="rIdX"> (DrawingML) atau <v:imagedata r:id="rIdX"> (VML)
    String? rid;
    for (final e in d.descendants.whereType<XmlElement>()) {
      if (e.name.local == 'blip') {
        rid = _attr(e, 'embed') ?? _attr(e, 'link');
        if (rid != null) break;
      }
      if (e.name.local == 'imagedata') {
        rid = _attr(e, 'id');
        if (rid != null) break;
      }
    }
    if (rid == null) return;
    final path = _rels[rid];
    if (path == null) return;
    final f = _zip.findFile(path);
    if (f == null) return;
    double w = 0, h = 0;
    for (final e in _descendants(d, 'extent')) {
      final cx = _num(_attr(e, 'cx')), cy = _num(_attr(e, 'cy'));
      if (cx != null && cy != null && cx > 0 && cy > 0) {
        w = cx / 9525;
        h = cy / 9525;
        break;
      }
    }
    if (w == 0) {
      // VML: style="width:120pt;height:80pt"
      for (final e in d.descendants.whereType<XmlElement>()) {
        final st = _attr(e, 'style');
        if (st == null) continue;
        final mw = RegExp(r'width:\s*([\d.]+)(pt|px|in)').firstMatch(st);
        final mh = RegExp(r'height:\s*([\d.]+)(pt|px|in)').firstMatch(st);
        if (mw != null && mh != null) {
          double conv(RegExpMatch m) {
            final v = double.parse(m.group(1)!);
            return switch (m.group(2)) { 'pt' => v * 4 / 3, 'in' => v * 96, _ => v };
          }

          w = conv(mw);
          h = conv(mh);
          break;
        }
      }
    }
    if (w <= 0 || h <= 0) {
      w = avail * 0.6;
      h = w * 0.66;
    }
    if (w > avail) {
      h = h * avail / w;
      w = avail;
    }
    out.add(DocxImage(Uint8List.fromList(_fileBytes(f)), w, h, path.split('/').last));
  }

  DocxTable? _table(XmlElement tbl, double avail) {
    final tblPr = _child(tbl, 'tblPr');
    final styleId = _attr(_child(tblPr, 'tblStyle'), 'val') ?? _defaultTableStyle;
    final borders = _readBorders(_child(tblPr, 'tblBorders')) ?? _styleBorders(styleId) ?? true;
    final jc = _attr(_child(tblPr, 'jc'), 'val');
    final align = jc == 'center' ? 'center' : (jc == 'right' || jc == 'end' ? 'right' : 'left');
    final indent = _twipsToPx(_num(_attr(_child(tblPr, 'tblInd'), 'w')) ?? 0).clamp(0, avail / 3).toDouble();

    var grid = _children(_child(tbl, 'tblGrid'), 'gridCol').map((g) => _twipsToPx(_num(_attr(g, 'w')) ?? 0)).toList();
    final rowsXml = _children(tbl, 'tr').toList();
    if (rowsXml.isEmpty) return null;
    // Bila grid tidak ada/nol, bagi rata sesuai jumlah kolom terbanyak.
    var maxCols = 0;
    for (final tr in rowsXml) {
      var n = 0;
      for (final tc in _children(tr, 'tc')) {
        n += int.tryParse(_attr(_child(_child(tc, 'tcPr'), 'gridSpan'), 'val') ?? '') ?? 1;
      }
      if (n > maxCols) maxCols = n;
    }
    if (grid.length < maxCols || grid.every((g) => g <= 0)) {
      grid = List<double>.filled(maxCols, (avail - indent) / (maxCols == 0 ? 1 : maxCols));
    }
    for (var i = 0; i < grid.length; i++) {
      if (grid[i] <= 0) grid[i] = 20;
    }
    final total = grid.fold<double>(0, (a, b) => a + b);
    final room = avail - indent;
    final scale = total > room && total > 0 ? room / total : 1.0;
    grid = grid.map((g) => g * scale).toList();

    final rows = <DocxRow>[];
    final starts = <List<int>>[];
    for (final tr in rowsXml) {
      final cells = <DocxCell>[];
      final st = <int>[];
      var col = 0;
      // Sel yang dilewati di awal baris (gridBefore)
      final gb = int.tryParse(_attr(_child(_child(tr, 'trPr'), 'gridBefore'), 'val') ?? '') ?? 0;
      if (gb > 0) {
        var w = 0.0;
        for (var i = 0; i < gb && i < grid.length; i++) {
          w += grid[i];
        }
        cells.add(DocxCell(blocks: const [], width: w, shading: null, vAlign: 'top', mergedFromAbove: false));
        st.add(-1);
        col = gb;
      }
      final tcs = <XmlElement>[];
      for (final c in tr.childElements) {
        if (c.name.local == 'tc') {
          tcs.add(c);
        } else if (c.name.local == 'sdt') {
          tcs.addAll(_children(_child(c, 'sdtContent'), 'tc'));
        }
      }
      for (final tc in tcs) {
        final tcPr = _child(tc, 'tcPr');
        final rawSpan = int.tryParse(_attr(_child(tcPr, 'gridSpan'), 'val') ?? '') ?? 1;
        final span = rawSpan < 1 ? 1 : (rawSpan > 64 ? 64 : rawSpan);
        var w = 0.0;
        for (var i = col; i < col + span && i < grid.length; i++) {
          w += grid[i];
        }
        if (w <= 0) w = 40;
        final vm = _child(tcPr, 'vMerge');
        final cont = vm != null && (_attr(vm, 'val') == null || _attr(vm, 'val') == 'continue');
        final va = _attr(_child(tcPr, 'vAlign'), 'val');
        cells.add(DocxCell(
          blocks: cont ? const [] : _blocks(tc, w - 15),
          width: w,
          shading: _hexColor(_attr(_child(tcPr, 'shd'), 'fill')),
          vAlign: va == 'center' ? 'center' : (va == 'bottom' ? 'bottom' : 'top'),
          mergedFromAbove: cont,
        ));
        st.add(vm != null ? col : -1);
        col += span;
      }
      rows.add(DocxRow(cells));
      starts.add(st);
    }
    // Tandai sel yang bersambung ke bawah (gabung baris) -> tanpa garis bawah.
    for (var r = 0; r + 1 < rows.length; r++) {
      for (var i = 0; i < rows[r].cells.length; i++) {
        final s = starts[r][i];
        if (s < 0) continue;
        final j = starts[r + 1].indexOf(s);
        if (j >= 0 && rows[r + 1].cells[j].mergedFromAbove) rows[r].cells[i].mergedBelow = true;
      }
    }
    return DocxTable(rows, borders, align, indent);
  }
}
