import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/categories.dart';
import '../core/file_tools.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';

// ============================================================================
//  Komponen tampilan bersama (gaya versi web "DocArchive").
// ============================================================================

/// Muncul halus sekali saat pertama tampil: memudar + naik sedikit.
/// [index] membuat daftar muncul berurutan (bertahap 40 ms, maks 10 langkah).
class Reveal extends StatefulWidget {
  final Widget child;
  final int index;
  final Offset offset;
  const Reveal({super.key, required this.child, this.index = 0, this.offset = const Offset(0, 0.06)});

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _c.value = 1;
      return;
    }
    final delay = Duration(milliseconds: 40 * math.min(widget.index, 10));
    Future.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _a,
        child: SlideTransition(position: Tween(begin: widget.offset, end: Offset.zero).animate(_a), child: widget.child),
      );
}

/// Angka yang menghitung naik saat muncul / berubah.
class CountUp extends StatelessWidget {
  final num value;
  final TextStyle style;
  final String Function(num v)? format;
  const CountUp({super.key, required this.value, required this.style, this.format});

  static String dots(num v) {
    final s = v.round().abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '${v < 0 ? '-' : ''}$b';
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: motion(context, const Duration(milliseconds: 900)),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text((format ?? dots)(v), style: style),
    );
  }
}

/// Kartu yang terangkat halus saat disorot mouse (versi web: hover:shadow-md).
class HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.radius = 14,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: w.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: w.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: motion(context, const Duration(milliseconds: 200)),
          curve: kMotionCurve,
          transform: Matrix4.translationValues(0, _hover && !reduceMotion(context) ? -2 : 0, 0),
          padding: w.padding,
          decoration: BoxDecoration(
            color: w.color ?? YmColors.surface,
            borderRadius: BorderRadius.circular(w.radius),
            border: w.borderColor != null
                ? Border.all(color: w.borderColor!)
                : (YmColors.isDark ? Border.all(color: _hover ? YmColors.primary.withOpacity(0.5) : YmColors.line) : null),
            boxShadow: _hover ? hoverShadow : softShadow,
          ),
          child: Material(type: MaterialType.transparency, child: w.child),
        ),
      ),
    );
  }
}

/// Chip kecil (versi web: px-2 py-0.5 rounded-md / rounded-full).
class SoftChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? fg;
  final Color? bg;
  final bool pill;
  final bool bold;
  const SoftChip(this.text, {super.key, this.icon, this.fg, this.bg, this.pill = false, this.bold = false});

  /// Chip status hijau / oranye / merah / biru.
  factory SoftChip.success(String t, {IconData? icon}) => SoftChip(t, icon: icon, fg: YmColors.success, bg: YmColors.successSoft, pill: true, bold: true);
  factory SoftChip.warning(String t, {IconData? icon}) => SoftChip(t, icon: icon, fg: YmColors.warning, bg: YmColors.warningSoft, pill: true, bold: true);
  factory SoftChip.danger(String t, {IconData? icon}) => SoftChip(t, icon: icon, fg: YmColors.danger, bg: YmColors.dangerSoft, pill: true, bold: true);
  factory SoftChip.primary(String t, {IconData? icon}) => SoftChip(t, icon: icon, fg: YmColors.primary, bg: YmColors.primarySoft, pill: true, bold: true);

  @override
  Widget build(BuildContext context) {
    final f = fg ?? YmColors.textMuted;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: pill ? 9 : 7, vertical: 3),
      decoration: BoxDecoration(color: bg ?? YmColors.surfaceContainer, borderRadius: BorderRadius.circular(pill ? 20 : 6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: f), const SizedBox(width: 4)],
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: kFont, fontSize: 11, height: 1.3, fontWeight: bold ? FontWeight.w600 : FontWeight.w500, color: f, letterSpacing: 0.1)),
          ),
        ],
      ),
    );
  }
}

/// Tanda tombol keyboard (mis. "Ctrl K").
class KbdHint extends StatelessWidget {
  final String text;
  const KbdHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: YmColors.surfaceHigh,
          borderRadius: BorderRadius.circular(7),
          boxShadow: softShadow,
        ),
        child: Text(text, style: TextStyle(fontFamily: kFont, fontSize: 11, fontWeight: FontWeight.w600, color: YmColors.textMuted)),
      );
}

