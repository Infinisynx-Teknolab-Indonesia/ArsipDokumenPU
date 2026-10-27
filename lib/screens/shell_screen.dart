import 'dart:async';
import 'package:flutter/material.dart';
import '../core/categories.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';
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
import '../pages/admin_pages.dart';

/// Satu halaman di dalam shell.
class _Page {
  final String id;
  final String label;
  final IconData icon;
  final String group; // '' | Kerja | Admin Server | Akun
  final String hint;
  final bool adminOnly;

  /// true = halaman menggambar judulnya sendiri (PageHeader dengan tombol aksi).
  final bool ownHeader;
  const _Page(this.id, this.label, this.icon, this.group, this.hint, {this.adminOnly = false, this.ownHeader = false});
}

const _pages = [
  _Page('dashboard', 'Dashboard', Icons.space_dashboard_outlined, '', '', ownHeader: true),
  _Page('docs', 'Semua Dokumen', Icons.folder_open_outlined, '', '', ownHeader: true),
  _Page('mydocs', 'Dokumen Saya', Icons.cloud_upload_outlined, '', '', ownHeader: true),
  _Page('local', 'Tersimpan di PC Ini', Icons.laptop_mac_outlined, '', '', ownHeader: true),
  _Page('upload', 'Unggah Dokumen', Icons.upload_file_outlined, 'Kerja',
      'Simpan dokumen baru ke arsip. Periksa dulu sebelum dikirim — kalau server mati, dokumen aman di PC dan terkirim otomatis.'),
  _Page('requests', 'Permintaan Edit', Icons.rate_review_outlined, 'Kerja', 'Perubahan data atau file dokumen yang menunggu persetujuan admin.'),
  _Page('projects', 'Proyek / Paket', Icons.engineering_outlined, 'Kerja', 'Paket pekerjaan jalan, jembatan, dan gedung beserta seluruh dokumennya.'),
  _Page('terms', 'Kamus Pencarian', Icons.menu_book_outlined, 'Kerja', 'Istilah yang memperluas pencarian, mis. "pengeluaran" ikut mencari kode 544.'),
  _Page('admin', 'Ringkasan Server', Icons.monitor_heart_outlined, 'Admin Server', '', adminOnly: true, ownHeader: true),
  _Page('devices', 'Perangkat (PC)', Icons.devices_outlined, 'Admin Server', '', adminOnly: true, ownHeader: true),
  _Page('users', 'Staf & Admin', Icons.groups_outlined, 'Admin Server',
      'Akun yang boleh login. Akun tersalin ke setiap PC yang disetujui supaya tetap bisa login saat server mati.',
      adminOnly: true),
  _Page('email', 'Email (SMTP)', Icons.alternate_email_rounded, 'Admin Server', '', adminOnly: true, ownHeader: true),
  _Page('security', 'Keamanan', Icons.shield_outlined, 'Admin Server', '', adminOnly: true, ownHeader: true),
  _Page('audit', 'Log Aktivitas', Icons.history_rounded, 'Admin Server', 'Jejak login, unggah, unduh, kirim email, dan perubahan dokumen.', adminOnly: true),
  _Page('server', 'Koneksi Server', Icons.dns_outlined, 'Admin Server', 'Alamat server API yang dipakai PC ini.', adminOnly: true),
  _Page('profile', 'Profil Saya', Icons.account_circle_outlined, 'Akun', 'Akun dan catatan kerja Anda.'),
  _Page('settings', 'Pengaturan', Icons.settings_outlined, 'Akun', '', ownHeader: true),
  _Page('help', 'Panduan', Icons.help_outline_rounded, 'Akun', 'Cara memakai aplikasi.'),
];

Widget _buildPage(String id) => switch (id) {
      'dashboard' => const DashboardPage(),
      'docs' => const DocumentsPage(),
      'mydocs' => const DocumentsPage(mode: DocsMode.mine),
      'local' => const DocumentsPage(mode: DocsMode.local),
      'upload' => const UploadPage(),
      'requests' => const RequestsPage(),
      'projects' => const ProjectsPage(),
      'terms' => const TermsPage(),
      'admin' => const AdminOverviewPage(),
      'devices' => const DevicesPage(),
      'users' => const UsersPage(),
      'email' => const EmailSettingsPage(),
      'security' => const SecurityPage(),
      'audit' => const AuditPage(),
      'server' => const ServerPage(),
      'profile' => const ProfilePage(),
      'help' => const HelpPage(),
      _ => const SettingsPage(),
    };

