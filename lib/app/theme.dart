import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const background = Color(0xFFF9F7F2);
  static const ink = Color(0xFF343850);
  static const subText = Color(0xFF6E7080);
  static const hint = Color(0xFF9A9BA4);
  static const accent = Color(0xFFBE5A4E);
  static const border = Color(0xFFE9E4DA);
  static const field = Color(0xFFF7F4EC);
  static const ring = Color(0xFFFBF4E3);
  static const pink = Color(0xFFF7E6DF);
  static const lavender = Color(0xFFE8E3F3);
  static const mint = Color(0xFFE2EBE2);
  static const yellow = Color(0xFFF5E8B5);
  static const blue = Color(0xFFE3ECF3);
}

/// 「Welcome back!」や「new!」などに使う筆記体風の書体。
TextStyle serifItalic({double size = 14, Color color = AppColors.accent}) =>
    GoogleFonts.lora(
      fontSize: size,
      color: color,
      fontStyle: FontStyle.italic,
    );

/// 「HANA SATO」や件数などに使う明朝風の書体。
TextStyle serif({double size = 14, Color color = AppColors.ink}) =>
    GoogleFonts.lora(fontSize: size, color: color);

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      surface: AppColors.background,
    ),
    scaffoldBackgroundColor: AppColors.background,
  );
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.field,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.accent),
    ),
  );
}
