import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';

// ─── Dark palette (GitHub-style neutral) ──────────────────────────────────────
class DarkColors {
  static const bg = Color(0xFF0D1117);
  static const surface = Color(0xFF161B22);
  static const surfaceElevated = Color(0xFF1C2128);
  static const surfaceHighlight = Color(0xFF22272E);
  static const border = Color(0xFF30363D);
  static const borderBright = Color(0xFF484F58);
  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const textMuted = Color(0xFF484F58);
  static const accent = Color(0xFF58A6FF);
  static const accentGlow = Color(0x3358A6FF);
  static const income = Color(0xFF3FB950);
  static const expense = Color(0xFFF85149);
  static const borrowed = Color(0xFFD29922);
  static const lend = Color(0xFF58A6FF);
}

// ─── Light palette ─────────────────────────────────────────────────────────────
class LightColors {
  static const bg = Color(0xFFF6F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFF0F2F5);
  static const surfaceHighlight = Color(0xFFE8ECF0);
  static const border = Color(0xFFD0D7DE);
  static const borderBright = Color(0xFFB0B8C1);
  static const textPrimary = Color(0xFF1F2328);
  static const textSecondary = Color(0xFF636C76);
  static const textMuted = Color(0xFFB0B8C1);
  static const accent = Color(0xFF0969DA);
  static const accentGlow = Color(0x330969DA);
  static const income = Color(0xFF1A7F37);
  static const expense = Color(0xFFCF222E);
  static const borrowed = Color(0xFF9A6700);
  static const lend = Color(0xFF0969DA);
}

// ─── Category colors ───────────────────────────────────────────────────────────
class CategoryColors {
  static const food = Color(0xFFFF5252);
  static const travel = Color(0xFF9E9E9E);
  static const essentials = Color(0xFF66BB6A);
  static const work = Color(0xFFFFCA28);
  static const misc = Color(0xFFAB47BC);
  static const shop = Color(0xFFFF7043);
  static const home = Color(0xFF26C6DA);
  static const health = Color(0xFFEC407A);
  static const salary = Color(0xFF42A5F5);
  static const cashback = Color(0xFF66BB6A);
  static const gifts = Color(0xFFEF5350);
  static const otherIncome = Color(0xFFFFCA28);
  static const borrowed = Color(0xFFFFB300);
  static const lend = Color(0xFF29B6F6);
}

class CategoryInfo {
  final String label;
  final IconData icon;
  final Color color;
  const CategoryInfo(
      {required this.label, required this.icon, required this.color});
}

const Map<TransactionCategory, CategoryInfo> categoryInfoMap = {
  TransactionCategory.food: CategoryInfo(
      label: 'Food',
      icon: Icons.restaurant_rounded,
      color: CategoryColors.food),
  TransactionCategory.travel: CategoryInfo(
      label: 'Travel',
      icon: Icons.flight_rounded,
      color: CategoryColors.travel),
  TransactionCategory.essentials: CategoryInfo(
      label: 'Essentials',
      icon: Icons.shopping_bag_rounded,
      color: CategoryColors.essentials),
  TransactionCategory.work: CategoryInfo(
      label: 'Work',
      icon: Icons.work_rounded,
      color: CategoryColors.work),
  TransactionCategory.misc: CategoryInfo(
      label: 'Misc',
      icon: Icons.category_rounded,
      color: CategoryColors.misc),
  TransactionCategory.shop: CategoryInfo(
      label: 'Shopping',
      icon: Icons.storefront_rounded,
      color: CategoryColors.shop),
  TransactionCategory.home: CategoryInfo(
      label: 'Home',
      icon: Icons.home_rounded,
      color: CategoryColors.home),
  TransactionCategory.health: CategoryInfo(
      label: 'Health',
      icon: Icons.favorite_rounded,
      color: CategoryColors.health),
  TransactionCategory.salary: CategoryInfo(
      label: 'Salary',
      icon: Icons.account_balance_wallet_rounded,
      color: CategoryColors.salary),
  TransactionCategory.cashback: CategoryInfo(
      label: 'Cashback',
      icon: Icons.currency_exchange_rounded,
      color: CategoryColors.cashback),
  TransactionCategory.gifts: CategoryInfo(
      label: 'Gifts',
      icon: Icons.card_giftcard_rounded,
      color: CategoryColors.gifts),
  TransactionCategory.otherIncome: CategoryInfo(
      label: 'Others',
      icon: Icons.add_circle_outline_rounded,
      color: CategoryColors.otherIncome),
  TransactionCategory.borrowed: CategoryInfo(
      label: 'Borrowed',
      icon: Icons.handshake_rounded,
      color: CategoryColors.borrowed),
  TransactionCategory.lend: CategoryInfo(
      label: 'Lend',
      icon: Icons.send_rounded,
      color: CategoryColors.lend),
};

// ─── Theme builder ─────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? DarkColors.bg : LightColors.bg;
    final surface = isDark ? DarkColors.surface : LightColors.surface;
    final surfaceElevated =
        isDark ? DarkColors.surfaceElevated : LightColors.surfaceElevated;
    final border = isDark ? DarkColors.border : LightColors.border;
    final textPrimary =
        isDark ? DarkColors.textPrimary : LightColors.textPrimary;
    final textSecondary =
        isDark ? DarkColors.textSecondary : LightColors.textSecondary;
    final textMuted = isDark ? DarkColors.textMuted : LightColors.textMuted;
    final accent = isDark ? DarkColors.accent : LightColors.accent;
    final base = isDark ? ThemeData.dark() : ThemeData.light();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        error: isDark ? DarkColors.expense : LightColors.expense,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme.copyWith(
        displayLarge: TextStyle(color: textPrimary),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
      )),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.dmSans(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: bg,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accent, width: 1.5)),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }
}

// ─── Context extension ─────────────────────────────────────────────────────────
extension AppColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get appBg => isDark ? DarkColors.bg : LightColors.bg;
  Color get appSurface =>
      isDark ? DarkColors.surface : LightColors.surface;
  Color get appSurfaceElevated =>
      isDark ? DarkColors.surfaceElevated : LightColors.surfaceElevated;
  Color get appSurfaceHighlight =>
      isDark ? DarkColors.surfaceHighlight : LightColors.surfaceHighlight;
  Color get appBorder => isDark ? DarkColors.border : LightColors.border;
  Color get appTextPrimary =>
      isDark ? DarkColors.textPrimary : LightColors.textPrimary;
  Color get appTextSecondary =>
      isDark ? DarkColors.textSecondary : LightColors.textSecondary;
  Color get appTextMuted =>
      isDark ? DarkColors.textMuted : LightColors.textMuted;
  Color get appAccent => isDark ? DarkColors.accent : LightColors.accent;
  Color get appIncome => isDark ? DarkColors.income : LightColors.income;
  Color get appExpense => isDark ? DarkColors.expense : LightColors.expense;
  Color get appBorrowed =>
      isDark ? DarkColors.borrowed : LightColors.borrowed;
  Color get appLend => isDark ? DarkColors.lend : LightColors.lend;
}