import 'package:flutter/material.dart';

class MekatronikPuanlama {
  static String durum(int puan) {
// ... aynı kalabilir
    if (puan >= 90) return "✅ MUKEMMEL";
    if (puan >= 75) return "⚙️ IYI";
    if (puan >= 60) return "⚠️ ORTA";
    return "❌ ZAYIF";
  }

  static Color renk(int puan) {
    if (puan >= 90) return Colors.green;
    if (puan >= 75) return Colors.lightGreen;
    if (puan >= 60) return Colors.orange;
    return Colors.red;
  }
}