/// Judul halaman gaya web: breadcrumb + chip ringkas, judul besar, keterangan,
/// dan tombol aksi di kanan.
class PageHeader extends StatelessWidget {
  final List<String> crumbs;
  final String title;
  final String? subtitle;
  final Widget? badge;
  final List<Widget> actions;
  final IconData? overlineIcon;
  final String? overline;

  const PageHeader({
    super.key,
    this.crumbs = const [],
    required this.title,
    this.subtitle,
    this.badge,
    this.actions = const [],
    this.overline,
    this.overlineIcon,
  });

  @override
  Widget build(BuildContext context) {
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (crumbs.isNotEmpty || badge != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var i = 0; i < crumbs.length; i++) ...[
                  if (i > 0) Icon(Icons.chevron_right_rounded, size: 16, color: YmColors.outline),
                  Text(crumbs[i],
                      style: TextStyle(
                        fontFamily: kFont,
                        fontSize: 12.5,
                        fontWeight: i == crumbs.length - 1 ? FontWeight.w600 : FontWeight.w500,
                        color: i == crumbs.length - 1 ? YmColors.textDark : YmColors.outline,
                      )),
                ],
                if (badge != null) ...[const SizedBox(width: 4), badge!],
              ],
            ),
          ),
        if (overline != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(overlineIcon ?? Icons.verified_rounded, size: 15, color: YmColors.primary),
              const SizedBox(width: 6),
              Text(overline!.toUpperCase(), style: YmTextStyles.overline.copyWith(color: YmColors.primary, letterSpacing: 1.1)),
            ]),
          ),
        Text(title, style: YmTextStyles.pageTitle),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(subtitle!, style: TextStyle(fontFamily: kFont, fontSize: 14, height: 1.55, color: YmColors.textMuted)),
          ),
        ],
      ],
    );
    if (actions.isEmpty) return left;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: left),
        const SizedBox(width: 20),
        Flexible(
          child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: actions),
        ),
      ],
    );
  }
}

/// Pilihan bersegmen dengan penanda yang meluncur (mis. "Data dokumen | File asli").
class SegmentedToggle<T> extends StatelessWidget {
  final List<(T, String, IconData?)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final double segmentWidth;
  const SegmentedToggle({super.key, required this.options, required this.value, required this.onChanged, this.segmentWidth = 150});

  @override
  Widget build(BuildContext context) {
    final index = math.max(0, options.indexWhere((o) => o.$1 == value));
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: YmColors.surfaceContainer, borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: segmentWidth * options.length,
        height: 36,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: motion(context),
              curve: Curves.easeOutBack,
              left: segmentWidth * index,
              top: 0,
              bottom: 0,
              width: segmentWidth,
              child: Container(
                decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(9), boxShadow: softShadow),
              ),
            ),
            Row(
              children: [
                for (final o in options)
                  SizedBox(
                    width: segmentWidth,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => onChanged(o.$1),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: motion(context, kMotionFast),
                          style: TextStyle(
                            fontFamily: kFont,
                            fontSize: 13,
                            fontWeight: o.$1 == value ? FontWeight.w600 : FontWeight.w500,
                            color: o.$1 == value ? YmColors.textDark : YmColors.outline,
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (o.$3 != null) ...[Icon(o.$3, size: 16, color: o.$1 == value ? YmColors.primary : YmColors.outline), const SizedBox(width: 6)],
                            Text(o.$2),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Batang kemajuan yang terisi dengan animasi.
class ProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color? color;
  final double height;
  const ProgressBar({super.key, required this.value, this.color, this.height = 6});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: YmColors.surfaceContainer,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0).toDouble()),
          duration: motion(context, const Duration(milliseconds: 900)),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            child: Container(decoration: BoxDecoration(color: color ?? YmColors.primary, borderRadius: BorderRadius.circular(height))),
          ),
        ),
      ),
    );
  }
}

