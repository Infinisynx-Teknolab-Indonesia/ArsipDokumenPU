import 'package:flutter/foundation.dart';

/// Navigasi antar halaman di dalam Shell (mis. dari Dashboard/Proyek
/// langsung ke Arsip Dokumen dengan filter proyek tertentu).
class Nav {
  static final page = ValueNotifier<String>('dashboard');

  /// Filter proyek yang diminta untuk halaman Arsip (id proyek), sekali pakai.
  static final docsProjectFilter = ValueNotifier<String?>(null);

  /// Proyek yang dipilih otomatis di halaman Unggah.
  static final uploadProject = ValueNotifier<String?>(null);

  /// Filter status awal untuk halaman Dokumen Saya ('', 'unsynced', 'failed', 'uploaded', 'today').
  static final myDocsStatus = ValueNotifier<String?>(null);

  /// Kata kunci yang dikirim ke halaman Arsip (mis. dari Kamus Pencarian).
  static final docsSearch = ValueNotifier<String?>(null);

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

  static void uploadForProject(String projectId) {
    uploadProject.value = projectId;
    page.value = 'upload';
  }
}
