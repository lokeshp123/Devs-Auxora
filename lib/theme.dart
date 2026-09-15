import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF8FAFC); // Crisp off-white paper background
  static const Color surface = Color(0xFFFFFFFF);    // Pure white for elevated cards and fields

  static const Color accentCyan = Color(0xFFDC2626); // Striking corporate red

  static const Color textWhite = Color(0xFF0F172A);  // Deep slate/black for headings and main text
  static const Color textMuted = Color(0xFF64748B);  // Professional gray for subtitles and labels

  static const Color borderDark = Color(0xFFE2E8F0); // Subtle light-gray lines for borders
  static const Color badgeBg = Color(0xFFFEE2E2);

  static const Color warningYellow = Color(0xFFFFB74D);
  static const Color infoBlue = Color(0xFF64B5F6);
  static const Color warningOrange = Color(0xFFFF8A65); // Deep Orange// Very soft tinted red for badges/chips

  // --- Standard Status Colors ---
  static const Color successGreen = Color(0xFF10B981);
  static const Color dangerRed = Color(0xFFEF4444);

  // --- Premium AppBar Gradient ---
  static const LinearGradient premiumGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFB91C1C)], // Deep rich red gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- Sidebar Settings ---
  // A dark sidebar paired with a white body gives an ultra-premium enterprise look
  static const Color sidebarBg = Color(0xFF0F172A);
  static const Color sidebarItemText = Color(0xFFCBD5E1);
  static const Color sidebarItemHover = Color(0xFF1E293B);
}