/// Grafik garis kecil (sparkline) — tergambar dari kiri ke kanan.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color? color;
  final double height;
  const Sparkline({super.key, required this.values, this.color, this.height = 36});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: motion(context, const Duration(milliseconds: 1200)),
        curve: Curves.easeInOutCubic,
        builder: (_, t, __) => CustomPaint(size: Size.infinite, painter: _SparkPainter(values, color ?? YmColors.primary, t)),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> v;
  final Color color;
  final double t;
  _SparkPainter(this.v, this.color, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final maxV = v.reduce(math.max);
    final minV = v.reduce(math.min);
    final span = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final pts = <Offset>[
      for (var i = 0; i < v.length; i++) Offset(size.width * i / (v.length - 1), size.height - 3 - (size.height - 6) * ((v[i] - minV) / span)),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final mx = (a.dx + b.dx) / 2;
      path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * t, size.height));
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withOpacity(0.18), color.withOpacity(0)])
            .createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.t != t || old.v != v || old.color != color;
}

/// Kartu angka gaya web: ubin ikon di kiri atas, chip di kanan atas, label,
/// angka besar (+ satuan), keterangan, dan isi tambahan (grafik / bar).
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final num? number; // kalau diisi, angka menghitung naik
  final String? unit;
  final IconData icon;
  final Color color;
  final String? sub;
  final Widget? chip;
  final Widget? footer;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.number,
    this.unit,
    this.sub,
    this.chip,
    this.footer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final numStyle = YmTextStyles.bigNumber.copyWith(color: color == YmColors.danger ? YmColors.danger : YmColors.textDark);
    return HoverCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withOpacity(YmColors.isDark ? 0.18 : 0.10), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: color, size: 21),
              ),
              const Spacer(),
              if (chip != null) chip!,
            ],
          ),
          const SizedBox(height: 14),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kFont, fontSize: 13, fontWeight: FontWeight.w500, color: YmColors.textMuted)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (number != null) CountUp(value: number!, style: numStyle) else Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: numStyle)),
              if (unit != null) ...[
                const SizedBox(width: 6),
                Flexible(child: Text(unit!, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.label.copyWith(fontSize: 12.5))),
              ],
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(sub!, style: YmTextStyles.label.copyWith(fontSize: 12, height: 1.45), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );
  }
}

/// Chip kategori (versi web: rounded-md bg-surface-container).
class CategoryBadge extends StatelessWidget {
  final String code;
  final bool compact;
  const CategoryBadge({super.key, required this.code, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(code);
    return SoftChip(compact ? c.label.split(' ').first : c.label);
  }
}

/// Chip status kirim dokumen (pill berwarna lembut).
class DocStatusChip extends StatelessWidget {
  final DocStatus status;
  const DocStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      DocStatus.draft => SoftChip.primary('Draf — belum dikirim', icon: Icons.edit_note_rounded),
      DocStatus.uploaded => SoftChip.success('Tersimpan di server', icon: Icons.check_rounded),
      DocStatus.uploading => SoftChip.primary('Sedang diunggah', icon: Icons.cloud_upload_outlined),
      DocStatus.pending => SoftChip.warning('Menunggu sinkron', icon: Icons.sync_problem_rounded),
      DocStatus.failed => SoftChip.danger('Gagal diunggah', icon: Icons.error_outline_rounded),
    };
  }
}

/// Teks status untuk tooltip / ekspor (dipakai juga oleh file_tools).
String docStatusText(DocStatus s) => statusLabel(s);

