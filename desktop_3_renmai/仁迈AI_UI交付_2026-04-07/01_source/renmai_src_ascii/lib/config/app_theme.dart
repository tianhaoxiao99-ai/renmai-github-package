import 'package:flutter/material.dart';

enum AppThemePreset {
  warmApricot,
  mutedRose,
  sakuraMist,
  macaronMint,
}

extension AppThemePresetX on AppThemePreset {
  String get storageValue {
    switch (this) {
      case AppThemePreset.warmApricot:
        return 'warm_apricot';
      case AppThemePreset.mutedRose:
        return 'muted_rose';
      case AppThemePreset.sakuraMist:
        return 'sakura_mist';
      case AppThemePreset.macaronMint:
        return 'macaron_mint';
    }
  }

  static AppThemePreset fromStorage(String? value) {
    switch (value) {
      case 'muted_rose':
        return AppThemePreset.mutedRose;
      case 'sakura_mist':
        return AppThemePreset.sakuraMist;
      case 'macaron_mint':
        return AppThemePreset.macaronMint;
      case 'warm_apricot':
      default:
        return AppThemePreset.warmApricot;
    }
  }
}

@immutable
class AppThemePalette {
  final AppThemePreset preset;
  final String label;
  final String subtitle;
  final Color primary;
  final Color primaryDeep;
  final Color accent;
  final Color sun;
  final Color lightBackground;
  final Color lightSurface;
  final Color lightSurfaceSoft;
  final Color lightStroke;
  final Color lightStrokeStrong;
  final Color lightTextPrimary;
  final Color lightTextSecondary;
  final Color lightTextMuted;
  final Color darkBackground;
  final Color darkSurface;
  final Color darkSurfaceSoft;
  final Color darkStroke;
  final Color darkTextPrimary;
  final Color darkTextSecondary;
  final Color darkTextMuted;
  final List<Color> lightPageGradient;
  final List<Color> darkPageGradient;
  final List<Color> previewColors;

  const AppThemePalette({
    required this.preset,
    required this.label,
    required this.subtitle,
    required this.primary,
    required this.primaryDeep,
    required this.accent,
    required this.sun,
    required this.lightBackground,
    required this.lightSurface,
    required this.lightSurfaceSoft,
    required this.lightStroke,
    required this.lightStrokeStrong,
    required this.lightTextPrimary,
    required this.lightTextSecondary,
    required this.lightTextMuted,
    required this.darkBackground,
    required this.darkSurface,
    required this.darkSurfaceSoft,
    required this.darkStroke,
    required this.darkTextPrimary,
    required this.darkTextSecondary,
    required this.darkTextMuted,
    required this.lightPageGradient,
    required this.darkPageGradient,
    required this.previewColors,
  });
}

class AppTheme {
  AppTheme._();

  static AppThemePreset _activePreset = AppThemePreset.warmApricot;

