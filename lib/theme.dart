import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AweColors {
  // Backgrounds (warm parchment)
  static const background = Color(0xFFF6F1E9);
  static const surface = Color(0xFFECE3D4);
  static const cardSurface = Color(0xFFFFFFFF);

  // Text
  static const textPrimary = Color(0xFF211D18);
  static const textSecondary = Color(0xFF8C8576);
  static const textOnImage = Color(0xFFFFFFFF);
  static const textOnImageMuted = Color(0xE0FFFFFF);
  static const textBody = Color(0xFF33302A);

  // Accents
  static const accentSlate = Color(0xFF1D4257);
  static const accentTerracotta = Color(0xFFC67D4A);
  static const accentGold = Color(0xFFA9761F);
  static const accentTeal = Color(0xFF2F6F8F);

  // Category Colors (badges and map pins)
  static const categoryPlace = Color(0xFF86C4E3);
  static const categoryTradition = Color(0xFFC67D4A);
  static const categoryTaste = Color(0xFFE7C98C);
  static const categoryStory = Color(0xFF7B6B8D);
  static const categorySound = Color(0xFF6F8C6A);
  static const categoryPerson = Color(0xFFB85C5C);

  // Emotion Colors
  static const emotionAwe = Color(0xFF86C4E3);
  static const emotionMystery = Color(0xFF7B6B8D);
  static const emotionSerenity = Color(0xFFE7C98C);
  static const emotionLostWorlds = Color(0xFF8A6B55);
  static const emotionSacred = Color(0xFFD4A853);
  static const emotionWild = Color(0xFFB85C5C);

  // Borders & Dividers (warm gold tones)
  static const border = Color(0xFFECE3D4);
  static const divider = Color(0xFFE7DFD0);

  // Bottom nav
  static const navActive = Color(0xFF1D4257);
  static const navInactive = Color(0xFFA89A82);
  static const navBackground = Color(0xFFF6F1E9);

  // Overlay (for text on images)
  static const imageOverlay = Color(0x99000000);
  static const imageGradientStart = Color(0x00000000);
  static const imageGradientEnd = Color(0xEB0B1A25);

  // Interactive states
  static const buttonPrimary = Color(0xFF1D4257);
  static const buttonPrimaryText = Color(0xFFFFFFFF);
  static const chipBackground = Color(0xFFF6ECD6);
  static const chipSelected = Color(0xFF1D4257);
  static const chipSelectedText = Color(0xFFFFFFFF);

  // Streak & gamification
  static const streakFlame = Color(0xFFC18B2C);
  static const streakBackground = Color(0xFFF6ECD6);

  // Did-you-know card
  static const sparkBackground = Color(0xFFE9F1F4);
  static const sparkAccent = Color(0xFF2F6F8F);

  // Error
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);

  // Legacy compat — maps old FlowColors names to new palette so existing screens compile.
  // These will be removed as screens are migrated.
  static const primaryDark = accentSlate;
  static const primaryDarkDeep = Color(0xFF1A2530);
  static const primaryDarkVariant = Color(0xFF34495E);
  static const textLight = Color(0xFFFFFFFF);
  static const textDark = textPrimary;
  static const textGrey = textSecondary;
  static const surfaceLight = background;
  static const surfaceDark = accentSlate;
  static const surfaceVariantDark = Color(0xFF34495E);
  static const softTeal = Color(0xFF4A9B9B);
  static const softTealLight = categoryPlace;
  static const warmOrange = accentTerracotta;
  static const warmCoral = Color(0xFFE8654A);
  static const paleBlue = categoryPlace;
  static const cardGradientStart = surface;
  static const cardGradientEnd = background;
  static const cardGradientStartDark = Color(0xFF34495E);
  static const cardGradientEndDark = accentSlate;
  static const featurePrimaryStartDark = accentSlate;
  static const featurePrimaryEndDark = Color(0xFF34495E);
  static const featureTealStartDark = Color(0xFF1A3A3A);
  static const featureTealEndDark = Color(0xFF2A4A4A);
  static const featureCoralStartDark = Color(0xFF3A2A2A);
  static const featureCoralEndDark = Color(0xFF4A3A3A);
  static const chipBgDark = surface;
  static const chipBorderDark = border;
  static const chipSelectedDark = accentSlate;
  static const cardSurfaceDark = cardSurface;
  static const cardBorderDark = border;
  static const accentGreen = categorySound;
  static const accentAmber = accentGold;
  static const accentOrange = accentTerracotta;
  static const accentBrown = Color(0xFF8A6B55);
  static const ctaGlowOuter = Color(0x22000000);
  static const ctaGlowInner = Color(0x11000000);
  static const vibrantViolet = Color(0xFF7C4DFF);
  static const statVioletStart = Color(0xFF6C63FF);
  static const statVioletEnd = Color(0xFF8E7CFF);
  static const statCyanStart = categoryPlace;
  static const statCyanEnd = Color(0xFF0072FF);
  static const statGreenStart = categorySound;
  static const statGreenEnd = Color(0xFF3BB2B8);
  static const cardGlowTop = Color(0x11000000);
  static const cardGlowBottom = Color(0x08000000);
  static const ticketPaperCream = surface;
  static const ticketPaperKraft = Color(0xFFE7D3B5);
  static const ticketPaperMint = Color(0xFFE6F2EA);
  static const ticketPaperPowder = Color(0xFFE8F0F7);
  static const ticketPaperRose = Color(0xFFF4E3E3);
  static const ticketPaperGrey = Color(0xFFEBE6DD);
  static const ticketInkDark = textPrimary;
  static const promoTextPaleBlue = textSecondary;
}

