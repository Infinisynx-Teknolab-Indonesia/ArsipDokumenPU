import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/file_tools.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../pages/email_dialog.dart';
import '../print/print_dialog.dart';
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
/// Toolbar-nya punya tombol CETAK (Ctrl+P) untuk semua jenis yang bisa ditampilkan.
class DocumentViewer extends StatefulWidget {
  final String path;
  final String fileName;
  final String initialQuery;
  final List<Widget> trailing;

  /// Tombol yang muncul kalau file tidak bisa ditampilkan (mis. buka dengan aplikasi lain).
  final List<Widget> fallbackActions;

  /// Judul untuk pekerjaan cetak (default: nama file).
  final String title;

  /// Boleh diisi dari luar (mis. tombol Cetak di header layar penuh).
  final PrintController? printController;

  const DocumentViewer({
    super.key,
    required this.path,
    required this.fileName,
    this.initialQuery = '',
    this.trailing = const [],
    this.fallbackActions = const [],
    this.title = '',
    this.printController,
  });

  @override
  State<DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<DocumentViewer> {
  late PrintController _print = widget.printController ?? PrintController();

  @override
  void didUpdateWidget(covariant DocumentViewer old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.printController != widget.printController) {
      _print = widget.printController ?? PrintController();
    }
  }

  void _doPrint() => showPrintDialog(context,
      controller: _print, title: widget.title.isEmpty ? widget.fileName : widget.title, fileName: widget.fileName);

  @override
  Widget build(BuildContext context) {
    final path = widget.path, fileName = widget.fileName, initialQuery = widget.initialQuery, fallbackActions = widget.fallbackActions;
    // tombol Cetak di depan tombol tambahan dari pemanggil
    final trailing = <Widget>[
      const ToolDivider(),
      ToolButton(icon: Icons.print_rounded, tooltip: 'Cetak / simpan PDF (Ctrl+P)', onPressed: _doPrint),
      ...widget.trailing,
    ];
    var ext = _extOf(fileName);
    if (ext.isEmpty) ext = _extOf(path);
    if (!File(path).existsSync()) {
      return ViewerMessage(icon: Icons.insert_drive_file_outlined, title: 'File tidak ditemukan', message: path, actions: fallbackActions);
    }
    final k = ValueKey('$path|$initialQuery');
    final pc = _print;
    final Widget viewer;
    switch (ext) {
      case 'pdf':
        viewer = PdfDocView(key: k, path: path, initialQuery: initialQuery, trailing: trailing, errorActions: fallbackActions, printController: pc);
        break;
      case 'docx':
      case 'docm':
      case 'dotx':
        viewer = DocxDocView(key: k, path: path, initialQuery: initialQuery, trailing: trailing, errorActions: fallbackActions, printController: pc);
        break;
      case 'xlsx':
      case 'xlsm':
        viewer = SheetDocView(key: k, path: path, initialQuery: initialQuery, trailing: trailing, errorActions: fallbackActions, printController: pc);
        break;
      case 'csv':
        viewer = SheetDocView(key: k, path: path, csv: true, initialQuery: initialQuery, trailing: trailing, errorActions: fallbackActions, printController: pc);
        break;
      case 'txt':
      case 'log':
      case 'md':
      case 'json':
      case 'xml':
        viewer = TextDocView(key: k, path: path, initialQuery: initialQuery, trailing: trailing, errorActions: fallbackActions, printController: pc);
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'bmp':
      case 'gif':
      case 'webp':
        viewer = ImageDocView(key: k, path: path, trailing: trailing, errorActions: fallbackActions, printController: pc);
        break;
      default:
        final (title, msg) = _unsupported(ext);
        return ViewerMessage(icon: Icons.insert_drive_file_rounded, title: title, message: msg, actions: fallbackActions);
    }
    // Ctrl+P / ⌘P = cetak
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): _doPrint,
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true): _doPrint,
      },
      child: viewer,
    );
  }

  (String, String) _unsupported(String ext) => switch (ext) {
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
}

/// Membuka dokumen di layar penuh di dalam aplikasi.
Future<void> openDocumentViewer(
  BuildContext context, {
  required String path,
  required String title,
  required String fileName,
  String initialQuery = '',
  String subtitle = '',
  DocRecord? doc, // diisi supaya tombol "Email" tersedia
}) {
  return Navigator.of(context).push(PageRouteBuilder(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 160),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (_, __, ___) => DocumentViewerPage(path: path, title: title, fileName: fileName, initialQuery: initialQuery, subtitle: subtitle, doc: doc),
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

class DocumentViewerPage extends StatefulWidget {
  final String path, title, fileName, initialQuery, subtitle;
  final DocRecord? doc;
  const DocumentViewerPage(
      {super.key, required this.path, required this.title, required this.fileName, this.initialQuery = '', this.subtitle = '', this.doc});

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  final _print = PrintController();

  @override
  Widget build(BuildContext context) {
    final path = widget.path, title = widget.title, fileName = widget.fileName, initialQuery = widget.initialQuery, subtitle = widget.subtitle;
    final doc = widget.doc;
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
            decoration: BoxDecoration(gradient: LinearGradient(colors: [YmColors.titleBarStart, YmColors.titleBarEnd])),
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
              if (canViewInApp(ext))
                _HeadButton(
                  icon: Icons.print_rounded,
                  label: 'Cetak',
                  onTap: () => showPrintDialog(context, controller: _print, title: title, fileName: fileName),
                ),
              if (doc != null && doc.serverId != null)
                _HeadButton(icon: Icons.forward_to_inbox_rounded, label: 'Email', onTap: () => showEmailDialog(context, doc)),
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
              title: title,
              initialQuery: initialQuery,
              printController: _print,
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
