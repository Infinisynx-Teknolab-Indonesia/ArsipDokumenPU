import 'dart:io';
import 'package:file_picker/file_picker.dart';
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
import 'doc_form.dart';
import '../viewer/document_viewer.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _PickedFile {
  final String path;
  final String name;
  final int size;
  _PickedFile(this.path, this.name, this.size);
  String get ext => name.contains('.') ? name.split('.').last.toLowerCase() : '';
  String get nameNoExt => name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
}

class _UploadPageState extends State<UploadPage> {
  final _meta = DocMeta();
  final List<_PickedFile> _files = [];
  final List<DocRecord> _justSaved = [];
  bool _saving = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    Nav.uploadProject.addListener(_applyPreset);
    _applyPreset();
  }

  void _applyPreset() {
    final id = Nav.uploadProject.value;
    if (id == null) return;
    setState(() => _meta.projectId = id);
    Nav.uploadProject.value = null;
  }

  @override
  void dispose() {
    Nav.uploadProject.removeListener(_applyPreset);
    _meta.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Pilih dokumen (PDF, Word, Excel, TXT, foto, gambar CAD)',
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (result == null) return;
    final added = <String>[];
    final rejected = <String>[];
    for (final f in result.files) {
      final path = f.path;
      if (path == null) continue;
      if (_files.any((e) => e.path == path)) continue;
      final size = await File(path).length();
      if (size > maxUploadBytes) {
        rejected.add('${f.name} (${formatBytes(size)})');
        continue;
      }
      _files.add(_PickedFile(path, f.name, size));
      added.add(f.name);
    }
    // judul otomatis dari nama file kalau masih kosong & hanya 1 file
    if (_meta.title.text.trim().isEmpty && _files.length == 1) {
      _meta.title.text = _files.first.nameNoExt.replaceAll(RegExp(r'[_]+'), ' ');
    }
    setState(() {});
    if (rejected.isNotEmpty && mounted) {
      showSnack(context, 'Terlalu besar (maks ${formatBytes(maxUploadBytes)}): ${rejected.join(', ')}', error: true);
    }
  }

  String _titleFor(_PickedFile f) {
    final baseTitle = _meta.title.text.trim();
    return _files.length == 1 ? baseTitle : (baseTitle.isEmpty ? f.nameNoExt : '$baseTitle - ${f.nameNoExt}');
  }

  bool _validate() {
    if (_files.isEmpty) {
      showSnack(context, 'Pilih minimal satu file.', error: true);
      return false;
    }
    if (_files.length == 1 && _meta.title.text.trim().isEmpty) {
      showSnack(context, 'Judul dokumen wajib diisi.', error: true);
      return false;
    }
    return true;
  }

  Future<void> _preview(_PickedFile f) => openDocumentViewer(
        context,
        path: f.path,
        title: _titleFor(f).isEmpty ? f.name : _titleFor(f),
        fileName: f.name,
        subtitle: 'Pratinjau — belum disimpan',
      );

  /// Periksa ulang data + isi file sebelum disimpan / dikirim.
  Future<void> _review() async {
    if (!_validate()) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => _ReviewDialog(
        meta: _meta,
        files: [for (final f in _files) (f, _titleFor(f))],
        onPreview: _preview,
      ),
    );
    if (choice == 'send') await _save(draft: false);
    if (choice == 'draft') await _save(draft: true);
  }

  Future<void> _save({bool draft = false}) async {
    if (!_validate()) return;
    final baseTitle = _meta.title.text.trim();
    final app = AppState.instance;
    final project = app.projectById(_meta.projectId);
    setState(() {
      _saving = true;
      _progress = 0;
    });
    final saved = <DocRecord>[];
    final errors = <String>[];
    for (final f in List<_PickedFile>.from(_files)) {
      final title = _files.length == 1
          ? baseTitle
          : (baseTitle.isEmpty ? f.nameNoExt : '$baseTitle - ${f.nameNoExt}');
      try {
        saved.add(await app.saveDocument(
          sourcePath: f.path,
          title: title,
          category: _meta.category,
          project: project,
          docNumber: _meta.number.text,
          docDate: _meta.docDate,
          description: _meta.description.text,
          tags: _meta.tags.text,
          series: _meta.series.text,
          draft: draft,
        ));
        _files.remove(f);
      } catch (e) {
        errors.add('${f.name}: $e');
      }
      if (mounted) setState(() => _progress++);
    }
    if (!draft) app.kickUpload();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _justSaved.insertAll(0, saved);
      if (errors.isEmpty) {
        // proyek, kategori & tanggal dibiarkan — memudahkan input berikutnya
        _meta.title.clear();
        _meta.number.clear();
        _meta.description.clear();
      }
    });
    if (errors.isNotEmpty) {
      showSnack(context, 'Sebagian gagal disimpan:\n${errors.join('\n')}', error: true);
    } else if (draft) {
      showSnack(context, '${saved.length} dokumen disimpan sebagai DRAF di PC ini. Periksa lalu kirim dari menu Dokumen Saya.');
    } else {
      showSnack(
        context,
        app.canUseServer
            ? '${saved.length} dokumen disimpan dan sedang diunggah ke server.'
            : '${saved.length} dokumen disimpan di PC ini. Akan diunggah otomatis saat terhubung ke server.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final totalSize = _files.fold<int>(0, (a, f) => a + f.size);
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!app.canUseServer)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: YmColors.statusAway.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: YmColors.statusAway.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: YmColors.statusAway),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      app.setupMode
                          ? 'Aplikasi belum terhubung ke server. Dokumen disimpan di PC ini dan diunggah otomatis setelah admin menghubungkan server.'
                          : 'Sedang offline. Dokumen tetap bisa disimpan — tersimpan aman di PC ini dan diunggah otomatis saat internet kembali.',
                      style: YmTextStyles.chatText.copyWith(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Panel(
                  title: 'Informasi Dokumen',
                  icon: Icons.edit_note_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DocMetaFields(meta: _meta, onChanged: () => setState(() {})),
                      if (_files.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'Unggah ${_files.length} file sekaligus: semua memakai info di atas. Judul tiap dokumen = '
                            '${_meta.title.text.trim().isEmpty ? 'nama file' : '"${_meta.title.text.trim()} - nama file"'}.',
                            style: YmTextStyles.label.copyWith(fontSize: 11.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Panel(
                  title: 'File Dokumen',
                  icon: Icons.attach_file_rounded,
                  trailing: _files.isEmpty ? null : Text('${_files.length} file • ${formatBytes(totalSize)}', style: YmTextStyles.label),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DropZone(onTap: _saving ? null : _pick),
                      const SizedBox(height: 12),
                      for (final f in _files)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: YmColors.panelBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: YmColors.borderLavender),
                          ),
                          child: Row(
                            children: [
                              FileTypeIcon(ext: f.ext, size: 32),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.username),
                                    Text('${fileKind(f.ext)} • ${formatBytes(f.size)}', style: YmTextStyles.label.copyWith(fontSize: 11)),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _preview(f),
                                icon: const Icon(Icons.visibility_rounded, size: 17),
                                label: Text(canViewInApp(f.ext) ? 'Lihat isi' : 'Detail'),
                              ),
                              IconButton(
                                tooltip: 'Hapus dari daftar',
                                onPressed: _saving ? null : () => setState(() => _files.remove(f)),
                                icon: Icon(Icons.close_rounded, size: 18, color: YmColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 6),
                      if (_saving) ...[
                        LinearProgressIndicator(value: _files.isEmpty ? null : _progress / (_progress + _files.length)),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: primaryButtonStyle(),
                          onPressed: _saving || _files.isEmpty ? null : _review,
                          icon: const Icon(Icons.fact_check_rounded, size: 19),
                          label: Text(_saving ? 'Menyimpan...' : 'Periksa & Simpan${_files.length > 1 ? ' (${_files.length} file)' : ''}'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          style: outlineButtonStyle(),
                          onPressed: _saving || _files.isEmpty ? null : () => _save(draft: true),
                          icon: const Icon(Icons.edit_note_rounded, size: 19),
                          label: const Text('Simpan sebagai draf (kirim nanti)'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Format: PDF, Word, Excel/CSV, TXT, foto (JPG/PNG), gambar CAD (DWG), ZIP/RAR. Maks ${formatBytes(maxUploadBytes)} per file.',
                        style: YmTextStyles.label.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_justSaved.isNotEmpty) ...[
            const SizedBox(height: 18),
            ListenableBuilder(
              listenable: app,
              builder: (context, _) => Panel(
                title: 'Baru disimpan (sesi ini)',
                icon: Icons.history_rounded,
                padding: const EdgeInsets.symmetric(vertical: 6),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(onPressed: () => Nav.showMyDocs(), child: const Text('Semua dokumen saya')),
                    TextButton(onPressed: () => setState(_justSaved.clear), child: const Text('Bersihkan')),
                  ],
                ),
                child: Column(
                  children: [
                    for (final d in _justSaved.take(15))
                      ListTile(
                        dense: true,
                        onTap: () => showDocDetail(context, d),
                        leading: FileTypeIcon(ext: d.extension),
                        title: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.username),
                        subtitle: Text('${categoryOf(d.category).label} • ${d.fileName} • ${formatBytes(d.fileSize)}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.label.copyWith(fontSize: 11)),
                        trailing: DocStatusChip(status: d.status),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  final VoidCallback? onTap;
  const _DropZone({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: YmColors.accentPurple.withOpacity(0.04),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: YmColors.accentPurple.withOpacity(0.35), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_outlined, size: 44, color: YmColors.accentPurple.withOpacity(0.8)),
              const SizedBox(height: 8),
              Text('Klik untuk memilih file', style: TextStyle(fontWeight: FontWeight.w700, color: YmColors.textDark)),
              const SizedBox(height: 3),
              Text('Bisa pilih banyak file sekaligus', style: YmTextStyles.label.copyWith(fontSize: 11.5)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Layar "Periksa sebelum simpan": ringkasan data + pratinjau isi tiap file.
class _ReviewDialog extends StatelessWidget {
  final DocMeta meta;
  final List<(_PickedFile, String)> files;
  final Future<void> Function(_PickedFile) onPreview;
  const _ReviewDialog({required this.meta, required this.files, required this.onPreview});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final project = app.projectById(meta.projectId);
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 130, child: Text(k, style: YmTextStyles.label.copyWith(fontSize: 12))),
            Expanded(child: Text(v.trim().isEmpty ? '-' : v, style: YmTextStyles.chatText.copyWith(fontSize: 13))),
          ]),
        );
    final online = app.canUseServer;
    return AlertDialog(
      title: Row(children: [
        Icon(Icons.fact_check_rounded, color: YmColors.accentPurple),
        const SizedBox(width: 10),
        Text('Periksa sebelum disimpan', style: YmTextStyles.username.copyWith(fontSize: 16)),
      ]),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            if (files.length == 1) row('Judul', files.first.$2),
            row('Nomor dokumen', meta.number.text),
            row('Tanggal dokumen', formatIsoDate(meta.docDate)),
            row('Kategori', categoryOf(meta.category).label),
            row('Proyek / paket', project == null ? '-' : project.label),
            row('Seri / kelompok', meta.series.text),
            row('Tag', meta.tags.text),
            row('Keterangan', meta.description.text),
            const Divider(height: 20),
            Text('FILE (${files.length}) — klik "Lihat isi" untuk memastikan file yang benar',
                style: YmTextStyles.label.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2)),
            const SizedBox(height: 8),
            for (final (f, title) in files)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: YmColors.panelBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: YmColors.borderLavender),
                ),
                child: Row(children: [
                  FileTypeIcon(ext: f.ext, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title.isEmpty ? f.name : title, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.username),
                      Text('${f.name} • ${formatBytes(f.size)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.label.copyWith(fontSize: 11)),
                    ]),
                  ),
                  TextButton.icon(
                    onPressed: () => onPreview(f),
                    icon: const Icon(Icons.visibility_rounded, size: 17),
                    label: const Text('Lihat isi'),
                  ),
                ]),
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (online ? YmColors.statusOnline : YmColors.statusAway).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                online
                    ? 'Server terhubung. "Kirim sekarang" langsung mengunggah ke server. "Simpan draf" menyimpan di PC dulu untuk dicek lagi.'
                    : 'Server belum terhubung / mati. Dokumen tetap disimpan di PC ini dan TERKIRIM OTOMATIS begitu server online lagi.',
                style: YmTextStyles.chatText.copyWith(fontSize: 12),
              ),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kembali, perbaiki')),
        OutlinedButton.icon(
          style: outlineButtonStyle(),
          onPressed: () => Navigator.pop(context, 'draft'),
          icon: const Icon(Icons.edit_note_rounded, size: 18),
          label: const Text('Simpan draf'),
        ),
        ElevatedButton.icon(
          style: primaryButtonStyle(),
          onPressed: () => Navigator.pop(context, 'send'),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: Text(online ? 'Sudah benar — kirim sekarang' : 'Simpan & kirim otomatis saat online'),
        ),
      ],
    );
  }
}
