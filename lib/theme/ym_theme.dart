import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart'; // extension get/put pada RecordRef
import '../core/local_db.dart';

/// ============================================================================
///  TEMA APLIKASI
///
///  Semua warna aplikasi diambil dari [AppPalette] yang sedang aktif. Pengguna
///  memilih tema di Pengaturan → Tampilan; pilihan disimpan di PC ini.
///
///  Menambah tema baru: tambahkan satu AppPalette di [appPalettes]. Selesai —
///  seluruh halaman otomatis ikut.
/// ============================================================================
class AppPalette {
  final String id;
  final String name;
  final String note;
  final bool dark;

  /// Warna utama: tombol utama, menu aktif, tautan.
  final Color primary;
  final Color onPrimary;

  /// Versi lebih gelap (latar layar login, gradasi).
  final Color primaryDeep;

  /// Versi sangat muda (latar menu aktif, chip terpilih).
  final Color primarySoft;

  /// Latar halaman.
  final Color bg;

  /// Latar kartu/panel.
  final Color surface;

  /// Latar sekunder di dalam kartu (header tabel, isian, kotak nilai).
  final Color surfaceAlt;

  /// Latar menu aktif / kontainer tingkat lebih tinggi (versi web: surface-container / -highest).
  final Color surfaceContainer;
  final Color surfaceHigh;

  /// Latar sidebar & top bar.
  final Color sidebar;

  /// Teks keterangan paling halus (tanggal, meta) — versi web: outline.
  final Color outline;
  final Color line;
  final Color text;
  final Color muted;
  final Color link;

  /// Aksen kedua (penanda kecil, sorotan).
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;

  /// Latar lembut untuk chip status (hijau / oranye / merah muda).
  final Color successSoft;
  final Color warningSoft;
  final Color dangerSoft;

  const AppPalette({
    required this.id,
    required this.name,
    required this.note,
    this.dark = false,
    required this.primary,
    this.onPrimary = Colors.white,
    required this.primaryDeep,
    required this.primarySoft,
    required this.bg,
    this.surface = Colors.white,
    required this.surfaceAlt,
    required this.surfaceContainer,
    required this.surfaceHigh,
    required this.sidebar,
    required this.line,
    required this.text,
    required this.muted,
    required this.outline,
    Color? link,
    required this.accent,
    this.success = const Color(0xFF006C4A),
    this.warning = const Color(0xFF8A4600),
    this.danger = const Color(0xFFBA1A1A),
    this.successSoft = const Color(0xFFCDF8E4),
    this.warningSoft = const Color(0xFFFFE6D3),
    this.dangerSoft = const Color(0xFFFFDAD6),
  }) : link = link ?? primary;
}

