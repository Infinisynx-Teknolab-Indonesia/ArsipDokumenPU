import 'package:flutter/material.dart';

/// Token desain Arsip Dokumen PU — konsep "gambar kerja PU".
///
///   Tinta  #14213D  biru tua seperti tinta gambar teknik: sidebar, tombol utama
///   Kertas #F4F6F9  latar halaman (abu kebiruan, bersih)
///   Garis  #E2E6EE  garis tipis pemisah & tepi kartu (tanpa bayangan abu-abu)
///   Biru PU #2457C5 ikon, tautan, elemen aktif di area putih
///   Marka  #F2A900  SATU aksen: kuning marka jalan — penanda menu aktif yang
///                   meluncur, garis fokus. Dipakai hemat.
///
/// Nama-nama lama (accentPurple, borderLavender, ...) sengaja dipertahankan
/// supaya semua halaman otomatis ikut tampilan baru tanpa diubah satu per satu.
class YmColors {
  // ---- palet baru
  static const ink = Color(0xFF14213D);
  static const inkSoft = Color(0xFF1E2F55);
  static const inkLine = Color(0xFF2A3B63);
  static const paper = Color(0xFFF4F6F9);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFE2E6EE);
  static const puBlue = Color(0xFF2457C5);
  static const marka = Color(0xFFF2A900);

  // ---- nama lama (dipakai di seluruh aplikasi)
  static const titleBarStart = ink;
  static const titleBarEnd = inkSoft;
  static const accentPurple = puBlue; // aksen utama di area putih
  static const accentBlue = ink;
  static const panelBackground = paper;
  static const contentBackground = surface;
  static const borderLavender = line;
  static const textDark = Color(0xFF18213A);
  static const textMuted = Color(0xFF6B7488);
  static const statusOnline = Color(0xFF1E9E6A);
  static const statusOffline = Color(0xFFB3B9C6);
  static const statusBusy = Color(0xFFD64545);
  static const statusAway = Color(0xFFDB8B00);
  static const bubbleIncoming = Color(0xFFEFF2F7);
  static const bubbleOutgoing = Color(0xFFE3EAF8);
  static const buzzRed = Color(0xFFD64545);

  // Layar login (latar tinta + ilustrasi kota/jembatan)
  static const heroGradientTop = Color(0xFF0E1830);
  static const heroGradientBottom = Color(0xFF1B2C52);
  static const cardGlass = Color(0xE6142039);
  static const fieldFillOnDark = Color(0x14FFFFFF);
}

/// Huruf: Plus Jakarta Sans (dibundel di assets/fonts).
const kFont = 'PlusJakartaSans';
const kFontFallback = ['Segoe UI', 'Arial'];

