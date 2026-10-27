import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/categories.dart';
import '../core/file_tools.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../services/nav.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';
import 'doc_detail.dart';

const _bulanPanjang = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

/// Dashboard (versi web: "Archive Overview & Operations").
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

        // ---- angka
        final thisWeek = docs.where((d) => now.difference(d.createdAt).inDays < 7).length;
        final weekly = List<double>.generate(10, (i) {
          final from = now.subtract(Duration(days: 7 * (10 - i)));
          final to = from.add(const Duration(days: 7));
          return docs.where((d) => d.createdAt.isAfter(from) && !d.createdAt.isAfter(to)).length.toDouble();
        });
        final onServer = docs.where((d) => d.status == DocStatus.uploaded).toList();
        final readOk = onServer.where((d) => d.contentStatus == 'ok').length;
        final readQueue = onServer.where((d) => d.contentStatus.isEmpty || d.contentStatus == 'pending').length;
        final readPct = onServer.isEmpty ? 1.0 : readOk / onServer.length;
        final failed = docs.where((d) => d.status == DocStatus.failed).toList();
        final drafts = app.myDrafts;
        final attention = failed.length + drafts.length + app.pendingRequests + (s.isAdmin ? app.pendingDevices : 0);
        final local = app.pendingCount + app.draftCount;
        final totalBytes = docs.fold<int>(0, (a, d) => a + d.fileSize);

        return PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                overline: 'Pusat kendali arsip',
                overlineIcon: Icons.verified_outlined,
                title: 'Ringkasan Arsip & Operasional',
                subtitle: 'Kondisi arsip ${app.agencyName} saat ini: dokumen terindeks, pembacaan isi file, distribusi kategori, dan antrian sinkron.',
                actions: [
                  _DateChip(now: now),
                  OutlinedButton.icon(
                    style: outlineButtonStyle(),
                    onPressed: docs.isEmpty
                        ? null
                        : () async {
                            final path = await FileTools.exportDocsCsv(docs, fileName: 'ringkasan_arsip_${isoDate(now)}.csv');
                            if (path != null && context.mounted) showSnack(context, 'Daftar ${docs.length} dokumen diekspor ke $path');
                          },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Ekspor daftar (CSV)'),
                  ),
                  ElevatedButton.icon(
                    style: primaryButtonStyle(),
                    onPressed: () => Nav.go(s.isSetupAdmin ? 'server' : 'upload'),
                    icon: Icon(s.isSetupAdmin ? Icons.dns_outlined : Icons.document_scanner_outlined, size: 18),
                    label: Text(s.isSetupAdmin ? 'Hubungkan server' : 'Unggah cepat'),
                  ),
                ],
              ),
              if (s.isSetupAdmin) ...[const SizedBox(height: 20), const _SetupBanner()],
              const SizedBox(height: 24),
              // ---- 4 kartu angka
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Reveal(
                      index: 0,
                      child: StatCard(
                        label: 'Total dokumen terarsip',
                        value: '${docs.length}',
                        number: docs.length,
                        unit: 'dokumen',
                        icon: Icons.source_outlined,
                        color: YmColors.primary,
                        chip: SoftChip.success('+$thisWeek minggu ini', icon: Icons.trending_up_rounded),
                        sub: '${formatBytes(totalBytes)} — PDF, Word, Excel, foto & gambar dari semua kategori',
                        footer: Sparkline(values: weekly),
                        onTap: () => Nav.go('docs'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Reveal(
                      index: 1,
                      child: StatCard(
                        label: 'Isi file terbaca',
                        value: '$readOk',
                        number: readOk,
                        unit: 'siap dicari',
                        icon: Icons.manage_search_rounded,
                        color: YmColors.accent,
                        chip: SoftChip.primary('${(readPct * 100).round()}% terbaca', icon: Icons.circle),
                        sub: 'Teks PDF, Word, dan Excel dibaca server supaya bisa dicari sampai ke isinya.',
                        footer: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          ProgressBar(value: readPct),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: Text('${onServer.length} di server', style: YmTextStyles.label)),
                            Text('$readQueue antre dibaca', style: YmTextStyles.label),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Reveal(
                      index: 2,
                      child: StatCard(
                        label: 'Perlu tindakan',
                        value: '$attention',
                        number: attention,
                        unit: 'item',
                        icon: Icons.notification_important_outlined,
                        color: attention > 0 ? YmColors.danger : YmColors.success,
                        chip: attention > 0 ? SoftChip.danger('Perlu perhatian', icon: Icons.priority_high_rounded) : SoftChip.success('Beres', icon: Icons.check_rounded),
                        sub: [
                          '${failed.length} gagal unggah',
                          '${drafts.length} draf',
                          '${app.pendingRequests} permintaan edit',
                          if (s.isAdmin) '${app.pendingDevices} PC baru',
                        ].join(' • '),
                        footer: Wrap(spacing: 6, runSpacing: 6, children: [
                          if (failed.isNotEmpty) SoftChip('${failed.length} upload ulang', bg: YmColors.surfaceAlt),
                          if (app.pendingRequests > 0) SoftChip('${app.pendingRequests} ditinjau', bg: YmColors.surfaceAlt),
                          if (attention == 0) SoftChip('Tidak ada antrian', bg: YmColors.surfaceAlt),
                        ]),
                        onTap: () => Nav.showMyDocs(failed.isNotEmpty ? 'failed' : 'draft'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Reveal(
                      index: 3,
                      child: StatCard(
                        label: 'Tersimpan di PC ini',
                        value: '$local',
                        number: local,
                        unit: 'menunggu sinkron',
                        icon: Icons.cloud_sync_outlined,
                        color: YmColors.warning,
                        chip: SoftChip.success('Aman di PC', icon: Icons.circle),
                        sub: 'Disimpan di PC. Terkirim otomatis begitu server terhubung.',
                        footer: Row(children: [
                          Icon(Icons.lock_outline_rounded, size: 15, color: YmColors.primary),
                          const SizedBox(width: 4),
                          Text('Database lokal', style: TextStyle(fontFamily: kFont, fontSize: 12, fontWeight: FontWeight.w600, color: YmColors.primary)),
                          const Spacer(),
                          Text(app.lastSyncAt == null ? 'belum sinkron' : 'Sinkron ${timeAgo(app.lastSyncAt)}', style: YmTextStyles.label),
                        ]),
                        onTap: () => Nav.go('local'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              // ---- distribusi + unggah cepat
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: Reveal(index: 4, child: _CategoryPanel(docs: docs))),
                  const SizedBox(width: 18),
                  const Expanded(child: Reveal(index: 5, child: _QuickUpload())),
                ],
              ),
              const SizedBox(height: 22),
              // ---- perlu tindakan + aktivitas
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: Reveal(index: 6, child: _ActionPanel(failed: failed, drafts: drafts))),
                  const SizedBox(width: 18),
                  Expanded(child: Reveal(index: 7, child: _ActivityPanel(docs: docs))),
                ],
              ),
              const SizedBox(height: 22),
              Reveal(index: 8, child: _ProjectsPanel(docs: docs)),
              const SizedBox(height: 18),
              Row(children: [
                Icon(Icons.storage_rounded, size: 16, color: YmColors.outline),
                const SizedBox(width: 6),
                Text('Database lokal (NoSQL) • ${CountUp.dots(app.allDocs.length)} catatan dokumen tersimpan untuk kerja offline',
                    style: YmTextStyles.label.copyWith(fontSize: 12)),
                const Spacer(),
                Text(app.lastPullAt == null ? '' : 'Data server diperbarui ${formatDateTime(app.lastPullAt)}', style: YmTextStyles.label.copyWith(fontSize: 12)),
              ]),
            ],
          ),
        );
      },
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime now;
  const _DateChip({required this.now});

  @override
  Widget build(BuildContext context) => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(12), boxShadow: softShadow),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_outlined, size: 17, color: YmColors.textMuted),
          const SizedBox(width: 8),
          Text('Hari ini, ${now.day} ${_bulanPanjang[now.month - 1]} ${now.year}',
              style: TextStyle(fontFamily: kFont, fontSize: 13, fontWeight: FontWeight.w600, color: YmColors.textDark)),
        ]),
      );
}