const appPalettes = <AppPalette>[
  // Persis warna versi web (Tailwind config "DocArchive").
  AppPalette(
    id: 'indigo',
    name: 'Indigo',
    note: 'Sama dengan versi web — bawaan',
    primary: Color(0xFF293CA0),
    primaryDeep: Color(0xFF1A2670),
    primarySoft: Color(0xFFDEE0FF),
    bg: Color(0xFFF8F9FF),
    surfaceAlt: Color(0xFFEFF4FF),
    surfaceContainer: Color(0xFFE5EEFF),
    surfaceHigh: Color(0xFFD3E4FE),
    sidebar: Color(0xFFF3F6FF),
    line: Color(0xFFDDE3F0),
    text: Color(0xFF0B1C30),
    muted: Color(0xFF454652),
    outline: Color(0xFF757684),
    accent: Color(0xFF4355B9),
  ),
  AppPalette(
    id: 'biru',
    name: 'Biru PU',
    note: 'Biru dinas pekerjaan umum',
    primary: Color(0xFF1D5FD0),
    primaryDeep: Color(0xFF0F2E66),
    primarySoft: Color(0xFFDCE8FC),
    bg: Color(0xFFF6F9FD),
    surfaceAlt: Color(0xFFEEF4FC),
    surfaceContainer: Color(0xFFE3EDFA),
    surfaceHigh: Color(0xFFD2E3FA),
    sidebar: Color(0xFFF1F6FD),
    line: Color(0xFFDDE5F1),
    text: Color(0xFF0F1B2D),
    muted: Color(0xFF465163),
    outline: Color(0xFF6E7787),
    accent: Color(0xFFF2A900),
  ),
  AppPalette(
    id: 'zamrud',
    name: 'Zamrud',
    note: 'Hijau teduh, nyaman untuk kerja lama',
    primary: Color(0xFF0E7A5A),
    primaryDeep: Color(0xFF0A3B2C),
    primarySoft: Color(0xFFD5F0E5),
    bg: Color(0xFFF6F9F7),
    surfaceAlt: Color(0xFFEDF5F1),
    surfaceContainer: Color(0xFFE2EFE9),
    surfaceHigh: Color(0xFFD0E8DD),
    sidebar: Color(0xFFF0F6F3),
    line: Color(0xFFDCE7E2),
    text: Color(0xFF10201A),
    muted: Color(0xFF45534D),
    outline: Color(0xFF6C7A74),
    accent: Color(0xFFE0A100),
  ),
  AppPalette(
    id: 'grafit',
    name: 'Grafit',
    note: 'Hitam-putih tegas, tautan biru',
    primary: Color(0xFF15181F),
    primaryDeep: Color(0xFF0B0D12),
    primarySoft: Color(0xFFE7E8EB),
    bg: Color(0xFFF8F8F9),
    surfaceAlt: Color(0xFFF2F3F5),
    surfaceContainer: Color(0xFFEAEBEE),
    surfaceHigh: Color(0xFFE0E2E6),
    sidebar: Color(0xFFF4F4F6),
    line: Color(0xFFE3E5E9),
    text: Color(0xFF111318),
    muted: Color(0xFF4B5160),
    outline: Color(0xFF6B7280),
    link: Color(0xFF2563EB),
    accent: Color(0xFF2563EB),
  ),
  AppPalette(
    id: 'konstruksi',
    name: 'Konstruksi',
    note: 'Oranye rompi proyek',
    primary: Color(0xFFC2410C),
    primaryDeep: Color(0xFF4A1D08),
    primarySoft: Color(0xFFFCE3D3),
    bg: Color(0xFFFBF9F7),
    surfaceAlt: Color(0xFFF7F1EC),
    surfaceContainer: Color(0xFFF2E8E0),
    surfaceHigh: Color(0xFFEDDCCF),
    sidebar: Color(0xFFF8F2ED),
    line: Color(0xFFEBE1D9),
    text: Color(0xFF221812),
    muted: Color(0xFF5A4B41),
    outline: Color(0xFF7E6E63),
    accent: Color(0xFF0F766E),
  ),
  AppPalette(
    id: 'malam',
    name: 'Malam',
    note: 'Gelap, hemat mata di ruangan redup',
    dark: true,
    primary: Color(0xFF7385F7),
    primaryDeep: Color(0xFF070A12),
    primarySoft: Color(0xFF232B5A),
    bg: Color(0xFF0B0F1A),
    surface: Color(0xFF131929),
    surfaceAlt: Color(0xFF182033),
    surfaceContainer: Color(0xFF1D263C),
    surfaceHigh: Color(0xFF253153),
    sidebar: Color(0xFF0F1424),
    line: Color(0xFF252E46),
    text: Color(0xFFE6E9F2),
    muted: Color(0xFFB2B8CA),
    outline: Color(0xFF8189A0),
    link: Color(0xFF94A2FF),
    accent: Color(0xFF94A2FF),
    success: Color(0xFF4ADE9F),
    warning: Color(0xFFFBBF6A),
    danger: Color(0xFFFF8A80),
    successSoft: Color(0xFF123B2E),
    warningSoft: Color(0xFF3D2A12),
    dangerSoft: Color(0xFF441B1B),
  ),
];

/// Tema yang aktif + simpan pilihan di PC ini.
class ThemeCtl extends ChangeNotifier {
  ThemeCtl._();
  static final ThemeCtl instance = ThemeCtl._();

  AppPalette palette = appPalettes.first;

