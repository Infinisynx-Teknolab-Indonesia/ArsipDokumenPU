import 'package:flutter/widgets.dart';

/// Navigasi antar halaman di dalam Shell (mis. dari Dashboard/Proyek
/// langsung ke Arsip Dokumen dengan filter tertentu).
class Nav {
  static final page = ValueNotifier<String>('dashboard');

  /// Halaman yang dipertahankan saat tema diganti (layar digambar ulang).
  static String? keepPage;

  /// Filter proyek yang diminta untuk halaman Arsip (id proyek), sekali pakai.
  static final docsProjectFilter = ValueNotifier<String?>(null);

  /// Filter kategori / tahun yang diminta untuk halaman Arsip (dari sidebar), sekali pakai.
  /// Tahun -1 = "lebih lama" (sebelum 4 tahun terakhir).
  static final docsCategory = ValueNotifier<String?>(null);
  static final docsYear = ValueNotifier<int?>(null);

  /// Filter yang SEDANG aktif di halaman Arsip — dipakai sidebar untuk menandai
  /// kategori / tahun yang dipilih.
  static final activeCategory = ValueNotifier<String>('');
  static final activeYear = ValueNotifier<int>(0);

  /// Proyek yang dipilih otomatis di halaman Unggah.
  static final uploadProject = ValueNotifier<String?>(null);

  /// Filter status awal untuk halaman Dokumen Saya ('', 'unsynced', 'failed', 'uploaded', 'today').
  static final myDocsStatus = ValueNotifier<String?>(null);

  /// Kata kunci yang dikirim ke halaman Arsip (mis. dari Kamus Pencarian / kolom cari atas).
  static final docsSearch = ValueNotifier<String?>(null);

  /// Kolom cari di top bar (Ctrl+K).
  static final globalSearchFocus = FocusNode(debugLabel: 'cari-global');

  static void searchDocs(String q) {
    docsSearch.value = q;
    page.value = 'docs';
  }

  static void go(String id) => page.value = id;

  static void showMyDocs([String status = '']) {
    myDocsStatus.value = status;
    page.value = 'mydocs';
  }

  static void openDocsForProject(String projectId) {
    docsProjectFilter.value = projectId;
    page.value = 'docs';
  }

  static void openCategory(String code) {
    docsCategory.value = code;
    page.value = 'docs';
  }

  static void openYear(int year) {
    docsYear.value = year;
    page.value = 'docs';
  }

  static void uploadForProject(String projectId) {
    uploadProject.value = projectId;
    page.value = 'upload';
  }
}
