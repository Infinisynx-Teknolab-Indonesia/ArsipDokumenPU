import 'package:flutter/material.dart';
import '../core/categories.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../services/nav.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';
import 'doc_detail.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.session!;
        final docs = app.visibleDocs;
        final now = DateTime.now();
        final thisMonth = docs.where((d) => d.createdAt.year == now.year && d.createdAt.month == now.month).length;
        final running = app.projects.where((p) => p.status == 'Pelaksanaan' || p.status == 'PHO' || p.status == 'Masa Pemeliharaan').toList();
        final yearValue = app.projects.where((p) => p.year == now.year).fold<double>(0, (a, p) => a + p.contractValue);
        final docCountByProject = <String, int>{};
        final byCategory = <String, int>{};
        for (final d in docs) {
          if (d.projectId.isNotEmpty) docCountByProject[d.projectId] = (docCountByProject[d.projectId] ?? 0) + 1;
          byCategory[d.category] = (byCategory[d.category] ?? 0) + 1;
        }
        final catSorted = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final maxCat = catSorted.isEmpty ? 1 : catSorted.first.value;

        return PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Welcome(name: s.fullName, setup: s.isSetupAdmin),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Total Dokumen Arsip',
                      value: '${docs.length}',
                      sub: '${formatBytes(docs.fold<int>(0, (a, d) => a + d.fileSize))} tersimpan',
                      icon: Icons.folder_copy_rounded,
                      color: YmColors.accentPurple,
                      onTap: () => Nav.go('docs'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: StatCard(
                      label: 'Proyek / Paket',
                      value: '${app.projects.length}',
                      sub: '${running.length} sedang berjalan',
                      icon: Icons.engineering_rounded,
                      color: const Color(0xFF1F7AE0),
                      onTap: () => Nav.go('projects'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: StatCard(
                      label: 'Nilai Kontrak TA ${now.year}',
                      value: formatRupiahShort(yearValue),
                      sub: 'total paket tahun ini',
                      icon: Icons.account_balance_rounded,
                      color: const Color(0xFF0E8F7E),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: StatCard(
                      label: 'Antrian Upload',
                      value: '${app.pendingCount}',
                      sub: app.failedCount > 0 ? '${app.failedCount} gagal' : '$thisMonth dokumen bulan ini',
                      icon: Icons.cloud_upload_rounded,
                      color: app.pendingCount > 0 || app.failedCount > 0 ? YmColors.statusAway : YmColors.statusOnline,
                      onTap: () => s.isAdmin ? Nav.go('docs') : Nav.showMyDocs(app.failedCount > 0 ? 'failed' : 'unsynced'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Panel(
                      title: 'Dokumen per Kategori',
                      icon: Icons.bar_chart_rounded,
                      child: catSorted.isEmpty
                          ? const Padding(padding: EdgeInsets.all(12), child: Text('Belum ada dokumen.', style: YmTextStyles.label))
                          : Column(
                              children: [
                                for (final e in catSorted.take(10))
                                  _CategoryBar(code: e.key, count: e.value, max: maxCat),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 6,
                    child: Panel(
                      title: 'Proyek Berjalan',
                      icon: Icons.construction_rounded,
                      trailing: TextButton(onPressed: () => Nav.go('projects'), child: const Text('Semua proyek')),
                      child: running.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                app.setupMode ? 'Hubungkan ke server untuk memuat data proyek.' : 'Belum ada proyek berstatus Pelaksanaan.',
                                style: YmTextStyles.label,
                              ),
                            )
                          : Column(
                              children: [
                                for (final p in running.take(6)) _ProjectRow(project: p, docCount: docCountByProject[p.id] ?? 0),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Panel(
                title: 'Dokumen Terbaru',
                icon: Icons.schedule_rounded,
                padding: const EdgeInsets.symmetric(vertical: 6),
                trailing: TextButton(onPressed: () => Nav.go('docs'), child: const Text('Buka arsip')),
                child: docs.isEmpty
                    ? EmptyState(
                        icon: Icons.upload_file_rounded,
                        title: 'Arsip masih kosong',
                        message: 'Mulai dengan mengunggah dokumen proyek: kontrak, laporan, gambar, foto progres, dan lainnya.',
                        action: ElevatedButton.icon(
                          style: primaryButtonStyle(),
                          onPressed: () => Nav.go('upload'),
                          icon: const Icon(Icons.upload_rounded, size: 18),
                          label: const Text('Unggah Dokumen'),
                        ),
                      )
                    : Column(children: [for (final d in docs.take(8)) _RecentRow(doc: d)]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Welcome extends StatelessWidget {
  final String name;
  final bool setup;
  const _Welcome({required this.name, required this.setup});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greet = hour < 11 ? 'Selamat pagi' : hour < 15 ? 'Selamat siang' : hour < 18 ? 'Selamat sore' : 'Selamat malam';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [YmColors.titleBarStart, YmColors.titleBarEnd]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greet, $name', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  setup
                      ? 'Aplikasi belum terhubung ke server. Atur alamat API di menu Server API agar staf bisa login.'
                      : 'Arsip digital dokumen proyek ${AppState.instance.agencyName}. Dokumen tetap tersimpan walau internet mati.',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (setup)
            ElevatedButton.icon(
              style: primaryButtonStyle(color: Colors.white).copyWith(foregroundColor: const WidgetStatePropertyAll(YmColors.accentPurple)),
              onPressed: () => Nav.go('server'),
              icon: const Icon(Icons.dns_rounded, size: 18),
              label: const Text('Atur Server API'),
            )
          else ...[
            ElevatedButton.icon(
              style: primaryButtonStyle(color: Colors.white).copyWith(foregroundColor: const WidgetStatePropertyAll(YmColors.accentPurple)),
              onPressed: () => Nav.go('upload'),
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('Unggah Dokumen'),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Nav.go('docs'),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Cari Arsip'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String code;
  final int count;
  final int max;
  const _CategoryBar({required this.code, required this.count, required this.max});

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(code);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(c.icon, size: 15, color: c.color),
          const SizedBox(width: 8),
          SizedBox(width: 190, child: Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.chatText.copyWith(fontSize: 12))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: count / max,
                minHeight: 10,
                backgroundColor: YmColors.panelBackground,
                valueColor: AlwaysStoppedAnimation(c.color),
              ),
            ),
          ),
          SizedBox(width: 44, child: Text('$count', textAlign: TextAlign.right, style: YmTextStyles.username)),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final Project project;
  final int docCount;
  const _ProjectRow({required this.project, required this.docCount});

  @override
  Widget build(BuildContext context) {
    final p = project;
    return InkWell(
      onTap: () => Nav.openDocsForProject(p.id),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.username),
                  const SizedBox(height: 2),
                  Text('${p.code} • ${p.type} • ${p.location}', maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.label.copyWith(fontSize: 11)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: p.progress / 100,
                            minHeight: 7,
                            backgroundColor: YmColors.panelBackground,
                            valueColor: const AlwaysStoppedAnimation(YmColors.statusOnline),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${p.progress}%', style: YmTextStyles.label.copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              children: [
                Text('$docCount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: YmColors.accentPurple)),
                Text('dokumen', style: YmTextStyles.label.copyWith(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final DocRecord doc;
  const _RecentRow({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc;
    return ListTile(
      dense: true,
      onTap: () => showDocDetail(context, d),
      leading: FileTypeIcon(ext: d.extension),
      title: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.username),
      subtitle: Text(
        [if (d.projectCode.isNotEmpty) d.projectCode, categoryOf(d.category).label, '${d.createdByName} • ${formatDateTime(d.createdAt)}'].join('  •  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: YmTextStyles.label.copyWith(fontSize: 11),
      ),
      trailing: DocStatusChip(status: d.status),
    );
  }
}