  static const List<AppThemePalette> palettes = [
    AppThemePalette(
      preset: AppThemePreset.warmApricot,
      label: '暖杏',
      subtitle: '克制暖纸面，像安静的家居灯光。',
      primary: Color(0xFFCB6D4B),
      primaryDeep: Color(0xFFA64F33),
      accent: Color(0xFF2F8C7A),
      sun: Color(0xFFD8A53B),
      lightBackground: Color(0xFFF7F0E7),
      lightSurface: Color(0xFFFFFDF9),
      lightSurfaceSoft: Color(0xFFFFF7EE),
      lightStroke: Color(0xFFE6D6C6),
      lightStrokeStrong: Color(0xFFD6BEA7),
      lightTextPrimary: Color(0xFF2C2117),
      lightTextSecondary: Color(0xFF6D5848),
      lightTextMuted: Color(0xFFA08976),
      darkBackground: Color(0xFF171210),
      darkSurface: Color(0xFF221B18),
      darkSurfaceSoft: Color(0xFF2C2320),
      darkStroke: Color(0xFF4E3F39),
      darkTextPrimary: Color(0xFFF6EEE7),
      darkTextSecondary: Color(0xFFD0C0B2),
      darkTextMuted: Color(0xFF9B877A),
      lightPageGradient: [
        Color(0xFFFBF5EC),
        Color(0xFFF7F0E7),
        Color(0xFFF4ECE2),
      ],
      darkPageGradient: [
        Color(0xFF181311),
        Color(0xFF1F1815),
        Color(0xFF171210),
      ],
      previewColors: [
        Color(0xFFCB6D4B),
        Color(0xFFD8A53B),
        Color(0xFF2F8C7A),
      ],
    ),
    AppThemePalette(
      preset: AppThemePreset.mutedRose,
      label: '淡红',
      subtitle: '柔和淡红与灰绿，轻一点也更耐看。',
      primary: Color(0xFFC96A72),
      primaryDeep: Color(0xFFA9535A),
      accent: Color(0xFF729B92),
      sun: Color(0xFFE8B39B),
      lightBackground: Color(0xFFFBF1F0),
      lightSurface: Color(0xFFFFFCFB),
      lightSurfaceSoft: Color(0xFFFFF3F2),
      lightStroke: Color(0xFFE8D7D5),
      lightStrokeStrong: Color(0xFFDAB8B4),
      lightTextPrimary: Color(0xFF342322),
      lightTextSecondary: Color(0xFF755958),
      lightTextMuted: Color(0xFFA08684),
      darkBackground: Color(0xFF181213),
      darkSurface: Color(0xFF251B1C),
      darkSurfaceSoft: Color(0xFF302224),
      darkStroke: Color(0xFF584345),
      darkTextPrimary: Color(0xFFF7EDEC),
      darkTextSecondary: Color(0xFFD7C1C0),
      darkTextMuted: Color(0xFFA89392),
      lightPageGradient: [
        Color(0xFFFFF7F6),
        Color(0xFFFBF1F0),
        Color(0xFFF7ECE9),
      ],
      darkPageGradient: [
        Color(0xFF191314),
        Color(0xFF22191A),
        Color(0xFF181213),
      ],
      previewColors: [
        Color(0xFFC96A72),
        Color(0xFFE8B39B),
        Color(0xFF729B92),
      ],
    ),
    AppThemePalette(
      preset: AppThemePreset.sakuraMist,
      label: '樱粉',
      subtitle: '粉雾和奶霜感更强，但信息层级仍然克制。',
      primary: Color(0xFFD98CAB),
      primaryDeep: Color(0xFFB96F8D),
      accent: Color(0xFF7EA6A0),
      sun: Color(0xFFF0C7D4),
      lightBackground: Color(0xFFFDF4F8),
      lightSurface: Color(0xFFFFFBFD),
      lightSurfaceSoft: Color(0xFFFFF1F7),
      lightStroke: Color(0xFFE8D6DF),
      lightStrokeStrong: Color(0xFFD9B8C8),
      lightTextPrimary: Color(0xFF34242B),
      lightTextSecondary: Color(0xFF745862),
      lightTextMuted: Color(0xFF9E8890),
      darkBackground: Color(0xFF191218),
      darkSurface: Color(0xFF261C23),
      darkSurfaceSoft: Color(0xFF32242C),
      darkStroke: Color(0xFF584450),
      darkTextPrimary: Color(0xFFF8EEF3),
      darkTextSecondary: Color(0xFFD6C2CB),
      darkTextMuted: Color(0xFFA7929D),
      lightPageGradient: [
        Color(0xFFFFF8FB),
        Color(0xFFFDF4F8),
        Color(0xFFF8EBF1),
      ],
      darkPageGradient: [
        Color(0xFF1A1319),
        Color(0xFF231922),
        Color(0xFF181117),
      ],
      previewColors: [
        Color(0xFFD98CAB),
        Color(0xFFF0C7D4),
        Color(0xFF7EA6A0),
      ],
    ),
    AppThemePalette(
      preset: AppThemePreset.macaronMint,
      label: '马卡龙',
      subtitle: '奶油粉、薄荷绿、黄油光，更轻松也不腻。',
      primary: Color(0xFF7EB6A5),
      primaryDeep: Color(0xFF5B9887),
      accent: Color(0xFFE79CB2),
      sun: Color(0xFFF0D38C),
      lightBackground: Color(0xFFF6F6F1),
      lightSurface: Color(0xFFFFFDFB),
      lightSurfaceSoft: Color(0xFFF7FBF7),
      lightStroke: Color(0xFFDDE4DE),
      lightStrokeStrong: Color(0xFFBCCABE),
      lightTextPrimary: Color(0xFF24302D),
      lightTextSecondary: Color(0xFF566C66),
      lightTextMuted: Color(0xFF82938D),
      darkBackground: Color(0xFF111715),
      darkSurface: Color(0xFF1A2421),
      darkSurfaceSoft: Color(0xFF22302C),
      darkStroke: Color(0xFF42514B),
      darkTextPrimary: Color(0xFFEEF5F2),
      darkTextSecondary: Color(0xFFC1D2CB),
      darkTextMuted: Color(0xFF8FA49D),
      lightPageGradient: [
        Color(0xFFFFFDF9),
        Color(0xFFF6F6F1),
        Color(0xFFEFF6F2),
      ],
      darkPageGradient: [
        Color(0xFF101715),
        Color(0xFF16211E),
        Color(0xFF0F1513),
      ],
      previewColors: [
        Color(0xFF7EB6A5),
        Color(0xFFE79CB2),
        Color(0xFFF0D38C),
      ],
    ),
  ];

