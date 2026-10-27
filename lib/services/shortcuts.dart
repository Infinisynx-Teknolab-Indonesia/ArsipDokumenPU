import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sembast/sembast.dart'; // extension get/put pada RecordRef
import '../core/local_db.dart';

/// Aksi yang punya pintasan keyboard (bisa diatur di Pengaturan → Pintasan keyboard).
enum AppAction { globalSearch, pageFind, upload, sync, fullscreen }

extension AppActionInfo on AppAction {
  String get title => switch (this) {
        AppAction.globalSearch => 'Cari di seluruh arsip',
        AppAction.pageFind => 'Cari di halaman / di dalam dokumen',
        AppAction.upload => 'Tambah dokumen baru',
        AppAction.sync => 'Sinkronkan sekarang',
        AppAction.fullscreen => 'Masuk / keluar layar penuh',
      };

  String get note => switch (this) {
        AppAction.globalSearch => 'Kursor langsung ke kolom cari di bagian atas.',
        AppAction.pageFind => 'Kotak saring halaman ini; saat dokumen terbuka = cari teks di dalam dokumen.',
        AppAction.upload => 'Buka halaman Unggah Dokumen.',
        AppAction.sync => 'Kirim antrian & ambil data terbaru dari server.',
        AppAction.fullscreen => 'Sama seperti tombol layar penuh di title bar.',
      };
}

/// Satu kombinasi tombol. [ctrl] = Ctrl (Windows) atau ⌘ Cmd (macOS).
@immutable
class KeyCombo {
  final int keyId;
  final bool ctrl, shift, alt;
  const KeyCombo(this.keyId, {this.ctrl = false, this.shift = false, this.alt = false});

  LogicalKeyboardKey get key => LogicalKeyboardKey(keyId);

  String get label {
    final parts = <String>[
      if (ctrl) defaultTargetPlatform == TargetPlatform.macOS ? '⌘' : 'Ctrl',
      if (alt) defaultTargetPlatform == TargetPlatform.macOS ? '⌥' : 'Alt',
      if (shift) 'Shift',
      _keyName(key),
    ];
    return parts.join(' ');
  }

  static String _keyName(LogicalKeyboardKey k) {
    final l = k.keyLabel;
    if (l.isNotEmpty && l.trim().isNotEmpty) return l.length == 1 ? l.toUpperCase() : l;
    return k.debugName ?? 'Key ${k.keyId}';
  }

  Map<String, Object> toJson() => {'k': keyId, 'c': ctrl, 's': shift, 'a': alt};

  static KeyCombo? fromJson(Object? j) {
    if (j is! Map) return null;
    final k = (j['k'] as num?)?.toInt();
    if (k == null) return null;
    return KeyCombo(k, ctrl: j['c'] == true, shift: j['s'] == true, alt: j['a'] == true);
  }

  bool matches(KeyEvent e) {
    final hw = HardwareKeyboard.instance;
    return e.logicalKey.keyId == keyId &&
        ctrl == (hw.isControlPressed || hw.isMetaPressed) &&
        shift == hw.isShiftPressed &&
        alt == hw.isAltPressed;
  }

  @override
  bool operator ==(Object other) => other is KeyCombo && other.keyId == keyId && other.ctrl == ctrl && other.shift == shift && other.alt == alt;

  @override
  int get hashCode => Object.hash(keyId, ctrl, shift, alt);

  /// Kombinasi dari tombol yang sedang ditekan (dipakai saat merekam pintasan baru).
  static KeyCombo? fromEvent(KeyEvent e) {
    final k = e.logicalKey;
    const mods = {
      LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.controlRight, LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.altLeft, LogicalKeyboardKey.altRight, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.metaRight,
      LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.alt, LogicalKeyboardKey.meta,
    };
    if (mods.contains(k)) return null;
    final hw = HardwareKeyboard.instance;
    return KeyCombo(k.keyId, ctrl: hw.isControlPressed || hw.isMetaPressed, shift: hw.isShiftPressed, alt: hw.isAltPressed);
  }
}

/// Pintasan keyboard aplikasi.
///
/// Dipasang sebagai penangan GLOBAL (HardwareKeyboard), jadi tetap bekerja
/// di mana pun kursor berada — termasuk saat tidak ada kolom yang aktif
/// (sebelumnya Ctrl+K / Ctrl+F kadang tidak bereaksi karena fokus hilang).
class ShortcutCtl extends ChangeNotifier {
  ShortcutCtl._();
  static final ShortcutCtl instance = ShortcutCtl._();

  static final Map<AppAction, KeyCombo> defaults = {
    AppAction.globalSearch: KeyCombo(LogicalKeyboardKey.keyK.keyId, ctrl: true),
    AppAction.pageFind: KeyCombo(LogicalKeyboardKey.keyF.keyId, ctrl: true),
    AppAction.upload: KeyCombo(LogicalKeyboardKey.keyU.keyId, ctrl: true),
    AppAction.sync: KeyCombo(LogicalKeyboardKey.f5.keyId),
    AppAction.fullscreen: KeyCombo(LogicalKeyboardKey.f11.keyId),
  };

  final Map<AppAction, KeyCombo> _map = Map.of(defaults);
  final Map<AppAction, VoidCallback> _handlers = {};

  /// Penampil dokumen yang sedang terbuka (paling akhir = paling atas): Ctrl+F mencari di dalamnya.
  final List<VoidCallback> _viewerFind = [];

  /// true saat pengguna sedang merekam pintasan baru di Pengaturan.
  bool recording = false;

  KeyCombo combo(AppAction a) => _map[a] ?? defaults[a]!;
  String label(AppAction a) => combo(a).label;

  static final _store = LocalDb.settings;

  Future<void> load() async {
    try {
      final r = await _store.record('shortcuts').get(LocalDb.db);
      if (r != null) {
        for (final a in AppAction.values) {
          final c = KeyCombo.fromJson(r[a.name]);
          if (c != null) _map[a] = c;
        }
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      await _store.record('shortcuts').put(LocalDb.db, {for (final e in _map.entries) e.key.name: e.value.toJson()});
    } catch (_) {}
  }

  /// Aksi lain yang sudah memakai kombinasi ini (untuk peringatan bentrok).
  AppAction? conflictOf(AppAction a, KeyCombo c) => _map.entries.where((e) => e.key != a && e.value == c).map((e) => e.key).firstOrNull;

  Future<void> set(AppAction a, KeyCombo c) async {
    _map[a] = c;
    notifyListeners();
    await _save();
  }

  Future<void> resetAll() async {
    _map
      ..clear()
      ..addAll(defaults);
    notifyListeners();
    await _save();
  }

  /// Dipanggil sekali di main.dart.
  void install(Map<AppAction, VoidCallback> handlers) {
    _handlers
      ..clear()
      ..addAll(handlers);
    HardwareKeyboard.instance.removeHandler(_onKey);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  void registerViewerFind(VoidCallback f) => _viewerFind.add(f);
  void unregisterViewerFind(VoidCallback f) => _viewerFind.remove(f);

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || recording) return false;
    for (final a in AppAction.values) {
      if (!combo(a).matches(e)) continue;
      if (a == AppAction.pageFind && _viewerFind.isNotEmpty) {
        _viewerFind.last();
        return true;
      }
      final h = _handlers[a];
      if (h == null) return false;
      h();
      return true;
    }
    return false;
  }
}