const _sidebarWidth = 284.0;

/// Kerangka utama setelah login (gaya versi web): top bar + sidebar + halaman.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  /// Halaman yang pernah dibuka — dibangun sekali lalu dipertahankan
  /// (isian form, hasil cari, posisi gulir tidak hilang).
  final _opened = <String>{};

  @override
  void initState() {
    super.initState();
    final keep = Nav.keepPage;
    Nav.keepPage = null;
    // Admin bawaan (belum ada server) langsung diarahkan ke Koneksi Server.
    Nav.page.value = keep ?? (AppState.instance.session?.isSetupAdmin == true ? 'server' : 'dashboard');
    Nav.page.addListener(_onNav);
  }

  @override
  void dispose() {
    Nav.page.removeListener(_onNav);
    super.dispose();
  }

  void _onNav() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.session;
        if (s == null) return const SizedBox();
        final pages = _pages.where((p) => !p.adminOnly || s.isAdmin).toList();
        final current = pages.where((p) => p.id == Nav.page.value).firstOrNull ?? pages.first;
        _opened.add(current.id);

        return Scaffold(
          backgroundColor: YmColors.paper,
          body: Column(
            children: [
              const _TopBar(),
              if (app.syncMessage != null) _Banner(text: app.syncMessage!),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Sidebar(pages: pages, active: current.id),
                    Expanded(
                      child: _AnimatedPages(
                        index: pages.indexOf(current),
                        children: [
                          for (final p in pages)
                            if (!_opened.contains(p.id))
                              const SizedBox.shrink()
                            else if (p.ownHeader)
                              _buildPage(p.id)
                            else
                              _HeaderedPage(page: p, child: _buildPage(p.id)),
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

/// Halaman yang belum punya judul sendiri: diberi PageHeader gaya web.
class _HeaderedPage extends StatelessWidget {
  final _Page page;
  final Widget child;
  const _HeaderedPage({required this.page, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 28, 36, 0),
          child: PageHeader(crumbs: [page.group.isEmpty ? 'Arsip' : page.group, page.label], title: page.label, subtitle: page.hint),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Halaman berganti dengan animasi naik + pudar. Semua halaman yang pernah
/// dibuka tetap hidup (seperti IndexedStack); hanya yang baru tampil dianimasikan.
class _AnimatedPages extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const _AnimatedPages({required this.index, required this.children});

  @override
  State<_AnimatedPages> createState() => _AnimatedPagesState();
}

class _AnimatedPagesState extends State<_AnimatedPages> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380), value: 1);
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutQuart);
  late final Animation<Offset> _slide = Tween(begin: const Offset(0, 0.018), end: Offset.zero).animate(_curve);

  @override
  void didUpdateWidget(covariant _AnimatedPages old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _c.duration = motion(context, const Duration(milliseconds: 380));
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
      sizing: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          FadeTransition(
            opacity: i == widget.index ? _curve : _still,
            child: SlideTransition(position: i == widget.index ? _slide : _stillOffset, child: widget.children[i]),
          ),
      ],
    );
  }
}

// ============================================================================
//  TOP BAR
// ============================================================================

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: YmColors.surface,
        border: YmColors.isDark ? Border(bottom: BorderSide(color: YmColors.line)) : null,
        boxShadow: YmColors.isDark ? null : const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          // Logo + instansi (selebar sidebar)
          SizedBox(
            width: _sidebarWidth,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 12),
              child: Row(
                children: [
                  const ArsipLogo(size: 36),
                  const SizedBox(width: 10),
                  Text('Arsip PU',
                      style: TextStyle(fontFamily: kFontDisplay, fontSize: 16, fontWeight: FontWeight.w700, color: YmColors.textDark, letterSpacing: -0.3)),
                  const SizedBox(width: 10),
                  const Flexible(child: _AgencyChip()),
                ],
              ),
            ),
          ),
          // Cari
          const Expanded(child: Align(alignment: Alignment.centerLeft, child: _GlobalSearch())),
          const SizedBox(width: 16),
          NetStatusPill(status: app.net, detailed: true),
          const SizedBox(width: 14),
          _AddButton(onTap: () => Nav.go('upload')),
          const SizedBox(width: 14),
          const _AvatarMenu(),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}

