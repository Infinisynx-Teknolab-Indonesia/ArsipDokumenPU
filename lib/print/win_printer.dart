import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

/// Akses printer Windows langsung lewat API Windows (winspool.drv + gdi32.dll)
/// memakai dart:ffi — tanpa plugin native tambahan dan tanpa WPS/Office.
///
/// Alur cetak: daftar printer -> CreateDC(printer) -> StartDoc -> per halaman:
/// StartPage, StretchDIBits(gambar halaman), EndPage -> EndDoc.
/// Gambar halaman dibuat oleh pdfrx (mesin PDFium) di print_service.dart.

// ------------------------------------------------------------------ struct

final class _PrinterInfo4 extends Struct {
  external Pointer<Utf16> pPrinterName;
  external Pointer<Utf16> pServerName;
  @Uint32()
  external int attributes;
}

final class _DocInfoW extends Struct {
  @Int32()
  external int cbSize;
  external Pointer<Utf16> lpszDocName;
  external Pointer<Utf16> lpszOutput;
  external Pointer<Utf16> lpszDatatype;
  @Uint32()
  external int fwType;
}

final class _BitmapInfoHeader extends Struct {
  @Uint32()
  external int biSize;
  @Int32()
  external int biWidth;
  @Int32()
  external int biHeight;
  @Uint16()
  external int biPlanes;
  @Uint16()
  external int biBitCount;
  @Uint32()
  external int biCompression;
  @Uint32()
  external int biSizeImage;
  @Int32()
  external int biXPelsPerMeter;
  @Int32()
  external int biYPelsPerMeter;
  @Uint32()
  external int biClrUsed;
  @Uint32()
  external int biClrImportant;
}

// ------------------------------------------------------------------ fungsi

final _winspool = DynamicLibrary.open('winspool.drv');
final _gdi32 = DynamicLibrary.open('gdi32.dll');

final _enumPrinters = _winspool.lookupFunction<
    Int32 Function(Uint32, Pointer<Utf16>, Uint32, Pointer<Uint8>, Uint32, Pointer<Uint32>, Pointer<Uint32>),
    int Function(int, Pointer<Utf16>, int, Pointer<Uint8>, int, Pointer<Uint32>, Pointer<Uint32>)>('EnumPrintersW');

final _getDefaultPrinter = _winspool
    .lookupFunction<Int32 Function(Pointer<Utf16>, Pointer<Uint32>), int Function(Pointer<Utf16>, Pointer<Uint32>)>('GetDefaultPrinterW');

final _createDC = _gdi32.lookupFunction<IntPtr Function(Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, Pointer<Void>),
    int Function(Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, Pointer<Void>)>('CreateDCW');
final _deleteDC = _gdi32.lookupFunction<Int32 Function(IntPtr), int Function(int)>('DeleteDC');
final _getDeviceCaps = _gdi32.lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>('GetDeviceCaps');
final _startDoc = _gdi32.lookupFunction<Int32 Function(IntPtr, Pointer<_DocInfoW>), int Function(int, Pointer<_DocInfoW>)>('StartDocW');
final _startPage = _gdi32.lookupFunction<Int32 Function(IntPtr), int Function(int)>('StartPage');
final _endPage = _gdi32.lookupFunction<Int32 Function(IntPtr), int Function(int)>('EndPage');
final _endDoc = _gdi32.lookupFunction<Int32 Function(IntPtr), int Function(int)>('EndDoc');
final _abortDoc = _gdi32.lookupFunction<Int32 Function(IntPtr), int Function(int)>('AbortDoc');
final _setStretchBltMode = _gdi32.lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>('SetStretchBltMode');
final _setBrushOrgEx = _gdi32
    .lookupFunction<Int32 Function(IntPtr, Int32, Int32, Pointer<Void>), int Function(int, int, int, Pointer<Void>)>('SetBrushOrgEx');
final _stretchDIBits = _gdi32.lookupFunction<
    Int32 Function(IntPtr, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Pointer<Void>, Pointer<Void>, Uint32, Uint32),
    int Function(int, int, int, int, int, int, int, int, int, Pointer<Void>, Pointer<Void>, int, int)>('StretchDIBits');

// konstanta Windows
const _printerEnumLocal = 0x2;
const _printerEnumConnections = 0x4;
const _horzRes = 8;
const _vertRes = 10;
const _logPixelsX = 88;
const _halftone = 4;
const _dibRgbColors = 0;
const _srcCopy = 0x00CC0020;

