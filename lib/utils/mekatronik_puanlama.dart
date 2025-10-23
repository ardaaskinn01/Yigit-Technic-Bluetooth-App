import 'package:flutter/material.dart';

class MekatronikPuanlama {
  // FAZ 0 - Pompa yükselme süresi puanı
  static int faz0Puan(double sure) {
    if (sure < 10) return 10;
    if (sure < 15) return 7;
    if (sure < 20) return 5;
    return 2;
  }

  // FAZ 1 - Isınma pompa süresi puanı
  static int faz1Puan(double pompaSuresi) {
    if (pompaSuresi < 60) return 15;
    if (pompaSuresi < 120) return 12;
    if (pompaSuresi < 180) return 8;
    return 4;
  }

  // FAZ 2 - Basınç valfi testi puanı
  static int faz2Puan(double pompaSuresi) {
    if (pompaSuresi < 30) return 20;
    if (pompaSuresi < 60) return 15;
    if (pompaSuresi < 90) return 10;
    return 5;
  }

  // FAZ 3 - Her vites için bar düşüşü puanı
  static int vitesBasincPuani(double basincDususu) {
    if (basincDususu <= 2.0) return 5;
    if (basincDususu <= 5.0) return 3;
    if (basincDususu <= 10.0) return 1;
    return 0;
  }

  // FAZ 3 - Tüm viteslerin ortalaması
  static int faz3ToplamPuan(Map<String, double> vitesler) {
    int toplam = 0;
    vitesler.forEach((vites, dusus) {
      toplam += vitesBasincPuani(dusus);
    });
    // normalize ve sınır kontrolü
    int finalPuan = ((toplam / 40.0) * 35).round();
    return finalPuan > 35 ? 35 : finalPuan;
  }

  // FAZ 4 - Test modu pompa süresi puanı
  static int faz4Puan(double pompaSuresi) {
    if (pompaSuresi < 60) return 20;
    if (pompaSuresi < 120) return 15;
    if (pompaSuresi < 180) return 10;
    return 5;
  }

  // TOPLAM PUAN HESAPLAMA
  static int toplamPuan({
    required double faz0Sure,
    required double faz1Pompa,
    required double faz2Pompa,
    required Map<String, double> faz3Vitesler,
    required double faz4Pompa,
  }) {
    return faz0Puan(faz0Sure) +
        faz1Puan(faz1Pompa) +
        faz2Puan(faz2Pompa) +
        faz3ToplamPuan(faz3Vitesler) +
        faz4Puan(faz4Pompa);
  }

  // DURUM METNİ
  static String saglikDurumu(int puan) {
    if (puan >= 90) return "MÜKEMMELİ";
    if (puan >= 80) return "ÇOK İYİ";
    if (puan >= 70) return "İYİ";
    if (puan >= 60) return "ORTA";
    if (puan >= 50) return "ZAYIF";
    return "KÖTÜ";
  }

  // RENK
  static Color puanRengi(int puan) {
    if (puan >= 90) return Colors.green;
    if (puan >= 80) return Colors.lightGreen;
    if (puan >= 70) return Colors.yellow;
    if (puan >= 60) return Colors.orange;
    return Colors.red;
  }

  // YILDIZ
  static int yildizSayisi(int puan) {
    if (puan >= 90) return 5;
    if (puan >= 80) return 4;
    if (puan >= 70) return 3;
    if (puan >= 60) return 2;
    if (puan >= 50) return 1;
    return 0;
  }
}
