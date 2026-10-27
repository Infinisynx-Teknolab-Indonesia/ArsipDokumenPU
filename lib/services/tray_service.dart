import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../core/local_db.dart';
import 'window_ctl.dart';

/// System tray — dibuat PERSIS seperti Batam ChitChat:
/// - Ikon di pojok kanan bawah taskbar
/// - Klik kiri  : buka / munculkan jendela
/// - Klik kanan : menu  "Buka Arsip Dokumen PU" | "Logout" | "Keluar"
/// - "Keluar"   : langsung menutup aplikasi
/// - Tombol X jendela: sembunyikan ke tray (aplikasi tetap jalan, antrian upload tetap terkirim)
///
/// Setiap tahap dibungkus try/catch sendiri (sama seperti ChitChat). Kalau ikon atau
/// menu gagal dipasang, tombol X tetap menutup aplikasi biasa supaya jendela tidak
/// "hilang" tanpa jalan kembali.
class TrayService {
  static bool _initialized = false;
  static bool _ready = false;

  static void Function()? _onExit;
  static void Function()? _onLogout;

  static bool get isReady => _ready;

  static Future<void> init({
    required void Function() onExitRequested,
    required void Function() onLogoutRequested,
  }) async {
    _onExit = onExitRequested;
    _onLogout = onLogoutRequested;
    if (_initialized) return;
    _initialized = true;

    // Listener dipasang PALING AWAL — walau ikon/menu gagal sebagian, klik tetap ditangani.
    trayManager.addListener(_TrayServiceListener());

    bool iconOk = false;
    bool menuOk = false;

    try {
      if (Platform.isMacOS) {
        // macOS: ikon menu bar hitam-putih (template) dari aset; warnanya
        // otomatis mengikuti mode terang/gelap. Ikon Dock dari AppIcon.
        await trayManager.setIcon('assets/icons/tray_icon_mac.png', isTemplate: true, iconSize: 18);
        iconOk = true;
      } else {
        final bytes = await rootBundle.load('assets/icons/app_icon.ico');
        final iconFile = File('${LocalDb.tempDir('tray').path}${Platform.pathSeparator}arsip_dokumen_tray.ico');
        await iconFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
        await trayManager.setIcon(iconFile.path);
        iconOk = true;
        // ikon jendela/taskbar juga (berlaku walau exe masih ikon bawaan Flutter)
        try {
          await windowManager.setIcon(iconFile.path);
        } catch (_) {}
      }
    } catch (e) {
      // ignore: avoid_print
      print('[TrayService] setIcon gagal: $e');
    }

    try {
      await trayManager.setToolTip('Arsip Dokumen PU');
    } catch (e) {
      // ignore: avoid_print
      print('[TrayService] setToolTip gagal: $e');
    }

    try {
      final menu = Menu(items: [
        MenuItem(key: 'show', label: 'Buka Arsip Dokumen PU'),
        MenuItem.separator(),
        MenuItem(key: 'logout', label: 'Logout'),
        MenuItem(key: 'exit', label: 'Keluar'),
      ]);
      await trayManager.setContextMenu(menu);
      menuOk = true;
    } catch (e) {
      // ignore: avoid_print
      print('[TrayService] setContextMenu gagal: $e');
    }

    // Tombol X = sembunyikan ke tray, HANYA kalau ikon + menu tray berhasil dipasang.
    if (iconOk && menuOk) {
      try {
        await windowManager.setPreventClose(true);
        windowManager.addListener(_WindowCloseListener());
        _ready = true;
      } catch (e) {
        // ignore: avoid_print
        print('[TrayService] setPreventClose gagal: $e');
      }
    } else {
      // ignore: avoid_print
      print('[TrayService] Tray belum lengkap (icon=$iconOk, menu=$menuOk) — tombol X menutup aplikasi biasa.');
    }
  }

  static Future<void> showWindow() => WindowCtl.show();

  /// Sembunyikan jendela ke tray (tombol "Kecilkan ke tray").
  static Future<void> hideToTray() async {
    if (_ready) {
      await windowManager.hide();
    } else {
      await windowManager.minimize();
    }
  }

  /// Tutup aplikasi sepenuhnya: hapus ikon tray dulu supaya tidak tertinggal.
  static Future<void> quit() async {
    try {
      await trayManager.destroy();
    } catch (_) {}
    try {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (_) {}
    exit(0);
  }
}

class _TrayServiceListener with TrayListener {
  @override
  void onTrayIconMouseDown() {
    // Klik kiri — munculkan jendela.
    WindowCtl.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    // Klik kanan — di Windows menu harus dimunculkan manual.
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') {
      WindowCtl.show();
    } else if (menuItem.key == 'logout') {
      // Munculkan jendela dulu supaya dialog konfirmasi logout terlihat.
      WindowCtl.show();
      TrayService._onLogout?.call();
    } else if (menuItem.key == 'exit') {
      TrayService._onExit?.call();
    }
  }
}

class _WindowCloseListener with WindowListener {
  @override
  void onWindowClose() async {
    final isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
    }
  }
}
