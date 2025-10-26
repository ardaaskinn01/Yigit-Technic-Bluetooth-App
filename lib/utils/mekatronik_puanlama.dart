import 'package:flutter/material.dart';

class MekatronikPuanlama {
  // 🔹 Faz 0 - 60 bar’a ulaşma süresi (Ağırlık: 10 puan)
  static int faz0Puan(double sure) {
    if (sure <= 8) return 10;
    if (sure <= 12) return 7;
    return 3;
  }

  // 🔹 Faz 2 - Sızdırmazlık testi (Ağırlık: 20 puan)
  static int faz2Puan(double barPerMinute) {
    // Kılavuzdaki Kapalı sistem sızdırmazlığını kullanacağız
    if (barPerMinute < 2) return 20;
    if (barPerMinute <= 5) return 12;
    return 5;
  }

  // 🔹 Faz 3 - Vites basınç düşüşleri (Ağırlık: 35 puan)
  static int faz3Puan(Map<String, double> vitesDusmeleri) {
    if (vitesDusmeleri.isEmpty) return 0;
    // Her bir vites grubuna maksimum 35 / 6 = 5.83 puan
    double toplamPuan = 0;
    int groupCount = 0;

    for (var d in vitesDusmeleri.values) {
      groupCount++;
      if (d < 3) toplamPuan += 5.83; // Mükemmel
      else if (d <= 6) toplamPuan += 3.5; // Orta
      else toplamPuan += 1.5; // Zayıf
    }
    return toplamPuan.round(); // Normalize edilmez, direkt toplanır (Max ~35)
  }

  // 🔹 Faz 4 - Dayanıklılık testi (Ağırlık: 20 puan)
  static int faz4Puan(double pumpSeconds) {
    if (pumpSeconds < 55) return 20;
    if (pumpSeconds <= 80) return 12;
    return 5;
  }

  // 🔹 Bonus Puan (Ağırlık: 15 puan) - Genel performansa göre orantılayalım
  static int bonusPuan(double faz0, double faz2, Map<String, double> faz3, double faz4) {
    // Tüm testler mükemmele yakınsa tam bonusu verelim
    int f0 = faz0Puan(faz0) == 10 ? 3 : 0;
    int f2 = faz2Puan(faz2) >= 15 ? 4 : 0;
    int f3 = faz3Puan(faz3) >= 30 ? 5 : 0;
    int f4 = faz4Puan(faz4) >= 15 ? 3 : 0;

    return f0 + f2 + f3 + f4; // Maksimum 15 puan
  }

  // 🔹 Genel hesaplama (Faz 2 için Kapalı sistem sızdırmazlığı kullanılacak)
  static int hesapla(double faz0Sure, double faz2KapaliBarPerMin, Map<String, double> faz3Map, double faz4PumpSeconds) {

    final f0 = faz0Puan(faz0Sure);
    final f2 = faz2Puan(faz2KapaliBarPerMin);
    final f3 = faz3Puan(faz3Map);
    final f4 = faz4Puan(faz4PumpSeconds);
    final bonus = bonusPuan(faz0Sure, faz2KapaliBarPerMin, faz3Map, faz4PumpSeconds);

    return f0 + f2 + f3 + f4 + bonus; // 0–100 arası
  }

  static String durum(int puan) {
// ... aynı kalabilir
    if (puan >= 90) return "✅ MÜKEMMEL";
    if (puan >= 75) return "⚙️ İYİ";
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