class _AgencyChip extends StatelessWidget {
  const _AgencyChip();

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final s = app.session!;
    return PopupMenuButton<String>(
      tooltip: 'Info server & PC ini',
      offset: const Offset(0, 44),
      onSelected: (v) => Nav.go(v),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: SizedBox(
            width: 280,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.agencyName, style: YmTextStyles.username),
              const SizedBox(height: 4),
              Text(app.setupMode ? 'Belum terhubung ke server' : app.settings.apiUrl, style: YmTextStyles.label),
              if (app.settings.deviceId > 0)
                Text('PC #${app.settings.deviceId}${app.deviceStatus.isEmpty ? '' : ' • ${app.deviceStatus}'}', style: YmTextStyles.label),
            ]),
          ),
        ),
        const PopupMenuDivider(),
        if (s.isAdmin) const PopupMenuItem(value: 'server', child: _MenuRow(icon: Icons.dns_outlined, text: 'Koneksi server')),
        if (s.isAdmin) const PopupMenuItem(value: 'devices', child: _MenuRow(icon: Icons.devices_outlined, text: 'Perangkat (PC)')),
        const PopupMenuItem(value: 'settings', child: _MenuRow(icon: Icons.settings_outlined, text: 'Pengaturan')),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
        decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: Text(app.agencyName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: kFont, fontSize: 11, fontWeight: FontWeight.w600, color: YmColors.textMuted)),
          ),
          Icon(Icons.expand_more_rounded, size: 16, color: YmColors.textMuted),
        ]),
      ),
    );
  }
}

class _GlobalSearch extends StatefulWidget {
  const _GlobalSearch();

  @override
  State<_GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends State<_GlobalSearch> {
  final _c = TextEditingController();
  bool _focus = false;

  @override
  void initState() {
    super.initState();
    Nav.globalSearchFocus.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() => _focus = Nav.globalSearchFocus.hasFocus);
  }

  @override
  void dispose() {
    Nav.globalSearchFocus.removeListener(_onFocus);
    _c.dispose();
    super.dispose();
  }

  void _submit(String q) {
    if (q.trim().isEmpty) return;
    Nav.searchDocs(q.trim());
    _c.clear();
    Nav.globalSearchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: motion(context),
      curve: kMotionCurve,
      constraints: BoxConstraints(maxWidth: _focus ? 640 : 560),
      height: 42,
      child: TextField(
        controller: _c,
        focusNode: Nav.globalSearchFocus,
        onSubmitted: _submit,
        style: TextStyle(fontFamily: kFont, fontSize: 13.5, color: YmColors.textDark),
        decoration: searchDecoration(
          'Cari semua dokumen: judul, nomor, isi file, proyek…',
          suffix: const Padding(padding: EdgeInsets.only(right: 8), child: Center(widthFactor: 1, child: KbdHint('Ctrl K'))),
        ).copyWith(fillColor: _focus ? YmColors.surface : YmColors.surfaceAlt, contentPadding: const EdgeInsets.symmetric(vertical: 11)),
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: motion(context, const Duration(milliseconds: 180)),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _hover ? Color.lerp(YmColors.primary, Colors.white, 0.12) : YmColors.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: YmColors.primary.withOpacity(_hover ? 0.38 : 0.26), blurRadius: _hover ? 14 : 8, offset: const Offset(0, 3))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedRotation(
              turns: _hover ? 0.25 : 0,
              duration: motion(context, const Duration(milliseconds: 220)),
              child: Icon(Icons.add_rounded, size: 19, color: YmColors.onPrimary),
            ),
            const SizedBox(width: 6),
            Text('Tambah Dokumen', style: TextStyle(fontFamily: kFont, fontSize: 13.5, fontWeight: FontWeight.w600, color: YmColors.onPrimary)),
          ]),
        ),
      ),
    );
  }
}

