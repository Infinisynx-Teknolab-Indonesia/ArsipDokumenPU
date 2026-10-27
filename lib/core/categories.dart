import 'package:flutter/material.dart';
import '../theme/ym_theme.dart';

/// Kategori dokumen — persis versi web: hanya 5 kategori, dua bahasa
/// (English / Bahasa Indonesia). Kode disimpan di database (aplikasi + server);
/// label tampil sesuai pilihan bahasa di Pengaturan → Bahasa kategori.
class DocCategory {
  final String code;
  final String labelEn;
  final String labelId;
  final IconData icon;
  final Color color;
  const DocCategory(this.code, this.labelEn, this.labelId, this.icon, this.color);

  /// Label sesuai bahasa yang dipilih ('en' | 'id' | 'both').
  String get label => switch (ThemeCtl.instance.lang) {
        'id' => labelId,
        'both' => '$labelEn / $labelId',
        _ => labelEn,
      };

  /// Label pendek (untuk chip / grafik).
  String get shortLabel => ThemeCtl.instance.lang == 'id' ? labelId : labelEn;
}

const docCategories = <DocCategory>[
  DocCategory('INVOICE', 'Invoices & Receipts', 'Faktur & Kuitansi', Icons.receipt_long_outlined, Color(0xFF293CA0)),
  DocCategory('CONTRACT', 'Contracts & Agreements', 'Kontrak & Perjanjian', Icons.description_outlined, Color(0xFF4355B9)),
  DocCategory('TAX', 'Tax & Financial Reports', 'Pajak & Laporan Keuangan', Icons.query_stats_rounded, Color(0xFF904D00)),
  DocCategory('SHIPMENT', 'Shipments & Trade Dossiers', 'Pengiriman & Dokumen Dagang', Icons.local_shipping_outlined, Color(0xFF006C4A)),
  DocCategory('MEETING', 'Meeting Minutes', 'Notulen Rapat', Icons.groups_outlined, Color(0xFF757684)),
];

/// Kategori bawaan untuk dokumen baru / kode yang tidak dikenal.
const defaultCategory = 'CONTRACT';

/// Kode kategori lama (versi sebelumnya) -> kategori baru, supaya cache lama tetap tampil benar.
const legacyCategoryMap = {
  'KONTRAK': 'CONTRACT', 'SPMK': 'CONTRACT', 'BA': 'CONTRACT', 'IZIN': 'CONTRACT', 'GAMBAR': 'CONTRACT', 'ASBUILT': 'CONTRACT',
  'RAB': 'TAX', 'MC': 'TAX', 'KEUANGAN': 'TAX',
  'UJI_MUTU': 'SHIPMENT', 'FOTO': 'SHIPMENT',
  'LAP_HARIAN': 'MEETING', 'LAP_MINGGUAN': 'MEETING', 'LAP_BULANAN': 'MEETING', 'SURAT': 'MEETING', 'K3': 'MEETING', 'LAINNYA': 'MEETING',
};

DocCategory categoryOf(String code) {
  final c = legacyCategoryMap[code] ?? code;
  return docCategories.firstWhere((e) => e.code == c, orElse: () => docCategories.firstWhere((e) => e.code == defaultCategory));
}

/// Kode kategori yang valid (kode lama diterjemahkan).
String normalizeCategory(String code) => categoryOf(code).code;

/// Jenis pekerjaan proyek.
const projectTypes = ['Jalan', 'Jembatan', 'Gedung / Bangunan', 'Irigasi', 'Drainase', 'Air Minum / Sanitasi', 'Lainnya'];

/// Status proyek.
const projectStatuses = ['Perencanaan', 'Lelang / Pengadaan', 'Pelaksanaan', 'PHO', 'Masa Pemeliharaan', 'FHO / Selesai', 'Dihentikan'];

/// Sumber dana.
const fundingSources = ['APBN', 'APBD Provinsi', 'APBD Kabupaten/Kota', 'DAK', 'SBSN', 'PHLN / Pinjaman', 'Lainnya'];