  /// true = animasi dimatikan di aplikasi ini (selain setelan Windows/macOS).
  bool lessMotion = false;

  /// Naik setiap kali tema diganti — dipakai sebagai key supaya seluruh layar
  /// digambar ulang dengan warna baru.
  int generation = 0;

  static final _store = LocalDb.settings;

  Future<void> load() async {
    try {
      final r = await _store.record('theme').get(LocalDb.db);
      final id = (r?['id'] ?? '').toString();
      palette = appPalettes.firstWhere((p) => p.id == id, orElse: () => appPalettes.first);
      lessMotion = r?['less_motion'] == true;
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      await _store.record('theme').put(LocalDb.db, {'id': palette.id, 'less_motion': lessMotion});
    } catch (_) {}
  }

  Future<void> setLessMotion(bool v) async {
    lessMotion = v;
    notifyListeners();
    await _save();
  }

  Future<void> set(String id) async {
    final p = appPalettes.firstWhere((e) => e.id == id, orElse: () => appPalettes.first);
    if (p.id == palette.id) return;
    palette = p;
    generation++;
    notifyListeners();
    await _save();
  }
}

/// Warna-warna aplikasi (selalu mengikuti tema aktif).
/// Nama lama (accentPurple, borderLavender, ...) tetap ada supaya semua
/// halaman lama otomatis ikut tema.
class YmColors {
  YmColors._();
  static AppPalette get _p => ThemeCtl.instance.palette;
  static bool get isDark => _p.dark;

  // ---- palet
  static Color get primary => _p.primary;
  static Color get onPrimary => _p.onPrimary;
  static Color get primarySoft => _p.primarySoft;
  static Color get primaryDeep => _p.primaryDeep;
  static Color get ink => _p.primary;
  static Color get inkSoft => _p.primaryDeep;
  static Color get inkLine => _p.line;
  static Color get paper => _p.bg;
  static Color get surface => _p.surface;
  static Color get surfaceAlt => _p.surfaceAlt;
  static Color get surfaceContainer => _p.surfaceContainer;
  static Color get surfaceHigh => _p.surfaceHigh;
  static Color get sidebar => _p.sidebar;
  static Color get outline => _p.outline;
  static Color get successSoft => _p.successSoft;
  static Color get warningSoft => _p.warningSoft;
  static Color get dangerSoft => _p.dangerSoft;
  static Color get line => _p.line;
  static Color get puBlue => _p.primary;
  static Color get link => _p.link;
  static Color get marka => _p.accent;
  static Color get accent => _p.accent;
  static Color get success => _p.success;
  static Color get warning => _p.warning;
  static Color get danger => _p.danger;

  // ---- nama lama
  static Color get titleBarStart => _p.primaryDeep;
  static Color get titleBarEnd => _p.primary;
  static Color get accentPurple => _p.primary;
  static Color get accentBlue => _p.primary;
  static Color get panelBackground => _p.surfaceAlt;
  static Color get contentBackground => _p.surface;
  static Color get borderLavender => _p.line;
  static Color get textDark => _p.text;
  static Color get textMuted => _p.muted;
  static Color get statusOnline => _p.success;
  static Color get statusOffline => _p.muted;
  static Color get statusBusy => _p.danger;
  static Color get statusAway => _p.warning;
  static Color get bubbleIncoming => _p.surfaceAlt;
  static Color get bubbleOutgoing => _p.primarySoft;
  static Color get buzzRed => _p.danger;

  // ---- layar login
  static Color get heroGradientTop => _p.primaryDeep;
  static Color get heroGradientBottom => Color.lerp(_p.primaryDeep, _p.primary, 0.45)!;
  static Color get cardGlass => _p.surface;
  static Color get fieldFillOnDark => const Color(0x14FFFFFF);
}

/// Huruf (dibundel di assets/fonts, sama seperti versi web):
///   Inter            -> teks isi, label, tombol
///   Plus Jakarta Sans -> judul halaman, judul kartu, angka besar
const kFont = 'Inter';
const kFontDisplay = 'PlusJakartaSans';
const kFontFallback = ['Segoe UI', 'Arial'];

class YmTextStyles {
  YmTextStyles._();

