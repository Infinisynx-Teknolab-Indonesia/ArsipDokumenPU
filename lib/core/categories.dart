import 'package:flutter/material.dart';

/// Kategori dokumen proyek konstruksi PU. Kode disimpan di database
/// (aplikasi + server), label boleh diubah kapan saja.
class DocCategory {
  final String code;
  final String label;
  final IconData icon;
  final Color color;
  const DocCategory(this.code, this.label, this.icon, this.color);
}

const docCategories = <DocCategory>[
  DocCategory('KONTRAK', 'Kontrak & Addendum', Icons.handshake_rounded, Color(0xFF5B4FE0)),
  DocCategory('SPMK', 'SPMK / Surat Perintah', Icons.assignment_turned_in_rounded, Color(0xFF2F3E9E)),
  DocCategory('RAB', 'RAB / BoQ / HPS', Icons.calculate_rounded, Color(0xFF0E8F7E)),
  DocCategory('GAMBAR', 'Gambar Rencana / Shop Drawing', Icons.architecture_rounded, Color(0xFF1F7AE0)),
  DocCategory('ASBUILT', 'Gambar As-Built', Icons.design_services_rounded, Color(0xFF3D9BE9)),
  DocCategory('LAP_HARIAN', 'Laporan Harian', Icons.today_rounded, Color(0xFFE08A1E)),
  DocCategory('LAP_MINGGUAN', 'Laporan Mingguan', Icons.date_range_rounded, Color(0xFFD9701A)),
  DocCategory('LAP_BULANAN', 'Laporan Bulanan', Icons.calendar_month_rounded, Color(0xFFC25A12)),
  DocCategory('MC', 'MC / Opname / Back-up Data', Icons.straighten_rounded, Color(0xFF8E44AD)),
  DocCategory('FOTO', 'Foto Dokumentasi Progres', Icons.photo_camera_rounded, Color(0xFF16A085)),
  DocCategory('BA', 'Berita Acara (PHO / FHO / Serah Terima)', Icons.gavel_rounded, Color(0xFFB03A2E)),
  DocCategory('UJI_MUTU', 'Uji Mutu / Hasil Laboratorium', Icons.science_rounded, Color(0xFF27AE60)),
  DocCategory('SURAT', 'Surat Menyurat', Icons.mail_rounded, Color(0xFF7F8C8D)),
  DocCategory('IZIN', 'Perizinan / AMDAL / Lingkungan', Icons.verified_rounded, Color(0xFF2E86C1)),
  DocCategory('KEUANGAN', 'Keuangan / Termin Pembayaran', Icons.payments_rounded, Color(0xFFD4AC0D)),
  DocCategory('K3', 'K3 / Keselamatan Konstruksi', Icons.health_and_safety_rounded, Color(0xFFE74C3C)),
  DocCategory('LAINNYA', 'Lainnya', Icons.folder_rounded, Color(0xFF8A8DAE)),
];

DocCategory categoryOf(String code) =>
    docCategories.firstWhere((c) => c.code == code, orElse: () => docCategories.last);

/// Jenis pekerjaan proyek.
const projectTypes = ['Jalan', 'Jembatan', 'Gedung / Bangunan', 'Irigasi', 'Drainase', 'Air Minum / Sanitasi', 'Lainnya'];

/// Status proyek.
const projectStatuses = ['Perencanaan', 'Lelang / Pengadaan', 'Pelaksanaan', 'PHO', 'Masa Pemeliharaan', 'FHO / Selesai', 'Dihentikan'];

/// Sumber dana.
const fundingSources = ['APBN', 'APBD Provinsi', 'APBD Kabupaten/Kota', 'DAK', 'SBSN', 'PHLN / Pinjaman', 'Lainnya'];
