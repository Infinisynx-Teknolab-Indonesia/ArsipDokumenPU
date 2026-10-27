import 'package:flutter/material.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../services/tray_service.dart';
import '../services/window_ctl.dart';

/// Kartu konten persis versi web: `p-space-lg rounded-xl bg-surface-container-lowest shadow-sm`.
/// Judul (opsional): ubin ikon 32 (rounded-lg bg-surface-container) + judul
/// headline-md + keterangan body-sm, jarak bawah 16.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget? titleBadge;

  /// Warna ubin ikon judul (mis. merah muda untuk "perlu tindakan").
  final Color? iconBg;
  final Color? iconFg;

  /// true = panel mengisi tinggi yang tersedia (child boleh ListView/Expanded).
  final bool expand;

  /// Warna latar lain (mis. kartu peringatan).
  final Color? color;
  final double radius;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.titleBadge,
    this.iconBg,
    this.iconFg,
    this.expand = false,
    this.color,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    // Panel tanpa padding (isi daftar menempel tepi): judul tetap diberi jarak 24.
    final pad = padding.resolve(TextDirection.ltr);
    final headPad = pad.left < 12 ? EdgeInsets.fromLTRB(24 - pad.left, (20 - pad.top).clamp(0, 20).toDouble(), 24 - pad.right, 16) : const EdgeInsets.only(bottom: 16);
    final head = title == null
        ? null
        : Padding(
            padding: headPad,
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: iconBg ?? YmColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, size: 20, color: iconFg ?? YmColors.primary),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(child: Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.headlineMd)),
                        if (titleBadge != null) ...[const SizedBox(width: 8), titleBadge!],
                      ]),
                      if (subtitle != null) Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: YmTextStyles.bodySm),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
          );
    final body = Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: padding,
        child: head == null
            ? child
            : Column(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [head, if (expand) Expanded(child: child) else child],
              ),
      ),
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? YmColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: YmColors.isDark ? Border.all(color: YmColors.line) : null,
        boxShadow: shadowSm,
      ),
      child: body,
    );
  }
}

InputDecoration fieldDecoration(String label, {IconData? icon, String? hint, Widget? suffix}) => InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      prefixIcon: icon == null ? null : Icon(icon, size: 18, color: YmColors.outline),
      suffixIcon: suffix,
      filled: true,
      fillColor: YmColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(color: YmColors.textMuted, fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: YmColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: YmColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: YmColors.primary, width: 1.6)),
    );

/// Kolom cari persis versi web: `bg-surface-container-low rounded-xl`, ikon
/// cari di kiri (outline, 20), tanpa garis; saat aktif latar putih + cincin
/// warna utama 20% (focus:ring-2 focus:ring-primary/20).
InputDecoration searchDecoration(String hint, {Widget? suffix}) => InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: YmColors.surfaceAlt,
      hoverColor: Colors.transparent,
      prefixIcon: Padding(padding: const EdgeInsets.only(left: 14, right: 8), child: Icon(Icons.search_rounded, size: 20, color: YmColors.outline)),
      prefixIconConstraints: const BoxConstraints(minWidth: 44),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
      hintStyle: TextStyle(fontFamily: kFont, color: YmColors.outline, fontSize: 14, height: 22 / 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: YmColors.primary.withOpacity(0.2), width: 2)),
    );

/// Tombol utama persis versi web: `h-10 px-4 rounded-xl bg-primary text-on-primary
/// font-label-lg` + bayangan biru tipis; saat disorot jadi primary-container.
ButtonStyle primaryButtonStyle({Color? color}) {
  final c = color ?? YmColors.primary;
  final isPrimary = color == null || color == YmColors.primary;
  final fg = isPrimary ? YmColors.onPrimary : Colors.white;
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.disabled)) return YmColors.surfaceContainer;
      if (s.contains(WidgetState.hovered)) return isPrimary ? YmColors.primaryContainer : Color.lerp(c, Colors.white, 0.12);
      return c;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? YmColors.outline : fg),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? 0 : (s.contains(WidgetState.hovered) ? 4 : 2)),
    shadowColor: WidgetStatePropertyAll(c.withOpacity(0.45)),
    minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: kFont, fontWeight: FontWeight.w500, fontSize: 14, height: 20 / 14)),
    iconSize: const WidgetStatePropertyAll(18),
    animationDuration: const Duration(milliseconds: 150),
  );
}

