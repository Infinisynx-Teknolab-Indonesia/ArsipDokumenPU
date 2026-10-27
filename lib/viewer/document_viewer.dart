import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/file_tools.dart';
import '../core/format.dart';
import '../theme/ym_theme.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';
import 'docx_view.dart';
import 'image_view.dart';
import 'pdf_view.dart';
import 'sheet_view.dart';
import 'text_view.dart';
import 'viewer_common.dart';

/// Jenis file yang bisa ditampilkan langsung di aplikasi (tanpa WPS/Office).
bool canViewInApp(String ext) => const [
      'pdf',
      'docx', 'docm', 'dotx',
      'xlsx', 'xlsm', 'csv',
      'txt', 'log', 'md', 'json', 'xml',
      'jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp',
    ].contains(ext.toLowerCase());

String _extOf(String name) {
  final i = name.lastIndexOf('.');
  return i < 0 ? '' : name.substring(i + 1).toLowerCase();
}

/// Penampil dokumen serba guna: memilih penampil sesuai jenis file.
/// Dipakai di panel pratinjau detail dokumen, layar penuh, dan sebelum upload.
class DocumentViewer extends StatelessWidget {
  final String path;
  final String fileName;
  final String initialQuery;
  final List<Widget> trailing;

  /// Tombol yang muncul kalau file tidak bisa ditampilkan (mis. buka dengan aplikasi lain).
  final List<Widget> fallbackActions;

  const DocumentViewer({
    super.key,
    required this.path,
    required this.fileName,
    this.initialQuery = '',
    this.trailing = const [],
    this.fallbackActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    var ext = _extOf(fileName);
    if (ext.isEmpty) ext = _extOf(path);
    if (!File(path).existsSync()) {
      return ViewerMessage(icon: Icons.insert_drive_file_outlined, title: 'File tidak ditemukan', message: path, actions: fallbackActions);
    }
    final k = ValueKey('$path|$initialQuery');
    switch (ext) {
      case 'pdf':
        return PdfDocView(key: k, path: path, initialQuery: initialQuery, trailing: trailing, errorActions: fallbackActions);
      case 'docx':
      case 'docm':
      case 'dotx':
        return DocxDocView(key: k, path: path, initialQuery: initialQuery, trailing: trailing, errorActions: fallbackActions);
      case 'xlsx':
      case 'xlsm':
        return SheetDocView(key: k, path: path, initialQuery: initialQuery, trailing: trailing, errorActions: fallbackActions);
      case 'csv':
        return SheetDocView(key: k, path: path, csv: true, initialQuery: initialQuery, trailing: trailing, errorActions: fallbackActions);
      case 'txt':
      case 'log':
      case 'md':
      case 'json':
      case 'xml':
        return TextDocView(key: k, path: path, initialQuery: initialQuery, trailing: trailing, errorActions: fallbackActions);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'bmp':
      case 'gif':
      case 'webp':
        return ImageDocView(key: k, path: path, trailing: trailing, errorActions: fallbackActions);
    }
    final (title, msg) = switch (ext) {
      'doc' => (
          'Format Word lama (.doc)',
          'File .doc (Word 97-2003) belum bisa ditampilkan langsung. Simpan ulang sebagai .docx di Word, atau buka dengan aplikasi lain.'
        ),
      'xls' => (
          'Format Excel lama (.xls)',
          'File .xls (Excel 97-2003) belum bisa ditampilkan langsung. Simpan ulang sebagai .xlsx, atau buka dengan aplikasi lain.'
        ),
      'dwg' => ('Gambar CAD (.dwg)', 'Gambar teknik AutoCAD perlu dibuka dengan aplikasi CAD.'),
      'zip' || 'rar' => ('File arsip (.$ext)', 'File terkompresi bisa disimpan salinannya lalu diekstrak.'),
      _ => ('File .$ext', 'Jenis file ini tidak bisa ditampilkan langsung di aplikasi.'),
    };
    return ViewerMessage(icon: Icons.insert_drive_file_rounded, title: title, message: msg, actions: fallbackActions);
  }
}

/// Membuka dokumen di layar penuh di dalam aplikasi.
Future<void> openDocumentViewer(
  BuildContext context, {
  required String path,
  required String title,
  required String fileName,
  String initialQuery = '',
  String subtitle = '',
}) {
  return Navigator.of(context).push(PageRouteBuilder(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 160),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (_, __, ___) => DocumentViewerPage(path: path, title: title, fileName: fileName, initialQuery: initialQuery, subtitle: subtitle),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

/// Tombol-tombol cadangan: buka dengan aplikasi lain, simpan salinan, lihat di folder.
List<Widget> externalFileActions(BuildContext context, String path, String fileName) => [
      OutlinedButton.icon(
        style: outlineButtonStyle(),
        onPressed: () => FileTools.open(path),
        icon: const Icon(Icons.open_in_new_rounded, size: 17),
        label: const Text('Buka dengan aplikasi lain'),
      ),
      OutlinedButton.icon(
        style: outlineButtonStyle(),
        onPressed: () async {
          final t = await FileTools.saveCopy(path, fileName);
          if (t != null && context.mounted) showSnack(context, 'Tersimpan ke $t');
        },
        icon: const Icon(Icons.save_alt_rounded, size: 17),
        label: const Text('Simpan salinan'),
      ),
    ];

class DocumentViewerPage extends StatelessWidget {
  final String path, title, fileName, initialQuery, subtitle;
  const DocumentViewerPage({super.key, required this.path, required this.title, required this.fileName, this.initialQuery = '', this.subtitle = ''});

  @override
  Widget build(BuildContext context) {
    final ext = _extOf(fileName);
    var size = '';
    try {
      size = formatBytes(File(path).lengthSync());
    } catch (_) {}
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: Scaffold(
        backgroundColor: kViewerBackground,
        body: Column(children: [
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [YmColors.titleBarStart, YmColors.titleBarEnd])),
            child: Row(children: [
              IconButton(
                tooltip: 'Kembali (Esc)',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              const SizedBox(width: 4),
              FileTypeIcon(ext: ext, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5)),
                    Text(
                      [fileName, if (size.isNotEmpty) size, if (subtitle.isNotEmpty) subtitle].join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              _HeadButton(icon: Icons.save_alt_rounded, label: 'Simpan salinan', onTap: () async {
                final t = await FileTools.saveCopy(path, fileName);
                if (t != null && context.mounted) showSnack(context, 'Tersimpan ke $t');
              }),
              _HeadButton(icon: Icons.folder_open_rounded, label: 'Lihat di folder', onTap: () => FileTools.showInFolder(path)),
              _HeadButton(icon: Icons.open_in_new_rounded, label: 'Aplikasi lain', onTap: () => FileTools.open(path)),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Tutup',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ]),
          ),
          Expanded(
            child: DocumentViewer(
              path: path,
              fileName: fileName,
              initialQuery: initialQuery,
              fallbackActions: externalFileActions(context, path, fileName),
            ),
          ),
        ]),
      ),
    );
  }
}

class _HeadButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HeadButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withOpacity(0.12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(label),
      ),
    );
  }
}
