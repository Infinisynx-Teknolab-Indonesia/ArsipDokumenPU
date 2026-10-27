import 'dart:async';
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import '../services/nav.dart';
import '../services/tray_service.dart';
import '../pages/dashboard_page.dart';
import '../pages/upload_page.dart';
import '../pages/documents_page.dart';
import '../pages/projects_page.dart';
import '../pages/users_page.dart';
import '../pages/audit_page.dart';
import '../pages/server_page.dart';
import '../pages/settings_page.dart';
import '../pages/profile_page.dart';
import '../pages/help_page.dart';
import '../pages/requests_page.dart';
import '../pages/terms_page.dart';

class _NavItem {
  final String id;
  final String label;
  final IconData icon;
  final String group; // Arsip | Pengelolaan | Akun
  final String hint; // keterangan singkat di bawah judul halaman
  final bool adminOnly;
  const _NavItem(this.id, this.label, this.icon, this.group, this.hint, {this.adminOnly = false});
}

const _nav = [
  _NavItem('dashboard', 'Dashboard', Icons.space_dashboard_outlined, 'Arsip', 'Ringkasan arsip dan antrian unggah'),
  _NavItem('upload', 'Unggah Dokumen', Icons.upload_file_outlined, 'Arsip', 'Simpan dokumen baru ke arsip'),
  _NavItem('mydocs', 'Dokumen Saya', Icons.assignment_ind_outlined, 'Arsip', 'Dokumen yang Anda input, termasuk draf dan antrian'),
  _NavItem('docs', 'Arsip Dokumen', Icons.folder_open_outlined, 'Arsip', 'Cari dan buka seluruh arsip — Ctrl+F untuk mencari'),
  _NavItem('requests', 'Permintaan Edit', Icons.rate_review_outlined, 'Arsip', 'Perubahan dokumen yang menunggu persetujuan admin'),
  _NavItem('projects', 'Proyek / Paket', Icons.engineering_outlined, 'Pengelolaan', 'Paket pekerjaan beserta dokumennya'),
  _NavItem('terms', 'Kamus Pencarian', Icons.menu_book_outlined, 'Pengelolaan', 'Istilah yang memperluas pencarian, mis. pengeluaran = 544'),
  _NavItem('users', 'Staf & Admin', Icons.groups_outlined, 'Pengelolaan', 'Akun yang boleh login', adminOnly: true),
  _NavItem('audit', 'Log Aktivitas', Icons.history_rounded, 'Pengelolaan', 'Jejak login, unggah, unduh, dan perubahan', adminOnly: true),
  _NavItem('server', 'Server API', Icons.dns_outlined, 'Pengelolaan', 'Alamat server dan perangkat terdaftar', adminOnly: true),
  _NavItem('profile', 'Profil Saya', Icons.account_circle_outlined, 'Akun', 'Akun dan catatan kerja Anda'),
  _NavItem('settings', 'Penyimpanan & Info', Icons.storage_outlined, 'Akun', 'Data yang tersimpan di PC ini'),
  _NavItem('help', 'Panduan', Icons.help_outline_rounded, 'Akun', 'Cara memakai aplikasi'),
];

