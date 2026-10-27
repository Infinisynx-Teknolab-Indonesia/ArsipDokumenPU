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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  WindowCtl.init(); // status full screen selalu sesuai kondisi jendela
  // Mesin PDF (PDFium) siap dipakai juga untuk mencetak, walau penampil PDF belum dibuka.
  // ignore: discarded_futures, unawaited_futures
  pdfrxFlutterInitialize();

  const options = WindowOptions(
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
    return MaterialApp(
      title: 'Arsip Dokumen PU',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: YmColors.accentPurple, primary: YmColors.accentPurple),
        scaffoldBackgroundColor: YmColors.panelBackground,
        fontFamily: 'Segoe UI',
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      // F11 = keluar/masuk full screen di layar mana pun.
      builder: (context, child) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f11): toggleFullScreen,
          // macOS: Ctrl + Cmd + F (standar Mac untuk layar penuh)
          const SingleActivator(LogicalKeyboardKey.keyF, control: true, meta: true): toggleFullScreen,
          // Ctrl+F / ⌘F di mana saja = pencarian (lihat services/find_shortcut.dart)
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => FindShortcut.run(appNavigatorKey.currentState),
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () => FindShortcut.run(appNavigatorKey.currentState),
        },
        child: Focus(
          autofocus: true,
          // Title bar: tampil di mode jendela; saat full screen tersembunyi
          // (muncul bila mouse diarahkan ke tepi atas layar).
          child: WindowFrame(child: child ?? const SizedBox()),
        ),
      ),
      navigatorKey: appNavigatorKey,
      home: const RootGate(),
    );
  }
}

/// Menampilkan Login atau Shell sesuai ada/tidaknya sesi.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) => AppState.instance.session == null ? const LoginScreen() : const ShellScreen(),
    );
  }
}