class _SetupBanner extends StatelessWidget {
  const _SetupBanner();

  @override
  Widget build(BuildContext context) => Reveal(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [YmColors.primaryDeep, YmColors.primary]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const Icon(Icons.dns_outlined, color: Colors.white, size: 28),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Aplikasi belum terhubung ke server. Hubungkan dulu supaya staf bisa login dan dokumen tersimpan di server. '
                'Semua fitur admin server (persetujuan PC, email, member) ada di aplikasi ini.',
                style: TextStyle(fontFamily: kFont, color: Colors.white, fontSize: 13.5, height: 1.5),
              ),
            ),
            const SizedBox(width: 14),
            ElevatedButton(
              style: primaryButtonStyle(color: Colors.white).copyWith(foregroundColor: WidgetStatePropertyAll(YmColors.primary)),
              onPressed: () => Nav.go('server'),
              child: const Text('Hubungkan server'),
            ),
          ]),
        ),
      );
}

/// Warna seri grafik dari tema (versi web: primary, primary-container, secondary, tertiary, abu).
List<Color> get _seriesColors => [YmColors.primary, YmColors.accent, YmColors.success, YmColors.warning, YmColors.outline];

class _CategoryPanel extends StatelessWidget {
  final List<DocRecord> docs;
  const _CategoryPanel({required this.docs});