  static const List<String> fontFallback = [
    'MiSans',
    'HarmonyOS Sans SC',
    'PingFang SC',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'Segoe UI',
  ];

  static AppThemePreset get activePreset => _activePreset;

  static void setActivePreset(AppThemePreset preset) {
    _activePreset = preset;
  }

  static AppThemePalette paletteFor(AppThemePreset preset) {
    return palettes.firstWhere((palette) => palette.preset == preset);
  }

  static AppThemePalette get activePalette => paletteFor(_activePreset);

  static Color get primary => activePalette.primary;
  static Color get primaryDeep => activePalette.primaryDeep;
  static Color get accent => activePalette.accent;
  static Color get sun => activePalette.sun;
  static Color get lightBackground => activePalette.lightBackground;
  static Color get lightSurface => activePalette.lightSurface;
  static Color get lightSurfaceSoft => activePalette.lightSurfaceSoft;
  static Color get lightStroke => activePalette.lightStroke;
  static Color get lightStrokeStrong => activePalette.lightStrokeStrong;
  static Color get lightTextPrimary => activePalette.lightTextPrimary;
  static Color get lightTextSecondary => activePalette.lightTextSecondary;
  static Color get lightTextMuted => activePalette.lightTextMuted;
  static Color get darkBackground => activePalette.darkBackground;
  static Color get darkSurface => activePalette.darkSurface;
  static Color get darkSurfaceSoft => activePalette.darkSurfaceSoft;
  static Color get darkStroke => activePalette.darkStroke;
  static Color get darkTextPrimary => activePalette.darkTextPrimary;
  static Color get darkTextSecondary => activePalette.darkTextSecondary;
  static Color get darkTextMuted => activePalette.darkTextMuted;
  static List<Color> get lightPageGradient => activePalette.lightPageGradient;
  static List<Color> get darkPageGradient => activePalette.darkPageGradient;

  static TextStyle _style({
    required double size,
    required FontWeight weight,
    required Color color,
    double height = 1.25,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFamilyFallback: fontFallback,
    );
  }

  static TextTheme _textTheme({
    required Color primaryText,
    required Color secondaryText,
    required Color mutedText,
    required Color accentColor,
  }) {
    return TextTheme(
      displaySmall: _style(
        size: 38,
        weight: FontWeight.w800,
        color: primaryText,
        height: 1.02,
        letterSpacing: 0,
      ),
      headlineLarge: _style(
        size: 32,
        weight: FontWeight.w800,
        color: primaryText,
        height: 1.06,
        letterSpacing: 0,
      ),
      headlineMedium: _style(
        size: 28,
        weight: FontWeight.w800,
        color: primaryText,
        height: 1.08,
        letterSpacing: 0,
      ),
      headlineSmall: _style(
        size: 24,
        weight: FontWeight.w700,
        color: primaryText,
        height: 1.1,
        letterSpacing: 0,
      ),
      titleLarge: _style(
        size: 19,
        weight: FontWeight.w700,
        color: primaryText,
        height: 1.2,
        letterSpacing: 0,
      ),
      titleMedium: _style(
        size: 16,
        weight: FontWeight.w700,
        color: primaryText,
        height: 1.25,
        letterSpacing: 0,
      ),
      titleSmall: _style(
        size: 13,
        weight: FontWeight.w600,
        color: primaryText,
        height: 1.3,
        letterSpacing: 0,
      ),
      bodyLarge: _style(
        size: 16,
        weight: FontWeight.w400,
        color: secondaryText,
        height: 1.65,
      ),
      bodyMedium: _style(
        size: 14,
        weight: FontWeight.w400,
        color: secondaryText,
        height: 1.58,
      ),
      bodySmall: _style(
        size: 12,
        weight: FontWeight.w400,
        color: mutedText,
        height: 1.5,
      ),
      labelLarge: _style(
        size: 13,
        weight: FontWeight.w700,
        color: accentColor,
        height: 1.2,
        letterSpacing: 0.2,
      ),
      labelMedium: _style(
        size: 12,
        weight: FontWeight.w600,
        color: mutedText,
        height: 1.2,
        letterSpacing: 0.1,
      ),
      labelSmall: _style(
        size: 11,
        weight: FontWeight.w600,
        color: mutedText,
        height: 1.2,
        letterSpacing: 0.1,
      ),
    );
  }

