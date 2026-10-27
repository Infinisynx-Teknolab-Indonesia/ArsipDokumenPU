import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/ym_theme.dart';
import '../services/tray_service.dart';
import '../services/window_ctl.dart';

/// Title bar sendiri (gaya Batam ChitChat) menggantikan title bar bawaan Windows:
/// - seret untuk memindahkan jendela, klik dua kali untuk maximize
/// - tombol: Full screen / keluar full screen, Minimize, Maximize, Tutup (ke tray)
/// Selalu tampil, juga saat full screen, supaya selalu ada tombol untuk
/// kembali ke full screen atau mengecilkan jendela.
class AppTitleBar extends StatelessWidget {
  const AppTitleBar({super.key});

  void _safe(Future<void> Function() f) {
    f().catchError((e) {
      // ignore: avoid_print
      print('[AppTitleBar] $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    // Material transparan: title bar berada di atas Navigator, perlu Material untuk gaya teks.
    return Material(
      color: Colors.transparent,
      child: _bar(),
    );
  }

  Widget _bar() {
    return SizedBox(
      height: 34,
      child: Stack(
        children: [
          Positioned.fill(
            child: DragToMoveArea(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [YmColors.titleBarStart, YmColors.titleBarEnd]),
                ),
                child: Stack(children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white.withOpacity(0.30), Colors.white.withOpacity(0.0)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(bottom: 0, left: 0, right: 0, child: Container(height: 1.5, color: Colors.black.withOpacity(0.18))),
                ]),
              ),
            ),
          ),
          Row(
            children: [
              // macOS: sisakan tempat untuk tombol bulat merah/kuning/hijau bawaan sistem
              SizedBox(width: Platform.isMacOS ? 78 : 10),
              const IgnorePointer(child: Icon(Icons.inventory_2_rounded, color: Colors.white, size: 16)),
              const SizedBox(width: 8),
              const IgnorePointer(
                child: Text('Arsip Dokumen PU', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              ValueListenableBuilder<bool>(
                valueListenable: WindowCtl.isFull,
                builder: (_, full, __) => _TitleBarButton(
                  icon: full ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  iconSize: 18,
                  tooltip: full ? 'Keluar dari full screen (F11)' : 'Full screen (F11)',
                  onTap: () => _safe(WindowCtl.toggleFullScreen),
                ),
              ),
              // Windows: tombol jendela sendiri. macOS memakai tombol bawaan sistem.
              if (!Platform.isMacOS) ...[
              _TitleBarButton(
                icon: Icons.remove,
                tooltip: 'Minimize',
                onTap: () => _safe(() async {
                  if (WindowCtl.isFull.value) await WindowCtl.exitFullScreen();
                  await windowManager.minimize();
                }),
              ),
              _TitleBarButton(
                icon: Icons.crop_square,
                iconSize: 12,
                tooltip: 'Maximize / Restore',
                onTap: () => _safe(() async {
                  if (WindowCtl.isFull.value) {
                    await WindowCtl.exitFullScreen();
                    return;
                  }
                  if (await windowManager.isMaximized()) {
                    await windowManager.unmaximize();
                  } else {
                    await windowManager.maximize();
                  }
                }),
              ),
              _TitleBarButton(
                icon: Icons.close,
                hoverColor: YmColors.buzzRed,
                tooltip: 'Tutup (aplikasi tetap berjalan di system tray)',
                onTap: () => _safe(TrayService.hideToTray),
              ),
              ],
              if (Platform.isMacOS) const SizedBox(width: 6),
            ],
          ),
        ],
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;
  final Color? hoverColor;
  final String tooltip;

  const _TitleBarButton({required this.icon, required this.onTap, required this.tooltip, this.iconSize = 14, this.hoverColor});

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    // Tanpa Tooltip: title bar ini berada di atas Navigator (tidak ada Overlay).
    return Semantics(
      label: widget.tooltip,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 44,
            height: 34,
            color: _hover ? (widget.hoverColor ?? Colors.white.withOpacity(0.2)) : Colors.transparent,
            alignment: Alignment.center,
            child: Icon(widget.icon, size: widget.iconSize, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Bingkai jendela utama:
/// - Mode jendela biasa : title bar selalu tampil di atas.
/// - Mode FULL SCREEN   : title bar disembunyikan (layar penuh sungguhan). Arahkan
///   mouse ke tepi paling atas layar -> title bar turun (untuk keluar full screen,
///   minimize, atau tutup ke tray), lalu naik lagi saat mouse menjauh.
class WindowFrame extends StatefulWidget {
  final Widget child;
  const WindowFrame({super.key, required this.child});

  @override
  State<WindowFrame> createState() => _WindowFrameState();
}

class _WindowFrameState extends State<WindowFrame> {
  bool _reveal = false;

  /// GlobalKey: isi aplikasi dipindah antara Column (jendela) dan Stack (full screen)
  /// tanpa kehilangan state (halaman aktif, isian form, dialog).
  final _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: WindowCtl.isFull,
      builder: (context, full, _) {
        if (!full) {
          return Column(children: [
            const AppTitleBar(),
            Expanded(child: KeyedSubtree(key: _contentKey, child: widget.child)),
          ]);
        }
        return Stack(
          children: [
            Positioned.fill(child: KeyedSubtree(key: _contentKey, child: widget.child)),
            // zona sensor tipis di tepi atas layar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 6,
              child: MouseRegion(
                opaque: false,
                onEnter: (_) => setState(() => _reveal = true),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              top: _reveal ? 0 : -40,
              left: 0,
              right: 0,
              child: MouseRegion(
                onExit: (_) => setState(() => _reveal = false),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 12)],
                  ),
                  child: const AppTitleBar(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