/// Daftar printer yang terpasang di Windows + printer default.
(List<String>, String?) winListPrinters() {
  final needed = calloc<Uint32>();
  final returned = calloc<Uint32>();
  final names = <String>[];
  try {
    const flags = _printerEnumLocal | _printerEnumConnections;
    _enumPrinters(flags, nullptr, 4, nullptr, 0, needed, returned);
    if (needed.value > 0) {
      final buf = calloc<Uint8>(needed.value);
      try {
        if (_enumPrinters(flags, nullptr, 4, buf, needed.value, needed, returned) != 0) {
          final infos = buf.cast<_PrinterInfo4>();
          for (var i = 0; i < returned.value; i++) {
            final p = infos[i].pPrinterName;
            if (p != nullptr) names.add(p.toDartString());
          }
        }
      } finally {
        calloc.free(buf);
      }
    }
  } finally {
    calloc.free(needed);
    calloc.free(returned);
  }

  String? def;
  final size = calloc<Uint32>()..value = 512;
  final nameBuf = calloc<Uint16>(512).cast<Utf16>();
  try {
    if (_getDefaultPrinter(nameBuf, size) != 0) def = nameBuf.toDartString();
  } finally {
    calloc.free(size);
    calloc.free(nameBuf);
  }
  if (def != null && !names.contains(def)) names.insert(0, def);
  return (names, def);
}

/// Satu pekerjaan cetak di printer Windows.
class WinPrintJob {
  final int _hdc;
  bool _open = false;

  /// Area yang bisa dicetak (piksel printer) dan resolusinya.
  final int width, height, dpi;

  WinPrintJob._(this._hdc, this.width, this.height, this.dpi);

  /// Buka printer [printerName] dan mulai dokumen bernama [docName].
  static WinPrintJob start(String printerName, String docName) {
    final driver = 'WINSPOOL'.toNativeUtf16();
    final device = printerName.toNativeUtf16();
    final hdc = _createDC(driver, device, nullptr, nullptr);
    calloc.free(driver);
    calloc.free(device);
    if (hdc == 0) throw Exception('Printer "$printerName" tidak bisa dibuka.');
    final job = WinPrintJob._(hdc, _getDeviceCaps(hdc, _horzRes), _getDeviceCaps(hdc, _vertRes), _getDeviceCaps(hdc, _logPixelsX));
    final di = calloc<_DocInfoW>();
    final name = docName.toNativeUtf16();
    try {
      di.ref
        ..cbSize = sizeOf<_DocInfoW>()
        ..lpszDocName = name
        ..lpszOutput = nullptr
        ..lpszDatatype = nullptr
        ..fwType = 0;
      if (_startDoc(hdc, di) <= 0) {
        _deleteDC(hdc);
        throw Exception('Printer menolak pekerjaan cetak (StartDoc gagal). Cek printer menyala & tidak error.');
      }
      job._open = true;
    } finally {
      calloc.free(di);
      calloc.free(name);
    }
    _setStretchBltMode(hdc, _halftone);
    _setBrushOrgEx(hdc, 0, 0, nullptr);
    return job;
  }

  /// Cetak satu halaman dari gambar BGRA (atas ke bawah) berukuran [imgW] x [imgH],
  /// diperbesar/diperkecil supaya pas di area cetak dan diletakkan di tengah.
  void printPage(Uint8List bgra, int imgW, int imgH) {
    if (_startPage(_hdc) <= 0) throw Exception('Gagal memulai halaman baru di printer.');
    final scale = (width / imgW) < (height / imgH) ? width / imgW : height / imgH;
    final dw = (imgW * scale).round();
    final dh = (imgH * scale).round();
    final x = ((width - dw) / 2).round();
    final y = ((height - dh) / 2).round();

    final bits = calloc<Uint8>(bgra.length);
    // BITMAPINFO = header + 1 RGBQUAD (tidak dipakai untuk 32-bit)
    final bmi = calloc<Uint8>(sizeOf<_BitmapInfoHeader>() + 4).cast<_BitmapInfoHeader>();
    try {
      bits.asTypedList(bgra.length).setAll(0, bgra);
      bmi.ref
        ..biSize = sizeOf<_BitmapInfoHeader>()
        ..biWidth = imgW
        ..biHeight = -imgH // negatif = baris dari atas ke bawah
        ..biPlanes = 1
        ..biBitCount = 32
        ..biCompression = 0 // BI_RGB
        ..biSizeImage = 0
        ..biXPelsPerMeter = 0
        ..biYPelsPerMeter = 0
        ..biClrUsed = 0
        ..biClrImportant = 0;
      final r = _stretchDIBits(_hdc, x, y, dw, dh, 0, 0, imgW, imgH, bits.cast(), bmi.cast(), _dibRgbColors, _srcCopy);
      if (r == 0) throw Exception('Gagal mengirim gambar halaman ke printer.');
    } finally {
      calloc.free(bits);
      calloc.free(bmi);
    }
    if (_endPage(_hdc) <= 0) throw Exception('Printer menolak halaman (EndPage gagal).');
  }

  void finish() {
    if (_open) _endDoc(_hdc);
    _open = false;
    _deleteDC(_hdc);
  }

  void abort() {
    if (_open) _abortDoc(_hdc);
    _open = false;
    _deleteDC(_hdc);
  }
}
