import 'package:flutter/material.dart';

/// Brand colours from the Kuzu Help logo (assets/images/logo/).
class AppColors {
  static const primary = Color(0xFFE8761C);   // logo orange (theme seed)
  static const primaryDeep = Color(0xFFB8540F); // buttons: dark enough for white text
  static const secondary = Color(0xFFC95F12); // 'Help' orange
  static const saffron = Color(0xFFF5B82E);   // also the rating stars
  static const maroon = Color(0xFF6E1F12);    // dzong roof
  static const ink = Color(0xFF2B1D14);       // 'Kuzu' dark brown
  static const ivory = Color(0xFFFBF6EC);     // logo ivory: soft panels behind icons and notes
  static const verified = Color(0xFF2E7D32);
  static const unavailable = Color(0xFF9E9E9E);
  static const error = Color(0xFFC62828);
  static const whatsapp = Color(0xFF128C7E);  // WhatsApp teal, dark enough for white text

  // Warm neutrals around the brand colours: white cards with hairline edges
  // on an off-white canvas. [muted] passes 4.5:1 on both white and [canvas].
  static const canvas = Color(0xFFF7F3EE);    // screen background
  static const sand = Color(0xFFEFE7DD);      // tracks, disabled fields
  static const line = Color(0xFFEBE3D8);      // card edges and dividers
  static const outline = Color(0xFFDCD1C4);   // field and button edges
  static const muted = Color(0xFF75685D);     // secondary text and icons
  static const inkSoft = Color(0xFF4E4036);   // body text under a title
  static const peach = Color(0xFFFDEBDB);     // brand tint: selection, icon tiles

  /// The logo's roof, from 'Help' orange down to maroon, for the panels at the
  /// top of the home screens. White text passes 4.5:1 on every part of it.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, Color(0xFF93391A), maroon],
    stops: [0, 0.6, 1],
  );
}