/// Kerangka utama setelah login: sidebar kiri + header + halaman.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  String get _active => Nav.page.value;

  @override
  void initState() {
    super.initState();
    // Admin default (belum ada server) langsung diarahkan ke Server API.
    Nav.page.value = AppState.instance.session?.isSetupAdmin == true ? 'server' : 'dashboard';
    Nav.page.addListener(_onNav);
  }

  @override
  void dispose() {
    Nav.page.removeListener(_onNav);
    super.dispose();
  }

  void _onNav() => setState(() {});

  void go(String id) => Nav.go(id);

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.session;
        if (s == null) return const SizedBox();
        final items = _nav.where((n) => !n.adminOnly || s.isAdmin).toList();
        final current = items.where((n) => n.id == _active).firstOrNull ?? items.first;

        return Scaffold(
          body: Row(
            children: [
              _Sidebar(items: items, active: _active, onSelect: go),
              Expanded(
                child: Column(
                  children: [
                    _Header(title: current.label, hint: current.hint),
                    if (app.syncMessage != null) _Banner(text: app.syncMessage!),
                    Expanded(
                      child: _AnimatedPages(
                        index: items.indexOf(current),
                        children: [
                          for (final n in items)
                            switch (n.id) {
                              'dashboard' => const DashboardPage(),
                              'upload' => const UploadPage(),
                              'mydocs' => const DocumentsPage(mineOnly: true),
                              'docs' => const DocumentsPage(),
                              'profile' => const ProfilePage(),
                              'help' => const HelpPage(),
                              'requests' => const RequestsPage(),
                              'terms' => const TermsPage(),
                              'projects' => const ProjectsPage(),
                              'users' => const UsersPage(),
                              'audit' => const AuditPage(),
                              'server' => const ServerPage(),
                              _ => const SettingsPage(),
                            },
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Halaman berganti dengan animasi geser + pudar. Semua halaman tetap hidup
/// (isian form, hasil cari, posisi gulir tidak hilang) — strukturnya sama
/// seperti IndexedStack, hanya halaman yang baru dibuka yang dianimasikan.
class _AnimatedPages extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const _AnimatedPages({required this.index, required this.children});

  @override
  State<_AnimatedPages> createState() => _AnimatedPagesState();
}

class _AnimatedPagesState extends State<_AnimatedPages> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: kMotion, value: 1);
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: kMotionCurve);
  late final Animation<Offset> _slide = Tween(begin: const Offset(0.025, 0), end: Offset.zero).animate(_curve);

  @override
  void didUpdateWidget(covariant _AnimatedPages old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _c.duration = motion(context);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _still = AlwaysStoppedAnimation<double>(1);
  static const _stillOffset = AlwaysStoppedAnimation<Offset>(Offset.zero);

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          FadeTransition(
            opacity: i == widget.index ? _curve : _still,
            child: SlideTransition(
              position: i == widget.index ? _slide : _stillOffset,
              child: widget.children[i],
            ),
          ),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<_NavItem> items;
  final String active;
  final ValueChanged<String> onSelect;
  const _Sidebar({required this.items, required this.active, required this.onSelect});

  static const _itemH = 40.0;
  static const _itemGap = 2.0;
  static const _groupH = 34.0;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final s = app.session!;

    // susun: judul kelompok + item; hitung posisi item aktif untuk penanda marka
    final entries = <Widget>[];
    double y = 0, activeTop = -1;
    String? group;
    for (final n in items) {
      if (n.group != group) {
        group = n.group;
        entries.add(SizedBox(
          height: _groupH,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 0, 8),
              child: Text(n.group, style: TextStyle(fontFamily: kFont, color: Colors.white.withOpacity(0.38), fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ));
        y += _groupH;
      }
      if (n.id == active) activeTop = y;
      entries.add(_SideItem(
        icon: n.icon,
        label: n.label,
        active: n.id == active,
        badge: n.id == 'mydocs' && app.myUnsyncedCount > 0
            ? '${app.myUnsyncedCount}'
            : n.id == 'requests' && app.pendingRequests > 0
                ? '${app.pendingRequests}'
                : null,
        onTap: () => onSelect(n.id),
      ));
      y += _itemH + _itemGap;
    }

    final name = s.fullName.isNotEmpty ? s.fullName : s.username;
    return Container(
      width: 256,
      color: YmColors.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
            child: Row(
              children: [
                const ArsipLogo(size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Arsip Dokumen PU',
                          style: TextStyle(fontFamily: kFont, color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2)),
                      Text(app.agencyName,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kFont, color: Colors.white.withOpacity(0.5), fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: Stack(
                children: [
                  // Penanda menu aktif: garis marka kuning yang meluncur
                  if (activeTop >= 0)
                    AnimatedPositioned(
                      duration: motion(context),
                      curve: kMotionCurve,
                      left: 0,
                      top: activeTop + 10,
                      child: Container(
                        width: 4,
                        height: _itemH - 20,
                        decoration: const BoxDecoration(
                          color: YmColors.marka,
                          borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                        ),
                      ),
                    ),
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: entries),
                ],
              ),
            ),
          ),
          const _SyncCard(),
          // Pengguna + logout / keluar
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: YmColors.inkLine,
                  child: Text(name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontFamily: kFont, color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: kFont, color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
                      Text('${s.isAdmin ? 'Admin' : 'Staf'} · @${s.username}${s.offline ? ' · offline' : ''}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: kFont, color: Colors.white.withOpacity(0.5), fontSize: 11)),
                    ],
                  ),
                ),
                _DarkIconButton(
                  icon: Icons.logout_rounded,
                  tooltip: 'Logout',
                  onTap: () async {
                    if (await confirmDialog(context,
                        title: 'Logout?', message: 'Anda akan kembali ke halaman login. Dokumen yang belum terupload tetap aman di PC ini.', ok: 'Logout')) {
                      app.logout();
                    }
                  },
                ),
                _DarkIconButton(icon: Icons.power_settings_new_rounded, tooltip: 'Keluar aplikasi', onTap: () => confirmExit(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _DarkIconButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 18, color: Colors.white.withOpacity(0.6)),
        hoverColor: Colors.white.withOpacity(0.08),
      );
}

class _SideItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final String? badge;
  final VoidCallback onTap;
  const _SideItem({required this.icon, required this.label, required this.active, required this.onTap, this.badge});

  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final fg = w.active ? Colors.white : Colors.white.withOpacity(_hover ? 0.92 : 0.68);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, _Sidebar._itemGap),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: w.onTap,
          child: AnimatedContainer(
            duration: motion(context, kMotionFast),
            height: _Sidebar._itemH,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: w.active ? Colors.white.withOpacity(0.09) : (_hover ? Colors.white.withOpacity(0.04) : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(w.icon, color: w.active ? YmColors.marka : fg, size: 19),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(w.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: kFont, color: fg, fontSize: 13, fontWeight: w.active ? FontWeight.w700 : FontWeight.w500)),
                ),
                if (w.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: YmColors.marka, borderRadius: BorderRadius.circular(10)),
                    child: Text(w.badge!, style: const TextStyle(fontFamily: kFont, color: YmColors.ink, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Status sinkronisasi di sidebar — satu baris ringkas + tombol sinkron.
class _SyncCard extends StatelessWidget {
  const _SyncCard();

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final pending = app.pendingCount;
    final failed = app.failedCount;
    final String line;
    if (app.setupMode) {
      line = pending > 0 ? '$pending dokumen menunggu server diatur' : 'Server belum diatur';
    } else if (app.syncing) {
      line = 'Mengunggah…';
    } else if (pending > 0) {
      line = app.isOnline ? '$pending dokumen dalam antrian' : '$pending dokumen menunggu koneksi';
    } else {
      line = 'Semua dokumen tersimpan di server';
    }
    final muted = TextStyle(fontFamily: kFont, color: Colors.white.withOpacity(0.45), fontSize: 11);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: app.syncing
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: YmColors.marka))
                : Icon(pending > 0 ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined, size: 17,
                    color: pending > 0 ? YmColors.marka : Colors.white.withOpacity(0.6)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line, style: const TextStyle(fontFamily: kFont, color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                if (failed > 0)
                  InkWell(
                    onTap: () => Nav.showMyDocs('failed'),
                    child: Text('$failed gagal — lihat', style: const TextStyle(fontFamily: kFont, color: Color(0xFFFFA4A4), fontSize: 11, decoration: TextDecoration.underline)),
                  )
                else if (app.lastSyncAt != null)
                  Text('Sinkron ${formatDateTime(app.lastSyncAt)}', style: muted),
              ],
            ),
          ),
          if (!app.setupMode)
            _DarkIconButton(
              icon: Icons.sync_rounded,
              tooltip: 'Sinkronkan sekarang',
              onTap: () {
                if (!app.syncing) unawaited(app.tick(forcePull: true));
              },
            ),
        ],
      ),
    );
  }
}

class _Header extends StatefulWidget {
  final String title;
  final String hint;
  const _Header({required this.title, required this.hint});

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  late Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Container(
      height: 78,
      padding: const EdgeInsets.fromLTRB(28, 0, 18, 0),
      decoration: const BoxDecoration(
        color: YmColors.paper,
        border: Border(bottom: BorderSide(color: YmColors.line)),
      ),
      child: Row(
        children: [
          // judul + keterangan; berganti dengan animasi geser saat pindah halaman
          Expanded(
            child: AnimatedSwitcher(
              duration: motion(context),
              switchInCurve: kMotionCurve,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, if (current != null) current]),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(anim), child: child),
              ),
              child: Column(
                key: ValueKey(widget.title),
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: YmTextStyles.pageTitle),
                  const SizedBox(height: 2),
                  Text(widget.hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.label.copyWith(fontSize: 12.5)),
                ],
              ),
            ),
          ),
          if (app.session?.offline == true) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: YmColors.statusAway.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: const Text('Login offline', style: TextStyle(fontFamily: kFont, fontSize: 12, fontWeight: FontWeight.w600, color: YmColors.statusAway)),
            ),
            const SizedBox(width: 10),
          ],
          NetStatusPill(status: app.net),
          const SizedBox(width: 16),
          Text(formatDateTime(_now), style: YmTextStyles.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          _HeaderButton(icon: Icons.south_east_rounded, tooltip: 'Kecilkan ke system tray (aplikasi tetap berjalan)', onTap: TrayService.hideToTray),
          _HeaderButton(icon: Icons.fullscreen_rounded, tooltip: 'Layar penuh (F11)', onTap: toggleFullScreen),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: YmColors.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: Icon(icon, size: 19, color: YmColors.textMuted),
        ),
      );
}

class _Banner extends StatelessWidget {
  final String text;
  const _Banner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: YmColors.marka.withOpacity(0.12),
        border: const Border(bottom: BorderSide(color: YmColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: YmColors.statusAway),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: YmTextStyles.chatText.copyWith(fontSize: 12.5))),
        ],
      ),
    );
  }
}
