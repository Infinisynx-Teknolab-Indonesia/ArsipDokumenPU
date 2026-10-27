import 'package:flutter/material.dart';
import '../services/find_shortcut.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../services/nav.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';

/// Kamus Pencarian: hubungkan istilah dengan kata/kode lain, mis.
/// "pengeluaran" <-> "belanja, biaya, 544". Mencari salah satunya akan
/// menemukan dokumen yang memuat yang lain (termasuk di isi PDF/Word/Excel).
class TermsPage extends StatefulWidget {
  const TermsPage({super.key});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> with PageSearchField<TermsPage> {
  final _test = TextEditingController();

  @override
  String get searchPageId => 'terms';
  @override
  TextEditingController get searchController => _test;

  @override
  void dispose() {
    _test.dispose();
    super.dispose();
  }

  Future<void> _edit([SearchTerm? t]) async {
    final term = TextEditingController(text: t?.term ?? '');
    final related = TextEditingController(text: t?.related ?? '');
    final note = TextEditingController(text: t?.note ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t == null ? 'Tambah Istilah' : 'Ubah Istilah'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: term, decoration: fieldDecoration('Istilah *', hint: 'mis. pengeluaran')),
              const SizedBox(height: 12),
              TextField(
                controller: related,
                minLines: 2,
                maxLines: 4,
                decoration: fieldDecoration('Kata / kode terkait (pisahkan koma) *', hint: 'mis. belanja, biaya, 544, 5.4.4'),
              ),
              const SizedBox(height: 12),
              TextField(controller: note, decoration: fieldDecoration('Catatan (opsional)', hint: 'mis. kode rekening sesuai BAS instansi')),
              const SizedBox(height: 8),
              Text('Berlaku dua arah: mencari "544" juga menemukan dokumen berisi "pengeluaran", dan sebaliknya.',
                  style: YmTextStyles.label.copyWith(fontSize: 11.5)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          ElevatedButton(style: primaryButtonStyle(), onPressed: () => Navigator.pop(c, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    if (term.text.trim().isEmpty || related.text.trim().isEmpty) {
      if (mounted) showSnack(context, 'Istilah dan kata terkait wajib diisi.', error: true);
      return;
    }
    try {
      await AppState.instance.saveTerm(SearchTerm(id: t?.id ?? '', term: term.text.trim(), related: related.text.trim(), note: note.text.trim()));
      if (mounted) showSnack(context, 'Kamus disimpan. Berlaku di semua PC setelah sinkron.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _delete(SearchTerm t) async {
    if (!await confirmDialog(context, title: 'Hapus istilah?', message: '"${t.term}" dihapus dari kamus.', ok: 'Hapus', danger: true)) return;
    try {
      await AppState.instance.deleteTerm(t);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _reindex() async {
    if (!await confirmDialog(context,
        title: 'Baca ulang isi semua file?',
        message: 'Server akan membaca ulang teks seluruh PDF/Word/Excel/TXT (berjalan di latar belakang). '
            'Gunakan setelah memasang OCR atau bila hasil pencarian isi file kurang lengkap.',
        ok: 'Mulai')) {
      return;
    }
    try {
      final n = await AppState.instance.withToken((a, t) => a.reindexAll(t));
      if (mounted) showSnack(context, '$n dokumen dijadwalkan dibaca ulang.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final isAdmin = app.session!.isAdmin;
        final canEdit = isAdmin && app.canUseServer;
        final extra = _test.text.trim().isEmpty ? <String>[] : app.searcher.extraTerms(_test.text.trim());
        final terms = List<SearchTerm>.from(app.terms)..sort((a, b) => a.term.compareTo(b.term));
        final indexed = app.allDocs.where((d) => app.tokens[d.clientId]?.isNotEmpty == true).length;
        return PageBody(
          scroll: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pencarian pintar membaca isi file PDF, Word (.docx), Excel (.xlsx), dan TXT di server. Kamus ini menghubungkan istilah '
                      'dengan kata/kode lain. $indexed dari ${app.allDocs.length} dokumen sudah terbaca isinya di PC ini.',
                      style: YmTextStyles.label.copyWith(fontSize: 12.5),
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: outlineButtonStyle(),
                      onPressed: canEdit ? _reindex : null,
                      icon: const Icon(Icons.manage_search_rounded, size: 18),
                      label: const Text('Baca ulang isi file'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: primaryButtonStyle(),
                      onPressed: canEdit ? () => _edit() : null,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Tambah Istilah'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 360,
                    child: TextField(
                      controller: _test,
                      focusNode: searchFocus,
                      onChanged: (_) => setState(() {}),
                      decoration: fieldDecoration('Coba kata kunci', icon: Icons.science_rounded, hint: 'mis. pengeluaran').copyWith(fillColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _test.text.trim().isEmpty ? '' : (extra.isEmpty ? 'Tidak ada perluasan dari kamus.' : 'Juga mencari: ${extra.join(', ')}'),
                      style: const TextStyle(fontSize: 12.5, color: YmColors.accentPurple, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_test.text.trim().isNotEmpty)
                    TextButton.icon(
                      onPressed: () => Nav.searchDocs(_test.text.trim()),
                      icon: const Icon(Icons.search_rounded, size: 17),
                      label: const Text('Buka Arsip'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Panel(
                  expand: true,
                  padding: EdgeInsets.zero,
                  title: 'Kamus Pencarian (${terms.length} istilah)',
                  icon: Icons.menu_book_rounded,
                  child: terms.isEmpty
                      ? const EmptyState(icon: Icons.menu_book_rounded, title: 'Kamus kosong', message: 'Tambahkan istilah dan kata/kode terkaitnya.')
                      : ListView.separated(
                          itemCount: terms.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: YmColors.borderLavender),
                          itemBuilder: (context, i) {
                            final t = terms[i];
                            return ListTile(
                              title: Text(t.term, style: YmTextStyles.username.copyWith(fontSize: 13)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      for (final r in t.related.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty))
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: YmColors.accentPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                          child: Text(r, style: const TextStyle(fontSize: 11.5, color: YmColors.accentPurple)),
                                        ),
                                    ],
                                  ),
                                  if (t.note.isNotEmpty)
                                    Padding(padding: const EdgeInsets.only(top: 4), child: Text(t.note, style: YmTextStyles.label.copyWith(fontSize: 11))),
                                ],
                              ),
                              trailing: isAdmin
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(onPressed: canEdit ? () => _edit(t) : null, icon: const Icon(Icons.edit_rounded, size: 18)),
                                        IconButton(
                                          onPressed: canEdit ? () => _delete(t) : null,
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: YmColors.buzzRed),
                                        ),
                                      ],
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
