import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/ym_theme.dart';

/// Bagian bersama untuk semua penampil dokumen di dalam aplikasi
/// (PDF, Word, Excel, teks, foto): toolbar, kotak cari, pola sorotan.

/// Warna sorotan hasil pencarian.
const kMatchColor = Color(0xFFFFE066);
const kActiveMatchColor = Color(0xFFFF9F1C);
const kViewerBackground = Color(0xFFE9EAF4);

/// Membuat pola pencarian dari kata kunci.
/// - Beberapa kata dipisah spasi = cari salah satunya.
/// - Angka/kode dicocokkan juga bila ditulis bertitik/berstrip:
///   "52201" menemukan "5.2.2.01", "544" menemukan "5.4.4".
RegExp? buildSearchPattern(String query) {
  final words = query
      .trim()
      .split(RegExp(r'\s+'))
      .map((w) => w.trim())
      .where((w) => w.isNotEmpty)
      .toSet()
      .toList()
    ..sort((a, b) => b.length.compareTo(a.length)); // kata panjang dulu
  if (words.isEmpty) return null;
  final parts = <String>[];
  for (final w in words) {
    final digits = w.replaceAll(RegExp(r'[.\-/]'), '');
    if (RegExp(r'^\d{3,}$').hasMatch(digits)) {
      parts.add(digits.split('').map(RegExp.escape).join(r'[.\-/ ]?'));
    } else {
      parts.add(RegExp.escape(w));
    }
  }
  return RegExp(parts.join('|'), caseSensitive: false);
}

/// Memecah [text] menjadi beberapa TextSpan dengan bagian yang cocok disorot.
/// [counter] dipakai untuk menandai sorotan yang sedang aktif (hasil ke-n).
List<InlineSpan> highlightSpans(String text, TextStyle style, RegExp? pattern, {MatchCounter? counter}) {
  if (pattern == null || text.isEmpty) return [TextSpan(text: text, style: style)];
  final out = <InlineSpan>[];
  var last = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.end == m.start) continue;
    if (m.start > last) out.add(TextSpan(text: text.substring(last, m.start), style: style));
    final idx = counter?.next() ?? -1;
    final active = counter != null && idx == counter.active;
    out.add(TextSpan(
      text: text.substring(m.start, m.end),
      style: style.copyWith(backgroundColor: active ? kActiveMatchColor : kMatchColor),
    ));
    last = m.end;
  }
  if (last < text.length) out.add(TextSpan(text: text.substring(last), style: style));
  return out;
}

/// Penghitung hasil pencarian saat membangun tampilan.
class MatchCounter {
  final int active;
  int count = 0;
  MatchCounter(this.active);
  int next() => count++;
}

/// Baris toolbar penampil (di atas dokumen).
/// Kalau ruangnya sempit (mis. panel pratinjau di detail dokumen), kotak cari
/// otomatis pindah ke baris kedua supaya tidak terpotong.
class ViewerToolbar extends StatelessWidget {
  final List<Widget> leading;
  final Widget? search;
  final List<Widget> trailing;
  final double wideWidth;
  const ViewerToolbar({super.key, required this.leading, this.search, this.trailing = const [], this.wideWidth = 820});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= wideWidth || search == null;
      Widget row(List<Widget> left, List<Widget> right) => SizedBox(
            height: 46,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: c.maxWidth > 20 ? c.maxWidth - 20 : 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: left),
                    const _Gap(),
                    Row(mainAxisSize: MainAxisSize.min, children: right),
                  ],
                ),
              ),
            ),
          );
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: YmColors.borderLavender)),
        ),
        child: wide
            ? row(leading, [if (search != null) search!, ...trailing])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                row(leading, trailing),
                const Divider(height: 1, color: YmColors.borderLavender),
                row([search!], const []),
              ]),
      );
    });
  }
}

/// Pengganti Spacer di dalam toolbar yang bisa digulir.
class _Gap extends StatelessWidget {
  const _Gap();
  @override
  Widget build(BuildContext context) => const SizedBox(width: 12);
}

/// Tombol ikon kecil untuk toolbar.
class ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  const ToolButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? YmColors.accentPurple.withOpacity(0.12) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 19, color: onPressed == null ? YmColors.statusOffline : YmColors.textDark),
        ),
      ),
    );
  }
}

class ToolDivider extends StatelessWidget {
  const ToolDivider({super.key});
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 8), color: YmColors.borderLavender);
}

/// Label kecil di toolbar (mis. "125%", "Hal. 3 / 10").
class ToolLabel extends StatelessWidget {
  final String text;
  final double minWidth;
  const ToolLabel(this.text, {super.key, this.minWidth = 0});
  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: YmColors.textDark)),
      );
}

/// Kontrol zoom standar: [-] 100% [+] [lebar penuh].
class ZoomControls extends StatelessWidget {
  final double zoom;
  final VoidCallback onZoomIn, onZoomOut;
  final VoidCallback? onFitWidth;
  final bool fitSelected;
  const ZoomControls({super.key, required this.zoom, required this.onZoomIn, required this.onZoomOut, this.onFitWidth, this.fitSelected = false});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ToolButton(icon: Icons.zoom_out_rounded, tooltip: 'Perkecil (Ctrl -)', onPressed: onZoomOut),
      ToolLabel('${(zoom * 100).round()}%', minWidth: 48),
      ToolButton(icon: Icons.zoom_in_rounded, tooltip: 'Perbesar (Ctrl +)', onPressed: onZoomIn),
      if (onFitWidth != null) ToolButton(icon: Icons.fit_screen_rounded, tooltip: 'Sesuaikan lebar layar', onPressed: onFitWidth, selected: fitSelected),
    ]);
  }
}

