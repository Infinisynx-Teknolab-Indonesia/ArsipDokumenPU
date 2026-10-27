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
import 'doc_quick_view.dart';

const _bulanPanjang = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

/// Jarak versi web: space-lg = 24, space-xl = 40.
const double _lg = 24;
const double _xl = 40;

/// Urutan & warna kategori persis versi web (Category Distribution):
/// Invoices = primary, Contracts = primary-container, Shipments = secondary,
/// Tax = tertiary-container, Meeting Minutes = outline.
const _webOrder = ['INVOICE', 'CONTRACT', 'SHIPMENT', 'TAX', 'MEETING'];

Color _catColor(String code) => switch (code) {
      'INVOICE' => YmColors.primary,
      'CONTRACT' => YmColors.primaryContainer,
      'SHIPMENT' => YmColors.success,
      'TAX' => Color.lerp(YmColors.warning, const Color(0xFFB86200), 0.45)!,
      _ => YmColors.outline,
    };

/// Dashboard — replika halaman web "Archive Overview & Operations".
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

        final kpis = <Widget>[
          StatCard(
            label: 'Total dokumen terindeks',
            value: '${docs.length}',
            number: docs.length,
            unit: 'dokumen',
            icon: Icons.source_outlined,
            color: YmColors.primary,
            chip: SoftChip.successStrong('+$thisWeek minggu ini', icon: Icons.trending_up_rounded),
            sub: 'PDF, Word, Excel & foto dari semua kategori (${formatBytes(totalBytes)})',
            footer: Sparkline(values: weekly),
            onTap: () => Nav.go('docs'),
          ),
          StatCard(
            label: 'Isi file terbaca',
            value: '$readOk',
            number: readOk,
            unit: 'Siap dicari',
            unitColor: YmColors.success,
            icon: Icons.manage_search_rounded,
            color: YmColors.primary,
            chip: SoftChip('Sehat (${(readPct * 100).round()}%)', fg: YmColors.primary, bg: YmColors.surfaceContainerHigh, pill: true, bold: true, dot: YmColors.primary),
            sub: 'Nomor, tanggal & nilai uang di PDF/Word/Excel ikut bisa dicari',
            footer: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ProgressBar(value: readPct),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Text('${(readPct * 100).round()}% terbaca', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline))),
                Text('$readQueue antre', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
              ]),
            ]),
          ),
          StatCard(
            label: 'Antrian perlu tindakan',
            value: '$attention',
            number: attention,
            unit: 'item',
            numberColor: attention > 0 ? YmColors.danger : null,
            icon: Icons.notification_important_outlined,
            color: YmColors.onDangerSoft,
            tileBg: YmColors.dangerSoft,
            chip: attention > 0
                ? SoftChip.danger('Perlu perhatian', icon: Icons.priority_high_rounded)
                : SoftChip.successStrong('Beres', icon: Icons.check_rounded),
            sub: '${failed.length} gagal unggah • ${drafts.length} draf • ${app.pendingRequests} permintaan edit',
            footer: Wrap(spacing: 8, runSpacing: 8, children: [
              _MiniTag('${failed.length} upload ulang'),
              _MiniTag(s.isAdmin ? '${app.pendingDevices} PC baru' : '${drafts.length} draf'),
            ]),
            onTap: () => Nav.showMyDocs(failed.isNotEmpty ? 'failed' : 'draft'),
          ),
          StatCard(
            label: 'Tersimpan di PC ini',
            value: '$local',
            number: local,
            unit: 'menunggu sinkron',
            unitColor: YmColors.warning,
            icon: Icons.cloud_sync_outlined,
            color: YmColors.onWarningSoft,
            tileBg: YmColors.warningSoft,
            chip: SoftChip.successStrong('Aman di PC', dot: YmColors.success),
            sub: 'Disimpan di PC. Terkirim otomatis begitu server terhubung.',
            footer: Row(children: [
              Icon(Icons.sync_lock_outlined, size: 16, color: YmColors.primary),
              const SizedBox(width: 4),
              Text('Database lokal', style: YmTextStyles.labelSm.copyWith(color: YmColors.primary)),
              const Spacer(),
              Text(app.lastSyncAt == null ? 'belum sinkron' : 'Sinkron ${timeAgo(app.lastSyncAt)}', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
            ]),
            onTap: () => Nav.go('local'),
          ),
        ];

        final left = <Widget>[
          _CategoryPanel(docs: docs),
          _ActionPanel(failed: failed, drafts: drafts),
          _ServicesPanel(readQueue: readQueue),
        ];
        final right = <Widget>[
          const _QuickUpload(),
          _ActivityPanel(docs: docs),
          _FooterCard(),
        ];

        return PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                overline: 'Pusat kendali arsip',
                overlineIcon: Icons.verified_outlined,
                title: 'Ringkasan Arsip & Operasional',
                subtitle: 'Kondisi arsip saat ini: dokumen terindeks, pembacaan isi file, distribusi kategori, dan antrian sinkron.',
                actions: [
                  _DateChip(now: now),
                  TextButton.icon(
                    style: _secondaryStyle(),
                    onPressed: docs.isEmpty
                        ? null
                        : () async {
                            final path = await FileTools.exportDocsCsv(docs, fileName: 'ringkasan_arsip_${isoDate(now)}.csv');
                            if (path != null && context.mounted) showSnack(context, 'Daftar ${docs.length} dokumen diekspor ke $path');
                          },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Unduh ringkasan (CSV)'),
                  ),
                  ElevatedButton.icon(
                    style: primaryButtonStyle(),
                    onPressed: () => Nav.go(s.isSetupAdmin ? 'server' : 'upload'),
                    icon: Icon(s.isSetupAdmin ? Icons.dns_outlined : Icons.document_scanner_outlined, size: 18),
                    label: Text(s.isSetupAdmin ? 'Hubungkan server' : 'Unggah cepat'),
                  ),
                ],
              ),
              if (s.isSetupAdmin) ...[const SizedBox(height: _lg), const _SetupBanner()],
              const SizedBox(height: _xl),
              // ---- 4 kartu KPI (grid-cols-4 gap-24)
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth >= 1100 ? 4 : 2;
                final w = (c.maxWidth - _lg * (cols - 1)) / cols;
                return Wrap(
                  spacing: _lg,
                  runSpacing: _lg,
                  children: [for (var i = 0; i < kpis.length; i++) SizedBox(width: w, child: Reveal(index: i, child: kpis[i]))],
                );
              }),
              const SizedBox(height: _xl),
              // ---- grid 12 kolom: kiri 8, kanan 4 (gap-40)
              LayoutBuilder(builder: (context, c) {
                Widget col(List<Widget> items, int base) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0) const SizedBox(height: _xl),
                          Reveal(index: base + i, child: items[i]),
                        ],
                      ],
                    );
                if (c.maxWidth < 1100) {
                  return col([...left, ...right], 4);
                }
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 8, child: col(left, 4)),
                  const SizedBox(width: _xl),
                  Expanded(flex: 4, child: col(right, 7)),
                ]);
              }),
            ],
          ),
        );
      },
    );
  }
}

