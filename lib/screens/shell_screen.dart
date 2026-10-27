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
import '../services/shortcuts.dart';
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

/// Lebar sidebar persis versi web: w-72 = 288 px.
const _sidebarWidth = 288.0;

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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
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

/// Top bar persis versi web: `h-16 px-space-lg bg-surface-container-lowest/90
/// shadow-[0_1px_8px_rgba(15,23,42,0.04)]`, isi dipisah gap 16.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: YmColors.surface.withOpacity(0.9),
        border: YmColors.isDark ? Border(bottom: BorderSide(color: YmColors.line)) : null,
        boxShadow: YmColors.isDark ? null : const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 1))],
      ),
      // Kolom cari TEPAT DI TENGAH: kiri & kanan diberi lebar sama (Expanded),
      // lebar kolom cari menyesuaikan lebar jendela (maks 576 seperti versi web).
      child: LayoutBuilder(builder: (context, c) {
        final searchW = (c.maxWidth - 2 * 440).clamp(300.0, 576.0).toDouble();
        return Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ArsipLogo(size: 36),
                    const SizedBox(width: 8),
                    Text('Arsip PU', style: YmTextStyles.headlineSm.copyWith(letterSpacing: -0.4)),
                    const SizedBox(width: 16),
                    const Flexible(child: _AgencyChip()),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(width: searchW, child: const _GlobalSearch()),
            const SizedBox(width: 16),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: NetStatusPill(status: app.net, detailed: c.maxWidth > 1600, compact: c.maxWidth <= 1600)),
                    const SizedBox(width: 16),
                    _AddButton(onTap: () => Nav.go('upload')),
                    const SizedBox(width: 16),
                    const _AvatarMenu(),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
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
              Text(app.setupMode ? 'Belum terhubung ke server' : app.settings.activeUrl, style: YmTextStyles.label),
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
      // versi web: px-2 py-1 rounded-lg bg-surface-container-low font-label-sm, maks 180 px
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(app.agencyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelSm),
          ),
          const SizedBox(width: 4),
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

  /// versi web: `flex-1 max-w-xl px-space-sm`, input `h-10 pl-11 rounded-xl
  /// bg-surface-container-low focus:bg-surface-container-lowest focus:ring-2 ring-primary/20`,
  /// tanda "Ctrl K" di kanan.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: AnimatedContainer(
        duration: motion(context, const Duration(milliseconds: 150)),
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _focus ? [BoxShadow(color: YmColors.primary.withOpacity(0.2), spreadRadius: 2)] : null,
        ),
        child: TextField(
          controller: _c,
          focusNode: Nav.globalSearchFocus,
          onSubmitted: _submit,
          style: YmTextStyles.bodyMd.copyWith(color: YmColors.textDark),
          decoration: searchDecoration(
            'Cari semua dokumen, nomor, isi file, dan proyek...',
            suffix: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(widthFactor: 1, child: KbdHint(ShortcutCtl.instance.label(AppAction.globalSearch))),
            ),
          ).copyWith(
            fillColor: _focus ? YmColors.surface : YmColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(vertical: 9),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
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

  /// versi web: `h-10 px-space-md rounded-xl bg-primary hover:bg-primary-container
  /// font-label-lg shadow-[0_2px_8px_-2px_rgba(41,60,160,0.3)]`, ikon "add" 18.
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: motion(context, const Duration(milliseconds: 150)),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _hover ? YmColors.primaryContainer : YmColors.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: YmColors.primary.withOpacity(0.3), blurRadius: 8, spreadRadius: -2, offset: const Offset(0, 2))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedRotation(
              turns: _hover ? 0.25 : 0,
              duration: motion(context, const Duration(milliseconds: 200)),
              child: Icon(Icons.add_rounded, size: 18, color: YmColors.onPrimary),
            ),
            const SizedBox(width: 4),
            Text('Tambah Dokumen', style: YmTextStyles.labelLg.copyWith(color: YmColors.onPrimary)),
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
      // versi web: w-8 h-8 rounded-full bg-primary ring-2 + ikon person 18, titik hijau 10
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: YmColors.primary, shape: BoxShape.circle, border: Border.all(color: YmColors.surface, width: 2)),
            child: Icon(Icons.person_rounded, size: 18, color: YmColors.onPrimary),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: AnimatedContainer(
              duration: motion(context),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: app.net == NetStatus.notConfigured ? YmColors.outline : YmColors.success,
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

/// Sidebar persis versi web: `w-72 bg-surface-container-low/70 px-space-md py-space-md`.
/// Menu utama (label-lg, ikon 20, py-2.5) → KATEGORI → PER TAHUN (label-md,
/// ikon 18, py-2) → Kerja → Admin Server; di bawah: kartu penyimpanan +
/// Pengaturan / Panduan. Latar menu aktif (`bg-surface-container-highest
/// text-primary shadow-sm`) MELUNCUR ke menu yang dipilih.
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
      r = off & box.size;
    }
    if (r != _highlight) setState(() => _highlight = r);
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
    // Kategori yang punya dokumen, terbanyak dulu (seperti versi web: 5–8 kategori)
    final cats = docCategories.where((c) => (byCat[c.code] ?? 0) > 0).toList()..sort((a, b) => (byCat[b.code] ?? 0).compareTo(byCat[a.code] ?? 0));
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
    final topYears = years.take(3).toList();
    final older = years.skip(3).fold<int>(0, (a, y) => a + (byYear[y] ?? 0));

    final groups = <String, List<_Page>>{};
    for (final p in widget.pages) {
      groups.putIfAbsent(p.group, () => []).add(p);
    }

    Widget pageItem(_Page p) {
      final (String? count, _BadgeKind kind) = switch (p.id) {
        'docs' => (CountUp.dots(docs.length), _BadgeKind.normal),
        'mydocs' => (CountUp.dots(mine), _BadgeKind.normal),
        'local' => (local > 0 ? '$local menunggu' : null, _BadgeKind.warning),
        'requests' => (app.pendingRequests > 0 ? '${app.pendingRequests}' : null, _BadgeKind.alert),
        'devices' => (app.pendingDevices > 0 ? '${app.pendingDevices}' : null, _BadgeKind.alert),
        _ => (null, _BadgeKind.normal),
      };
      return _SideItem(
        key: _key(p.id),
        icon: p.icon,
        label: p.label,
        active: _activeId == p.id,
        badge: count,
        badgeKind: kind,
        hoverTint: p.id == 'local' ? YmColors.warning : null,
        onTap: () => Nav.go(p.id),
      );
    }

    return Container(
      width: _sidebarWidth,
      decoration: BoxDecoration(
        color: Color.alphaBlend(YmColors.surfaceAlt.withOpacity(0.7), YmColors.paper),
        border: YmColors.isDark ? Border(right: BorderSide(color: YmColors.line)) : null,
        boxShadow: YmColors.isDark ? null : const [BoxShadow(color: Color(0x050F172A), blurRadius: 12, offset: Offset(1, 0))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Stack(
                  key: _stackKey,
                  children: [
                    // Latar menu aktif yang MELUNCUR ke item yang dipilih
                    if (_highlight != null)
                      AnimatedPositioned(
                        duration: motion(context, const Duration(milliseconds: 320)),
                        curve: Curves.easeOutCubic,
                        left: _highlight!.left,
                        top: _highlight!.top,
                        width: _highlight!.width,
                        height: _highlight!.height,
                        child: Container(
                          decoration: BoxDecoration(color: YmColors.surfaceHigh, borderRadius: BorderRadius.circular(12), boxShadow: shadowSm),
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final p in groups[''] ?? const <_Page>[]) pageItem(p),
                        // ---- kategori
                        const _SectionHead(text: 'Kategori'),
                        if (cats.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                            child: Text('Belum ada dokumen.', style: YmTextStyles.bodySm),
                          ),
                        for (final c in cats)
                          _SideItem(
                            key: _key('cat:${c.code}'),
                            icon: c.icon,
                            label: c.label,
                            small: true,
                            active: _activeId == 'cat:${c.code}',
                            badge: CountUp.dots(byCat[c.code] ?? 0),
                            onTap: () => Nav.openCategory(c.code),
                          ),
                        // ---- per tahun
                        if (topYears.isNotEmpty) ...[
                          const _SectionHead(text: 'Per tahun'),
                          for (final y in topYears)
                            _SideItem(
                              key: _key('year:$y'),
                              icon: Icons.calendar_today_outlined,
                              label: '$y',
                              small: true,
                              active: _activeId == 'year:$y',
                              badge: CountUp.dots(byYear[y] ?? 0),
                              onTap: () => Nav.openYear(y),
                            ),
                          if (older > 0)
                            _SideItem(
                              key: _key('year:-1'),
                              icon: Icons.history_rounded,
                              label: 'Lebih lama',
                              small: true,
                              active: _activeId == 'year:-1',
                              badge: CountUp.dots(older),
                              onTap: () => Nav.openYear(-1),
                            ),
                        ],
                        for (final g in const ['Kerja', 'Admin Server'])
                          if (groups[g] != null) ...[
                            _SectionHead(text: g),
                            for (final p in groups[g]!) pageItem(p),
                          ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ---- bawah: kartu penyimpanan + Pengaturan / Panduan (pt-space-md gap-space-sm)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SyncCard(),
                const SizedBox(height: 8),
                for (final p in groups['Akun'] ?? const <_Page>[])
                  if (p.id != 'profile') _FootLink(icon: p.id == 'settings' ? Icons.settings_outlined : Icons.help_outline_rounded, label: p.label, active: widget.active == p.id, onTap: () => Nav.go(p.id)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _BadgeKind { normal, warning, alert }

/// Judul kelompok: `mt-space-md mb-space-xs px-space-md font-label-sm text-outline uppercase tracking-wider font-semibold`.
class _SectionHead extends StatelessWidget {
  final String text;
  const _SectionHead({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text.toUpperCase(), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, letterSpacing: 0.55)),
      );
}

/// Item menu: `flex justify-between px-space-md py-2.5 rounded-xl text-on-surface-variant
/// hover:bg-surface-container hover:text-on-surface` (kategori/tahun: py-2, ikon 18, label-md).
class _SideItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool small;
  final String? badge;
  final _BadgeKind badgeKind;
  final Color? hoverTint;
  final VoidCallback onTap;
  const _SideItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.small = false,
    this.badge,
    this.badgeKind = _BadgeKind.normal,
    this.hoverTint,
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
    final iconColor = w.active ? YmColors.primary : (_hover ? (w.hoverTint ?? YmColors.primary) : YmColors.outline);
    final base = w.small ? YmTextStyles.labelMd : YmTextStyles.labelLg;
    final (Color bBg, Color bFg, FontWeight bW) = switch (w.badgeKind) {
      _BadgeKind.warning => (YmColors.warningSoft, YmColors.onWarningSoft, FontWeight.w600),
      _BadgeKind.alert => (YmColors.danger, Colors.white, FontWeight.w600),
      _BadgeKind.normal => (YmColors.surfaceContainer, YmColors.textMuted, FontWeight.w600),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: w.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: motion(context, const Duration(milliseconds: 150)),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: w.small ? 8 : 10),
            decoration: BoxDecoration(
              color: !w.active && _hover ? YmColors.surfaceContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(w.icon, color: iconColor, size: w.small ? 18 : 20),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: motion(context, const Duration(milliseconds: 150)),
                    style: base.copyWith(color: fg, fontWeight: w.active ? FontWeight.w600 : FontWeight.w500),
                    child: Text(w.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (w.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: bBg, borderRadius: BorderRadius.circular(999)),
                    child: Text(w.badge!, style: YmTextStyles.labelSm.copyWith(color: bFg, fontWeight: bW)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tautan bawah sidebar: `px-space-md py-2 rounded-lg font-label-md`, ikon 18.
class _FootLink extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FootLink({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  State<_FootLink> createState() => _FootLinkState();
}

class _FootLinkState extends State<_FootLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final fg = w.active ? YmColors.primary : (_hover ? YmColors.textDark : YmColors.textMuted);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: w.onTap,
        child: AnimatedContainer(
          duration: motion(context, const Duration(milliseconds: 150)),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: w.active ? YmColors.surfaceHigh : (_hover ? YmColors.surfaceContainer : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(w.icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(w.label, style: YmTextStyles.labelMd.copyWith(color: fg)),
          ]),
        ),
      ),
    );
  }
}

/// Kartu penyimpanan (versi web: "Cloud Storage 17%"): `p-space-sm rounded-xl
/// bg-surface-container-lowest shadow-[0_1px_4px_rgba(15,23,42,0.04)]`, batang h-1.5.
/// Di sini: berapa persen dokumen sudah aman di server.
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: YmColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: YmColors.isDark ? null : const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(app.setupMode ? 'Server belum diatur' : 'Tersimpan di server',
                  style: YmTextStyles.labelSm.copyWith(color: YmColors.textDark, fontWeight: FontWeight.w500)),
            ),
            Text('${(pct * 100).round()}%', style: YmTextStyles.labelSm.copyWith(color: YmColors.primary)),
          ]),
          const SizedBox(height: 6),
          ProgressBar(value: pct, height: 6),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: failed > 0
                  ? InkWell(
                      onTap: () => Nav.showMyDocs('failed'),
                      child: Text('$failed gagal diunggah — lihat', style: YmTextStyles.bodySm.copyWith(color: YmColors.danger, fontWeight: FontWeight.w600)),
                    )
                  : Text('${formatBytes(bytes)} dari ${CountUp.dots(docs.length)} dokumen',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.bodySm),
            ),
            if (!app.setupMode)
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: app.syncing ? null : () => unawaited(app.tick(forcePull: true)),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: app.syncing
                      ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: YmColors.primary))
                      : Tooltip(message: 'Sinkronkan sekarang', child: Icon(Icons.sync_rounded, size: 16, color: YmColors.outline)),
                ),
              ),
          ]),
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
