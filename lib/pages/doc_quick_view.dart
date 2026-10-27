import 'package:flutter/material.dart';
import '../core/categories.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/smart_search.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';
import 'doc_detail.dart';

/// Panel samping (geser dari kanan) saat dokumen diklik:
/// ringkasan detail + DOKUMEN TERKAIT / RELASINYA (seri, nomor/kode sama, proyek sama, …).
/// Klik dokumen terkait = pindah ke dokumen itu di panel yang sama (ada tombol kembali).
Future<void> showDocQuickView(BuildContext context, DocRecord doc) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: Colors.black.withOpacity(0.25),
    transitionDuration: motion(context, const Duration(milliseconds: 260)),
    pageBuilder: (ctx, _, __) => Align(
      alignment: Alignment.centerRight,
      child: _QuickView(first: doc),
    ),
    transitionBuilder: (ctx, a, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

class _QuickView extends StatefulWidget {
  final DocRecord first;
  const _QuickView({required this.first});

  @override
  State<_QuickView> createState() => _QuickViewState();
}

class _QuickViewState extends State<_QuickView> {
  late final List<DocRecord> _stack = [widget.first];
  DocRecord get d => _stack.last;

  void _go(DocRecord o) => setState(() => _stack.add(o));
  void _back() => setState(() => _stack.removeLast());

  Future<void> _openFull({bool file = false, bool related = false}) async {
    // Halaman detail dibuka di atas panel ini; tombol kembali = balik ke panel.
    await showDocDetail(context, d, startOnFile: file, initialTab: related ? 2 : 0);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final w = (MediaQuery.of(context).size.width * 0.42).clamp(420.0, 560.0).toDouble();
    final searcher = app.searcher;
    final related = searcher.related(d, app.visibleDocs);
    final series = searcher.seriesOf(d, app.visibleDocs);
    final seriesIds = series.map((e) => e.clientId).toSet();
    final others = related.where((r) => !seriesIds.contains(r.doc.clientId)).toList();
    final cat = categoryOf(d.category);

    return Material(
      color: YmColors.surface,
      elevation: 16,
      child: SizedBox(
        width: w,
        height: double.infinity,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ---- kepala
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: YmColors.line))),
            child: Row(children: [
              if (_stack.length > 1)
                IconButton(tooltip: 'Kembali ke ${_stack[_stack.length - 2].title}', onPressed: _back, icon: const Icon(Icons.arrow_back_rounded, size: 20))
              else
                const SizedBox(width: 8),
              Expanded(
                child: Text(_stack.length > 1 ? 'Dokumen terkait (${_stack.length - 1} langkah)' : 'Detail & relasi dokumen',
                    style: YmTextStyles.labelLg.copyWith(color: YmColors.textMuted)),
              ),
              IconButton(tooltip: 'Tutup (Esc)', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, size: 20)),
            ]),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: motion(context, const Duration(milliseconds: 200)),
              child: ListView(
                key: ValueKey(d.clientId),
                padding: const EdgeInsets.all(24),
                children: [
                  // ---- ringkasan
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FileTypeIcon(ext: d.extension, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.title, style: YmTextStyles.headlineMd.copyWith(color: YmColors.textDark)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          CategoryBadge(code: cat.code, compact: true),
                          DocStatusChip(status: d.status),
                        ]),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      _row('Nomor', d.docNumber),
                      _row('Tanggal', formatIsoDate(d.docDate)),
                      _row('Proyek / paket', d.projectCode.isEmpty ? '' : '${d.projectCode} — ${d.projectName}'),
                      _row('Seri', d.series),
                      _row('Tag', d.tags),
                      _row('File', '${d.fileName} (${formatBytes(d.fileSize)})'),
                      _row('Diinput', '${d.createdByName} • ${timeAgo(d.createdAt)}', last: true),
                    ]),
                  ),
                  if (d.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(d.description, maxLines: 4, overflow: TextOverflow.ellipsis, style: YmTextStyles.bodySm),
                  ],
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: primaryButtonStyle(),
                        onPressed: () => _openFull(file: true),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Lihat file'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: outlineButtonStyle(),
                        onPressed: () => _openFull(),
                        icon: const Icon(Icons.open_in_full_rounded, size: 18),
                        label: const Text('Detail lengkap'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 28),

                  // ---- seri
                  if (series.length > 1) ...[
                    _head(Icons.timeline_rounded, 'Satu seri', '${series.length} versi', 'Versi lain dari dokumen yang sama, urut tahun.'),
                    const SizedBox(height: 10),
                    for (var i = 0; i < series.length; i++)
                      _SeriesRow(doc: series[i], current: series[i].clientId == d.clientId, last: i == series.length - 1, onTap: series[i].clientId == d.clientId ? null : () => _go(series[i])),
                    const SizedBox(height: 24),
                  ],

                  // ---- terkait
                  _head(Icons.hub_outlined, 'Dokumen terkait', '${others.length}', 'Nomor/kode sama di data atau isi file, proyek sama, tag, dan judul mirip.'),
                  const SizedBox(height: 10),
                  if (others.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Icon(Icons.link_off_rounded, size: 18, color: YmColors.outline),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Dokumen ini berdiri sendiri — belum ada dokumen lain yang berhubungan.', style: YmTextStyles.bodySm)),
                      ]),
                    )
                  else
                    for (final r in others.take(30)) Padding(padding: const EdgeInsets.only(bottom: 8), child: _RelatedRow(r: r, onTap: () => _go(r.doc))),
                  if (others.length > 30)
                    TextButton(onPressed: () => _openFull(related: true), child: Text('Lihat semua ${others.length} dokumen terkait')),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _row(String label, String value, {bool last = false}) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(label, style: YmTextStyles.labelMd.copyWith(color: YmColors.textMuted))),
          Expanded(child: SelectableText(value.isEmpty ? '—' : value, style: YmTextStyles.labelMd.copyWith(color: YmColors.textDark, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _head(IconData icon, String title, String count, String note) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 20, color: YmColors.primary),
          const SizedBox(width: 8),
          Text(title, style: YmTextStyles.headlineSm.copyWith(color: YmColors.textDark)),
          const SizedBox(width: 8),
          SoftChip.primary(count),
        ]),
        const SizedBox(height: 2),
        Text(note, style: YmTextStyles.bodySm),
      ]);
}