  @override
  Widget build(BuildContext context) {
    final byCat = <String, List<DocRecord>>{};
    for (final d in docs) {
      byCat.putIfAbsent(d.category, () => []).add(d);
    }
    final sorted = byCat.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    final top = sorted.take(4).toList();
    final rest = sorted.skip(4).expand((e) => e.value).toList();
    final groups = <(String, String, List<DocRecord>)>[
      for (final e in top) (e.key, categoryOf(e.key).label, e.value),
      if (rest.isNotEmpty) ('', 'Kategori lainnya', rest),
    ];
    final total = math.max(1, docs.length);
    final totalBytes = docs.fold<int>(0, (a, d) => a + d.fileSize);
    final hashed = docs.where((d) => d.sha256.isNotEmpty).length;

    return Panel(
      title: 'Distribusi kategori & penyimpanan',
      subtitle: 'Total ${formatBytes(totalBytes)} dari ${CountUp.dots(docs.length)} dokumen terdigitalisasi',
      icon: Icons.pie_chart_outline_rounded,
      trailing: TextButton(
        onPressed: () => Nav.go('docs'),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Lihat semua dokumen'), SizedBox(width: 4), Icon(Icons.arrow_forward_rounded, size: 16)]),
      ),
      child: docs.isEmpty
          ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text('Belum ada dokumen.', style: YmTextStyles.label))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                // batang bertumpuk yang tumbuh dari kiri
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: motion(context, const Duration(milliseconds: 1100)),
                  curve: Curves.easeOutCubic,
                  builder: (_, t, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 12,
                      child: Row(children: [
                        for (var i = 0; i < groups.length; i++)
                          Expanded(
                            flex: math.max(1, (groups[i].$3.length * 1000 * t / total).round()),
                            child: Container(
                              margin: EdgeInsets.only(right: i == groups.length - 1 ? 0 : 2),
                              color: _seriesColors[i % _seriesColors.length],
                            ),
                          ),
                        Expanded(flex: math.max(1, ((1 - t) * 1000).round()), child: Container(color: YmColors.surfaceContainer)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, c) {
                  final w = (c.maxWidth - 24) / 3;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < groups.length; i++)
                        SizedBox(
                          width: w,
                          child: _CatTile(
                            color: _seriesColors[i % _seriesColors.length],
                            label: groups[i].$2,
                            count: groups[i].$3.length,
                            pct: groups[i].$3.length / total,
                            bytes: groups[i].$3.fold<int>(0, (a, d) => a + d.fileSize),
                            sub: groups[i].$1.isEmpty
                                ? '${sorted.length - top.length} kategori lain'
                                : '${groups[i].$3.where((d) => d.status == DocStatus.uploaded).length} di server',
                            onTap: groups[i].$1.isEmpty ? () => Nav.go('docs') : () => Nav.openCategory(groups[i].$1),
                          ),
                        ),
                      SizedBox(
                        width: w,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          height: 118,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [YmColors.primary, YmColors.primaryDeep]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('RINGKASAN AUDIT',
                                style: TextStyle(fontFamily: kFont, fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.7))),
                            const SizedBox(height: 6),
                            const Text('Semua dokumen tercatat',
                                style: TextStyle(fontFamily: kFontDisplay, fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, height: 1.25)),
                            const Spacer(),
                            Row(children: [
                              Expanded(
                                child: Text('$hashed sidik jari SHA-256',
                                    style: TextStyle(fontFamily: kFont, fontSize: 11.5, color: Colors.white.withOpacity(0.75))),
                              ),
                              const Icon(Icons.verified_user_outlined, size: 18, color: Colors.white),
                            ]),
                          ]),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
    );
  }
}