/// Kotak cari di dalam dokumen: ketik, Enter = hasil berikutnya, Shift+Enter = sebelumnya.
class DocSearchBox extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onSearch;
  final VoidCallback onNext, onPrev;
  final int current; // 0-based, -1 = belum ada
  final int total;
  final bool busy;
  final FocusNode? focusNode;
  const DocSearchBox({
    super.key,
    this.initial = '',
    required this.onSearch,
    required this.onNext,
    required this.onPrev,
    required this.current,
    required this.total,
    this.busy = false,
    this.focusNode,
  });

  @override
  State<DocSearchBox> createState() => _DocSearchBoxState();
}

class _DocSearchBoxState extends State<DocSearchBox> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => widget.onSearch(v));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final has = _c.text.trim().isNotEmpty;
    final label = !has
        ? ''
        : widget.busy
            ? 'mencari...'
            : widget.total == 0
                ? 'tidak ada'
                : '${widget.current + 1} / ${widget.total}';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 230,
        height: 34,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.enter, shift: true): widget.onPrev,
            const SingleActivator(LogicalKeyboardKey.f3, shift: true): widget.onPrev,
            const SingleActivator(LogicalKeyboardKey.f3): widget.onNext,
          },
          child: TextField(
            controller: _c,
            focusNode: widget.focusNode,
            onChanged: _changed,
            onSubmitted: (_) {
              widget.onNext();
              widget.focusNode?.requestFocus();
            },
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Cari di dokumen (Ctrl+F)',
              hintStyle: const TextStyle(fontSize: 12.5, color: YmColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: YmColors.textMuted),
              prefixIconConstraints: const BoxConstraints(minWidth: 34),
              suffixIcon: has
                  ? InkWell(
                      onTap: () {
                        _c.clear();
                        widget.onSearch('');
                        setState(() {});
                      },
                      child: const Icon(Icons.close_rounded, size: 16, color: YmColors.textMuted),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 30),
              filled: true,
              fillColor: YmColors.panelBackground,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: YmColors.borderLavender)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: YmColors.borderLavender)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: YmColors.accentPurple)),
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      SizedBox(
        width: 66,
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: widget.total == 0 && has && !widget.busy ? YmColors.buzzRed : YmColors.textMuted)),
      ),
      ToolButton(icon: Icons.keyboard_arrow_up_rounded, tooltip: 'Sebelumnya (Shift+Enter)', onPressed: widget.total > 0 ? widget.onPrev : null),
      ToolButton(icon: Icons.keyboard_arrow_down_rounded, tooltip: 'Berikutnya (Enter)', onPressed: widget.total > 0 ? widget.onNext : null),
    ]);
  }
}

/// Pintasan keyboard penampil: Ctrl+F, Ctrl+plus, Ctrl+minus, Ctrl+0.
class ViewerShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback? onFind, onZoomIn, onZoomOut, onZoomReset;
  const ViewerShortcuts({super.key, required this.child, this.onFind, this.onZoomIn, this.onZoomOut, this.onZoomReset});

  @override
  Widget build(BuildContext context) {
    final b = <ShortcutActivator, VoidCallback>{};
    // Ctrl di Windows, Cmd (⌘) di macOS — keduanya didaftarkan.
    void add(LogicalKeyboardKey k, VoidCallback? f) {
      if (f == null) return;
      b[SingleActivator(k, control: true)] = f;
      b[SingleActivator(k, meta: true)] = f;
    }

    add(LogicalKeyboardKey.keyF, onFind);
    add(LogicalKeyboardKey.equal, onZoomIn);
    add(LogicalKeyboardKey.numpadAdd, onZoomIn);
    add(LogicalKeyboardKey.minus, onZoomOut);
    add(LogicalKeyboardKey.numpadSubtract, onZoomOut);
    add(LogicalKeyboardKey.digit0, onZoomReset);
    return CallbackShortcuts(bindings: b, child: Focus(autofocus: true, child: child));
  }
}

/// Pesan error / format tidak didukung di tengah penampil.
class ViewerMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;
  const ViewerMessage({super.key, required this.icon, required this.title, required this.message, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kViewerBackground,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      // bisa digulir: pesan panjang tidak lagi "overflowed" (garis kuning-hitam)
      child: SingleChildScrollView(
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: YmColors.accentPurple.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: YmColors.accentPurple),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: YmTextStyles.username.copyWith(fontSize: 15)),
          const SizedBox(height: 6),
          SelectableText(_short(message), textAlign: TextAlign.center, style: YmTextStyles.chatText.copyWith(fontSize: 12.5, color: YmColors.textMuted, height: 1.4)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: actions),
          ],
        ]),
      ),
      ),
    );
  }

  /// Detail teknis error bisa sangat panjang -> cukup beberapa baris pertama.
  static String _short(String m) {
    final lines = m.split('\n');
    var out = lines.take(4).join('\n');
    if (out.length > 400) out = '${out.substring(0, 400)}…';
    return lines.length > 4 && !out.endsWith('…') ? '$out…' : out;
  }
}

/// Langkah zoom standar.
const zoomSteps = [0.25, 0.33, 0.5, 0.67, 0.75, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 4.0];

double zoomStepUp(double z) => zoomSteps.firstWhere((s) => s > z + 0.001, orElse: () => zoomSteps.last);
double zoomStepDown(double z) => zoomSteps.lastWhere((s) => s < z - 0.001, orElse: () => zoomSteps.first);