class _SeriesRow extends StatelessWidget {
  final DocRecord doc;
  final bool current;
  final bool last;
  final VoidCallback? onTap;
  const _SeriesRow({required this.doc, required this.current, required this.last, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 24,
              child: Column(children: [
                const SizedBox(height: 6),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: current ? YmColors.primary : YmColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: YmColors.primary, width: 2),
                  ),
                ),
                if (!last) Expanded(child: Container(width: 2, color: YmColors.primary.withOpacity(0.25))),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('${doc.year}', style: YmTextStyles.labelSm.copyWith(color: YmColors.primary)),
                    if (current) ...[const SizedBox(width: 6), SoftChip.primary('sedang dibuka')],
                  ]),
                  Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelLg.copyWith(color: YmColors.textDark, fontWeight: FontWeight.w600)),
                  if (doc.docNumber.isNotEmpty) Text(doc.docNumber, style: YmTextStyles.bodySm),
                ]),
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: YmColors.outline),
          ]),
        ),
      );
}

class _RelatedRow extends StatelessWidget {
  final RelatedDoc r;
  final VoidCallback onTap;
  const _RelatedRow({required this.r, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final o = r.doc;
    return HoverCard(
      onTap: onTap,
      color: YmColors.surfaceAlt,
      hoverColor: YmColors.surfaceContainer,
      baseShadowOverride: const [],
      hoverShadowOverride: const [],
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FileTypeIcon(ext: o.extension, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelLg.copyWith(color: YmColors.textDark, fontWeight: FontWeight.w600)),
            Text(
              [o.docNumber, '${o.year}', categoryOf(o.category).shortLabel].where((e) => e.isNotEmpty).join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: YmTextStyles.bodySm,
            ),
            if (r.reasons.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (final why in r.reasons.take(3)) SoftChip(why, icon: Icons.link_rounded, fg: YmColors.primary, bg: YmColors.surface),
              ]),
            ],
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: YmColors.outline),
      ]),
    );
  }
}