/// Tombol sekunder versi web: bg-surface-container hover:bg-surface-container-high, rounded-xl.
ButtonStyle _secondaryStyle() => ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      foregroundColor: WidgetStatePropertyAll(YmColors.textDark),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      backgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.hovered) ? YmColors.surfaceContainerHigh : YmColors.surfaceContainer),
      textStyle: WidgetStatePropertyAll(YmTextStyles.labelLg),
    );

/// Tombol kecil di kartu (px-16 py-6 rounded-lg label-md).
ButtonStyle _smallStyle({required bool primary, Color? color}) {
  final base = color ?? YmColors.primary;
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    foregroundColor: WidgetStatePropertyAll(primary ? Colors.white : YmColors.textDark),
    backgroundColor: WidgetStateProperty.resolveWith((st) {
      final h = st.contains(WidgetState.hovered);
      if (primary) return h && color == null ? YmColors.primaryContainer : (h ? base.withOpacity(0.9) : base);
      return h ? YmColors.paper : YmColors.surface;
    }),
    textStyle: WidgetStatePropertyAll(YmTextStyles.labelMd.copyWith(fontWeight: primary ? FontWeight.w600 : FontWeight.w500)),
  );
}

class _MiniTag extends StatelessWidget {
  final String text;
  const _MiniTag(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: YmColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: YmTextStyles.labelSm.copyWith(color: YmColors.textDark, fontWeight: FontWeight.w500)),
      );
}

