import 'package:flutter/material.dart';

class AppRadii {
  AppRadii._();
  static const double xs = 8;
  static const double sm = 10;
  static const double btn = 12;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 100;
}

class AppShadows {
  AppShadows._();

  static const card = BoxShadow(
    color: Color(0x33000000),
    blurRadius: 10,
    offset: Offset(0, 4),
  );

  static const hoverGlow = BoxShadow(
    color: Color(0x1FFF8C42),
    blurRadius: 28,
    spreadRadius: 2,
  );

  static const ctaGlow = BoxShadow(
    color: Color(0x40FF8C42),
    blurRadius: 16,
    spreadRadius: 0,
  );
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}
