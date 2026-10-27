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

  /// Latar gradasi (mis. kartu "perlu ditinjau": from-tertiary-fixed/20 via-transparent).
  final Gradient? gradient;

  /// Warna latar saat disorot (versi web: hover:bg-surface-container).
  final Color? hoverColor;

  /// Bayangan khusus (null = shadow-sm / hover:shadow-md).
  final List<BoxShadow>? baseShadowOverride;
  final List<BoxShadow>? hoverShadowOverride;
  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.radius = 12,
    this.gradient,
    this.hoverColor,
    this.baseShadowOverride,
    this.hoverShadowOverride,
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
          transform: Matrix4.translationValues(0, _hover && w.onTap != null && !reduceMotion(context) ? -1 : 0, 0),
          padding: w.padding,
          decoration: BoxDecoration(
            color: _hover && w.hoverColor != null ? w.hoverColor : (w.color ?? YmColors.surface),
            gradient: w.gradient,
            borderRadius: BorderRadius.circular(w.radius),
            border: w.borderColor != null
                ? Border.all(color: w.borderColor!)
                : (YmColors.isDark ? Border.all(color: _hover ? YmColors.primary.withOpacity(0.5) : YmColors.line) : null),
            boxShadow: _hover ? (w.hoverShadowOverride ?? hoverShadow) : (w.baseShadowOverride ?? softShadow),
          ),
          child: Material(type: MaterialType.transparency, child: w.child),
        ),
      ),
    );
  }
}

/// Chip kecil persis versi web.
/// - chip kategori: `px-2 py-0.5 rounded-md bg-surface-container text-on-surface-variant font-label-sm`
/// - pill status:   `px-2.5 py-0.5 rounded-full font-label-sm font-semibold` + ikon 14
class SoftChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? fg;
  final Color? bg;
  final bool pill;
  final bool bold;

  /// Titik bulat kecil di depan teks (versi web: w-1.5 h-1.5 rounded-full).
  final Color? dot;
  const SoftChip(this.text, {super.key, this.icon, this.fg, this.bg, this.pill = false, this.bold = false, this.dot});

  /// Chip status hijau / biru / oranye / merah (warna persis versi web).
  factory SoftChip.success(String t, {IconData? icon, Color? dot}) =>
      SoftChip(t, icon: icon, dot: dot, fg: YmColors.onSuccessSoft, bg: YmColors.successContainer.withOpacity(0.5), pill: true, bold: true);
  factory SoftChip.successStrong(String t, {IconData? icon, Color? dot}) =>
      SoftChip(t, icon: icon, dot: dot, fg: YmColors.onSuccessContainer, bg: YmColors.successContainer, pill: true, bold: true);
  factory SoftChip.primary(String t, {IconData? icon, Color? dot}) =>
      SoftChip(t, icon: icon, dot: dot, fg: YmColors.onPrimaryFixed, bg: YmColors.primaryFixed, pill: true, bold: true);
  factory SoftChip.warning(String t, {IconData? icon, Color? dot}) =>
      SoftChip(t, icon: icon, dot: dot, fg: YmColors.onWarningSoft, bg: YmColors.warningSoft, pill: true, bold: true);
  factory SoftChip.danger(String t, {IconData? icon, Color? dot}) =>
      SoftChip(t, icon: icon, dot: dot, fg: YmColors.onDangerSoft, bg: YmColors.dangerSoft, pill: true, bold: true);
  factory SoftChip.neutral(String t, {IconData? icon}) => SoftChip(t, icon: icon, fg: YmColors.textMuted, bg: YmColors.surfaceContainerHigh, pill: true);

  @override
  Widget build(BuildContext context) {
    final f = fg ?? YmColors.textMuted;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: pill ? 10 : 8, vertical: 2),
      decoration: BoxDecoration(color: bg ?? YmColors.surfaceContainer, borderRadius: BorderRadius.circular(pill ? 999 : 6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 6)],
          if (icon != null) ...[Icon(icon, size: 14, color: f), const SizedBox(width: 4)],
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: YmTextStyles.labelSm.copyWith(color: f, fontWeight: bold ? FontWeight.w600 : FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// Tanda tombol keyboard persis versi web:
/// `px-2 py-0.5 rounded-lg bg-surface-container-highest text-on-surface-variant font-label-sm shadow-sm`.
/// [small] = gaya di kotak saring (`px-1.5 py-0.5 rounded bg-surface-container text-outline`).
class KbdHint extends StatelessWidget {
  final String text;
  final bool small;
  const KbdHint(this.text, {super.key, this.small = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: 2),
        decoration: BoxDecoration(
          color: small ? YmColors.surfaceContainer : YmColors.surfaceHigh,
          borderRadius: BorderRadius.circular(small ? 4 : 8),
          boxShadow: small ? null : shadowSm,
        ),
        child: Text(text, style: YmTextStyles.labelSm.copyWith(color: small ? YmColors.outline : YmColors.textMuted)),
      );
}

/// Judul halaman persis versi web:
/// jejak `font-label-md text-outline` dipisah "/" (atau ›) + chip ringkas,
/// judul `font-display-lg` (36/44, -0.02em), keterangan `font-body-md`
/// maks 768px, tombol aksi di kanan (rata bawah). Jarak bawah 24.
class PageHeader extends StatelessWidget {
  final List<String> crumbs;
  final String title;
  final String? subtitle;
  final Widget? badge;
  final List<Widget> actions;
  final IconData? overlineIcon;
  final String? overline;

  /// true = pemisah jejak berupa ikon › (versi web halaman kategori).
  final bool chevrons;

  const PageHeader({
    super.key,
    this.crumbs = const [],
    required this.title,
    this.subtitle,
    this.badge,
    this.actions = const [],
    this.overline,
    this.overlineIcon,
    this.chevrons = false,
  });

  @override
  Widget build(BuildContext context) {
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (crumbs.isNotEmpty || badge != null)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < crumbs.length; i++) ...[
                if (i > 0)
                  chevrons
                      ? Icon(Icons.chevron_right_rounded, size: 16, color: YmColors.outlineVariant)
                      : Text('/', style: YmTextStyles.labelSm.copyWith(color: YmColors.outlineVariant)),
                Text(
                  crumbs[i],
                  style: YmTextStyles.labelMd.copyWith(
                    color: i == crumbs.length - 1 ? YmColors.textDark : (chevrons ? YmColors.textMuted : YmColors.outline),
                    fontWeight: i == crumbs.length - 1 ? (chevrons ? FontWeight.w600 : FontWeight.w500) : FontWeight.w500,
                  ),
                ),
              ],
              if (badge != null) badge!,
            ],
          ),
        if (overline != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(overlineIcon ?? Icons.verified_outlined, size: 18, color: YmColors.primary),
              const SizedBox(width: 4),
              Text(overline!.toUpperCase(), style: YmTextStyles.labelSm.copyWith(color: YmColors.primary, letterSpacing: 0.55)),
            ]),
          ),
        Padding(
          padding: EdgeInsets.only(top: crumbs.isNotEmpty ? 4 : 0),
          child: Text(title, style: YmTextStyles.display),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 768),
            child: Text(subtitle!, style: YmTextStyles.bodyMd),
          ),
        ],
      ],
    );
    if (actions.isEmpty) return left;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Flexible(
          child: Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: actions),
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
        color: YmColors.surfaceContainerHigh,
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

