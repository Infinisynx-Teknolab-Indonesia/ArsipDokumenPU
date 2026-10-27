import 'package:flutter/material.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../services/tray_service.dart';
import '../services/window_ctl.dart';

/// Panel putih berbingkai lavender — gaya kartu Batam ChitChat.
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
    return Container(
      decoration: BoxDecoration(
        color: YmColors.contentBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: YmColors.borderLavender),
        boxShadow: [BoxShadow(color: YmColors.accentBlue.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: YmColors.panelBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: YmColors.borderLavender)),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[Icon(icon, size: 16, color: YmColors.accentPurple), const SizedBox(width: 8)],
                  Expanded(child: Text(title!, style: YmTextStyles.username.copyWith(fontSize: 13))),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          // Material transparan: efek klik ListTile/InkWell tergambar DI ATAS
          // latar putih panel (tanpa ini Flutter terus memberi peringatan
          // "ListTile background color or ink splashes may be invisible").
          if (expand)
            Expanded(child: Material(type: MaterialType.transparency, child: Padding(padding: padding, child: child)))
          else
            Material(type: MaterialType.transparency, child: Padding(padding: padding, child: child)),
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
      fillColor: YmColors.panelBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      labelStyle: const TextStyle(color: YmColors.textMuted, fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: YmColors.borderLavender)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: YmColors.borderLavender)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: YmColors.accentPurple, width: 1.5)),
    );

ButtonStyle primaryButtonStyle({Color color = YmColors.accentPurple}) => ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      disabledBackgroundColor: YmColors.borderLavender,
      disabledForegroundColor: YmColors.textMuted,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    );

ButtonStyle outlineButtonStyle() => OutlinedButton.styleFrom(
      foregroundColor: YmColors.accentPurple,
      side: const BorderSide(color: YmColors.borderLavender),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    );

void showSnack(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text),
    backgroundColor: error ? YmColors.buzzRed : YmColors.titleBarStart,
    behavior: SnackBarBehavior.floating,
    width: 520,
    duration: Duration(seconds: error ? 6 : 3),
  ));
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String ok = 'Ya', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: YmTextStyles.username.copyWith(fontSize: 15)),
      content: SizedBox(width: 420, child: Text(message, style: YmTextStyles.chatText.copyWith(fontSize: 13))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        ElevatedButton(
          style: primaryButtonStyle(color: danger ? YmColors.buzzRed : YmColors.accentPurple),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withOpacity(0.12) : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: onDark ? Colors.white : YmColors.textDark)),
        ],
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [YmColors.accentPurple, YmColors.titleBarEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [BoxShadow(color: YmColors.accentPurple.withOpacity(0.45), blurRadius: size * 0.3, offset: Offset(0, size * 0.08))],
      ),
      child: Icon(Icons.inventory_2_rounded, color: Colors.white, size: size * 0.55),
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
      title: Text('Keluar aplikasi?', style: YmTextStyles.username.copyWith(fontSize: 15)),
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
          style: YmTextStyles.chatText.copyWith(fontSize: 13),
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
