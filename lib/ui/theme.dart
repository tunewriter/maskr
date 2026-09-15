import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xFF062726);
  static const surface = Color(0xFF102B3F);
  static const primary = Color(0xFFA06CD5);
  static const primary45 = Color(0x73A06CD5);
  static const primaryGlow = Color(0x4DA06CD5);
  static const secondary = Color(0xFF6247AA);
  static const text = Color(0xFFE2CFEA);
  static const muted = Color(0x99E2CFEA);
  static const outline = Color(0x29E2CFEA);
  static const success = Color(0xFF7FD1C0);
  static const selection = Color(0x4D9A6FB0);
  static const scrollThumb = Color(0x4DE2CFEA);
  static const scrollHover = Color(0x80E2CFEA);

  static const rulePalette = <Color>[
    Color(0xFFA06CD5),
    Color(0xFFE85D75),
    Color(0xFF4EC9A8),
    Color(0xFFF2A65A),
    Color(0xFF9368E0),
    Color(0xFF3FB7B7),
    Color(0xFFF06292),
    Color(0xFF5C6BC0),
    Color(0xFFFFB74D),
    Color(0xFF4DD0E1),
  ];
}

abstract final class AppTextStyles {
  static TextStyle mono(double size, {Color color = AppColors.text}) =>
      TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: size,
          height: 1.5,
          color: color);

  static TextStyle ui(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text,
    double? height,
  }) =>
      TextStyle(
          fontFamily: 'Outfit',
          fontSize: size,
          color: color,
          fontWeight: weight);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: AppColors.text,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: Color(0xFFE57373),
      onError: Colors.white,
    ),
  );

  return base.copyWith(
    textSelectionTheme: const TextSelectionThemeData(
      selectionColor: AppColors.selection,
      selectionHandleColor: AppColors.primary,
      cursorColor: AppColors.primary,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered)
            ? AppColors.scrollHover
            : AppColors.scrollThumb,
      ),
      trackColor: const WidgetStatePropertyAll(Colors.transparent),
      thickness: const WidgetStatePropertyAll(8),
      radius: const Radius.circular(4),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: AppColors.text, fontSize: 12),
      waitDuration: const Duration(milliseconds: 400),
    ),
  );
}