  static TextStyle get appTitle => const TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 12, fontWeight: FontWeight.w600)
      .copyWith(color: YmColors.textDark);

  /// Judul baris / nama (mis. judul dokumen di daftar).
  static TextStyle get username => TextStyle(
      fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 13, fontWeight: FontWeight.w600, color: YmColors.textDark, height: 1.3);

  static TextStyle get statusMessage =>
      TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 11, fontStyle: FontStyle.italic, color: YmColors.textMuted);

  static TextStyle get buddyName =>
      TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 12.5, fontWeight: FontWeight.w600, color: YmColors.textDark);

  /// Teks isi.
  static TextStyle get chatText =>
      TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 13, color: YmColors.textDark, height: 1.45);

  /// Teks keterangan kecil.
  static TextStyle get label =>
      TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 11.5, color: YmColors.textMuted, height: 1.35);

  /// Judul halaman besar.
  static TextStyle get pageTitle => TextStyle(
      fontFamily: kFontDisplay, fontFamilyFallback: kFontFallback, fontSize: 30, fontWeight: FontWeight.w700, color: YmColors.textDark, letterSpacing: -0.6, height: 1.2);

  /// Judul kartu / dokumen (versi web: headline-sm 16px).
  static TextStyle get headline => TextStyle(
      fontFamily: kFontDisplay, fontFamilyFallback: kFontFallback, fontSize: 16, fontWeight: FontWeight.w700, color: YmColors.textDark, letterSpacing: -0.1, height: 1.4);

  /// Angka besar di kartu statistik.
  static TextStyle get bigNumber => TextStyle(
      fontFamily: kFontDisplay, fontFamilyFallback: kFontFallback, fontSize: 30, fontWeight: FontWeight.w700, color: YmColors.textDark, letterSpacing: -0.6, height: 1.1);

  /// Judul kelompok kecil (versi web: label-sm, huruf kapital, renggang).
  static TextStyle get overline => TextStyle(
      fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 11, fontWeight: FontWeight.w600, color: YmColors.outline, letterSpacing: 0.6);

  /// Judul bagian (kartu/panel).
  static TextStyle get sectionTitle =>
      TextStyle(fontFamily: kFontDisplay, fontFamilyFallback: kFontFallback, fontSize: 16, fontWeight: FontWeight.w700, color: YmColors.textDark, letterSpacing: -0.2);

  /// Label kecil di atas nilai (mis. "Nomor dokumen").
  static TextStyle get fieldLabel =>
      TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 11.5, fontWeight: FontWeight.w600, color: YmColors.textMuted, letterSpacing: 0.1);

  /// Nilai data (mis. isi nomor dokumen).
  static TextStyle get fieldValue =>
      TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 14, fontWeight: FontWeight.w600, color: YmColors.textDark, height: 1.4);
}

const ymBorderRadius = 12.0;

/// Durasi animasi standar (0 bila pengguna mematikan animasi di Windows/macOS — lihat [motion]).
const kMotionFast = Duration(milliseconds: 160);
const kMotion = Duration(milliseconds: 320);
const kMotionSlow = Duration(milliseconds: 520);
const kMotionCurve = Curves.easeOutCubic;

Duration motion(BuildContext context, [Duration d = kMotion]) => MediaQuery.maybeOf(context)?.disableAnimations == true ? Duration.zero : d;

bool reduceMotion(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations == true;

/// Bayangan lembut untuk kartu (hampir tak terlihat, hanya memberi kedalaman).
List<BoxShadow> get softShadow => YmColors.isDark
    ? const []
    : const [
        BoxShadow(color: Color(0x0F0F172A), blurRadius: 3, offset: Offset(0, 1)),
        BoxShadow(color: Color(0x080F172A), blurRadius: 2, offset: Offset(0, 1)),
      ];

/// Bayangan kartu saat disorot mouse (versi web: hover:shadow-md).
List<BoxShadow> get hoverShadow => YmColors.isDark
    ? const []
    : const [
        BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, 4)),
        BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 2)),
      ];