class _CatTile extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final double pct;
  final int bytes;
  final String sub;
  final VoidCallback onTap;
  const _CatTile({required this.color, required this.label, required this.count, required this.pct, required this.bytes, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => HoverCard(
        onTap: onTap,
        color: YmColors.surfaceAlt,
        padding: const EdgeInsets.all(14),
        radius: 12,
        child: SizedBox(
          height: 90,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.username.copyWith(fontSize: 12.5))),
              Text('${(pct * 100).round()}%', style: TextStyle(fontFamily: kFont, fontSize: 12, fontWeight: FontWeight.w700, color: YmColors.primary)),
            ]),
            const Spacer(),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              CountUp(value: count, style: YmTextStyles.bigNumber.copyWith(fontSize: 22)),
              const SizedBox(width: 6),
              Text('dokumen • ${formatBytes(bytes)}', style: YmTextStyles.label),
            ]),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(fontFamily: kFont, fontSize: 11.5, color: YmColors.success, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _QuickUpload extends StatelessWidget {
  const _QuickUpload();

  @override
  Widget build(BuildContext context) {
    Widget feat(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            Icon(icon, size: 17, color: YmColors.textMuted),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: YmTextStyles.chatText.copyWith(fontSize: 12.5))),
            Icon(Icons.check_circle_rounded, size: 18, color: YmColors.primary),
          ]),
        );
    return Panel(
      title: 'Unggah cepat',
      subtitle: 'Kontrak, laporan, gambar kerja, foto progres, berita acara.',
      icon: Icons.upload_file_outlined,
      trailing: SoftChip.primary('Otomatis'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          _DashedBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              child: Column(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: YmColors.surface, shape: BoxShape.circle, boxShadow: softShadow),
                  child: Icon(Icons.cloud_upload_outlined, color: YmColors.primary, size: 26),
                ),
                const SizedBox(height: 12),
                Text('Pilih file untuk diarsipkan', style: YmTextStyles.headline.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text('PDF, Word, Excel, foto, gambar CAD, atau ZIP', textAlign: TextAlign.center, style: YmTextStyles.label.copyWith(fontSize: 12)),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ElevatedButton(style: primaryButtonStyle(), onPressed: () => Nav.go('upload'), child: const Text('Pilih file')),
                  const SizedBox(width: 8),
                  OutlinedButton(style: outlineButtonStyle(), onPressed: () => Nav.go('mydocs'), child: const Text('Dokumen saya')),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          feat(Icons.auto_awesome_outlined, 'Isi PDF/Word/Excel dibaca untuk pencarian'),
          feat(Icons.pin_outlined, 'Kode & nomor dikenali (mis. 544)'),
          feat(Icons.laptop_mac_outlined, 'Tersimpan di PC bila server mati'),
        ],
      ),
    );
  }
}

/// Kotak bergaris putus-putus (area unggah).
class _DashedBox extends StatelessWidget {
  final Widget child;
  const _DashedBox({required this.child});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashPainter(YmColors.primary.withOpacity(0.35)),
        child: Container(
          decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(14)),
          child: child,
        ),
      );
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    final path = Path()..addRRect(rr);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}

