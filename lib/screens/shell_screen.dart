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
  final bool adminOnly;
  const _NavItem(this.id, this.label, this.icon, {this.adminOnly = false});
}

const _nav = [
  _NavItem('dashboard', 'Dashboard', Icons.space_dashboard_rounded),
  _NavItem('upload', 'Unggah Dokumen', Icons.upload_file_rounded),
  _NavItem('mydocs', 'Dokumen Saya', Icons.assignment_ind_rounded),
  _NavItem('docs', 'Arsip Dokumen', Icons.folder_open_rounded),
  _NavItem('requests', 'Permintaan Edit', Icons.rate_review_rounded),
  _NavItem('projects', 'Proyek / Paket', Icons.engineering_rounded),
  _NavItem('terms', 'Kamus Pencarian', Icons.menu_book_rounded),
  _NavItem('users', 'Staf & Admin', Icons.groups_rounded, adminOnly: true),
  _NavItem('audit', 'Log Aktivitas', Icons.history_rounded, adminOnly: true),
  _NavItem('server', 'Server API', Icons.dns_rounded, adminOnly: true),
  _NavItem('profile', 'Profil Saya', Icons.account_circle_rounded),
  _NavItem('settings', 'Penyimpanan & Info', Icons.settings_rounded),
  _NavItem('help', 'Panduan', Icons.help_outline_rounded),
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
                    _Header(title: current.label, icon: current.icon, active: current.id == _active),
                    if (app.syncMessage != null) _Banner(text: app.syncMessage!),
                    Expanded(
                      child: IndexedStack(
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

class _Sidebar extends StatelessWidget {
  final List<_NavItem> items;
  final String active;
  final ValueChanged<String> onSelect;
  const _Sidebar({required this.items, required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final s = app.session!;
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [YmColors.heroGradientTop, YmColors.titleBarStart, YmColors.heroGradientBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                ArsipLogo(size: 38),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Arsip Dokumen PU', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('Arsip Proyek Konstruksi', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Kartu user
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: YmColors.accentPurple,
                  child: Text(
                    (s.fullName.isNotEmpty ? s.fullName : s.username).substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.fullName, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _RoleChip(text: s.isAdmin ? 'ADMIN' : 'STAF'),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text('@${s.username}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final n in items)
                  _SideItem(
                    icon: n.icon,
                    label: n.label,
                    active: n.id == active,
                    badge: n.id == 'mydocs' && app.myUnsyncedCount > 0
                        ? '${app.myUnsyncedCount}'
                        : n.id == 'requests' && app.pendingRequests > 0
                            ? '${app.pendingRequests}'
                            : null,
                    onTap: () => onSelect(n.id),
                  ),
              ],
            ),
          ),
          const _SyncCard(),
          const SizedBox(height: 8),
          const Divider(color: Colors.white24, height: 1),
          _SideItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            active: false,
            onTap: () async {
              if (await confirmDialog(context, title: 'Logout?', message: 'Anda akan kembali ke halaman login. Dokumen yang belum terupload tetap aman di PC ini.', ok: 'Logout')) {
                app.logout();
              }
            },
          ),
          _SideItem(icon: Icons.power_settings_new_rounded, label: 'Keluar Aplikasi', active: false, onTap: () => confirmExit(context)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String text;
  const _RoleChip({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: YmColors.accentPurple, borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );
}

class _SideItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final String? badge;
  final VoidCallback onTap;
  const _SideItem({required this.icon, required this.label, required this.active, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: active ? Colors.white.withOpacity(0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: active ? Colors.white : Colors.white70, size: 19),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: TextStyle(
                    color: active ? Colors.white : Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  )),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: YmColors.statusAway, borderRadius: BorderRadius.circular(10)),
                    child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu kecil status sinkronisasi di sidebar.
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
      line = 'Mengunggah...';
    } else if (pending > 0) {
      line = app.isOnline ? '$pending dokumen dalam antrian' : '$pending dokumen menunggu internet';
    } else {
      line = 'Semua dokumen terupload';
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (app.syncing)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else
                Icon(pending > 0 ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(child: Text(line, style: const TextStyle(color: Colors.white, fontSize: 11.5))),
            ],
          ),
          if (failed > 0) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => Nav.showMyDocs('failed'),
              child: Text('$failed gagal — klik untuk lihat', style: const TextStyle(color: Color(0xFFFF9A9A), fontSize: 10.5, decoration: TextDecoration.underline)),
            ),
          ],
          if (app.lastSyncAt != null) ...[
            const SizedBox(height: 4),
            Text('Sinkron terakhir ${formatDateTime(app.lastSyncAt)}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
          if (!app.setupMode) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: app.syncing ? null : () => unawaited(app.tick(forcePull: true)),
                icon: const Icon(Icons.sync_rounded, size: 15),
                label: const Text('Sinkronkan sekarang'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(fontSize: 11.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool active;
  const _Header({required this.title, required this.icon, this.active = true});

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
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: YmColors.borderLavender)),
      ),
      child: Row(
        children: [
          Icon(widget.icon, color: YmColors.accentPurple, size: 22),
          const SizedBox(width: 10),
          Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: YmColors.textDark)),
          const SizedBox(width: 14),
          Flexible(
            child: Text(app.agencyName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: YmTextStyles.label.copyWith(fontSize: 12)),
          ),
          const Spacer(),
          if (app.session?.offline == true) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: YmColors.statusAway.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: const Text('Login offline', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: YmColors.statusAway)),
            ),
            const SizedBox(width: 10),
          ],
          NetStatusPill(status: app.net),
          const SizedBox(width: 16),
          Text(formatDateTime(_now), style: YmTextStyles.label.copyWith(fontSize: 12)),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Kecilkan ke system tray (aplikasi tetap berjalan)',
            onPressed: TrayService.hideToTray,
            icon: const Icon(Icons.south_east_rounded, color: YmColors.textMuted),
          ),
          IconButton(
            tooltip: 'Full screen (F11)',
            onPressed: toggleFullScreen,
            icon: const Icon(Icons.fullscreen_rounded, color: YmColors.textMuted),
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
    return Container(
      width: double.infinity,
      color: YmColors.statusAway.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: YmColors.statusAway),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: YmTextStyles.chatText.copyWith(fontSize: 12.5))),
        ],
      ),
    );
  }
}
