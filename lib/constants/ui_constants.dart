import 'package:flutter/material.dart';

/// UI Constants for consistent styling throughout the app
class UiConstants {
  // Private constructor to prevent instantiation
  UiConstants._();
  
  /// Spacing constants
  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;
  static const double spacing64 = 64.0;
  
  /// Border radius constants
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;
  static const double radiusCircular = 1000.0;
  
  /// Avatar size constants
  static const double avatarSizeSmall = 28.0;
  static const double avatarSizeMedium = 40.0;
  static const double avatarSizeLarge = 50.0;
  static const double avatarSizeXLarge = 60.0;
  
  /// Font size constants
  static const double fontSizeXSmall = 10.0;
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeNormal = 16.0;
  static const double fontSizeLarge = 18.0;
  static const double fontSizeXLarge = 24.0;
  static const double fontSizeXXLarge = 32.0;
  
  /// Animation durations
  static const Duration animationShort = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationLong = Duration(milliseconds: 500);
  
  /// Opacity values
  static const double opacityDisabled = 0.5;
  static const double opacityLight = 0.7;
  static const double opacityFull = 1.0;
  
  /// Shadows
  static const List<BoxShadow> shadowLight = [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];
  
  static const List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Colors.black26,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
  
  static const List<BoxShadow> shadowStrong = [
    BoxShadow(
      color: Colors.black38,
      blurRadius: 12,
      offset: Offset(0, 3),
    ),
  ];
  
  /// Input decoration
  static InputDecoration searchInputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText ?? 'Buscar...',
      prefixIcon: Icon(Icons.search),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.grey[200],
      contentPadding: EdgeInsets.symmetric(
        horizontal: spacing16,
        vertical: spacing8,
      ),
    );
  }
  
  static InputDecoration messageInputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText ?? 'Escribe un mensaje...',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXLarge),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.grey[200],
      contentPadding: EdgeInsets.symmetric(
        horizontal: spacing16,
        vertical: spacing8,
      ),
    );
  }
  
  /// Text styles
  static const TextStyle headingTextStyle = TextStyle(
    fontSize: fontSizeXLarge,
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle subheadingTextStyle = TextStyle(
    fontSize: fontSizeLarge,
    fontWeight: FontWeight.w500,
  );
  
  static const TextStyle bodyTextStyle = TextStyle(
    fontSize: fontSizeNormal,
  );
  
  static const TextStyle captionTextStyle = TextStyle(
    fontSize: fontSizeSmall,
    color: Colors.grey,
  );
} 