class _DateChip extends StatelessWidget {
  final DateTime now;
  const _DateChip({required this.now});

  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(12), boxShadow: shadowSm),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_outlined, size: 18, color: YmColors.primary),
          const SizedBox(width: 4),
          Text('Hari ini, ${now.day} ${_bulanPanjang[now.month - 1]} ${now.year}', style: YmTextStyles.labelLg.copyWith(color: YmColors.textDark)),
        ]),
      );
}

class _SetupBanner extends StatelessWidget {
  const _SetupBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(_lg),
        decoration: BoxDecoration(color: YmColors.primary, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.dns_outlined, color: Colors.white, size: 26),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Aplikasi belum terhubung ke server. Pakai server bawaan atau isi alamat server lain supaya staf bisa login dan dokumen tersimpan di server.',
              style: YmTextStyles.bodyMd.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            style: _smallStyle(primary: false),
            onPressed: () => Nav.go('server'),
            child: const Text('Hubungkan server'),
          ),
        ]),
      );
}

// ============================================================ A. distribusi kategori

class _CategoryPanel extends StatelessWidget {
  final List<DocRecord> docs;
  const _CategoryPanel({required this.docs});

  @override
  Widget build(BuildContext context) {
    final byCat = {for (final c in _webOrder) c: <DocRecord>[]};
    for (final d in docs) {
      byCat[categoryOf(d.category).code]!.add(d);
    }
    final total = docs.isEmpty ? 1 : docs.length;
    final totalBytes = docs.fold<int>(0, (a, d) => a + d.fileSize);
    final hashed = docs.where((d) => d.sha256.isNotEmpty).length;

    return Panel(
      title: 'Distribusi kategori & penyimpanan',
      subtitle: 'Total ${formatBytes(totalBytes)} dari ${CountUp.dots(docs.length)} dokumen terdigitalisasi',
      icon: Icons.pie_chart_outline_rounded,
      trailing: _LinkButton(text: 'Lihat semua dokumen', onTap: () => Nav.go('docs')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // batang bertumpuk h-3.5, p-0.5, gap-0.5 — tumbuh dari kiri
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: motion(context, const Duration(milliseconds: 1100)),
            curve: Curves.easeOutCubic,
            builder: (_, t, __) => Container(
              height: 14,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: YmColors.surfaceContainer, borderRadius: BorderRadius.circular(999)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Row(children: [
                  for (final c in _webOrder)
                    if (byCat[c]!.isNotEmpty)
                      Expanded(
                        flex: math.max(1, (byCat[c]!.length * 1000 * t / total).round()),
                        child: Container(margin: const EdgeInsets.only(right: 2), color: _catColor(c)),
                      ),
                  Expanded(flex: math.max(1, ((1 - t) * 1000).round()), child: const SizedBox()),
                ]),
              ),
            ),
          ),
          const SizedBox(height: _lg),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 640 ? 3 : 2;
            final w = (c.maxWidth - 16 * (cols - 1)) / cols;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final code in _webOrder)
                  SizedBox(width: w, child: _CatTile(code: code, docs: byCat[code]!, total: total)),
                SizedBox(width: w, child: _AuditTile(hashed: hashed, total: docs.length)),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _LinkButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  const _LinkButton({required this.text, required this.onTap});

  @override
  State<_LinkButton> createState() => _LinkButtonState();
}

class _LinkButtonState extends State<_LinkButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = _hover ? YmColors.primaryContainer : YmColors.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.text, style: YmTextStyles.labelMd.copyWith(color: c, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          AnimatedSlide(
            offset: Offset(_hover ? 0.2 : 0, 0),
            duration: motion(context, const Duration(milliseconds: 150)),
            child: Icon(Icons.arrow_forward_rounded, size: 16, color: c),
          ),
        ]),
      ),
    );
  }
}