class _ActionPanel extends StatelessWidget {
  final List<DocRecord> failed;
  final List<DocRecord> drafts;
  const _ActionPanel({required this.failed, required this.drafts});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final s = app.session!;
    final items = <Widget>[
      if (s.isAdmin && app.pendingDevices > 0)
        _ActionItem(
          icon: Icons.devices_outlined,
          title: '${app.pendingDevices} PC baru menunggu persetujuan',
          tag: 'Keamanan',
          tagColor: YmColors.danger,
          desc: 'Staf belum bisa login di PC tersebut sampai Anda menyetujuinya.',
          primary: ('Tinjau PC', () => Nav.go('devices')),
        ),
      if (app.pendingRequests > 0)
        _ActionItem(
          icon: Icons.rate_review_outlined,
          title: '${app.pendingRequests} permintaan perubahan dokumen',
          tag: s.isAdmin ? 'Menunggu Anda' : 'Menunggu admin',
          tagColor: YmColors.warning,
          desc: 'Perubahan data atau file dokumen yang sudah diarsipkan.',
          primary: ('Buka', () => Nav.go('requests')),
        ),
      for (final d in failed.take(3))
        _ActionItem(
          icon: Icons.cloud_off_outlined,
          title: d.title,
          tag: 'Gagal diunggah',
          tagColor: YmColors.danger,
          desc: d.lastError ?? 'Dokumen belum masuk server.',
          secondary: ('Lihat', () => showDocDetail(context, d)),
          primary: ('Upload ulang', () => app.retryDoc(d)),
        ),
      for (final d in drafts.take(3))
        _ActionItem(
          icon: Icons.edit_note_rounded,
          title: d.title,
          tag: 'Draf belum dikirim',
          tagColor: YmColors.primary,
          desc: '${categoryOf(d.category).label} • diinput ${timeAgo(d.createdAt)} • periksa isi file sebelum dikirim',
          primary: ('Periksa & kirim', () => showDocDetail(context, d)),
        ),
    ];
    return Panel(
      title: 'Perlu tindakan segera',
      subtitle: 'Selesaikan supaya semua dokumen tersimpan aman di server.',
      icon: Icons.report_outlined,
      trailing: items.isEmpty ? SoftChip.success('Beres') : SoftChip.danger('${items.length} prioritas'),
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(children: [
                Icon(Icons.task_alt_rounded, size: 34, color: YmColors.success),
                const SizedBox(height: 8),
                Text('Tidak ada yang perlu ditindaklanjuti.', style: YmTextStyles.chatText),
              ]),
            )
          : Column(children: [
              const SizedBox(height: 6),
              for (var i = 0; i < items.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: Reveal(index: i, child: items[i])),
            ]),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String tag;
  final Color tagColor;
  final String desc;
  final (String, VoidCallback) primary;
  final (String, VoidCallback)? secondary;
  const _ActionItem({required this.icon, required this.title, required this.tag, required this.tagColor, required this.desc, required this.primary, this.secondary});

  @override
  Widget build(BuildContext context) => HoverCard(
        color: YmColors.surfaceAlt,
        radius: 12,
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(10), boxShadow: softShadow),
            child: Icon(icon, color: YmColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.username.copyWith(fontSize: 13.5)),
              const SizedBox(height: 5),
              SoftChip(tag, fg: tagColor, bg: tagColor.withOpacity(0.12), bold: true),
              const SizedBox(height: 5),
              Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: YmTextStyles.label.copyWith(fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 12),
          if (secondary != null) ...[
            OutlinedButton(style: outlineButtonStyle().copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
                onPressed: secondary!.$2, child: Text(secondary!.$1)),
            const SizedBox(width: 8),
          ],
          ElevatedButton(
            style: primaryButtonStyle().copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 10))),
            onPressed: primary.$2,
            child: Text(primary.$1),
          ),
        ]),
      );
}

