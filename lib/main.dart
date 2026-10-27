import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart' show pdfrxFlutterInitialize;
import 'package:window_manager/window_manager.dart';
import 'theme/ym_theme.dart';
import 'services/app_state.dart';
import 'services/tray_service.dart';
import 'services/window_ctl.dart';
import 'widgets/app_title_bar.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'widgets/common.dart';
import 'services/find_shortcut.dart';
import 'services/nav.dart';
import 'services/shortcuts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  WindowCtl.init(); // status full screen selalu sesuai kondisi jendela
  // Mesin PDF (PDFium) siap dipakai juga untuk mencetak, walau penampil PDF belum dibuka.
  // ignore: discarded_futures, unawaited_futures
  pdfrxFlutterInitialize();

  final options = WindowOptions(
    size: Size(1366, 768),
    minimumSize: Size(1100, 680),
    center: true,
    title: 'Arsip Dokumen PU',
    backgroundColor: YmColors.heroGradientTop,
    // Title bar bawaan Windows disembunyikan, diganti AppTitleBar (gaya Batam ChitChat)
    titleBarStyle: TitleBarStyle.hidden,
    skipTaskbar: false,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
    await WindowCtl.enterFullScreen(); // mulai full screen
  });

  await AppState.instance.load();
  await ThemeCtl.instance.load(); // tema pilihan pengguna (Pengaturan → Tema tampilan)
  await ShortcutCtl.instance.load(); // pintasan keyboard (Pengaturan → Pintasan keyboard)
  ShortcutCtl.instance.install({
    AppAction.globalSearch: _focusGlobalSearch,
    AppAction.pageFind: () => FindShortcut.run(appNavigatorKey.currentState),
    AppAction.fullscreen: () => toggleFullScreen(),
    AppAction.upload: () {
      if (AppState.instance.session == null) return;
      appNavigatorKey.currentState?.popUntil((r) => r.isFirst);
      Nav.go('upload');
    },
    AppAction.sync: () {
      final app = AppState.instance;
      if (app.session != null && !app.setupMode && !app.syncing) app.tick(forcePull: true);
    },
  });
  // System tray persis Batam ChitChat: klik kanan -> Buka / Logout / Keluar.
  // "Keluar" dari tray langsung menutup aplikasi.
  await TrayService.init(
    onExitRequested: () => TrayService.quit(),
    onLogoutRequested: () {
      final ctx = appNavigatorKey.currentContext;
      if (AppState.instance.session == null || ctx == null) return;
      confirmDialog(ctx, title: 'Logout?', message: 'Anda akan kembali ke halaman login. Dokumen yang belum terupload tetap aman di PC ini.', ok: 'Logout')
          .then((ok) {
        if (ok) AppState.instance.logout();
      });
    },
  );
  runApp(const ArsipApp());
}

/// Untuk menampilkan dialog dari menu tray (di luar widget tree).
final appNavigatorKey = GlobalKey<NavigatorState>();

class ArsipApp extends StatelessWidget {
  const ArsipApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Dibangun ulang saat tema / setelan animasi diganti.
    return ListenableBuilder(
      listenable: ThemeCtl.instance,
      builder: (context, _) => MaterialApp(
        title: 'Arsip Dokumen PU',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(), // lihat theme/ym_theme.dart
        themeAnimationDuration: const Duration(milliseconds: 350),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            // "Kurangi animasi" dari Pengaturan aplikasi ATAU dari Windows/macOS
            data: mq.copyWith(disableAnimations: mq.disableAnimations || ThemeCtl.instance.lessMotion),
            // Pintasan keyboard (Ctrl+K, Ctrl+F, F11, ...) dipasang global lewat
            // ShortcutCtl (services/shortcuts.dart) — bisa diatur di Pengaturan.
            child: CallbackShortcuts(
              bindings: const {},
              child: Focus(
                autofocus: true,
                // Title bar: tampil di mode jendela; saat full screen tersembunyi
                // (muncul bila mouse diarahkan ke tepi atas layar).
                child: WindowFrame(child: child ?? const SizedBox()),
              ),
            ),
          );
        },
        navigatorKey: appNavigatorKey,
        home: const RootGate(),
      ),
    );
  }
}

void _focusGlobalSearch() {
  if (AppState.instance.session == null) return;
  appNavigatorKey.currentState?.popUntil((r) => r.isFirst);
  WidgetsBinding.instance.addPostFrameCallback((_) => Nav.globalSearchFocus.requestFocus());
}

/// Menampilkan Login atau Shell sesuai ada/tidaknya sesi.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    // key = generasi tema: saat tema diganti, layar dibangun ulang dengan warna baru.
    return ListenableBuilder(
      listenable: Listenable.merge([AppState.instance, ThemeCtl.instance]),
      builder: (context, _) {
        final g = ThemeCtl.instance.generation;
        return AppState.instance.session == null ? LoginScreen(key: ValueKey('login$g')) : ShellScreen(key: ValueKey('shell$g'));
      },
    );
  }
}