@Deprecated('Use AweColors instead')
typedef FlowColors = AweColors;

class FontSizes {
  static const double displayLarge = 48.0;
  static const double displayMedium = 36.0;
  static const double displaySmall = 30.0;
  static const double headlineLarge = 28.0;
  static const double headlineMedium = 22.0;
  static const double headlineSmall = 20.0;
  static const double titleLarge = 20.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;
  static const double bodyLarge = 17.0;
  static const double bodyMedium = 15.0;
  static const double bodySmall = 13.0;
}

ThemeData get aweTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: AweColors.accentSlate,
    onPrimary: AweColors.cardSurface,
    primaryContainer: AweColors.surface,
    onPrimaryContainer: AweColors.textPrimary,
    secondary: AweColors.accentTerracotta,
    onSecondary: Colors.white,
    tertiary: AweColors.accentGold,
    onTertiary: Colors.white,
    error: AweColors.error,
    onError: Colors.white,
    errorContainer: AweColors.errorContainer,
    onErrorContainer: const Color(0xFF410002),
    surface: AweColors.background,
    onSurface: AweColors.textPrimary,
  ),
  brightness: Brightness.light,
  scaffoldBackgroundColor: AweColors.background,
  appBarTheme: AppBarTheme(
    backgroundColor: AweColors.background,
    foregroundColor: AweColors.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: GoogleFonts.dmSerifDisplay(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w400,
      color: AweColors.textPrimary,
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AweColors.navBackground,
    selectedItemColor: AweColors.navActive,
    unselectedItemColor: AweColors.navInactive,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    color: AweColors.cardSurface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AweColors.border, width: 0.5),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    elevation: 4,
    backgroundColor: AweColors.accentSlate,
    contentTextStyle: GoogleFonts.sourceSans3(
      color: Colors.white,
      fontWeight: FontWeight.w500,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  textTheme: TextTheme(
    displayLarge: GoogleFonts.dmSerifDisplay(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w700,
      height: 1.15,
      color: AweColors.textPrimary,
    ),
    displayMedium: GoogleFonts.dmSerifDisplay(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w700,
      height: 1.15,
      color: AweColors.textPrimary,
    ),
    displaySmall: GoogleFonts.dmSerifDisplay(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: AweColors.textPrimary,
    ),
    headlineLarge: GoogleFonts.dmSerifDisplay(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AweColors.textPrimary,
    ),
    headlineMedium: GoogleFonts.dmSerifDisplay(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: AweColors.textPrimary,
    ),
    headlineSmall: GoogleFonts.dmSerifDisplay(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: AweColors.textPrimary,
    ),
    titleLarge: GoogleFonts.sourceSans3(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: AweColors.textPrimary,
    ),
    titleMedium: GoogleFonts.sourceSans3(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: AweColors.textPrimary,
    ),
    titleSmall: GoogleFonts.sourceSans3(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: AweColors.textPrimary,
    ),
    labelLarge: GoogleFonts.sourceSans3(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AweColors.textPrimary,
    ),
    labelMedium: GoogleFonts.sourceSans3(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: AweColors.textSecondary,
    ),
    labelSmall: GoogleFonts.sourceSans3(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: AweColors.textSecondary,
    ),
    bodyLarge: GoogleFonts.sourceSans3(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      height: 1.6,
      color: AweColors.textPrimary,
    ),
    bodyMedium: GoogleFonts.sourceSans3(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: AweColors.textPrimary,
    ),
    bodySmall: GoogleFonts.sourceSans3(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: AweColors.textSecondary,
    ),
  ),
);

@Deprecated('Use aweTheme instead')
ThemeData get lightTheme => aweTheme;

@Deprecated('Use aweTheme instead — app is now light-only')
ThemeData get darkTheme => aweTheme;