class _CatTile extends StatelessWidget {
  final String code;
  final List<DocRecord> docs;
  final int total;
  const _CatTile({required this.code, required this.docs, required this.total});

  @override
  Widget build(BuildContext context) {
    final cat = categoryOf(code);
    final color = _catColor(code);
    final bytes = docs.fold<int>(0, (a, d) => a + d.fileSize);
    final server = docs.where((d) => d.status == DocStatus.uploaded).toList();
    final read = server.where((d) => d.contentStatus == 'ok').length;
    final readPct = server.isEmpty ? 0 : (read * 100 / server.length).round();
    final pending = docs.length - server.length;
    return HoverCard(
      onTap: () => Nav.openCategory(code),
      color: YmColors.surfaceAlt,
      hoverColor: YmColors.surfaceContainer,
      baseShadowOverride: const [],
      hoverShadowOverride: const [],
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 84,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Tooltip(
                message: '${cat.labelEn} / ${cat.labelId}',
                child: Text(cat.shortLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelMd.copyWith(color: YmColors.textDark, fontWeight: FontWeight.w600)),
              ),
            ),
            Text('${(docs.length * 100 / total).round()}%', style: YmTextStyles.labelSm.copyWith(color: code == 'MEETING' ? YmColors.outline : color)),
          ]),
          const Spacer(),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text('${docs.length} dokumen', style: YmTextStyles.headlineSm.copyWith(color: YmColors.textDark)),
            const Spacer(),
            Text(formatBytes(bytes), style: YmTextStyles.bodySm.copyWith(color: YmColors.outline)),
          ]),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(children: [
              if (docs.isEmpty)
                const TextSpan(text: 'Belum ada dokumen')
              else if (pending > 0) ...[
                TextSpan(text: '$pending', style: TextStyle(color: YmColors.warning, fontWeight: FontWeight.w500)),
                const TextSpan(text: ' belum di server'),
              ] else ...[
                TextSpan(text: '$readPct%', style: TextStyle(color: YmColors.success, fontWeight: FontWeight.w500)),
                const TextSpan(text: ' isi terbaca'),
              ],
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: YmTextStyles.bodySm,
          ),
        ]),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final int hashed;
  final int total;
  const _AuditTile({required this.hashed, required this.total});

  @override
  Widget build(BuildContext context) => Container(
        height: 116,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: YmColors.primary, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('RINGKASAN AUDIT', style: YmTextStyles.labelSm.copyWith(color: YmColors.onPrimaryContainer, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(hashed == total ? 'Semua dokumen tercatat utuh' : '$hashed dari $total tercatat utuh',
              maxLines: 2, overflow: TextOverflow.ellipsis, style: YmTextStyles.headlineSm.copyWith(color: Colors.white)),
          const Spacer(),
          Row(children: [
            Expanded(child: Text('Tervalidasi SHA-256', style: YmTextStyles.bodySm.copyWith(color: YmColors.onPrimaryContainer))),
            const Icon(Icons.verified_user_outlined, size: 20, color: Colors.white),
          ]),
        ]),
      );
}

