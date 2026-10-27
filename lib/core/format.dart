const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String two(int n) => n.toString().padLeft(2, '0');

/// 26 Okt 2026 14:05
String formatDateTime(DateTime? d) {
  if (d == null) return '-';
  final l = d.toLocal();
  return '${l.day} ${_bulan[l.month - 1]} ${l.year} ${two(l.hour)}:${two(l.minute)}';
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String baseName(String path) {
  final parts = path.split(RegExp(r'[\\/]'));
  return parts.isEmpty ? path : parts.last;
}

/// Ekstensi file yang boleh diunggah.
const allowedExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv', 'txt', 'jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp', 'dwg', 'zip', 'rar'];

/// Batas ukuran per file (bisa diubah; samakan dengan server).
const maxUploadBytes = 100 * 1024 * 1024;

String fileKind(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf':
      return 'PDF';
    case 'doc':
    case 'docx':
      return 'Word';
    case 'xls':
    case 'xlsx':
    case 'csv':
      return 'Excel';
    case 'txt':
      return 'Teks';
    case 'dwg':
      return 'CAD';
    case 'zip':
    case 'rar':
      return 'Arsip';
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'bmp':
    case 'gif':
    case 'webp':
      return 'Foto';
    default:
      return ext.toUpperCase();
  }
}

/// 2026-10-26
String isoDate(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// "2026-10-26" -> "26 Okt 2026"
String formatIsoDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso.isEmpty ? '-' : iso;
  return '${d.day} ${_bulan[d.month - 1]} ${d.year}';
}

/// Rp 1.250.000.000
String formatRupiah(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}Rp ${b.toString()}';
}

/// Ringkas: 1,25 M / 850 jt
String formatRupiahShort(num v) {
  if (v >= 1e12) return 'Rp ${(v / 1e12).toStringAsFixed(2).replaceAll('.', ',')} T';
  if (v >= 1e9) return 'Rp ${(v / 1e9).toStringAsFixed(2).replaceAll('.', ',')} M';
  if (v >= 1e6) return 'Rp ${(v / 1e6).toStringAsFixed(0)} jt';
  return formatRupiah(v);
}

bool isImageExt(String ext) => const ['jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp'].contains(ext.toLowerCase());
bool isTextExt(String ext) => const ['txt', 'csv'].contains(ext.toLowerCase());
