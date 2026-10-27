import 'package:flutter/material.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../services/tray_service.dart';
import '../services/window_ctl.dart';

/// Kartu konten gaya versi web: permukaan putih, sudut 12, bayangan sangat
/// halus. Judul (opsional) di atas dengan ikon kecil di ubin berwarna lembut.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  /// true = panel mengisi tinggi yang tersedia (child boleh ListView/Expanded).
  /// false (default) = setinggi isinya, aman di dalam scroll view.
  final bool expand;

  /// Warna latar lain (mis. kartu peringatan).
  final Color? color;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.expand = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Material transparan: efek klik ListTile/InkWell tergambar di atas latar panel.
    final body = Material(type: MaterialType.transparency, child: Padding(padding: padding, child: child));
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? YmColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: YmColors.isDark ? Border.all(color: YmColors.line) : null,
        boxShadow: softShadow,
      ),
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, size: 18, color: YmColors.primary),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: icon != null ? 6 : 0),
                          child: Text(title!, style: YmTextStyles.sectionTitle),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: YmTextStyles.label.copyWith(fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          if (expand) Expanded(child: body) else body,
        ],
      ),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: YmColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: YmColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: YmColors.primary, width: 1.6)),
    );

/// Kolom cari gaya web: latar biru sangat muda, tanpa garis, sudut 12,
/// berubah putih + cincin warna utama saat aktif.
InputDecoration searchDecoration(String hint, {Widget? suffix}) => InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: YmColors.surfaceAlt,
      hoverColor: YmColors.surfaceContainer,
      prefixIcon: Icon(Icons.search_rounded, size: 20, color: YmColors.outline),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: TextStyle(fontFamily: kFont, color: YmColors.outline, fontSize: 13.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: YmColors.primary.withOpacity(0.35), width: 2)),
    );

/// Tombol utama: warna utama tema (atau warna lain untuk aksi khusus, mis. merah = hapus).
ButtonStyle primaryButtonStyle({Color? color}) {
  final c = color ?? YmColors.primary;
  final fg = c == YmColors.primary ? YmColors.onPrimary : Colors.white;
  return ElevatedButton.styleFrom(
    backgroundColor: c,
    foregroundColor: fg,
    disabledBackgroundColor: YmColors.surfaceContainer,
    disabledForegroundColor: YmColors.outline,
    elevation: 0,
    shadowColor: c.withOpacity(0.35),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, fontSize: 13.5),
  ).copyWith(
    // terangkat sedikit saat disorot (versi web: shadow + hover warna lebih terang)
    elevation: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.hovered) ? 4 : 1),
    overlayColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.hovered) ? Colors.white.withOpacity(0.10) : null),
  );
}

ButtonStyle outlineButtonStyle() => OutlinedButton.styleFrom(
      foregroundColor: YmColors.textDark,
      backgroundColor: YmColors.surface,
      side: BorderSide(color: YmColors.line),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, fontSize: 13),
    );

/// Tombol lembut (versi web: bg-surface-container-low) — untuk aksi di baris daftar.
ButtonStyle softButtonStyle({Color? fg, Color? bg}) => TextButton.styleFrom(
      foregroundColor: fg ?? YmColors.textDark,
      backgroundColor: bg ?? YmColors.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      minimumSize: const Size(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, fontSize: 12),
    ).copyWith(
      overlayColor: WidgetStatePropertyAll(YmColors.primary.withOpacity(0.06)),
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

/// Pill status koneksi (versi web: "Offline Mode: 4 files local, auto-syncing"
/// dengan titik berdenyut).
class NetStatusPill extends StatelessWidget {
  final NetStatus status;
  final bool onDark;

  /// Tampilkan jumlah dokumen yang masih di PC (top bar).
  final bool detailed;
  const NetStatusPill({super.key, required this.status, this.onDark = false, this.detailed = false});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final local = app.session == null ? 0 : app.pendingCount + app.draftCount;
    final (Color color, Color bg, String text) = switch (status) {
      NetStatus.online => (
          YmColors.success,
          YmColors.successSoft,
          detailed && local > 0 ? 'Online · $local dokumen sedang dikirim' : 'Online · tersinkron dengan server'
        ),
      NetStatus.offline => (
          YmColors.warning,
          YmColors.warningSoft,
          detailed ? 'Mode offline: $local dokumen di PC, terkirim otomatis' : 'Offline — data disimpan di PC'
        ),
      NetStatus.checking => (YmColors.primary, YmColors.primarySoft, 'Memeriksa server…'),
      NetStatus.notConfigured => (YmColors.outline, YmColors.surfaceContainer, 'Belum terhubung ke server'),
    };
    return AnimatedContainer(
      duration: motion(context),
      curve: kMotionCurve,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withOpacity(0.10) : bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseDot(color: color, pulse: status != NetStatus.notConfigured),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: motion(context),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a), child: c),
            ),
            child: Text(
              text,
              key: ValueKey(text),
              style: TextStyle(fontFamily: kFont, fontSize: 12, fontWeight: FontWeight.w600, color: onDark ? Colors.white : Color.lerp(color, YmColors.textDark, 0.25)),
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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

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
              Container(
                width: s + s * 1.2 * t,
                height: s + s * 1.2 * t,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(0.55 * (1 - t))),
              ),
            Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
          ]);
        },
      ),
    );
  }
}

/// Logo aplikasi: ubin warna aksen dengan ikon arsip (versi web: rounded-xl bg-primary-container).
class ArsipLogo extends StatelessWidget {
  final double size;
  const ArsipLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(YmColors.primary, Colors.white, 0.12)!, YmColors.primary],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [BoxShadow(color: YmColors.primary.withOpacity(0.28), blurRadius: size * 0.25, offset: Offset(0, size * 0.08))],
      ),
      child: Icon(Icons.archive_outlined, color: Colors.white, size: size * 0.55),
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
