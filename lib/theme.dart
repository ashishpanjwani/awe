import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Awe Travel App Color Palette
class FlowColors {
  // Primary Dark Blue - Main brand color
  static const primaryDark = Color(0xFF0B1C2E);
  // Deeper dark tone for vertical gradients/background depth
  static const primaryDarkDeep = Color(0xFF071423);
  static const primaryDarkVariant = Color(0xFF1A2B3E);
  
  // Legacy Teal (kept for subtle accents where already used)
  static const softTeal = Color(0xFF4A9B9B);
  static const softTealLight = Color(0xFF6BB6CD);
  
  // Warm Accents - For interactive elements
  static const warmOrange = Color(0xFFFF8A65);
  static const warmCoral = Color(0xFFFF7043);
  
  // Gradient Colors for Cards
  static const cardGradientStart = Color(0xFFE8E3F3);
  static const cardGradientEnd = Color(0xFFF3F0FF);
  static const cardGradientStartDark = Color(0xFF1E2A3A);
  static const cardGradientEndDark = Color(0xFF2A3B4E);
  
  // Feature Card Gradients (Dark mode tuned)
  // Primary (Itinerary)
  // Harmonized with primaryDark (#0B1C2E): subtle blue tints for a cohesive look
  static const featurePrimaryStartDark = Color(0xFF102237); // slightly lighter than primaryDark
  static const featurePrimaryEndDark = Color(0xFF142C43);
  // Teal (QuickTrip)
  // Deep teal tints that sit well on the blue background (no gray cast)
  static const featureTealStartDark = Color(0xFF0D2E2F);
  static const featureTealEndDark = Color(0xFF154244);
  // Coral (Discover)
  // Muted warm browns with a coral hint to avoid muddy tones on dark blue
  static const featureCoralStartDark = Color(0xFF241A17);
  static const featureCoralEndDark = Color(0xFF31231E);
  
  // Text Colors
  static const textLight = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF1C1C1C);
  static const textGrey = Color(0xFF9E9E9E);
  
  // Surface Colors
  static const surfaceLight = Color(0xFFFAFAFA);
  static const surfaceDark = Color(0xFF0F1419);
  static const surfaceVariantDark = Color(0xFF1A1F26);

  // Promotional text accent
  // Tuned to better match the outline color in the promo image
  static const promoTextPaleBlue = Color(0xFF7c8a98);

  // Pale blue accent for outlined illustrations and accents on dark bg
  static const paleBlue = Color(0xFFA7BED3);

  // UI Surfaces & Borders (Dark)
  static const cardSurfaceDark = Color(0xFF0D1725); // slightly above primaryDark
  static const cardBorderDark = Color(0xFFFFFFFF); // will be used with low alpha
  static const chipBgDark = Color(0xFF0F1D2E);
  static const chipBorderDark = Color(0xFFFFFFFF); // with low alpha in code
  static const chipSelectedDark = Color(0xFF15324F); // soft blue highlight

  // Muted accent set for icons/highlights (no neon)
  static const accentTeal = Color(0xFF4A9B9B);
  static const accentGreen = Color(0xFF5FAE7C);
  static const accentAmber = Color(0xFFE9B562);
  static const accentOrange = Color(0xFFE18A5C);
  static const accentBrown = Color(0xFF8A6B55);

  // CTA Glow
  static const ctaGlowOuter = Color(0xFF0E2A46);
  static const ctaGlowInner = Color(0xFF1C3C5C);

  // Vibrant accent (replaces teal for buttons and key actions)
  // Electric Violet provides energetic contrast on dark surfaces
  static const vibrantViolet = Color(0xFF7C4DFF);

  // Premium gradients for statistic tiles and profile accents
  // Keeping all design tokens centralized here per design guidelines
  static const statVioletStart = Color(0xFF6C63FF);
  static const statVioletEnd = Color(0xFF8E7CFF);
  static const statCyanStart = Color(0xFF00C6FF);
  static const statCyanEnd = Color(0xFF0072FF);
  static const statGreenStart = Color(0xFF42E695);
  static const statGreenEnd = Color(0xFF3BB2B8);
  static const cardGlowTop = Color(0x33FFFFFF); // subtle white glow overlay
  static const cardGlowBottom = Color(0x11000000); // soft shadow tone

  // Vintage Ticket Paper Palette (original lighter daily papers)
  // General ticket colors; compatible with dark navy background
  static const ticketPaperCream = Color(0xFFF3E9D7); // light cream parchment
  static const ticketPaperKraft = Color(0xFFE7D3B5); // light kraft tan
  static const ticketPaperMint = Color(0xFFE6F2EA); // pale mint
  static const ticketPaperPowder = Color(0xFFE8F0F7); // powder blue
  static const ticketPaperRose = Color(0xFFF4E3E3); // soft rose
  static const ticketPaperGrey = Color(0xFFEBE6DD); // warm light grey
  static const ticketInkDark = Color(0xFF2E2A22); // deep ink for legibility
}

