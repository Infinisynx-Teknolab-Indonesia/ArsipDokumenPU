import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../theme/ym_theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';
import 'doc_form.dart';

/// Staf mengajukan perubahan dokumen yang sudah diarsipkan: ubah data
/// dan/atau ganti file. Perubahan baru berlaku setelah disetujui admin.
Future<bool?> showEditRequestDialog(BuildContext context, DocRecord doc) {
  return showDialog<bool>(context: context, builder: (_) => _EditRequestDialog(doc: doc));
}

class _EditRequestDialog extends StatefulWidget {
  final DocRecord doc;
  const _EditRequestDialog({required this.doc});

  @override
  State<_EditRequestDialog> createState() => _EditRequestDialogState();
}

class _EditRequestDialogState extends State<_EditRequestDialog> {
  final _meta = DocMeta();
  final _reason = TextEditingController();
  String? _filePath;
  int _fileSize = 0;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _meta.fillFrom(widget.doc);
  }

  @override
  void dispose() {
    _meta.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(
      dialogTitle: 'Pilih file pengganti',
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    final path = r?.files.single.path;
    if (path == null) return;
    final size = await File(path).length();
    if (size > maxUploadBytes) {
      if (mounted) showSnack(context, 'File terlalu besar (maks ${formatBytes(maxUploadBytes)}).', error: true);
      return;
    }
    setState(() {
      _filePath = path;
      _fileSize = size;
    });
  }

  Map<String, String> _changes() {
    final d = widget.doc;
    final m = <String, String>{};
    void put(String k, String now, String before) {
      if (now != before) m[k] = now;
    }

    put('title', _meta.title.text.trim(), d.title);
    put('doc_number', _meta.number.text.trim(), d.docNumber);
    put('doc_date', _meta.docDate, d.docDate.isEmpty ? isoDate(d.createdAt) : d.docDate);
    put('category', _meta.category, d.category);
    put('project_id', _meta.projectId, d.projectId);
    put('description', _meta.description.text.trim(), d.description);
    put('tags', _meta.tags.text.trim(), d.tags);
    put('series', _meta.series.text.trim(), d.series);
    return m;
  }

  Future<void> _send() async {
    final changes = _changes();
    String? err;
    if (_meta.title.text.trim().isEmpty) {
      err = 'Judul tidak boleh kosong.';
    } else if (changes.isEmpty && _filePath == null) {
      err = 'Belum ada yang diubah. Ubah data di atas atau pilih file pengganti.';
    } else if (_reason.text.trim().length < 5) {
      err = 'Tulis alasan perubahan (minimal 5 karakter) supaya admin bisa menilai.';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await AppState.instance.requestEdit(widget.doc, reason: _reason.text.trim(), changes: changes, filePath: _filePath);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final changes = _changes();
    return AlertDialog(
      title: const Text('Ajukan Perubahan Dokumen'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: YmColors.accentPurple.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: YmColors.accentPurple, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Dokumen sudah diarsipkan, jadi perubahan dikirim ke admin dulu. Data lama tetap berlaku sampai disetujui. '
                        'Kalau file diganti, file lama disimpan sebagai riwayat versi.',
                        style: YmTextStyles.chatText.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DocMetaFields(meta: _meta, onChanged: () => setState(() {})),
              const SizedBox(height: 16),
              Text('File pengganti (opsional)', style: YmTextStyles.username),
              const SizedBox(height: 6),
              Row(
                children: [
                  FileTypeIcon(ext: (_filePath ?? widget.doc.fileName).split('.').last, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _filePath == null ? 'Tetap: ${widget.doc.fileName}' : 'Baru: ${baseName(_filePath!)} (${formatBytes(_fileSize)})',
                      style: YmTextStyles.chatText.copyWith(fontSize: 12.5),
                    ),
                  ),
                  if (_filePath != null)
                    TextButton(onPressed: () => setState(() => _filePath = null), child: const Text('Batal ganti')),
                  OutlinedButton.icon(
                    style: outlineButtonStyle(),
                    onPressed: _sending ? null : _pickFile,
                    icon: const Icon(Icons.attach_file_rounded, size: 17),
                    label: const Text('Pilih file'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reason,
                minLines: 2,
                maxLines: 4,
                decoration: fieldDecoration('Alasan perubahan *', icon: Icons.chat_rounded,
                    hint: 'mis. Salah ketik nomor kontrak; file yang benar adalah versi yang sudah ditandatangani'),
              ),
              const SizedBox(height: 10),
              Text(
                changes.isEmpty && _filePath == null
                    ? 'Belum ada perubahan.'
                    : 'Akan diajukan: ${[...changes.keys.map(_label), if (_filePath != null) 'file'].join(', ')}',
                style: YmTextStyles.label.copyWith(fontSize: 12, color: YmColors.accentPurple),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: YmColors.buzzRed, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _sending ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton.icon(
          style: primaryButtonStyle(),
          onPressed: _sending ? null : _send,
          icon: const Icon(Icons.send_rounded, size: 17),
          label: Text(_sending ? 'Mengirim...' : 'Kirim ke Admin'),
        ),
      ],
    );
  }
}

String _label(String k) => const {
      'title': 'judul',
      'doc_number': 'nomor',
      'doc_date': 'tanggal',
      'category': 'kategori',
      'project_id': 'proyek',
      'description': 'keterangan',
      'tags': 'tag',
      'series': 'seri',
    }[k] ??
    k;

/// Label field untuk halaman Permintaan Edit.
String fieldLabel(String k) => _label(k);