/// Kartu angka persis versi web (dashboard):
/// `p-space-lg rounded-xl bg-surface-container-lowest shadow-sm hover:shadow-md`
/// ubin ikon 40 (rounded-xl) + chip di kanan atas; mt-4 label `font-label-md`;
/// angka `font-display-lg` + satuan `font-label-sm`; keterangan `font-body-sm` mt-2;
/// isi bawah (grafik/bar/chip) mt-4 pt-2.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final num? number; // kalau diisi, angka menghitung naik
  final String? unit;
  final Color? unitColor;
  final IconData icon;
  final Color color; // warna ikon
  final Color? tileBg; // latar ubin ikon (bawaan: surface-container)
  final Color? numberColor;
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
    this.unitColor,
    this.tileBg,
    this.numberColor,
    this.sub,
    this.chip,
    this.footer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final numStyle = YmTextStyles.display.copyWith(color: numberColor ?? YmColors.textDark);
    return HoverCard(
      onTap: onTap,
      padding: const EdgeInsets.all(24),
      radius: 12,
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
                decoration: BoxDecoration(color: tileBg ?? YmColors.surfaceContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              if (chip != null) chip!,
            ],
          ),
          const SizedBox(height: 16),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelMd.copyWith(color: YmColors.textMuted)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (number != null) CountUp(value: number!, style: numStyle) else Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: numStyle)),
              if (unit != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(unit!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: YmTextStyles.labelSm.copyWith(color: unitColor ?? YmColors.outline, fontWeight: unitColor == null ? FontWeight.w600 : FontWeight.w600)),
                ),
              ],
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 8),
            Text(sub!, style: YmTextStyles.bodySm, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (footer != null) ...[const SizedBox(height: 24), footer!],
        ],
      ),
    );
  }
}