class _ActivityPanel extends StatelessWidget {
  final List<DocRecord> docs;
  const _ActivityPanel({required this.docs});

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance.session!;
    final recent = docs.take(6).toList();
    return Panel(
      title: 'Aktivitas terbaru',
      icon: Icons.history_rounded,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        PulseDot(color: YmColors.success, size: 6),
        const SizedBox(width: 4),
        Text('Langsung', style: TextStyle(fontFamily: kFont, fontSize: 12, fontWeight: FontWeight.w600, color: YmColors.success)),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          if (recent.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text('Belum ada aktivitas.', style: YmTextStyles.label)),
          for (var i = 0; i < recent.length; i++)
            Reveal(
              index: i,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => showDocDetail(context, recent[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FileTypeIcon(ext: recent[i].extension, size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(recent[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.username.copyWith(fontSize: 13)),
                        Text(
                          recent[i].isUnsynced ? 'Diinput ${recent[i].createdByName} • belum di server' : 'Diunggah ${recent[i].createdByName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: YmTextStyles.label.copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: timeAgo(recent[i].createdAt)),
                            const TextSpan(text: '  •  '),
                            TextSpan(text: categoryOf(recent[i].category).label.split(' /').first, style: TextStyle(color: YmColors.link, fontWeight: FontWeight.w600)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: kFont, fontSize: 11.5, color: YmColors.outline),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(backgroundColor: YmColors.surfaceAlt, padding: const EdgeInsets.symmetric(vertical: 12)),
            onPressed: () => Nav.go(s.isAdmin ? 'audit' : 'docs'),
            child: Text(s.isAdmin ? 'Lihat log aktivitas lengkap' : 'Lihat semua dokumen'),
          ),
        ],
      ),
    );
  }
}

class _ProjectsPanel extends StatelessWidget {
  final List<DocRecord> docs;
  const _ProjectsPanel({required this.docs});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final running = app.projects.where((p) => p.status == 'Pelaksanaan' || p.status == 'PHO' || p.status == 'Masa Pemeliharaan').toList();
    final list = (running.isEmpty ? app.projects : running).take(4).toList();
    final count = <String, int>{};
    for (final d in docs) {
      if (d.projectId.isNotEmpty) count[d.projectId] = (count[d.projectId] ?? 0) + 1;
    }
    final yearValue = app.projects.where((p) => p.year == DateTime.now().year).fold<double>(0, (a, p) => a + p.contractValue);
    return Panel(
      title: running.isEmpty ? 'Proyek / paket' : 'Proyek berjalan',
      subtitle: 'Nilai kontrak TA ${DateTime.now().year}: ${formatRupiahShort(yearValue)} dari ${app.projects.length} paket',
      icon: Icons.engineering_outlined,
      trailing: SoftChip.success('${running.length} berjalan'),
      child: list.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(app.setupMode ? 'Hubungkan ke server untuk memuat data proyek.' : 'Belum ada proyek.', style: YmTextStyles.label),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: _ProjectTile(p: list[i], docs: count[list[i].id] ?? 0)),
                ],
                for (var i = list.length; i < 4; i++) ...[const SizedBox(width: 12), const Expanded(child: SizedBox())],
              ]),
            ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final Project p;
  final int docs;
  const _ProjectTile({required this.p, required this.docs});

  @override
  Widget build(BuildContext context) {
    final icon = switch (p.type) {
      'Jembatan' => Icons.architecture_rounded,
      'Gedung / Bangunan' => Icons.apartment_rounded,
      'Irigasi' || 'Drainase' => Icons.water_rounded,
      'Air Minum / Sanitasi' => Icons.water_drop_outlined,
      _ => Icons.add_road_rounded,
    };
    return HoverCard(
      color: YmColors.surfaceAlt,
      radius: 12,
      onTap: () => Nav.openDocsForProject(p.id),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(10), boxShadow: softShadow),
            child: Icon(icon, size: 20, color: YmColors.primary),
          ),
          const Spacer(),
          SoftChip.success(p.status),
        ]),
        const SizedBox(height: 12),
        Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: YmTextStyles.headline.copyWith(fontSize: 14.5)),
        const SizedBox(height: 4),
        Text([p.code, p.location].where((e) => e.isNotEmpty).join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.label.copyWith(fontSize: 12)),
        const SizedBox(height: 12),
        ProgressBar(value: p.progress / 100, color: YmColors.success),
        const SizedBox(height: 8),
        Row(children: [
          Text('Progres ${p.progress}%', style: YmTextStyles.label),
          const Spacer(),
          Text('$docs dokumen', style: TextStyle(fontFamily: kFont, fontSize: 11.5, color: YmColors.primary, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}
