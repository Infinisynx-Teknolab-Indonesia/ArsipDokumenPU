import 'package:flutter/widgets.dart';
import 'app_state.dart';
import 'nav.dart';

/// Ctrl+F (⌘F di macOS) di MANA SAJA = pencarian.
///  - Halaman yang punya kotak cari (Arsip, Dokumen Saya, Proyek, Kamus, Log)
///    -> kursor langsung masuk ke kotak cari halaman itu, teksnya terpilih.
///  - Halaman lain (Dashboard, Unggah, Profil, ...) -> pindah ke Arsip Dokumen
///    dan kotak cari aktif.
///  - Sedang membuka dokumen (PDF/Word/Excel/teks) -> cari DI DALAM dokumen
///    (ditangani penampil dokumen sendiri, lihat viewer/viewer_common.dart).
/// Dipasang sekali di main.dart (MaterialApp.builder).
class FindShortcut {
  FindShortcut._();

  static final _fields = <String, PageSearchField>{};

  static void register(String pageId, PageSearchField field) => _fields[pageId] = field;

  static void unregister(String pageId, PageSearchField field) {
    if (identical(_fields[pageId], field)) _fields.remove(pageId);
  }

  static void run(NavigatorState? navigator) {
    if (AppState.instance.session == null) return; // layar login
    // tutup dialog / layar dokumen yang sedang terbuka
    navigator?.popUntil((r) => r.isFirst);
    var id = Nav.page.value;
    if (!_fields.containsKey(id)) {
      id = 'docs';
      Nav.go('docs');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final f = _fields[id];
      if (f == null || !f.mounted) return;
      f.searchFocus.requestFocus();
      final c = f.searchController;
      c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
    });
  }
}

/// Pasang di State halaman yang punya kotak cari: `with PageSearchField<NamaPage>`,
/// isi [searchPageId] & [searchController], lalu beri `focusNode: searchFocus`
/// pada TextField-nya.
mixin PageSearchField<T extends StatefulWidget> on State<T> {
  final searchFocus = FocusNode();

  /// id menu di sidebar (lihat screens/shell_screen.dart `_nav`).
  String get searchPageId;
  TextEditingController get searchController;

  @override
  void initState() {
    super.initState();
    FindShortcut.register(searchPageId, this);
  }

  @override
  void dispose() {
    FindShortcut.unregister(searchPageId, this);
    searchFocus.dispose();
    super.dispose();
  }
}