class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu();

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final s = app.session!;
    final name = s.fullName.isNotEmpty ? s.fullName : s.username;
    return PopupMenuButton<String>(
      tooltip: name,
      offset: const Offset(0, 48),
      onSelected: (v) async {
        switch (v) {
          case 'logout':
            if (await confirmDialog(context,
                title: 'Logout?', message: 'Anda akan kembali ke halaman login. Dokumen yang belum terupload tetap aman di PC ini.', ok: 'Logout')) {
              app.logout();
            }
          case 'exit':
            if (context.mounted) await confirmExit(context);
          case 'tray':
            await TrayService.hideToTray();
          case 'full':
            await toggleFullScreen();
          default:
            Nav.go(v);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: SizedBox(
            width: 240,
            child: Row(children: [
              _Avatar(name: name, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.username),
                  Text('${s.isAdmin ? 'Admin' : 'Staf'} • @${s.username}${s.offline ? ' • login offline' : ''}', style: YmTextStyles.label),
                ]),
              ),
            ]),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'profile', child: _MenuRow(icon: Icons.account_circle_outlined, text: 'Profil saya')),
        const PopupMenuItem(value: 'settings', child: _MenuRow(icon: Icons.palette_outlined, text: 'Pengaturan & tema')),
        const PopupMenuItem(value: 'help', child: _MenuRow(icon: Icons.help_outline_rounded, text: 'Panduan')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'full', child: _MenuRow(icon: Icons.fullscreen_rounded, text: 'Layar penuh (F11)')),
        const PopupMenuItem(value: 'tray', child: _MenuRow(icon: Icons.south_east_rounded, text: 'Kecilkan ke system tray')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'logout', child: _MenuRow(icon: Icons.logout_rounded, text: 'Logout')),
        PopupMenuItem(value: 'exit', child: _MenuRow(icon: Icons.power_settings_new_rounded, text: 'Keluar aplikasi', color: YmColors.danger)),
      ],
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _Avatar(name: name, size: 34),
          Positioned(
            right: -1,
            bottom: -1,
            child: AnimatedContainer(
              duration: motion(context),
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: app.isOnline ? YmColors.success : YmColors.warning,
                shape: BoxShape.circle,
                border: Border.all(color: YmColors.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final double size;
  const _Avatar({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final initials = parts.isEmpty ? '?' : (parts.length == 1 ? parts.first.substring(0, 1) : '${parts[0][0]}${parts[1][0]}').toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: YmColors.primary, shape: BoxShape.circle),
      child: Text(initials, style: TextStyle(fontFamily: kFont, color: YmColors.onPrimary, fontWeight: FontWeight.w700, fontSize: size * 0.36)),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _MenuRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 19, color: color ?? YmColors.textMuted),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(fontFamily: kFont, fontSize: 13, color: color ?? YmColors.textDark)),
      ]);
}

// ============================================================================
//  SIDEBAR
// ============================================================================

class _Sidebar extends StatefulWidget {
  final List<_Page> pages;
  final String active;
  const _Sidebar({required this.pages, required this.active});

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  final _stackKey = GlobalKey();
  final _keys = <String, GlobalKey>{};
  Rect? _highlight;
  bool _catsOpen = true, _yearsOpen = true, _allCats = false;
  Timer? _follow;

  GlobalKey _key(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    Nav.activeCategory.addListener(_changed);
    Nav.activeYear.addListener(_changed);
  }

