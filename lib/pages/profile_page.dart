import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../services/nav.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';

/// Profil saya: info akun, ringkasan aktivitas input, ganti password.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _new2 = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _new2.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    String? err;
    if (_old.text.isEmpty) {
      err = 'Isi password lama.';
    } else if (_new.text.length < 8) {
      err = 'Password baru minimal 8 karakter.';
    } else if (_new.text != _new2.text) {
      err = 'Konfirmasi password baru tidak sama.';
    } else if (_new.text == _old.text) {
      err = 'Password baru sama dengan yang lama.';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AppState.instance.changeOwnPassword(_old.text, _new.text);
      _old.clear();
      _new.clear();
      _new2.clear();
      if (mounted) showSnack(context, 'Password berhasil diganti. Login berikutnya (online maupun offline) memakai password baru.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.session!;
        final me = s.username.toLowerCase();
        final mine = app.visibleDocs.where((d) => d.createdBy.toLowerCase() == me).toList();
        final now = DateTime.now();
        final today = mine.where((d) => d.createdAt.year == now.year && d.createdAt.month == now.month && d.createdAt.day == now.day).length;
        final month = mine.where((d) => d.createdAt.year == now.year && d.createdAt.month == now.month).length;
        final pending = mine.where((d) => d.status == DocStatus.pending || d.status == DocStatus.uploading).length;
        final failed = mine.where((d) => d.status == DocStatus.failed).length;
        final size = mine.fold<int>(0, (a, d) => a + d.fileSize);

        return PageBody(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Kartu profil
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [YmColors.titleBarStart, YmColors.titleBarEnd]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: Colors.white.withOpacity(0.18),
                          child: Text(
                            (s.fullName.isNotEmpty ? s.fullName : s.username).substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.fullName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('@${s.username}  •  ${s.isAdmin ? 'Admin' : 'Staf'}  •  ${app.agencyName}',
                                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12.5)),
                              const SizedBox(height: 4),
                              Text(
                                s.isSetupAdmin
                                    ? 'Akun sementara (belum terhubung ke server)'
                                    : s.offline
                                        ? 'Masuk secara offline — data akan disinkronkan saat server terhubung'
                                        : 'Masuk secara online',
                                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: StatCard(label: 'Diinput hari ini', value: '$today', icon: Icons.today_rounded, color: YmColors.accentBlue, onTap: () => Nav.showMyDocs('today'))),
                      const SizedBox(width: 12),
                      Expanded(child: StatCard(label: 'Bulan ini', value: '$month', icon: Icons.calendar_month_rounded, color: YmColors.accentPurple, onTap: () => Nav.showMyDocs())),
                      const SizedBox(width: 12),
                      Expanded(child: StatCard(label: 'Total dokumen saya', value: '${mine.length}', sub: formatBytes(size), icon: Icons.folder_copy_rounded, color: const Color(0xFF0E8F7E), onTap: () => Nav.showMyDocs())),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          label: 'Belum terupload',
                          value: '$pending',
                          sub: failed > 0 ? '$failed gagal' : null,
                          icon: Icons.cloud_upload_rounded,
                          color: pending + failed > 0 ? YmColors.statusAway : YmColors.statusOnline,
                          onTap: () => Nav.showMyDocs(failed > 0 ? 'failed' : 'unsynced'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    title: 'Ganti Password',
                    icon: Icons.lock_reset_rounded,
                    child: s.isSetupAdmin
                        ? Text('Akun administrator sementara tidak bisa diganti passwordnya. Hubungkan ke server, lalu gunakan akun dari server.',
                            style: YmTextStyles.label.copyWith(fontSize: 12.5))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!app.canUseServer)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text('Ganti password butuh koneksi ke server. Saat ini offline.',
                                      style: YmTextStyles.label.copyWith(fontSize: 12.5, color: YmColors.statusAway)),
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _old,
                                      obscureText: _obscure,
                                      decoration: fieldDecoration('Password lama', icon: Icons.lock_outline_rounded),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _new,
                                      obscureText: _obscure,
                                      decoration: fieldDecoration('Password baru (min. 8)', icon: Icons.lock_rounded),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _new2,
                                      obscureText: _obscure,
                                      onSubmitted: (_) => _changePassword(),
                                      decoration: fieldDecoration(
                                        'Ulangi password baru',
                                        icon: Icons.lock_rounded,
                                        suffix: IconButton(
                                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                                          onPressed: () => setState(() => _obscure = !_obscure),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 10),
                                Text(_error!, style: TextStyle(color: YmColors.buzzRed, fontSize: 12.5)),
                              ],
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  style: primaryButtonStyle(),
                                  onPressed: _saving || !app.canUseServer ? null : _changePassword,
                                  icon: const Icon(Icons.save_rounded, size: 18),
                                  label: Text(_saving ? 'Menyimpan...' : 'Simpan Password Baru'),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    title: 'Sesi',
                    icon: Icons.manage_accounts_rounded,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Logout untuk berganti pengguna. Dokumen yang belum terupload tetap aman di PC ini dan akan diunggah otomatis.',
                            style: YmTextStyles.chatText.copyWith(fontSize: 12.5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          style: outlineButtonStyle(),
                          onPressed: () async {
                            if (await confirmDialog(context, title: 'Logout?', message: 'Anda akan kembali ke halaman login.', ok: 'Logout')) {
                              app.logout();
                            }
                          },
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Logout'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: primaryButtonStyle(color: YmColors.buzzRed),
                          onPressed: () => confirmExit(context),
                          icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                          label: const Text('Keluar Aplikasi'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