class LightModeColors {
  static const lightPrimary = FlowColors.softTeal;
  static const lightOnPrimary = FlowColors.textLight;
  static const lightPrimaryContainer = FlowColors.cardGradientStart;
  static const lightOnPrimaryContainer = FlowColors.primaryDark;
  static const lightSecondary = FlowColors.softTeal;
  static const lightOnSecondary = FlowColors.textLight;
  static const lightTertiary = FlowColors.warmCoral;
  static const lightOnTertiary = FlowColors.textLight;
  static const lightError = Color(0xFFBA1A1A);
  static const lightOnError = FlowColors.textLight;
  static const lightErrorContainer = Color(0xFFFFDAD6);
  static const lightOnErrorContainer = Color(0xFF410002);
  static const lightInversePrimary = FlowColors.softTealLight;
  static const lightShadow = Color(0xFF000000);
  static const lightSurface = FlowColors.surfaceLight;
  static const lightOnSurface = FlowColors.textDark;
  static const lightAppBarBackground = FlowColors.cardGradientStart;
}

class DarkModeColors {
  static const darkPrimary = FlowColors.softTealLight;
  static const darkOnPrimary = FlowColors.primaryDark;
  static const darkPrimaryContainer = FlowColors.cardGradientStartDark;
  static const darkOnPrimaryContainer = FlowColors.textLight;
  static const darkSecondary = FlowColors.softTeal;
  static const darkOnSecondary = FlowColors.textLight;
  static const darkTertiary = FlowColors.warmCoral;
  static const darkOnTertiary = FlowColors.primaryDark;
  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);
  static const darkInversePrimary = FlowColors.softTeal;
  static const darkShadow = Color(0xFF000000);
  static const darkSurface = FlowColors.surfaceDark;
  static const darkOnSurface = FlowColors.textLight;
  static const darkAppBarBackground = FlowColors.primaryDark;
}

