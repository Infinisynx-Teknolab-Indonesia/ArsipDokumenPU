import 'package:flutter/material.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../services/tray_service.dart';
import '../services/window_ctl.dart';

/// Kartu konten: putih, garis tepi 1px, tanpa bayangan. Judul (opsional) di
/// baris atas yang dipisah garis tipis — rapi & tenang.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? title;
  final IconData? icon;
  final Widget? trailing;

  /// true = panel mengisi tinggi yang tersedia (child boleh ListView/Expanded).
  /// false (default) = setinggi isinya, aman di dalam scroll view.
  final bool expand;

  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.title, this.icon, this.trailing, this.expand = false});

  @override
  Widget build(BuildContext context) {
    // Material transparan: efek klik ListTile/InkWell tergambar DI ATAS
    // latar putih panel (tanpa ini Flutter terus memberi peringatan
    // "ListTile background color or ink splashes may be invisible").
    final body = Material(type: MaterialType.transparency, child: Padding(padding: padding, child: child));
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: YmColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: YmColors.line),
      ),
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: YmColors.line))),
              child: Row(
                children: [
                  if (icon != null) ...[Icon(icon, size: 18, color: YmColors.puBlue), const SizedBox(width: 10)],
                  Expanded(child: Text(title!, style: YmTextStyles.sectionTitle)),
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
      prefixIcon: icon == null ? null : Icon(icon, size: 18, color: YmColors.textMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: const TextStyle(color: YmColors.textMuted, fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: YmColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: YmColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: YmColors.puBlue, width: 1.6)),
    );

/// Tombol utama: tinta biru tua (atau warna lain untuk aksi khusus, mis. merah = hapus).
/// Warna lama "accentPurple" otomatis diterjemahkan ke tinta supaya semua tombol seragam.
ButtonStyle primaryButtonStyle({Color color = YmColors.ink}) {
  final c = color == YmColors.accentPurple ? YmColors.ink : color;
  return ElevatedButton.styleFrom(
    backgroundColor: c,
    foregroundColor: Colors.white,
    disabledBackgroundColor: YmColors.line,
    disabledForegroundColor: YmColors.textMuted,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, fontSize: 13),
  ).copyWith(
    // sedikit lebih terang saat disorot mouse
    overlayColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.hovered) ? Colors.white.withOpacity(0.08) : null),
  );
}

ButtonStyle outlineButtonStyle() => OutlinedButton.styleFrom(
      foregroundColor: YmColors.textDark,
      backgroundColor: Colors.white,
      side: const BorderSide(color: YmColors.line),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, fontSize: 13),
    );

void showSnack(BuildContext context, String text, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Row(children: [
      Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: error ? const Color(0xFFFFB4B4) : YmColors.marka, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: const TextStyle(fontFamily: kFont, color: Colors.white, fontSize: 13, height: 1.4))),
    ]),
    backgroundColor: error ? const Color(0xFF8E2A2A) : YmColors.ink,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    width: 540,
    duration: Duration(seconds: error ? 6 : 3),
  ));
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String ok = 'Ya', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: SizedBox(width: 420, child: Text(message, style: YmTextStyles.chatText.copyWith(color: YmColors.textMuted))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        ElevatedButton(
          style: primaryButtonStyle(color: danger ? YmColors.buzzRed : YmColors.ink),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Pill status koneksi server.
class NetStatusPill extends StatelessWidget {
  final NetStatus status;
  final bool onDark;
  const NetStatusPill({super.key, required this.status, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final (Color color, String text, IconData icon) = switch (status) {
      NetStatus.online => (YmColors.statusOnline, 'Server online', Icons.cloud_done_rounded),
      NetStatus.offline => (YmColors.buzzRed, 'Offline — data disimpan di PC', Icons.cloud_off_rounded),
      NetStatus.checking => (YmColors.statusAway, 'Memeriksa server...', Icons.cloud_sync_rounded),
      NetStatus.notConfigured => (YmColors.statusOffline, 'Belum terhubung ke server', Icons.link_off_rounded),
    };
    // titik status + teks, tanpa kotak berwarna yang ramai
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: onDark ? Colors.white.withOpacity(0.14) : YmColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(color: color, pulse: status == NetStatus.checking || status == NetStatus.online),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontFamily: kFont, fontSize: 12, fontWeight: FontWeight.w600, color: onDark ? Colors.white : YmColors.textDark)),
        ],
      ),
    );
  }
}

/// Titik status yang berdenyut pelan (menandakan koneksi hidup).
class _PulseDot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _PulseDot({required this.color, required this.pulse});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _PulseDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations == true;
    if (widget.pulse && !reduce) {
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
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          if (widget.pulse)
            Container(
              width: 6 + 8 * _c.value,
              height: 6 + 8 * _c.value,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(0.35 * (1 - _c.value))),
            ),
          Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
        ]),
      ),
    );
  }
}

/// Logo aplikasi (digambar, tanpa file aset).
class ArsipLogo extends StatelessWidget {
  final double size;
  const ArsipLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    // Ubin tinta dengan kotak arsip putih + garis marka kuning di bawah
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: YmColors.puBlue,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Icon(Icons.inventory_2_rounded, color: Colors.white, size: size * 0.52),
        Positioned(
          bottom: size * 0.13,
          child: Container(width: size * 0.34, height: size * 0.06, decoration: BoxDecoration(color: YmColors.marka, borderRadius: BorderRadius.circular(size))),
        ),
      ]),
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
          style: primaryButtonStyle(color: YmColors.buzzRed),
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
