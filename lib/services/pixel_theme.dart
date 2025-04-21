import 'package:flutter/material.dart';

class PixelTheme {
  // Yellow-based color scheme
  static const Color background = Color(0xFFF8F4E3);    // Yellow background
  static const Color primary = Color(0xFFFF7A59);       // Orange
  static const Color secondary = Color(0xFFFFBB36);     // Yellow
  static const Color surface = Color(0xFFFFF1DC);       // Light yellow surface
  static const Color text = Color(0xFF3A3A3A);          // Dark gray text
  static const Color textLight = Color(0xFF666666);     // Light gray text
  static const Color accent = Color(0xFF1B8A6B);        // Green accent
  static const Color error = Color(0xFFD35269);         // Red error
  
  // Font size
  static const double fontSizeSmall = 10.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeLarge = 18.0;
  static const double fontSizeXLarge = 24.0;
  
  // Border style - thicker border
  static BoxBorder pixelBorder = Border.all(
    color: text,
    width: 2.0,
  );
  
  // Card shadow style
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      offset: const Offset(4, 4),
      blurRadius: 0, // No blur, keep pixel feel
    ),
  ];
  
  // Button style
  static ButtonStyle buttonStyle = ElevatedButton.styleFrom(
    backgroundColor: surface, 
    foregroundColor: text,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.zero, // Square edge
      side: BorderSide(color: text, width: 2.0),
    ),
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
  );
  
  // Monospaced font style
  static TextStyle get titleStyle => TextStyle(
    //fontFamily: 'DMMono', 
    fontSize: fontSizeLarge,
    fontWeight: FontWeight.bold,
    color: text,
  );
  
  static TextStyle get bodyStyle => TextStyle(
    //fontFamily: 'DMMono',
    fontSize: fontSizeMedium,
    color: text,
  );
  
  static TextStyle get labelStyle => TextStyle(
    //fontFamily: 'DMMono',
    fontSize: fontSizeSmall,
    color: textLight,
  );
}