  static ThemeData lightTheme({
    required AppThemePreset preset,
    bool highContrast = false,
  }) {
    final palette = paletteFor(preset);
    final primaryText = highContrast
        ? _blend(palette.lightTextPrimary, Colors.black, 0.18)
        : palette.lightTextPrimary;
    final secondaryText = highContrast
        ? _blend(palette.lightTextSecondary, palette.lightTextPrimary, 0.16)
        : palette.lightTextSecondary;
    final mutedText = highContrast
        ? _blend(palette.lightTextMuted, palette.lightTextSecondary, 0.16)
        : palette.lightTextMuted;
    final stroke = highContrast
        ? _blend(palette.lightStroke, palette.primaryDeep, 0.24)
        : palette.lightStroke;
    final strokeStrong = highContrast
        ? _blend(palette.lightStrokeStrong, palette.primaryDeep, 0.28)
        : palette.lightStrokeStrong;
    final indicator = highContrast
        ? _blend(palette.lightSurfaceSoft, palette.primary, 0.18)
        : _blend(palette.lightSurfaceSoft, palette.primary, 0.08);
    final textTheme = _textTheme(
      primaryText: primaryText,
      secondaryText: secondaryText,
      mutedText: mutedText,
      accentColor: palette.primary,
    );
    final colorScheme = ColorScheme.light(
      primary: palette.primary,
      onPrimary: Colors.white,
      secondary: palette.accent,
      onSecondary: Colors.white,
      tertiary: palette.sun,
      onTertiary: primaryText,
      surface: palette.lightSurface,
      onSurface: primaryText,
      error: const Color(0xFFC35353),
      onError: Colors.white,
    ).copyWith(
      outline: strokeStrong,
      outlineVariant: stroke,
      shadow: const Color(0x14000000),
      surfaceTint: palette.primary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.lightBackground,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: stroke,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: primaryText,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: palette.lightSurface.withValues(alpha: 0.992),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: stroke.withValues(alpha: 0.82)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.lightSurface.withValues(alpha: 0.99),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: stroke.withValues(alpha: 0.86)),
        ),
      ),
      iconTheme: IconThemeData(color: secondaryText, size: 20),
      chipTheme: ChipThemeData(
        backgroundColor: highContrast
            ? palette.lightSurfaceSoft.withValues(alpha: 0.98)
            : palette.lightSurface.withValues(alpha: 0.92),
        selectedColor: _blend(palette.lightSurfaceSoft, palette.primary, 0.12),
        side: BorderSide(color: strokeStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: textTheme.titleSmall?.copyWith(color: primaryText),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: textTheme.titleSmall,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: textTheme.titleSmall,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryText,
          side: BorderSide(
            color: strokeStrong.withValues(alpha: 0.92),
            width: 1.1,
          ),
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: textTheme.titleSmall,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: textTheme.titleSmall,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: highContrast
            ? palette.lightSurface.withValues(alpha: 0.98)
            : palette.lightSurfaceSoft,
        hintStyle: textTheme.bodyMedium?.copyWith(color: mutedText),
        labelStyle: textTheme.bodySmall,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
        prefixIconColor: mutedText,
        suffixIconColor: mutedText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: stroke.withValues(alpha: 0.9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: stroke.withValues(alpha: 0.9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: highContrast ? palette.primaryDeep : strokeStrong,
            width: highContrast ? 1.6 : 1,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFC35353)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFC35353)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.lightSurface.withValues(alpha: 0.98),
        indicatorColor: indicator,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelMedium?.copyWith(color: primaryText);
          }
          return textTheme.labelMedium?.copyWith(color: secondaryText);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: indicator,
        selectedIconTheme: IconThemeData(color: primaryText),
        unselectedIconTheme: IconThemeData(color: secondaryText),
        selectedLabelTextStyle:
            textTheme.labelMedium?.copyWith(color: primaryText),
        unselectedLabelTextStyle:
            textTheme.labelMedium?.copyWith(color: secondaryText),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(999),
        thickness: WidgetStateProperty.all(9),
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(false),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return palette.primary.withValues(alpha: 0.7);
          }
          if (states.contains(WidgetState.hovered)) {
            return palette.primary.withValues(alpha: 0.56);
          }
          return palette.primary.withValues(alpha: 0.34);
        }),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: primaryText,
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
    );
  }

  static ThemeData darkTheme({
    required AppThemePreset preset,
    bool highContrast = false,
  }) {
    final palette = paletteFor(preset);
    final primaryText = palette.darkTextPrimary;
    final secondaryText = highContrast
        ? _blend(palette.darkTextSecondary, Colors.white, 0.14)
        : palette.darkTextSecondary;
    final mutedText = highContrast
        ? _blend(palette.darkTextMuted, palette.darkTextSecondary, 0.14)
        : palette.darkTextMuted;
    final stroke = highContrast
        ? _blend(palette.darkStroke, palette.sun, 0.16)
        : palette.darkStroke;
    final indicator = highContrast
        ? _blend(palette.darkSurfaceSoft, palette.primary, 0.28)
        : _blend(palette.darkSurfaceSoft, palette.primary, 0.18);
    final textTheme = _textTheme(
      primaryText: primaryText,
      secondaryText: secondaryText,
      mutedText: mutedText,
      accentColor: Colors.white,
    );
    final colorScheme = ColorScheme.dark(
      primary: palette.primary,
      onPrimary: Colors.white,
      secondary: palette.accent,
      onSecondary: Colors.white,
      tertiary: palette.sun,
      onTertiary: primaryText,
      surface: palette.darkSurface,
      onSurface: primaryText,
      error: const Color(0xFFF08A72),
      onError: Colors.black,
    ).copyWith(
      outline: stroke,
      outlineVariant: stroke.withValues(alpha: 0.92),
      shadow: const Color(0x42000000),
      surfaceTint: palette.primary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.darkBackground,
      textTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: stroke,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: primaryText,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: palette.darkSurface.withValues(alpha: 0.96),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: stroke),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.darkSurface.withValues(alpha: 0.98),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: stroke.withValues(alpha: 0.94)),
        ),
      ),
      iconTheme: IconThemeData(color: secondaryText, size: 20),
      chipTheme: ChipThemeData(
        backgroundColor:
            highContrast ? palette.darkSurface : palette.darkSurfaceSoft,
        selectedColor: _blend(palette.darkSurfaceSoft, palette.primary, 0.18),
        side: BorderSide(color: stroke),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: textTheme.titleSmall?.copyWith(color: primaryText),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: textTheme.titleSmall,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: textTheme.titleSmall,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryText,
          side: BorderSide(color: stroke, width: 1.1),
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: textTheme.titleSmall,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: textTheme.titleSmall,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.darkSurface,
        hintStyle: textTheme.bodyMedium?.copyWith(color: mutedText),
        labelStyle: textTheme.bodySmall,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
        prefixIconColor: mutedText,
        suffixIconColor: mutedText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: highContrast
                ? palette.primary
                : _blend(palette.darkStroke, palette.primary, 0.22),
            width: highContrast ? 1.6 : 1,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.darkSurface.withValues(alpha: 0.98),
        indicatorColor: indicator,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelMedium?.copyWith(color: primaryText);
          }
          return textTheme.labelMedium?.copyWith(color: secondaryText);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: indicator,
        selectedIconTheme: IconThemeData(color: primaryText),
        unselectedIconTheme: IconThemeData(color: secondaryText),
        selectedLabelTextStyle:
            textTheme.labelMedium?.copyWith(color: primaryText),
        unselectedLabelTextStyle:
            textTheme.labelMedium?.copyWith(color: secondaryText),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(999),
        thickness: WidgetStateProperty.all(9),
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(false),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return palette.primary.withValues(alpha: 0.82);
          }
          if (states.contains(WidgetState.hovered)) {
            return palette.primary.withValues(alpha: 0.68);
          }
          return palette.primary.withValues(alpha: 0.42);
        }),
      ),
    );
  }

  static Color _blend(Color source, Color target, double amount) {
    return Color.lerp(source, target, amount)!;
  }
}
