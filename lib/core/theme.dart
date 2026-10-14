import 'package:flutter/material.dart';

const kExpense = Color(0xFF9B4A38);
const kIncome = Color(0xFF2E7D6B);
const kTransfer = Color(0xFF2B4BCF);
const kLoan = Color(0xFFC8962B);
const kInk = Color(0xFF1C1C1C);

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: kTransfer, brightness: b);
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'PlexArabic',
    colorScheme: scheme,
  );
  return base.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