/// Ikon jenis file.
class FileTypeIcon extends StatelessWidget {
  final String ext;
  final double size;
  const FileTypeIcon({super.key, required this.ext, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (ext.toLowerCase()) {
      'pdf' => (const Color(0xFFD93025), Icons.picture_as_pdf_outlined),
      'doc' || 'docx' => (const Color(0xFF2B579A), Icons.description_outlined),
      'xls' || 'xlsx' || 'csv' => (const Color(0xFF217346), Icons.table_chart_outlined),
      'txt' => (YmColors.textMuted, Icons.article_outlined),
      'jpg' || 'jpeg' || 'png' || 'bmp' || 'gif' || 'webp' => (const Color(0xFF0E8F7E), Icons.image_outlined),
      'dwg' => (const Color(0xFFB7472A), Icons.architecture_rounded),
      'zip' || 'rar' => (const Color(0xFF8E44AD), Icons.folder_zip_outlined),
      _ => (YmColors.textMuted, Icons.insert_drive_file_outlined),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withOpacity(YmColors.isDark ? 0.2 : 0.10), borderRadius: BorderRadius.circular(size * 0.28)),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}

/// Ubin ikon kategori (versi web: w-11 h-11 rounded-xl bg-primary-fixed/50).
class CategoryTile extends StatelessWidget {
  final String code;
  final double size;
  final Color? tint;
  const CategoryTile({super.key, required this.code, this.size = 44, this.tint});

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(code);
    final color = tint ?? YmColors.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tint != null ? tint!.withOpacity(0.14) : YmColors.primarySoft.withOpacity(YmColors.isDark ? 1 : 0.6), borderRadius: BorderRadius.circular(size * 0.28)),
      child: Icon(c.icon, color: color, size: size * 0.5),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Reveal(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(20)),
                child: Icon(icon, size: 30, color: YmColors.primary),
              ),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: YmTextStyles.sectionTitle),
              const SizedBox(height: 6),
              SizedBox(width: 420, child: Text(message, textAlign: TextAlign.center, style: YmTextStyles.label.copyWith(fontSize: 13, height: 1.55))),
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pembungkus halaman: padding standar (versi web: 40px) + area scroll opsional.
class PageBody extends StatelessWidget {
  final Widget child;
  final bool scroll;
  final double maxWidth;
  const PageBody({super.key, required this.child, this.scroll = true, this.maxWidth = 1480});

  @override
  Widget build(BuildContext context) {
    const pad = EdgeInsets.fromLTRB(36, 28, 36, 36);
    final inner = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
    return scroll ? SingleChildScrollView(padding: pad, child: inner) : Padding(padding: pad, child: inner);
  }
}

/// Dropdown kecil dengan gaya seragam (untuk filter) — versi web: h-10 rounded-xl bg-surface-container-low.
class FilterDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double width;
  final IconData? icon;

  const FilterDropdown({super.key, required this.value, required this.items, required this.onChanged, this.width = 200, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: YmColors.outline), const SizedBox(width: 6)],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                items: items,
                onChanged: onChanged,
                isExpanded: true,
                dropdownColor: YmColors.surface,
                style: TextStyle(fontFamily: kFont, fontSize: 13, color: YmColors.textDark, fontWeight: FontWeight.w500),
                icon: Icon(Icons.expand_more_rounded, size: 18, color: YmColors.outline),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip filter cepat (versi web: "Recently Added", "Needs Review (14)").
class QuickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? dot;
  final Color? tone; // warna khusus (mis. oranye untuk "perlu ditinjau")
  const QuickChip({super.key, required this.label, required this.selected, required this.onTap, this.icon, this.dot, this.tone});

  @override
  Widget build(BuildContext context) {
    final t = tone;
    final bg = selected ? YmColors.primary : (t != null ? t.withOpacity(YmColors.isDark ? 0.18 : 0.12) : YmColors.surfaceAlt);
    final fg = selected ? YmColors.onPrimary : (t ?? YmColors.textMuted);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: motion(context, const Duration(milliseconds: 200)),
          curve: kMotionCurve,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (dot != null) ...[
              Container(width: 7, height: 7, decoration: BoxDecoration(color: selected ? YmColors.onPrimary : dot, shape: BoxShape.circle)),
              const SizedBox(width: 7),
            ],
            if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 5)],
            Text(label, style: TextStyle(fontFamily: kFont, fontSize: 12.5, fontWeight: FontWeight.w600, color: fg)),
          ]),
        ),
      ),
    );
  }
}

/// "3 hari lalu", "18 mnt lalu".
String timeAgo(DateTime? d) {
  if (d == null) return '-';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays == 1) return 'kemarin';
  if (diff.inDays < 30) return '${diff.inDays} hari lalu';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} bln lalu';
  return '${(diff.inDays / 365).floor()} thn lalu';
}