// ============================================================ B. perlu tindakan

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
          iconColor: YmColors.primary,
          title: '${app.pendingDevices} PC baru menunggu persetujuan',
          tag: SoftChip.danger('Keamanan'),
          desc: 'Staf belum bisa login di PC tersebut sampai disetujui.',
          primary: ('Tinjau PC', () => Nav.go('devices')),
        ),
      if (app.pendingRequests > 0)
        _ActionItem(
          icon: Icons.rate_review_outlined,
          iconColor: YmColors.warning,
          title: '${app.pendingRequests} permintaan perubahan dokumen',
          tag: SoftChip.warning(s.isAdmin ? 'Menunggu Anda' : 'Menunggu admin'),
          desc: 'Perubahan data atau file dokumen yang sudah diarsipkan.',
          primary: ('Buka', () => Nav.go('requests')),
        ),
      for (final d in failed.take(3))
        _ActionItem(
          icon: Icons.cloud_off_outlined,
          iconColor: YmColors.danger,
          title: d.title,
          tag: SoftChip.danger('Gagal diunggah'),
          desc: d.lastError ?? 'Dokumen belum masuk server.',
          secondary: ('Lihat', () => showDocDetail(context, d)),
          primary: ('Upload ulang', () => app.retryDoc(d)),
        ),
      for (final d in drafts.take(3))
        _ActionItem(
          icon: Icons.edit_note_rounded,
          iconColor: YmColors.success,
          title: d.title,
          tag: SoftChip.neutral('Draf belum dikirim'),
          desc: '${categoryOf(d.category).shortLabel} • diinput ${timeAgo(d.createdAt)} • periksa isi file sebelum dikirim',
          primary: ('Periksa & kirim', () => showDocDetail(context, d)),
          primaryColor: YmColors.success,
        ),
    ];
    return Panel(
      title: 'Perlu tindakan segera',
      subtitle: 'Selesaikan supaya semua dokumen tersimpan aman di server.',
      icon: Icons.report_outlined,
      iconBg: YmColors.dangerSoft,
      iconFg: YmColors.onDangerSoft,
      titleBadge: items.isEmpty ? SoftChip.successStrong('Beres') : SoftChip.danger('${items.length} prioritas'),
      trailing: _LinkButton(text: 'Dokumen saya', onTap: () => Nav.go('mydocs')),
      child: items.isEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Icon(Icons.task_alt_rounded, size: 30, color: YmColors.success),
                const SizedBox(height: 8),
                Text('Tidak ada yang perlu ditindaklanjuti.', style: YmTextStyles.bodyMd),
              ]),
            )
          : Column(children: [
              for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 8), items[i]],
            ]),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget tag;
  final String desc;
  final (String, VoidCallback) primary;
  final (String, VoidCallback)? secondary;
  final Color? primaryColor;
  const _ActionItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.tag,
    required this.desc,
    required this.primary,
    this.secondary,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) => HoverCard(
        color: YmColors.surfaceAlt,
        hoverColor: YmColors.surfaceContainer,
        baseShadowOverride: const [],
        hoverShadowOverride: const [],
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: YmColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelLg.copyWith(color: YmColors.textDark, fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                tag,
              ]),
              const SizedBox(height: 2),
              Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.bodySm),
            ]),
          ),
          const SizedBox(width: 16),
          if (secondary != null) ...[
            ElevatedButton(style: _smallStyle(primary: false).copyWith(elevation: const WidgetStatePropertyAll(1)), onPressed: secondary!.$2, child: Text(secondary!.$1)),
            const SizedBox(width: 4),
          ],
          ElevatedButton(style: _smallStyle(primary: true, color: primaryColor), onPressed: primary.$2, child: Text(primary.$1)),
        ]),
      );
}

// ============================================================ C. koneksi & layanan

