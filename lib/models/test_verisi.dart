import 'package:intl/intl.dart';

class TestVerisi {
  final String testAdi;
  final DateTime tarih;
  final String fazAdi;
  final double minBasinc;
  final double maxBasinc;
  final double toplamPompaSuresi;
  final int vitesSayisi;
  final int puan; // 0–100 arası (100'e güncellendi)
  final String sonuc; // Mükemmel / İyi / Orta / Zayıf
  // 🔹 YENİ: Faz puanları
  final double? faz0Puan;
  final double? faz2Puan;
  final double? faz3Puan;
  final double? faz4Puan;
  final int? bonusPuan;

  TestVerisi({
    required this.testAdi,
    required this.tarih,
    required this.fazAdi,
    required this.minBasinc,
    required this.maxBasinc,
    required this.toplamPompaSuresi,
    required this.vitesSayisi,
    required this.puan,
    required this.sonuc,
    required this.faz0Puan,
    required this.faz2Puan,
    required this.faz3Puan,
    required this.faz4Puan,
    this.bonusPuan,
  });

  // 🔹 YENİ: copyWith metodu - nesneyi kopyalayıp güncellemek için
  TestVerisi copyWith({
    String? testAdi,
    DateTime? tarih,
    String? fazAdi,
    double? minBasinc,
    double? maxBasinc,
    double? toplamPompaSuresi,
    int? vitesSayisi,
    int? puan,
    String? sonuc,
    double? faz0Sure,
    double? faz2Puan,
    double? faz3Puan,
    double? faz4PompaSuresi,
    String? cihazRaporu,
    // 🔹 YENİ: Faz puanları
    double? faz0Puan,
    double? faz1Puan,
    double? faz2PuanDetay,
    double? faz3PuanDetay,
    double? faz4Puan,
    int? bonusPuan,
  }) {
    return TestVerisi(
      testAdi: testAdi ?? this.testAdi,
      tarih: tarih ?? this.tarih,
      fazAdi: fazAdi ?? this.fazAdi,
      minBasinc: minBasinc ?? this.minBasinc,
      maxBasinc: maxBasinc ?? this.maxBasinc,
      toplamPompaSuresi: toplamPompaSuresi ?? this.toplamPompaSuresi,
      vitesSayisi: vitesSayisi ?? this.vitesSayisi,
      puan: puan ?? this.puan,
      sonuc: sonuc ?? this.sonuc,
      faz0Puan: faz0Puan ?? this.faz0Puan,
      faz2Puan: faz2Puan ?? this.faz2Puan,
      faz3Puan: faz3Puan ?? this.faz3Puan,
      faz4Puan: faz4Puan ?? this.faz4Puan,
      bonusPuan: bonusPuan ?? this.bonusPuan,
    );
  }

  Map<String, dynamic> toJson() => {
    'testAdi': testAdi,
    'tarih': tarih.toIso8601String(),
    'fazAdi': fazAdi,
    'minBasinc': minBasinc,
    'maxBasinc': maxBasinc,
    'toplamPompaSuresi': toplamPompaSuresi,
    'vitesSayisi': vitesSayisi,
    'puan': puan,
    'sonuc': sonuc,
    'faz0Puan': faz0Puan,
    'faz2Puan': faz2Puan,
    'faz3Puan': faz3Puan,
    'faz4Puan': faz4Puan,
    'bonusPuan': bonusPuan,
  };

  factory TestVerisi.fromJson(Map<String, dynamic> json) {
    return TestVerisi(
      testAdi: json['testAdi'],
      tarih: DateTime.parse(json['tarih']),
      fazAdi: json['fazAdi'],
      minBasinc: (json['minBasinc'] ?? json['minBasinç'] ?? 0).toDouble(),
      maxBasinc: (json['maxBasinc'] ?? json['maxBasinç'] ?? 0).toDouble(),
      toplamPompaSuresi: (json['toplamPompaSuresi'] ?? 0).toDouble(),
      vitesSayisi: json['vitesSayisi'] ?? 0,
      puan: json['puan'] ?? 0,
      sonuc: json['sonuc'] ?? "Bilinmiyor",
      faz0Puan: json['faz0Puan']?.toDouble(),
      faz2Puan: (json['faz2Puan'] ?? 0).toDouble(),
      faz3Puan: (json['faz3Puan'] ?? 0).toDouble(),
      faz4Puan: json['faz4Puan']?.toDouble(),
      bonusPuan: json['bonusPuan']?.toInt(),
    );
  }

  String get formattedDate {
    return DateFormat('dd.MM.yyyy HH:mm').format(tarih);
  }

  // 🔹 YENİ: Faz puanları toplamını hesapla
  double get fazPuanlariToplami {
    double toplam = 0;
    toplam += faz0Puan ?? 0;
    toplam += faz2Puan ?? 0;
    toplam += faz3Puan ?? 0;
    toplam += faz4Puan ?? 0;
    toplam += faz4Puan ?? 0;
    toplam += (bonusPuan ?? 0).toDouble();
    return toplam;
  }

  // 🔹 YENİ: Tüm faz puanları mevcut mu?
  bool get tumFazPuanlariMevcut {
    return faz0Puan != null &&
        faz2Puan != null &&
        faz3Puan != null &&
        faz4Puan != null &&
        bonusPuan != null;
  }
}