class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 24.0;
  static const double headlineSmall = 22.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 18.0;
  static const double titleSmall = 16.0;
  static const double labelLarge = 16.0;
  static const double labelMedium = 14.0;
  static const double labelSmall = 12.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: LightModeColors.lightPrimary,
    onPrimary: LightModeColors.lightOnPrimary,
    primaryContainer: LightModeColors.lightPrimaryContainer,
    onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
    secondary: LightModeColors.lightSecondary,
    onSecondary: LightModeColors.lightOnSecondary,
    tertiary: LightModeColors.lightTertiary,
    onTertiary: LightModeColors.lightOnTertiary,
    error: LightModeColors.lightError,
    onError: LightModeColors.lightOnError,
    errorContainer: LightModeColors.lightErrorContainer,
    onErrorContainer: LightModeColors.lightOnErrorContainer,
    inversePrimary: LightModeColors.lightInversePrimary,
    shadow: LightModeColors.lightShadow,
    surface: LightModeColors.lightSurface,
    onSurface: LightModeColors.lightOnSurface,
  ),
  brightness: Brightness.light,
  appBarTheme: AppBarTheme(
    backgroundColor: LightModeColors.lightAppBarBackground,
    foregroundColor: LightModeColors.lightOnPrimaryContainer,
    elevation: 0,
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    elevation: 8,
    backgroundColor: Colors.black87,
    contentTextStyle: GoogleFonts.raleway(
      color: Colors.white,
      fontWeight: FontWeight.w600,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    ),
  ),
  textTheme: TextTheme(
    // Hero/marketing headings – unified to Raleway for consistency
    displayLarge: GoogleFonts.raleway(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    displayMedium: GoogleFonts.raleway(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    displaySmall: GoogleFonts.raleway(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    // Section/page headings – Raleway maintained
    headlineLarge: GoogleFonts.raleway(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w600,
      height: 1.22,
    ),
    headlineMedium: GoogleFonts.raleway(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w600,
      height: 1.22,
    ),
    headlineSmall: GoogleFonts.raleway(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w700,
      height: 1.22,
    ),
    // App/UI titles – Raleway for crisp modern UI
    titleLarge: GoogleFonts.raleway(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    titleMedium: GoogleFonts.raleway(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    titleSmall: GoogleFonts.raleway(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    // Controls/labels – Raleway medium for clarity
    labelLarge: GoogleFonts.raleway(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    labelMedium: GoogleFonts.raleway(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    labelSmall: GoogleFonts.raleway(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    // Body copy – Raleway regular for readability
    bodyLarge: GoogleFonts.raleway(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    bodyMedium: GoogleFonts.raleway(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    bodySmall: GoogleFonts.raleway(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
  ),
);

ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: DarkModeColors.darkPrimary,
    onPrimary: DarkModeColors.darkOnPrimary,
    primaryContainer: DarkModeColors.darkPrimaryContainer,
    onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
    secondary: DarkModeColors.darkSecondary,
    onSecondary: DarkModeColors.darkOnSecondary,
    tertiary: DarkModeColors.darkTertiary,
    onTertiary: DarkModeColors.darkOnTertiary,
    error: DarkModeColors.darkError,
    onError: DarkModeColors.darkOnError,
    errorContainer: DarkModeColors.darkErrorContainer,
    onErrorContainer: DarkModeColors.darkOnErrorContainer,
    inversePrimary: DarkModeColors.darkInversePrimary,
    shadow: DarkModeColors.darkShadow,
    surface: DarkModeColors.darkSurface,
    onSurface: DarkModeColors.darkOnSurface,
  ),
  brightness: Brightness.dark,
  appBarTheme: AppBarTheme(
    backgroundColor: DarkModeColors.darkAppBarBackground,
    foregroundColor: DarkModeColors.darkOnPrimaryContainer,
    elevation: 0,
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    elevation: 8,
    backgroundColor: FlowColors.surfaceLight,
    contentTextStyle: GoogleFonts.raleway(
      color: FlowColors.textDark,
      fontWeight: FontWeight.w600,
    ),
    actionTextColor: FlowColors.softTealLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    ),
  ),
  textTheme: TextTheme(
    // Hero/marketing headings – unified to Raleway for consistency
    displayLarge: GoogleFonts.raleway(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    displayMedium: GoogleFonts.raleway(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    displaySmall: GoogleFonts.raleway(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    headlineLarge: GoogleFonts.raleway(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w600,
      height: 1.22,
    ),
    headlineMedium: GoogleFonts.raleway(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w600,
      height: 1.22,
    ),
    headlineSmall: GoogleFonts.raleway(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w700,
      height: 1.22,
    ),
    titleLarge: GoogleFonts.raleway(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    titleMedium: GoogleFonts.raleway(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    titleSmall: GoogleFonts.raleway(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    labelLarge: GoogleFonts.raleway(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    labelMedium: GoogleFonts.raleway(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    labelSmall: GoogleFonts.raleway(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    bodyLarge: GoogleFonts.raleway(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    bodyMedium: GoogleFonts.raleway(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    bodySmall: GoogleFonts.raleway(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
  ),
);
