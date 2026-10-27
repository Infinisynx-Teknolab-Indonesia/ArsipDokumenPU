import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/local_db.dart';
import '../theme/ym_theme.dart';
import '../widgets/common.dart';
import 'print_service.dart';

/// Penghubung tombol Print dengan penampil dokumen yang sedang tampil.
/// Setiap penampil (PDF/Word/Excel/teks/foto) mengisi [buildPdf]: menghasilkan
/// file PDF siap cetak (PDF asli langsung, jenis lain diubah dulu ke PDF).
class PrintController {
  Future<String> Function()? buildPdf;
  bool get ready => buildPdf != null;
}

/// Simpan bytes PDF ke folder sementara aplikasi -> path.
Future<String> writeTempPdf(Uint8List bytes, String baseName) async {
  final safe = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
  final name = safe.toLowerCase().endsWith('.pdf') ? safe : '$safe.pdf';
  final f = File('${LocalDb.tempDir('print').path}${Platform.pathSeparator}$name');
  await f.writeAsBytes(bytes, flush: true);
  return f.path;
}

Future<void> showPrintDialog(BuildContext context, {required PrintController controller, required String title, required String fileName}) {
  if (!controller.ready) {
    showSnack(context, 'Dokumen belum selesai dimuat. Tunggu sebentar lalu coba lagi.', error: true);
    return Future.value();
  }
  return showDialog(context: context, barrierDismissible: false, builder: (_) => _PrintDialog(controller: controller, title: title, fileName: fileName));
}

class _PrintDialog extends StatefulWidget {
  final PrintController controller;
  final String title, fileName;
  const _PrintDialog({required this.controller, required this.title, required this.fileName});

  @override
  State<_PrintDialog> createState() => _PrintDialogState();
}

class _PrintDialogState extends State<_PrintDialog> {
  String? _pdf;
  int _pages = 0;
  String? _error;
  List<String> _printers = const [];
  String? _printer;
  bool _allPages = true;
  final _range = TextEditingController();
  int _copies = 1;
  bool _printing = false;
  int _done = 0, _total = 0;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _range.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final results = await Future.wait([
        widget.controller.buildPdf!(),
        PrintService.printers().then((v) => v as Object),
      ]);
      final pdf = results[0] as String;
      final (printers, def) = results[1] as (List<String>, String?);
      final pages = await PrintService.pageCount(pdf);
      if (!mounted) return;
      setState(() {
        _pdf = pdf;
        _pages = pages;
        _printers = printers;
        _printer = def ?? (printers.isEmpty ? null : printers.first);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _savePdf() async {
    final src = _pdf;
    if (src == null) return;
    final base = widget.fileName.contains('.') ? widget.fileName.substring(0, widget.fileName.lastIndexOf('.')) : widget.fileName;
    final target = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan sebagai PDF',
      fileName: '$base.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (target == null) return;
    final path = target.toLowerCase().endsWith('.pdf') ? target : '$target.pdf';
    await File(src).copy(path);
    if (mounted) showSnack(context, 'PDF tersimpan: $path');
  }

  Future<void> _print() async {
    final pdf = _pdf, printer = _printer;
    if (pdf == null || printer == null) return;
    Set<int>? pages;
    try {
      pages = _allPages ? null : PrintService.parseRanges(_range.text, _pages);
    } on FormatException catch (e) {
      showSnack(context, e.message, error: true);
      return;
    }
    setState(() {
      _printing = true;
      _done = 0;
      _total = (pages?.length ?? _pages) * _copies;
    });
    try {
      await PrintService.printPdf(
        pdfPath: pdf,
        printer: printer,
        jobName: widget.title,
        copies: _copies,
        pages: pages,
        onProgress: (d, t) {
          if (mounted) setState(() => _done = d);
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Dokumen dikirim ke printer $printer.');
    } catch (e) {
      if (mounted) {
        setState(() => _printing = false);
        showSnack(context, 'Gagal mencetak: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _pdf != null;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.print_rounded, color: YmColors.accentPurple),
        const SizedBox(width: 10),
        Expanded(child: Text('Cetak dokumen', style: YmTextStyles.username.copyWith(fontSize: 16))),
      ]),
      content: SizedBox(
        width: 460,
        child: _error != null
            ? Text('Dokumen tidak bisa disiapkan untuk dicetak:\n$_error', style: const TextStyle(color: YmColors.buzzRed))
            : !ready
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Row(children: [
                      SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                      SizedBox(width: 14),
                      Expanded(child: Text('Menyiapkan dokumen untuk dicetak...')),
                    ]),
                  )
                : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: YmTextStyles.username),
                    Text('$_pages halaman • ${widget.fileName}', style: YmTextStyles.label.copyWith(fontSize: 12)),
                    const SizedBox(height: 16),
                    if (_printers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: YmColors.statusAway.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          Platform.isMacOS
                              ? 'Belum ada printer. Tambahkan di System Settings → Printers & Scanners. Dokumen tetap bisa disimpan sebagai PDF.'
                              : 'Belum ada printer terpasang di Windows. Tambahkan di Settings → Bluetooth & devices → Printers & scanners. Dokumen tetap bisa disimpan sebagai PDF.',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        key: ValueKey(_printer),
                        initialValue: _printer,
                        isExpanded: true,
                        decoration: fieldDecoration('Printer', icon: Icons.print_rounded),
                        items: [for (final p in _printers) DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))],
                        onChanged: _printing ? null : (v) => setState(() => _printer = v),
                      ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Text('Jumlah salinan', style: YmTextStyles.chatText.copyWith(fontSize: 13)),
                      const Spacer(),
                      IconButton(
                        onPressed: _printing || _copies <= 1 ? null : () => setState(() => _copies--),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                      SizedBox(width: 30, child: Text('$_copies', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
                      IconButton(
                        onPressed: _printing || _copies >= 99 ? null : () => setState(() => _copies++),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ]),
                    RadioListTile<bool>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: true,
                      groupValue: _allPages,
                      onChanged: _printing ? null : (v) => setState(() => _allPages = true),
                      title: Text('Semua halaman ($_pages)'),
                    ),
                    RadioListTile<bool>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: false,
                      groupValue: _allPages,
                      onChanged: _printing ? null : (v) => setState(() => _allPages = false),
                      title: TextField(
                        controller: _range,
                        enabled: !_printing,
                        onTap: () => setState(() => _allPages = false),
                        decoration: const InputDecoration(isDense: true, hintText: 'Halaman tertentu, mis. 1-3, 5'),
                      ),
                    ),
                    if (_printing) ...[
                      const SizedBox(height: 10),
                      LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
                      const SizedBox(height: 6),
                      Text('Mengirim ke printer... $_done / $_total halaman', style: YmTextStyles.label.copyWith(fontSize: 12)),
                    ],
                  ]),
      ),
      actions: [
        TextButton(onPressed: _printing ? null : () => Navigator.pop(context), child: const Text('Tutup')),
        if (ready)
          OutlinedButton.icon(
            style: outlineButtonStyle(),
            onPressed: _printing ? null : _savePdf,
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: const Text('Simpan PDF'),
          ),
        if (ready)
          ElevatedButton.icon(
            style: primaryButtonStyle(),
            onPressed: _printing || _printer == null ? null : _print,
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Cetak'),
          ),
      ],
    );
  }
}