/// Tema Material untuk seluruh aplikasi (mengikuti tema aktif).
ThemeData buildAppTheme() {
  final p = ThemeCtl.instance.palette;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    brightness: p.dark ? Brightness.dark : Brightness.light,
    primary: p.primary,
    onPrimary: p.onPrimary,
    secondary: p.accent,
    surface: p.surface,
    onSurface: p.text,
    error: p.danger,
  );
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.line));
  final base = ThemeData(brightness: p.dark ? Brightness.dark : Brightness.light, useMaterial3: true);
  return ThemeData(
    useMaterial3: true,
    brightness: p.dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    fontFamily: kFont,
    fontFamilyFallback: kFontFallback,
    textTheme: base.textTheme.apply(fontFamily: kFont, bodyColor: p.text, displayColor: p.text),
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.surface,
    cardColor: p.surface,
    hoverColor: p.primary.withOpacity(0.05),
    splashColor: p.primary.withOpacity(0.08),
    highlightColor: Colors.transparent,
    visualDensity: VisualDensity.standard,
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: p.muted),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: p.line)),
      titleTextStyle: TextStyle(fontFamily: kFontDisplay, fontSize: 18, fontWeight: FontWeight.w800, color: p.text, letterSpacing: -0.3),
      contentTextStyle: TextStyle(fontFamily: kFont, fontSize: 13.5, color: p.text, height: 1.5),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.line)),
      textStyle: TextStyle(fontFamily: kFont, fontSize: 13, color: p.text),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(p.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.line))),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(color: p.muted, fontSize: 13),
      hintStyle: TextStyle(color: p.muted.withOpacity(0.8), fontSize: 13),
      prefixIconColor: p.muted,
      suffixIconColor: p.muted,
      border: border,
      enabledBorder: border,
      disabledBorder: border.copyWith(borderSide: BorderSide(color: p.line.withOpacity(0.6))),
      focusedBorder: border.copyWith(borderSide: BorderSide(color: p.primary, width: 1.6)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        backgroundColor: p.surface,
        side: BorderSide(color: p.line),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.link,
        textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: p.muted)),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.primarySoft,
      side: BorderSide(color: p.line),
      labelStyle: TextStyle(fontFamily: kFont, fontSize: 12.5, fontWeight: FontWeight.w600, color: p.text),
      secondaryLabelStyle: TextStyle(fontFamily: kFont, fontSize: 12.5, fontWeight: FontWeight.w700, color: p.primary),
      checkmarkColor: p.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.primary,
      unselectedLabelColor: p.muted,
      indicatorColor: p.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: p.line,
      labelStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w700, fontSize: 13.5),
      unselectedLabelStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w500, fontSize: 13.5),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : p.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : p.surfaceAlt),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : p.line),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : Colors.transparent),
      side: BorderSide(color: p.muted.withOpacity(0.6), width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: p.dark ? const Color(0xFF2A3247) : const Color(0xFF1B2033), borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontFamily: kFont, color: Colors.white, fontSize: 12),
      waitDuration: const Duration(milliseconds: 400),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(6),
      radius: const Radius.circular(6),
      thumbColor: WidgetStateProperty.all(p.muted.withOpacity(0.35)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.muted,
      textColor: p.text,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary, linearTrackColor: p.surfaceAlt),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.dark ? const Color(0xFF2A3247) : const Color(0xFF1B2033),
      contentTextStyle: const TextStyle(fontFamily: kFont, color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    // Halaman yang dibuka di atas (detail dokumen, layar penuh): geser + pudar.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.windows: SlideFadePageTransitionsBuilder(),
      TargetPlatform.macOS: SlideFadePageTransitionsBuilder(),
      TargetPlatform.linux: SlideFadePageTransitionsBuilder(),
    }),
  );
}

/// Transisi halaman: masuk dari kanan sedikit sambil memudar; halaman di
/// belakangnya bergeser sedikit ke kiri (efek bertumpuk).
class SlideFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const SlideFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutQuart, reverseCurve: Curves.easeInCubic);
    final behind = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
    return SlideTransition(
      position: Tween(begin: Offset.zero, end: const Offset(-0.04, 0)).animate(behind),
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