/// Tombol sekunder persis versi web: `h-10 px-4 rounded-xl bg-surface-container-lowest
/// text-on-surface shadow-sm hover:bg-surface-container font-label-lg`, ikon abu.
ButtonStyle outlineButtonStyle() => ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.hovered) ? YmColors.surfaceContainer : YmColors.surface),
      foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? YmColors.outline : YmColors.textDark),
      iconColor: WidgetStatePropertyAll(YmColors.outline),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      side: WidgetStatePropertyAll(YmColors.isDark ? BorderSide(color: YmColors.line) : BorderSide.none),
      elevation: const WidgetStatePropertyAll(1),
      shadowColor: const WidgetStatePropertyAll(Color(0x33000000)),
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: kFont, fontWeight: FontWeight.w500, fontSize: 14, height: 20 / 14)),
      iconSize: const WidgetStatePropertyAll(18),
    );

/// Tombol lembut di baris daftar persis versi web: `h-9 px-3 rounded-lg
/// bg-surface-container-low hover:bg-surface-container font-label-sm`.
ButtonStyle softButtonStyle({Color? fg, Color? bg, Color? hover}) => ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.hovered) ? (hover ?? (bg == null ? YmColors.surfaceContainer : Color.lerp(bg, Colors.white, 0.12))) : (bg ?? YmColors.surfaceAlt)),
      foregroundColor: WidgetStatePropertyAll(fg ?? YmColors.textDark),
      iconColor: WidgetStatePropertyAll(fg ?? YmColors.textDark),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, fontSize: 11, height: 14 / 11, letterSpacing: 0.22)),
      iconSize: const WidgetStatePropertyAll(16),
    );