class YmTextStyles {
  static const appTitle = TextStyle(
    fontFamily: kFont,
    fontFamilyFallback: kFontFallback,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  /// Judul baris / nama (mis. judul dokumen di daftar).
  static const username = TextStyle(
    fontFamily: kFont,
    fontFamilyFallback: kFontFallback,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: YmColors.textDark,
    height: 1.3,
  );

  static const statusMessage = TextStyle(
    fontFamily: kFont,
    fontFamilyFallback: kFontFallback,
    fontSize: 11,
    fontStyle: FontStyle.italic,
    color: YmColors.textMuted,
  );

  static const buddyName = TextStyle(
    fontFamily: kFont,
    fontFamilyFallback: kFontFallback,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: YmColors.textDark,
  );

  /// Teks isi.
  static const chatText = TextStyle(
    fontFamily: kFont,
    fontFamilyFallback: kFontFallback,
    fontSize: 13,
    color: YmColors.textDark,
    height: 1.45,
  );

  /// Teks keterangan kecil.
  static const label = TextStyle(
    fontFamily: kFont,
    fontFamilyFallback: kFontFallback,
    fontSize: 11.5,
    color: YmColors.textMuted,
    height: 1.35,
  );

  /// Judul halaman (header).
  static const pageTitle = TextStyle(
    fontFamily: kFont,
    fontFamilyFallback: kFontFallback,
    fontSize: 21,
    fontWeight: FontWeight.w700,
    color: YmColors.textDark,
    letterSpacing: -0.3,
  );

  /// Judul bagian (kartu/panel).
  static const sectionTitle = TextStyle(
    fontFamily: kFont,
    fontFamilyFallback: kFontFallback,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: YmColors.textDark,
  );
}

const ymBorderRadius = 10.0;

/// Durasi animasi standar (dipendekkan jadi 0 bila pengguna mematikan animasi
/// di Windows/macOS — lihat [motion]).
const kMotionFast = Duration(milliseconds: 160);
const kMotion = Duration(milliseconds: 260);
const kMotionCurve = Curves.easeOutCubic;

Duration motion(BuildContext context, [Duration d = kMotion]) =>
    MediaQuery.maybeOf(context)?.disableAnimations == true ? Duration.zero : d;

/// Tema Material untuk seluruh aplikasi.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: YmColors.puBlue,
    primary: YmColors.puBlue,
    secondary: YmColors.marka,
    surface: YmColors.surface,
    error: YmColors.buzzRed,
  );
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: YmColors.line));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: kFont,
    fontFamilyFallback: kFontFallback,
    scaffoldBackgroundColor: YmColors.paper,
    visualDensity: VisualDensity.standard,
    dividerTheme: const DividerThemeData(color: YmColors.line, thickness: 1, space: 1),
    iconTheme: const IconThemeData(color: YmColors.textMuted),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: YmColors.line)),
      titleTextStyle: const TextStyle(fontFamily: kFont, fontSize: 17, fontWeight: FontWeight.w700, color: YmColors.textDark),
      contentTextStyle: const TextStyle(fontFamily: kFont, fontSize: 13.5, color: YmColors.textDark, height: 1.45),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: const TextStyle(color: YmColors.textMuted, fontSize: 13),
      hintStyle: const TextStyle(color: Color(0xFF9AA1B2), fontSize: 13),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: YmColors.puBlue, width: 1.6)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: YmColors.ink,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: YmColors.textDark,
        side: const BorderSide(color: YmColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: YmColors.puBlue,
        textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: YmColors.ink,
      side: const BorderSide(color: YmColors.line),
      labelStyle: const TextStyle(fontFamily: kFont, fontSize: 12.5, fontWeight: FontWeight.w600, color: YmColors.textDark),
      secondaryLabelStyle: const TextStyle(fontFamily: kFont, fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: YmColors.textDark,
      unselectedLabelColor: YmColors.textMuted,
      indicatorColor: YmColors.marka,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: YmColors.line,
      labelStyle: TextStyle(fontFamily: kFont, fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: TextStyle(fontFamily: kFont, fontWeight: FontWeight.w500, fontSize: 13),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: YmColors.ink, borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontFamily: kFont, color: Colors.white, fontSize: 12),
      waitDuration: const Duration(milliseconds: 400),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(6),
      radius: const Radius.circular(6),
      thumbColor: WidgetStateProperty.all(const Color(0x33384766)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: YmColors.textMuted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: YmColors.puBlue, linearTrackColor: YmColors.line),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: YmColors.ink,
      contentTextStyle: const TextStyle(fontFamily: kFont, color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    // Halaman yang dibuka di atas (mis. layar penuh dokumen): geser + pudar.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.windows: SlideFadePageTransitionsBuilder(),
      TargetPlatform.macOS: SlideFadePageTransitionsBuilder(),
      TargetPlatform.linux: SlideFadePageTransitionsBuilder(),
    }),
  );
}

/// Transisi halaman: masuk dari kanan sedikit sambil memudar.
class SlideFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const SlideFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: kMotionCurve, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0.03, 0), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