class _ServicesPanel extends StatelessWidget {
  final int readQueue;
  const _ServicesPanel({required this.readQueue});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final online = app.isOnline;
    final st = app.settings;
    final host = Uri.tryParse(st.activeUrl)?.authority ?? st.activeUrl;
    final active = [online, true, online].where((e) => e).length;
    final tiles = [
      _ServiceTile(
        icon: Icons.dns_outlined,
        status: online ? 'Terhubung' : (st.isConnected ? 'Offline' : 'Belum diatur'),
        ok: online,
        title: st.usesDefault ? 'Server bawaan' : 'Server lain',
        desc: host.isEmpty ? 'Alamat server belum diisi' : host,
        footLeft: app.lastPullAt == null ? 'Belum ambil data' : 'Data ${timeAgo(app.lastPullAt)}',
        footRight: 'FastAPI + MySQL',
      ),
      _ServiceTile(
        icon: Icons.storage_rounded,
        status: 'Aktif',
        ok: true,
        title: 'Database lokal PC ini',
        desc: '${CountUp.dots(app.allDocs.length)} catatan untuk kerja offline',
        footLeft: '${app.pendingCount} antre kirim',
        footRight: 'Kirim otomatis',
        footRightColor: YmColors.success,
      ),
      _ServiceTile(
        icon: Icons.manage_search_rounded,
        status: online ? 'Berjalan' : 'Menunggu',
        ok: online,
        title: 'Pembaca isi file',
        desc: 'PDF, Word, Excel & TXT dibaca di server',
        footLeft: '$readQueue antre dibaca',
        footRight: 'Pencarian isi',
      ),
    ];
    return Panel(
      title: 'Koneksi & layanan',
      subtitle: 'Server arsip, database di PC ini, dan pembaca isi file untuk pencarian.',
      icon: Icons.hub_outlined,
      trailing: SoftChip('$active layanan aktif', fg: YmColors.onSuccessContainer, bg: YmColors.successContainer, pill: true, bold: true, dot: YmColors.success),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 560) {
          return Column(children: [for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(height: 16), tiles[i]]]);
        }
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(width: 16), Expanded(child: tiles[i])],
          ]),
        );
      }),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final String status;
  final bool ok;
  final String title;
  final String desc;
  final String footLeft;
  final String footRight;
  final Color? footRightColor;
  const _ServiceTile({
    required this.icon,
    required this.status,
    required this.ok,
    required this.title,
    required this.desc,
    required this.footLeft,
    required this.footRight,
    this.footRightColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: YmColors.primary),
            ),
            const Spacer(),
            ok ? SoftChip.successStrong(status) : SoftChip.warning(status),
          ]),
          const SizedBox(height: 8),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelLg.copyWith(color: YmColors.textDark, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: YmTextStyles.bodySm),
          const Spacer(),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text(footLeft, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontWeight: FontWeight.w500))),
            Text(footRight, style: YmTextStyles.labelSm.copyWith(color: footRightColor ?? YmColors.primary, fontWeight: FontWeight.w500)),
          ]),
        ]),
      );
}

// ============================================================ D. unggah cepat

class _QuickUpload extends StatelessWidget {
  const _QuickUpload();

  @override
  Widget build(BuildContext context) {
    Widget toggle(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(icon, size: 18, color: YmColors.outline),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: YmTextStyles.bodySm.copyWith(color: YmColors.textDark))),
            // sakelar "selalu aktif" (w-9 h-5)
            Tooltip(
              message: 'Selalu aktif',
              child: Container(
                width: 36,
                height: 20,
                padding: const EdgeInsets.all(2),
                alignment: Alignment.centerRight,
                decoration: BoxDecoration(color: YmColors.primary, borderRadius: BorderRadius.circular(999)),
                child: Container(width: 16, height: 16, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: shadowSm)),
              ),
            ),
          ]),
        );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.upload_file_outlined, size: 20, color: YmColors.primary),
            const SizedBox(width: 4),
            Expanded(child: Text('Unggah cepat', style: YmTextStyles.headlineSm.copyWith(color: YmColors.textDark))),
            SoftChip('Otomatis', fg: YmColors.primary, bg: YmColors.surfaceContainer, pill: true),
          ]),
          const SizedBox(height: 8),
          Text('Unggah faktur, kontrak, laporan pajak, dokumen pengiriman, atau notulen rapat.', style: YmTextStyles.bodySm),
          const SizedBox(height: 16),
          _DropArea(),
          const SizedBox(height: 16),
          toggle(Icons.auto_awesome_outlined, 'Baca isi file untuk pencarian'),
          toggle(Icons.content_copy_outlined, 'Simpan di PC bila server mati'),
        ],
      ),
    );
  }
}

class _DropArea extends StatefulWidget {
  @override
  State<_DropArea> createState() => _DropAreaState();
}

