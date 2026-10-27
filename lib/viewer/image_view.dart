import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import '../print/pdf_builder.dart';
import '../print/print_dialog.dart';
import 'viewer_common.dart';

/// Penampil foto (JPG, PNG, BMP, GIF, WEBP): zoom dengan roda mouse /
/// tombol, geser, putar 90°.
class ImageDocView extends StatefulWidget {
  final String path;
  final List<Widget> trailing;
  final List<Widget> errorActions;

  /// Diisi penampil: cara membuat PDF siap cetak (tombol Cetak).
  final PrintController? printController;
  const ImageDocView({super.key, required this.path, this.trailing = const [], this.errorActions = const [], this.printController});

  @override
  State<ImageDocView> createState() => _ImageDocViewState();
}

class _ImageDocViewState extends State<ImageDocView> {
  final _t = TransformationController();
  final _areaKey = GlobalKey();
  int _turns = 0;
  double _zoom = 1;
  Size? _imgSize;

  @override
  void initState() {
    super.initState();
    widget.printController?.buildPdf = _buildPdf;
    _t.addListener(() {
      final z = _t.value.getMaxScaleOnAxis();
      if ((z - _zoom).abs() > 0.005 && mounted) setState(() => _zoom = z);
    });
    _resolveSize();
  }

  void _resolveSize() {
    final img = FileImage(File(widget.path));
    final stream = img.resolve(const ImageConfiguration());
    late final ImageStreamListener l;
    l = ImageStreamListener((info, _) {
      if (mounted) setState(() => _imgSize = Size(info.image.width.toDouble(), info.image.height.toDouble()));
      stream.removeListener(l);
    }, onError: (_, __) => stream.removeListener(l));
    stream.addListener(l);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _scale(double factor) {
    final z = (_zoom * factor).clamp(0.2, 8.0);
    final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    final cx = box == null ? 0.0 : box.size.width / 2;
    final cy = box == null ? 0.0 : box.size.height / 2;
    final f = z / _zoom;
    // zoom terhadap titik tengah layar
    _t.value = Matrix4.translationValues(cx, cy, 0)
        .multiplied(Matrix4.diagonal3Values(f, f, 1))
        .multiplied(Matrix4.translationValues(-cx, -cy, 0))
        .multiplied(_t.value);
  }

  Future<String> _buildPdf() async {
    final bytes = await File(widget.path).readAsBytes();
    final size = _imgSize;
    var landscape = size != null && size.width > size.height;
    if (_turns.isOdd) landscape = !landscape;
    final pdf = await compute(_imagePdf, (bytes, landscape));
    return writeTempPdf(pdf, widget.path.split(RegExp(r'[\\/]')).last);
  }

  void _reset() => _t.value = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    return ViewerShortcuts(
      onZoomIn: () => _scale(1.25),
      onZoomOut: () => _scale(0.8),
      onZoomReset: _reset,
      child: Column(children: [
        ViewerToolbar(
          leading: [
            const Icon(Icons.image_rounded, size: 18, color: Color(0xFFB0306A)),
            const SizedBox(width: 6),
            ToolLabel(_imgSize == null ? 'Foto' : 'Foto • ${_imgSize!.width.toInt()} × ${_imgSize!.height.toInt()} px'),
            const ToolDivider(),
            ZoomControls(zoom: _zoom, onZoomIn: () => _scale(1.25), onZoomOut: () => _scale(0.8), onFitWidth: _reset),
            ToolButton(icon: Icons.rotate_left_rounded, tooltip: 'Putar ke kiri', onPressed: () => setState(() => _turns = (_turns + 3) % 4)),
            ToolButton(icon: Icons.rotate_right_rounded, tooltip: 'Putar ke kanan', onPressed: () => setState(() => _turns = (_turns + 1) % 4)),
          ],
          trailing: widget.trailing,
        ),
        Expanded(
          child: Container(
            key: _areaKey,
            color: const Color(0xFF2A2D3E),
            child: InteractiveViewer(
              transformationController: _t,
              minScale: 0.2,
              maxScale: 8,
              boundaryMargin: const EdgeInsets.all(400),
              child: Center(
                child: RotatedBox(
                  quarterTurns: _turns,
                  child: Image.file(
                    File(widget.path),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, e, __) => ViewerMessage(
                      icon: Icons.broken_image_rounded,
                      title: 'Foto tidak bisa ditampilkan',
                      message: 'Format foto tidak dikenali atau file rusak.\n$e',
                      actions: widget.errorActions,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

Future<Uint8List> _imagePdf((Uint8List, bool) job) => pdfFromImageFile(job.$1, landscape: job.$2);