  @override
  void dispose() {
    Nav.activeCategory.removeListener(_changed);
    Nav.activeYear.removeListener(_changed);
    _follow?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// id item yang aktif: kategori/tahun yang sedang difilter di Semua Dokumen, atau id halaman.
  String get _activeId {
    if (widget.active == 'docs') {
      if (Nav.activeCategory.value.isNotEmpty) return 'cat:${Nav.activeCategory.value}';
      if (Nav.activeYear.value != 0) return 'year:${Nav.activeYear.value}';
    }
    return widget.active;
  }

  void _measure() {
    if (!mounted) return;
    final box = _keys[_activeId]?.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    Rect? r;
    if (box != null && stack != null && box.attached && stack.attached && box.hasSize) {
      final off = box.localToGlobal(Offset.zero, ancestor: stack);
      // tanpa margin bawah item (2px)
      r = Rect.fromLTWH(off.dx, off.dy, box.size.width, box.size.height - 2);
    }
    if (r != _highlight) setState(() => _highlight = r);
  }

  /// Ikuti posisi item aktif selama bagian yang dilipat sedang beranimasi.
  void _followFor(Duration d) {
    _follow?.cancel();
    final end = DateTime.now().add(d);
    _follow = Timer.periodic(const Duration(milliseconds: 16), (t) {
      _measure();
      if (DateTime.now().isAfter(end)) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final app = AppState.instance;
    final s = app.session!;
    final docs = app.visibleDocs;
    final me = s.username.toLowerCase();
    final mine = docs.where((d) => d.createdBy.toLowerCase() == me).length;
    final local = docs.where((d) => d.isUnsynced).length;
    final byCat = <String, int>{};
    final byYear = <int, int>{};
    for (final d in docs) {
      byCat[d.category] = (byCat[d.category] ?? 0) + 1;
      byYear[d.year] = (byYear[d.year] ?? 0) + 1;
    }
    final cats = docCategories.where((c) => _allCats || (byCat[c.code] ?? 0) > 0).toList()
      ..sort((a, b) => (byCat[b.code] ?? 0).compareTo(byCat[a.code] ?? 0));
    final shownCats = _allCats ? cats : cats.take(7).toList();
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
    final topYears = years.take(4).toList();
    final older = years.skip(4).fold<int>(0, (a, y) => a + (byYear[y] ?? 0));

    String? badge(String id) => switch (id) {
          'docs' => CountUp.dots(docs.length),
          'mydocs' => CountUp.dots(mine),
          'requests' => app.pendingRequests > 0 ? '${app.pendingRequests}' : null,
          'devices' => app.pendingDevices > 0 ? '${app.pendingDevices}' : null,
          _ => null,
        };

    Widget item(_Page p) => _SideItem(
          key: _key(p.id),
          icon: p.icon,
          label: p.label,
          active: _activeId == p.id,
          count: p.id == 'local' ? null : badge(p.id),
          alert: (p.id == 'requests' && app.pendingRequests > 0) || (p.id == 'devices' && app.pendingDevices > 0),
          warn: p.id == 'local' && local > 0 ? '$local menunggu' : null,
          onTap: () => Nav.go(p.id),
        );

    final groups = <String, List<_Page>>{};
    for (final p in widget.pages) {
      groups.putIfAbsent(p.group, () => []).add(p);
    }

    return Container(
      width: _sidebarWidth,
      decoration: BoxDecoration(
        color: YmColors.sidebar,
        border: YmColors.isDark ? Border(right: BorderSide(color: YmColors.line)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Stack(
                  key: _stackKey,
                  children: [
                    // Latar menu aktif yang MELUNCUR ke item yang dipilih
                    if (_highlight != null)
                      AnimatedPositioned(
                        duration: motion(context, const Duration(milliseconds: 340)),
                        curve: Curves.easeOutBack,
                        left: _highlight!.left,
                        top: _highlight!.top,
                        width: _highlight!.width,
                        height: _highlight!.height,
                        child: Container(
                          decoration: BoxDecoration(color: YmColors.surfaceHigh, borderRadius: BorderRadius.circular(12), boxShadow: softShadow),
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final p in groups[''] ?? const <_Page>[]) item(p),
                        // ---- kategori
                        _SectionHead(
                          text: 'Kategori',
                          open: _catsOpen,
                          onTap: () {
                            setState(() => _catsOpen = !_catsOpen);
                            _followFor(const Duration(milliseconds: 420));
                          },
                        ),
                        _Collapse(
                          open: _catsOpen,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            if (shownCats.isEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 2, 8, 6),
                                child: Text('Belum ada dokumen.', style: YmTextStyles.label),
                              ),
                            for (final c in shownCats)
                              _SideItem(
                                key: _key('cat:${c.code}'),
                                icon: c.icon,
                                label: c.label,
                                small: true,
                                active: _activeId == 'cat:${c.code}',
                                count: (byCat[c.code] ?? 0) > 0 ? CountUp.dots(byCat[c.code]!) : null,
                                onTap: () => Nav.openCategory(c.code),
                              ),
                            _TextLink(
                              text: _allCats ? 'Tampilkan lebih sedikit' : 'Semua kategori',
                              onTap: () {
                                setState(() => _allCats = !_allCats);
                                _followFor(const Duration(milliseconds: 420));
                              },
                            ),
                          ]),
                        ),
                        // ---- per tahun
                        if (topYears.isNotEmpty) ...[
                          _SectionHead(
                            text: 'Per tahun',
                            open: _yearsOpen,
                            onTap: () {
                              setState(() => _yearsOpen = !_yearsOpen);
                              _followFor(const Duration(milliseconds: 420));
                            },
                          ),
                          _Collapse(
                            open: _yearsOpen,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              for (final y in topYears)
                                _SideItem(
                                  key: _key('year:$y'),
                                  icon: Icons.calendar_today_outlined,
                                  label: '$y',
                                  small: true,
                                  active: _activeId == 'year:$y',
                                  count: CountUp.dots(byYear[y] ?? 0),
                                  onTap: () => Nav.openYear(y),
                                ),
                              if (older > 0)
                                _SideItem(
                                  key: _key('year:-1'),
                                  icon: Icons.history_rounded,
                                  label: 'Lebih lama',
                                  small: true,
                                  active: _activeId == 'year:-1',
                                  count: CountUp.dots(older),
                                  onTap: () => Nav.openYear(-1),
                                ),
                            ]),
                          ),
                        ],
                        for (final g in const ['Kerja', 'Admin Server'])
                          if (groups[g] != null) ...[
                            _SectionHead(text: g),
                            for (final p in groups[g]!) item(p),
                          ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const _SyncCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final p in groups['Akun'] ?? const <_Page>[])
                if (p.id != 'profile')
                  _SideItem(icon: p.icon, label: p.label, small: true, active: widget.active == p.id, solidActive: true, onTap: () => Nav.go(p.id)),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Bagian sidebar yang bisa dilipat (animasi tinggi + pudar).
class _Collapse extends StatelessWidget {
  final bool open;
  final Widget child;
  const _Collapse({required this.open, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: motion(context, const Duration(milliseconds: 360)),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: motion(context, const Duration(milliseconds: 240)),
        opacity: open ? 1 : 0,
        child: open ? child : const SizedBox(width: double.infinity),
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  final String text;
  final bool? open;
  final VoidCallback? onTap;
  const _SectionHead({required this.text, this.open, this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(14, 22, 8, 8),
      child: Row(children: [
        Expanded(child: Text(text.toUpperCase(), style: YmTextStyles.overline.copyWith(letterSpacing: 1.0))),
        if (open != null)
          AnimatedRotation(
            turns: open! ? 0 : -0.25,
            duration: motion(context, const Duration(milliseconds: 240)),
            child: Icon(Icons.expand_more_rounded, size: 16, color: YmColors.outline),
          ),
      ]),
    );
    if (onTap == null) return row;
    return MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: row));
  }
}

class _TextLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _TextLink({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 2, 0, 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: const Size(0, 28)),
            child: Text(text, style: TextStyle(fontFamily: kFont, fontSize: 12, fontWeight: FontWeight.w600, color: YmColors.link)),
          ),
        ),
      );
}

class _SideItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool small;
  final String? count;
  final bool alert;
  final String? warn;

  /// true = latar aktif digambar sendiri (bagian bawah sidebar, di luar penanda meluncur).
  final bool solidActive;
  final VoidCallback onTap;
  const _SideItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.small = false,
    this.count,
    this.alert = false,
    this.warn,
    this.solidActive = false,
  });

  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final fg = w.active ? YmColors.primary : (_hover ? YmColors.textDark : YmColors.textMuted);
    final bg = w.active
        ? (w.solidActive ? YmColors.surfaceHigh : Colors.transparent)
        : (_hover ? YmColors.surfaceContainer.withOpacity(YmColors.isDark ? 0.7 : 0.9) : Colors.transparent);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: w.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: motion(context, const Duration(milliseconds: 170)),
            height: w.small ? 38 : 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                AnimatedScale(
                  scale: _hover && !w.active ? 1.08 : 1,
                  duration: motion(context, const Duration(milliseconds: 170)),
                  child: Icon(w.icon, color: w.active || _hover ? YmColors.primary : YmColors.outline, size: w.small ? 18 : 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: motion(context, const Duration(milliseconds: 170)),
                    style: TextStyle(fontFamily: kFont, color: fg, fontSize: w.small ? 13 : 14, fontWeight: w.active ? FontWeight.w600 : FontWeight.w500),
                    child: Text(w.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (w.warn != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: YmColors.warningSoft, borderRadius: BorderRadius.circular(20)),
                    child: Text(w.warn!, style: TextStyle(fontFamily: kFont, color: YmColors.warning, fontSize: 10.5, fontWeight: FontWeight.w600)),
                  )
                else if (w.count != null)
                  AnimatedContainer(
                    duration: motion(context, const Duration(milliseconds: 170)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: w.alert ? YmColors.danger : (w.active ? YmColors.surface : YmColors.surfaceContainer),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(w.count!,
                        style: TextStyle(fontFamily: kFont, color: w.alert ? Colors.white : YmColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu di bawah sidebar (versi web: "Cloud Storage 17%"): berapa persen
/// dokumen sudah aman di server + tombol sinkron.
class _SyncCard extends StatelessWidget {
  const _SyncCard();

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final docs = app.visibleDocs;
    final onServer = docs.where((d) => d.status == DocStatus.uploaded).length;
    final pct = docs.isEmpty ? 1.0 : onServer / docs.length;
    final bytes = docs.fold<int>(0, (a, d) => a + d.fileSize);
    final failed = app.failedCount;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
      decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(12), boxShadow: softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(app.setupMode ? 'Server belum diatur' : 'Tersimpan di server',
                  style: TextStyle(fontFamily: kFont, fontSize: 12.5, fontWeight: FontWeight.w600, color: YmColors.textDark)),
            ),
            Text('${(pct * 100).round()}%', style: TextStyle(fontFamily: kFont, fontSize: 12.5, fontWeight: FontWeight.w700, color: YmColors.primary)),
            SizedBox(
              width: 30,
              height: 30,
              child: app.syncing
                  ? Padding(padding: const EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2, color: YmColors.primary))
                  : IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Sinkronkan sekarang',
                      iconSize: 17,
                      onPressed: app.setupMode ? null : () => unawaited(app.tick(forcePull: true)),
                      icon: Icon(Icons.sync_rounded, color: YmColors.outline),
                    ),
            ),
          ]),
          const SizedBox(height: 4),
          ProgressBar(value: pct, height: 6),
          const SizedBox(height: 7),
          if (failed > 0)
            InkWell(
              onTap: () => Nav.showMyDocs('failed'),
              child: Text('$failed gagal diunggah — lihat', style: TextStyle(fontFamily: kFont, color: YmColors.danger, fontSize: 11.5, fontWeight: FontWeight.w600)),
            )
          else
            Text(
              '${formatBytes(bytes)} • ${CountUp.dots(docs.length)} dokumen${app.lastSyncAt != null ? ' • ${timeAgo(app.lastSyncAt)}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: YmTextStyles.label.copyWith(fontSize: 11.5),
            ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  const _Banner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Reveal(
      offset: const Offset(0, -0.4),
      child: Container(
        width: double.infinity,
        color: YmColors.warningSoft,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: YmColors.warning),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: YmTextStyles.chatText.copyWith(fontSize: 12.5))),
          ],
        ),
      ),
    );
  }
}
