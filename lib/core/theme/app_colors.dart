import 'package:flutter/material.dart';

class AppColors {
  // ── Brand ATR ──
  static const Color atrNavyBlue = Color(0xFF1A2332);
  static const Color atrNavyDarker = Color(0xFF0D1420);
  static const Color atrNavyDark = atrNavyDarker;
  static const Color atrOrange = Color(0xFFFF8C42);
  static const Color atrOrangeGlow = Color(0xFFFF6B1A);

  // ── Premium Dark Surfaces (Navy-tinted, não preto puro) ──
  static const Color backgroundDark = Color(0xFF0B0F19);
  static const Color surfaceDark = Color(0xFF131825);
  static const Color surfaceCardDark = Color(0xFF111827);
  static const Color surfaceDarkAlt = Color(0xFF0F172A);
  static const Color surfaceElevatedDark = Color(0xFF1A2035);
  static const Color surfaceHoverDark = Color(0xFF1F2940);
  static const Color surfaceDeepNavy = Color(0xFF0D1530);

  // ── Premium Light Surfaces ──
  static const Color backgroundLight = Color(0xFFF6F8FC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFF0F4FA);
  static const Color surfaceHoverLight = Color(0xFFE8EDF6);
  static const Color surfaceLightAlt = Color(0xFFF8FAFC);

  // ── Tipografia ──
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF8B9CC0);
  static const Color textMutedDark = Color(0xFF64748B);
  static const Color textTertiaryDark = Color(0xFF94A3B8);

  // ── Bordas ──
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF1E2A3E);
  static const Color borderGlowDark = Color(0xFF2A3A55);
  static const Color borderLightHex = Color(0xFFE5E7EB);

  // ── Status ──
  static const Color statusSuccess = Color(0xFF34D399);
  static const Color statusWarning = Color(0xFFFBBF24);
  static const Color statusError = Color(0xFFF87171);
  static const Color statusInfo = Color(0xFF60A5FA);
  static const Color accentBlue = Color(0xFF3B82F6);

  // ── Glow / Neon helpers ──
  static const Color glowOrange = Color(0x40FF8C42);
  static const Color glowSuccess = Color(0x3034D399);
  static const Color glowInfo = Color(0x3060A5FA);
  static const Color glowError = Color(0x30F87171);

  // ── Hairline / glow utility ──
  static const Color hairlineGlow = Color(0x1AFFFFFF);
  static const Color cardBorderDark = Color(0x0DFFFFFF);

  // ── Background gradients ──
  static const List<Color> premiumGradient = [Color(0xFF667EEA), Color(0xFF764BA2)];
  static const List<Color> warmGradient = [Color(0xFFFF8C42), Color(0xFFFF5F6D)];
  static const List<Color> coolGradient = [Color(0xFF36D1DC), Color(0xFF5B86E5)];

  // Background legacy
  static const Color statusSuccessBg = Color(0xFFD1FAE5);
  static const Color statusWarningBg = Color(0xFFFEF3C7);
  static const Color statusErrorBg = Color(0xFFFEE2E2);
  static const Color statusInfoBg = Color(0xFFDBEAFE);
}
