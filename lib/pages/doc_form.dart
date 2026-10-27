import 'package:flutter/material.dart';
import '../core/categories.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';

/// Nilai isian metadata dokumen (dipakai di Unggah & Edit).
class DocMeta {
  final title = TextEditingController();
  final number = TextEditingController();
  final description = TextEditingController();
  final tags = TextEditingController();
  final series = TextEditingController();
  String category = 'LAINNYA';
  String projectId = '';
  String docDate = isoDate(DateTime.now());

  void dispose() {
    title.dispose();
    number.dispose();
    description.dispose();
    tags.dispose();
    series.dispose();
  }

  void fillFrom(DocRecord d) {
    title.text = d.title;
    number.text = d.docNumber;
    description.text = d.description;
    tags.text = d.tags;
    series.text = d.series;
    category = d.category;
    projectId = d.projectId;
    docDate = d.docDate.isEmpty ? isoDate(d.createdAt) : d.docDate;
  }
}

/// Kolom isian metadata dokumen.
class DocMetaFields extends StatefulWidget {
  final DocMeta meta;

  /// false = judul tidak ditampilkan (unggah banyak file: judul = nama file).
  final bool showTitle;
  final VoidCallback? onChanged;

  const DocMetaFields({super.key, required this.meta, this.showTitle = true, this.onChanged});

  @override
  State<DocMetaFields> createState() => _DocMetaFieldsState();
}

class _DocMetaFieldsState extends State<DocMetaFields> {
  DocMeta get m => widget.meta;

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(m.docDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(DateTime.now().year + 5),
      helpText: 'Tanggal dokumen',
    );
    if (picked != null) {
      setState(() => m.docDate = isoDate(picked));
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = AppState.instance.projects;
    final validProject = m.projectId.isEmpty || projects.any((p) => p.id == m.projectId);
    if (!validProject) m.projectId = '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('proj-${m.projectId}-${projects.length}'),
          initialValue: m.projectId,
          isExpanded: true,
          decoration: fieldDecoration('Proyek / Paket Pekerjaan', icon: Icons.engineering_rounded),
          items: [
            const DropdownMenuItem(value: '', child: Text('— Tanpa proyek / umum —')),
            for (final p in projects)
              DropdownMenuItem(value: p.id, child: Text('${p.code} — ${p.name} (${p.year})', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            setState(() => m.projectId = v ?? '');
            widget.onChanged?.call();
          },
        ),
        if (projects.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              AppState.instance.setupMode
                  ? 'Daftar proyek muncul setelah aplikasi terhubung ke server.'
                  : 'Belum ada proyek. Admin bisa menambahkannya di menu Proyek / Paket.',
              style: YmTextStyles.label.copyWith(fontSize: 11),
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                key: ValueKey('cat-${m.category}'),
                initialValue: m.category,
                isExpanded: true,
                decoration: fieldDecoration('Kategori Dokumen', icon: Icons.category_rounded),
                items: [
                  for (final c in docCategories)
                    DropdownMenuItem(
                      value: c.code,
                      child: Row(children: [
                        Icon(c.icon, size: 16, color: c.color),
                        const SizedBox(width: 8),
                        Flexible(child: Text(c.label, overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                ],
                onChanged: (v) {
                  setState(() => m.category = v ?? 'LAINNYA');
                  widget.onChanged?.call();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: fieldDecoration('Tanggal Dokumen', icon: Icons.event_rounded),
                  child: Text(formatIsoDate(m.docDate), style: const TextStyle(fontSize: 13.5)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (widget.showTitle) ...[
          TextField(
            controller: m.title,
            decoration: fieldDecoration('Judul / Nama Dokumen *', icon: Icons.title_rounded, hint: 'mis. Laporan Mingguan ke-12 Peningkatan Jalan Simpang Kara'),
            onChanged: (_) => widget.onChanged?.call(),
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: m.number,
          decoration: fieldDecoration('Nomor Dokumen / Surat', icon: Icons.tag_rounded, hint: 'mis. 600/123/PUPR/X/2026'),
        ),
        const SizedBox(height: 14),
        _SeriesField(meta: m, onChanged: widget.onChanged),
        const SizedBox(height: 14),
        TextField(
          controller: m.tags,
          decoration: fieldDecoration('Tag (pisahkan dengan koma)', icon: Icons.sell_rounded, hint: 'mis. aspal, STA 0+000 - 1+500, minggu 12'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: m.description,
          minLines: 3,
          maxLines: 5,
          decoration: fieldDecoration('Keterangan', icon: Icons.notes_rounded, hint: 'Ringkasan isi dokumen, lokasi STA, catatan pengawas, dll.'),
        ),
      ],
    );
  }
}

/// Dialog edit metadata dokumen. true = tersimpan.
Future<bool?> showDocEditDialog(BuildContext context, DocRecord d) {
  return showDialog<bool>(context: context, builder: (_) => _DocEditDialog(doc: d));
}

class _DocEditDialog extends StatefulWidget {
  final DocRecord doc;
  const _DocEditDialog({required this.doc});

  @override
  State<_DocEditDialog> createState() => _DocEditDialogState();
}

class _DocEditDialogState extends State<_DocEditDialog> {
  final _meta = DocMeta();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _meta.fillFrom(widget.doc);
  }

  @override
  void dispose() {
    _meta.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_meta.title.text.trim().isEmpty) {
      showSnack(context, 'Judul dokumen wajib diisi.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await AppState.instance.updateDocMeta(widget.doc, {
        'title': _meta.title.text.trim(),
        'doc_number': _meta.number.text.trim(),
        'doc_date': _meta.docDate,
        'category': _meta.category,
        'project_id': _meta.projectId,
        'description': _meta.description.text.trim(),
        'tags': _meta.tags.text.trim(),
        'series': _meta.series.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, e.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Info Dokumen'),
      content: SizedBox(width: 640, child: SingleChildScrollView(child: DocMetaFields(meta: _meta))),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(style: primaryButtonStyle(), onPressed: _saving ? null : _save, child: Text(_saving ? 'Menyimpan...' : 'Simpan')),
      ],
    );
  }
}


/// Isian "Seri / Kelompok Dokumen" dengan saran dari seri yang sudah ada.
/// Dokumen dengan seri sama dianggap satu rangkaian lintas tahun
/// (mis. "Dokumen 1": Formula A 2000 -> Formula B 2002 -> Formula C 2026).
class _SeriesField extends StatefulWidget {
  final DocMeta meta;
  final VoidCallback? onChanged;
  const _SeriesField({required this.meta, this.onChanged});

  @override
  State<_SeriesField> createState() => _SeriesFieldState();
}

class _SeriesFieldState extends State<_SeriesField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  DocMeta get meta => widget.meta;
  VoidCallback? get onChanged => widget.onChanged;

  @override
  Widget build(BuildContext context) {
    final all = AppState.instance.allSeries;
    return RawAutocomplete<String>(
      textEditingController: meta.series,
      focusNode: _focus,
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty) return all.take(20);
        return all.where((s) => s.toLowerCase().contains(q)).take(20);
      },
      onSelected: (_) => onChanged?.call(),
      fieldViewBuilder: (context, controller, focusNode, onSubmit) => TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: (_) => onChanged?.call(),
        decoration: fieldDecoration(
          'Seri / Kelompok Dokumen (opsional)',
          icon: Icons.account_tree_rounded,
          hint: 'mis. Dokumen 1 — isi sama untuk Formula A, B, C dari tahun berbeda',
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 520),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final o in options)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.account_tree_rounded, size: 18, color: YmColors.accentPurple),
                    title: Text(o),
                    onTap: () => onSelected(o),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