/// Chip kategori persis versi web: `px-2 py-0.5 rounded-md bg-surface-container font-label-sm`.
class CategoryBadge extends StatelessWidget {
  final String code;
  final bool compact;
  const CategoryBadge({super.key, required this.code, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(code);
    return SoftChip(compact ? c.label.split(' ').first : c.label, fg: YmColors.textMuted, bg: YmColors.surfaceContainer);
  }
}

/// Pill status kirim dokumen (warna persis versi web).
class DocStatusChip extends StatelessWidget {
  final DocStatus status;
  const DocStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      DocStatus.draft => SoftChip.primary('Draf: belum dikirim', icon: Icons.edit_note_rounded),
      DocStatus.uploaded => SoftChip.success('Tersimpan di server', icon: Icons.check_rounded),
      DocStatus.uploading => SoftChip.primary('Sedang diunggah', icon: Icons.cloud_upload_outlined),
      DocStatus.pending => SoftChip.warning('Offline: menunggu sinkron', icon: Icons.sync_problem_outlined),
      DocStatus.failed => SoftChip.warning('Perlu ditinjau: gagal unggah', icon: Icons.flag_outlined),
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

/// Ubin ikon dokumen persis versi web: `w-11 h-11 rounded-xl bg-primary-fixed/50 text-primary` (ikon 22).
class CategoryTile extends StatelessWidget {
  final String code;
  final double size;
  final Color? bg;
  final Color? fg;
  final IconData? icon;
  const CategoryTile({super.key, required this.code, this.size = 44, this.bg, this.fg, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(code);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg ?? YmColors.primaryFixed.withOpacity(YmColors.isDark ? 1 : 0.5), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon ?? c.icon, color: fg ?? YmColors.primary, size: size / 2),
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

/// Pembungkus halaman persis versi web: `<main class="px-space-lg py-space-lg">` = 24 px,
/// lebar penuh.
class PageBody extends StatelessWidget {
  final Widget child;
  final bool scroll;
  final double maxWidth;
  const PageBody({super.key, required this.child, this.scroll = true, this.maxWidth = double.infinity});

  @override
  Widget build(BuildContext context) {
    const pad = EdgeInsets.all(24);
    final inner = maxWidth == double.infinity
        ? child
        : Align(alignment: Alignment.topLeft, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child));
    return scroll ? SingleChildScrollView(padding: pad, child: inner) : Padding(padding: pad, child: inner);
  }
}

/// Pilihan saring persis versi web:
/// `h-11 pl-3 pr-8 rounded-xl bg-surface-container-low font-label-md` + ikon expand 16.
class FilterDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double width;
  final IconData? icon;
  final double height;

  const FilterDropdown({super.key, required this.value, required this.items, required this.onChanged, this.width = 200, this.icon, this.height = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.only(left: 12, right: 8),
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
                focusColor: Colors.transparent,
                dropdownColor: YmColors.surface,
                style: YmTextStyles.labelMd,
                icon: Icon(Icons.expand_more_rounded, size: 16, color: YmColors.outline),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip saring cepat persis versi web: `px-3.5 py-1.5 rounded-full font-label-md`.
/// - terpilih: bg-primary text-on-primary shadow-sm
/// - biasa: bg-surface-container-low text-on-surface-variant
/// - [tone] warning: bg-tertiary-fixed text-on-tertiary-fixed (+ ikon tertiary)
/// - [tone] success: bg-secondary-container/40 text-on-secondary-fixed-variant (+ titik)
enum ChipTone { normal, warning, success, danger }

class QuickChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final ChipTone tone;
  const QuickChip({super.key, required this.label, required this.selected, required this.onTap, this.icon, this.tone = ChipTone.normal});

  @override
  State<QuickChip> createState() => _QuickChipState();
}

class _QuickChipState extends State<QuickChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final (Color bg, Color fg, Color iconColor) = w.selected
        ? (YmColors.primary, YmColors.onPrimary, YmColors.onPrimary)
        : switch (w.tone) {
            ChipTone.warning => (YmColors.warningSoft, YmColors.onWarningSoft, YmColors.warning),
            ChipTone.success => (YmColors.successContainer.withOpacity(0.4), YmColors.onSuccessSoft, YmColors.success),
            ChipTone.danger => (YmColors.dangerSoft, YmColors.onDangerSoft, YmColors.danger),
            ChipTone.normal => (_hover ? YmColors.surfaceContainer : YmColors.surfaceAlt, YmColors.textMuted, YmColors.textMuted),
          };
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: w.onTap,
        child: AnimatedContainer(
          duration: motion(context, const Duration(milliseconds: 150)),
          curve: kMotionCurve,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), boxShadow: w.selected ? shadowSm : null),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (w.tone == ChipTone.success && !w.selected) ...[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: YmColors.success, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            if (w.icon != null) ...[Icon(w.icon, size: 15, color: iconColor), const SizedBox(width: 6)],
            Text(w.label, style: YmTextStyles.labelMd.copyWith(color: fg)),
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
