import 'package:flutter/material.dart';

class AppColors {
  // Brand Identity Palette
  static const Color pink = Color(0xFFFF4DA6); // Passion — aksen, ikon hati, indikator
  static const Color purple = Color(0xFF7B3FE4); // Kreativitas
  static const Color yellow = Color(0xFFFFC629); // Optimisme
  static const Color darkGrey = Color(0xFF2E2E2E); // Profesional

  /// Pink lebih pekat untuk tombol & teks tautan: kontras dengan putih 4,8:1 (WCAG AA),
  /// sedangkan pink brand hanya 3:1 sehingga dipakai untuk aksen saja.
  static const Color pinkDeep = Color(0xFFD81B7A);
  static const Color success = Color(0xFF1E8E5A);
  static const Color warning = Color(0xFFB86E00);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [pink, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [pink, purple],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Latar lembut untuk kartu sorotan (beranda, info cara sewa).
  static const LinearGradient softGradient = LinearGradient(
    colors: [Color(0xFFFFE3F1), Color(0xFFEDE3FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Light Theme Colors
  static const Color lightBg = Color(0xFFFAF8FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightInputFill = Color(0xFFF3EFF8);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightOutline = Color(0xFFE8E2EF);

  // Dark Theme Colors
  static const Color darkBg = Color(0xFF14121C);
  static const Color darkSurface = Color(0xFF211D2E);
  static const Color darkInputFill = Color(0xFF2B263B);
  static const Color darkCard = Color(0xFF1C1927);
  static const Color darkOutline = Color(0xFF332D44);
}

/// Jarak & radius yang dipakai bersama agar semua layar terasa satu keluarga.
class AppSpacing {
  static const double page = 16;
  static const double section = 28;
  static const double radius = 16;
  static const double radiusSmall = 12;
}

class AppThemeData {
  static ThemeData lightTheme() => _build(Brightness.light);
  static ThemeData darkTheme() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? AppColors.darkBg : AppColors.lightBg;
    final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final card = dark ? AppColors.darkCard : AppColors.lightCard;
    final outline = dark ? AppColors.darkOutline : AppColors.lightOutline;
    final text = dark ? Colors.white : AppColors.darkGrey;
    final fill = dark ? AppColors.darkInputFill : AppColors.lightInputFill;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.pink,
      brightness: brightness,
      // Terang: pink pekat agar teks tautan & tombol terbaca. Gelap: pink terang di atas latar gelap.
      primary: dark ? const Color(0xFFFF7DBB) : AppColors.pinkDeep,
      onPrimary: dark ? const Color(0xFF3B0021) : Colors.white,
      secondary: AppColors.purple,
      tertiary: AppColors.yellow,
      surface: surface,
      onSurface: text,
      outlineVariant: outline,
    );

    final base = dark ? ThemeData.dark() : ThemeData.light();
    final textTheme = base.textTheme
        .apply(fontFamily: 'Poppins', bodyColor: text, displayColor: text)
        .copyWith(
          titleLarge: base.textTheme.titleLarge?.copyWith(
              fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: text, fontSize: 20),
          titleMedium: base.textTheme.titleMedium?.copyWith(
              fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: text),
          titleSmall: base.textTheme.titleSmall?.copyWith(
              fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: text),
        );

    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    const buttonText = TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600);
    final filledStyle = FilledButton.styleFrom(
      backgroundColor: AppColors.pinkDeep,
      foregroundColor: Colors.white,
      disabledBackgroundColor: text.withValues(alpha: 0.12),
      disabledForegroundColor: text.withValues(alpha: 0.45),
      minimumSize: const Size(48, 50),
      shape: buttonShape,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      textStyle: buttonText,
      elevation: 0,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: 'Poppins', color: text, fontSize: 19, fontWeight: FontWeight.w700),
        iconTheme: IconThemeData(color: text),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          side: BorderSide(color: outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: filledStyle),
      // Banyak layar lama memakai ElevatedButton: gayanya disamakan dengan FilledButton.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pinkDeep,
          foregroundColor: Colors.white,
          disabledBackgroundColor: text.withValues(alpha: 0.12),
          disabledForegroundColor: text.withValues(alpha: 0.45),
          elevation: 0,
          minimumSize: const Size(48, 50),
          shape: buttonShape,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 48),
          shape: buttonShape,
          side: BorderSide(color: outline, width: 1.2),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 44),
          textStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSmall)),
        side: BorderSide(color: outline),
        backgroundColor: surface,
        selectedColor: scheme.primary.withValues(alpha: dark ? 0.28 : 0.12),
        checkmarkColor: scheme.primary,
        labelStyle: TextStyle(fontFamily: 'Poppins', color: text, fontSize: 13, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.pink.withValues(alpha: dark ? 0.25 : 0.16),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: dark ? const Color(0xFFFF7DBB) : AppColors.pinkDeep);
          }
          return IconThemeData(color: text.withValues(alpha: 0.55));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? text : text.withValues(alpha: 0.6),
            )),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        indicatorColor: scheme.primary,
        unselectedLabelColor: text.withValues(alpha: 0.6),
        labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        dividerColor: outline,
      ),
    );
  }
}