void showSnack(BuildContext context, String text, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Row(children: [
      Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: error ? const Color(0xFFFFB4AB) : const Color(0xFF82F5C1), size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: const TextStyle(fontFamily: kFont, color: Colors.white, fontSize: 13, height: 1.4))),
    ]),
    backgroundColor: error ? const Color(0xFF7A1F1A) : const Color(0xFF213145),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    width: 560,
    duration: Duration(seconds: error ? 6 : 3),
  ));
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String ok = 'Ya', bool danger = false}) async {
  final r = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: const Color(0x590B1C30),
    transitionDuration: motion(context, const Duration(milliseconds: 220)),
    transitionBuilder: (c, a, _, child) {
      final curved = CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
      return FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(curved), child: child));
    },
    pageBuilder: (c, _, __) => AlertDialog(
      icon: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: danger ? YmColors.dangerSoft : YmColors.primarySoft, borderRadius: BorderRadius.circular(12)),
        child: Icon(danger ? Icons.warning_amber_rounded : Icons.help_outline_rounded, color: danger ? YmColors.danger : YmColors.primary),
      ),
      title: Text(title),
      content: SizedBox(width: 420, child: Text(message, textAlign: TextAlign.center, style: YmTextStyles.chatText.copyWith(color: YmColors.textMuted))),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        OutlinedButton(style: outlineButtonStyle(), onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        ElevatedButton(
          style: primaryButtonStyle(color: danger ? YmColors.danger : null),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Pill status koneksi persis versi web: `px-4 py-1.5 rounded-full
/// bg-secondary-container/40 text-on-secondary-fixed-variant` + titik berdenyut (animate-ping).
class NetStatusPill extends StatelessWidget {
  final NetStatus status;
  final bool onDark;

  /// Tampilkan jumlah dokumen yang masih di PC (top bar).
  final bool detailed;

  /// Teks pendek (top bar di layar sempit).
  final bool compact;
  const NetStatusPill({super.key, required this.status, this.onDark = false, this.detailed = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final local = app.session == null ? 0 : app.pendingCount + app.draftCount;
    var (Color dot, Color bg, Color fg, String text) = switch (status) {
      NetStatus.online => (
          YmColors.success,
          YmColors.successContainer.withOpacity(0.4),
          YmColors.onSuccessSoft,
          detailed && local > 0 ? 'Online: $local dokumen sedang dikirim' : 'Online: tersinkron dengan server'
        ),
      NetStatus.offline => (
          YmColors.success,
          YmColors.successContainer.withOpacity(0.4),
          YmColors.onSuccessSoft,
          detailed ? 'Mode Offline: $local dokumen di PC, sinkron otomatis' : 'Mode Offline: data disimpan di PC'
        ),
      NetStatus.checking => (YmColors.primary, YmColors.primaryFixed, YmColors.onPrimaryFixed, 'Memeriksa server…'),
      NetStatus.notConfigured => (YmColors.outline, YmColors.surfaceContainer, YmColors.textMuted, 'Belum terhubung ke server'),
    };
    if (compact) {
      text = switch (status) {
        NetStatus.online => local > 0 ? 'Online • $local dikirim' : 'Online',
        NetStatus.offline => local > 0 ? 'Mode Offline • $local di PC' : 'Mode Offline',
        NetStatus.checking => 'Memeriksa…',
        NetStatus.notConfigured => 'Belum terhubung',
      };
    }
    return AnimatedContainer(
      duration: motion(context),
      curve: kMotionCurve,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: onDark ? Colors.white.withOpacity(0.10) : bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseDot(color: dot, pulse: status != NetStatus.notConfigured),
          const SizedBox(width: 4),
          Flexible(
            child: AnimatedSwitcher(
              duration: motion(context),
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a), child: c),
              ),
              child: Text(
                text,
                key: ValueKey(text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: YmTextStyles.labelSm.copyWith(fontWeight: FontWeight.w500, color: onDark ? Colors.white : fg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Titik status yang berdenyut (versi web: animate-ping).
class PulseDot extends StatefulWidget {
  final Color color;
  final bool pulse;
  final double size;
  const PulseDot({super.key, required this.color, this.pulse = true, this.size = 8});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant PulseDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.pulse && !reduceMotion(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2,
      height: s * 2,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = Curves.easeOut.transform(_c.value);
          return Stack(alignment: Alignment.center, children: [
            if (widget.pulse)
              // animate-ping: membesar sampai 2x sambil memudar dari 75%
              Container(
                width: s * (1 + t),
                height: s * (1 + t),
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(0.75 * (1 - t))),
              ),
            Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
          ]);
        },
      ),
    );
  }
}

/// Logo aplikasi persis versi web: `w-9 h-9 rounded-xl bg-primary-container`
/// dengan ikon arsip putih 20 + shadow-sm.
class ArsipLogo extends StatelessWidget {
  final double size;
  const ArsipLogo({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: YmColors.primaryContainer, borderRadius: BorderRadius.circular(size / 3), boxShadow: shadowSm),
      child: Icon(Icons.archive_outlined, color: Colors.white, size: size * 0.56),
    );
  }
}

/// Keluar aplikasi (window fullscreen tidak punya tombol X).
Future<void> confirmExit(BuildContext context) async {
  final pending = AppState.instance.allDocs.where((d) => d.isUnsynced && d.status.name != 'failed').length;
  final tray = TrayService.isReady;
  final choice = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Keluar aplikasi?'),
      content: SizedBox(
        width: 440,
        child: Text(
          [
            if (pending > 0)
              'Masih ada $pending dokumen yang belum terupload. Data aman di PC ini dan akan diunggah otomatis saat aplikasi dibuka lagi dan internet tersedia.'
            else
              'Aplikasi Arsip Dokumen PU akan ditutup.',
            if (tray) '\nPilih "Kecilkan ke tray" supaya aplikasi tetap berjalan di pojok kanan bawah taskbar dan antrian terus diunggah.',
          ].join('\n'),
          style: YmTextStyles.chatText.copyWith(color: YmColors.textMuted),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, 'cancel'), child: const Text('Batal')),
        if (tray)
          OutlinedButton.icon(
            style: outlineButtonStyle(),
            onPressed: () => Navigator.pop(c, 'tray'),
            icon: const Icon(Icons.south_east_rounded, size: 17),
            label: const Text('Kecilkan ke tray'),
          ),
        ElevatedButton(
          style: primaryButtonStyle(color: YmColors.danger),
          onPressed: () => Navigator.pop(c, 'exit'),
          child: const Text('Keluar'),
        ),
      ],
    ),
  );
  if (choice == 'tray') {
    await TrayService.hideToTray();
    return;
  }
  if (choice != 'exit') return;
  await TrayService.quit();
}

Future<void> toggleFullScreen() => WindowCtl.toggleFullScreen();