class _DropAreaState extends State<_DropArea> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => Nav.go('upload'),
          child: AnimatedContainer(
            duration: motion(context, const Duration(milliseconds: 150)),
            padding: const EdgeInsets.all(_lg),
            decoration: BoxDecoration(color: _hover ? YmColors.surfaceContainer : YmColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              AnimatedScale(
                scale: _hover ? 1.05 : 1,
                duration: motion(context, const Duration(milliseconds: 150)),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: shadowSm),
                  child: Icon(Icons.cloud_upload_outlined, color: YmColors.primary, size: 30),
                ),
              ),
              const SizedBox(height: 8),
              Text('Pilih file untuk diarsipkan', textAlign: TextAlign.center, style: YmTextStyles.headlineSm.copyWith(color: YmColors.textDark)),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text('PDF, Word, Excel, foto, gambar CAD, atau paket .ZIP', textAlign: TextAlign.center, style: YmTextStyles.bodySm.copyWith(color: YmColors.outline)),
              ),
              const SizedBox(height: 16),
              Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 4, children: [
                ElevatedButton(style: _smallStyle(primary: true).copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 36))), onPressed: () => Nav.go('upload'), child: const Text('Pilih file')),
                ElevatedButton(
                  style: _smallStyle(primary: false).copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 36)), elevation: const WidgetStatePropertyAll(1)),
                  onPressed: () => Nav.go('mydocs'),
                  child: const Text('Dokumen saya'),
                ),
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: YmColors.surfaceHigh, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bolt_rounded, size: 16, color: YmColors.primary),
                  const SizedBox(width: 4),
                  Text('Nomor & kode dikenali otomatis', style: YmTextStyles.labelSm.copyWith(color: YmColors.primary, fontWeight: FontWeight.w500)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

// ============================================================ E. aktivitas

class _ActivityPanel extends StatelessWidget {
  final List<DocRecord> docs;
  const _ActivityPanel({required this.docs});

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance.session!;
    final recent = docs.take(5).toList();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.history_rounded, size: 20, color: YmColors.primary),
            const SizedBox(width: 4),
            Expanded(child: Text('Aktivitas terbaru', style: YmTextStyles.headlineSm.copyWith(color: YmColors.textDark))),
            PulseDot(color: YmColors.success, size: 6),
            const SizedBox(width: 4),
            Text('Langsung', style: YmTextStyles.labelSm.copyWith(color: YmColors.success)),
          ]),
          const SizedBox(height: 16),
          if (recent.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('Belum ada aktivitas.', style: YmTextStyles.bodySm)),
          for (var i = 0; i < recent.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _ActivityItem(d: recent[i]),
          ],
          const SizedBox(height: _lg),
          TextButton(
            style: _secondaryStyle().copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 40)), textStyle: WidgetStatePropertyAll(YmTextStyles.labelMd.copyWith(fontWeight: FontWeight.w600))),
            onPressed: () => Nav.go(s.isAdmin ? 'audit' : 'docs'),
            child: Text(s.isAdmin ? 'Lihat log aktivitas & akses lengkap' : 'Lihat semua dokumen'),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final DocRecord d;
  const _ActivityItem({required this.d});

  @override
  Widget build(BuildContext context) {
    final cat = categoryOf(d.category);
    final local = d.isUnsynced;
    final tileBg = local ? YmColors.warningSoft : YmColors.surfaceContainerHigh;
    final tileFg = local ? YmColors.onWarningSoft : (cat.code == 'SHIPMENT' ? YmColors.success : YmColors.primary);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showDocQuickView(context, d),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(color: tileBg, borderRadius: BorderRadius.circular(8)),
          child: Icon(local ? Icons.laptop_outlined : cat.icon, size: 18, color: tileFg),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelMd.copyWith(color: YmColors.textDark, fontWeight: FontWeight.w600)),
            Text(local ? 'Diinput ${d.createdByName} • tersimpan di PC, menunggu dikirim' : 'Diunggah ${d.createdByName}${d.docNumber.isEmpty ? '' : ' • ${d.docNumber}'}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.bodySm),
            const SizedBox(height: 4),
            Row(children: [
              Text(timeAgo(d.createdAt), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontWeight: FontWeight.w500)),
              Text('  •  ', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
              Flexible(
                child: Text(local ? 'Database lokal' : cat.shortLabel,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelSm.copyWith(color: local ? YmColors.warning : tileFg, fontWeight: FontWeight.w500)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ============================================================ footer

class _FooterCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.storage_rounded, size: 20, color: YmColors.success),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Database lokal • ${CountUp.dots(app.allDocs.length)} catatan',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelSm.copyWith(color: YmColors.textMuted, fontWeight: FontWeight.w500)),
        ),
        Text(app.lastPullAt == null ? 'Belum sinkron' : 'Sinkron ${timeAgo(app.lastPullAt)}', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
