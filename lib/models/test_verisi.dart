import 'package:intl/intl.dart';

class TestVerisi {
  final String testAdi;
  final DateTime tarih;
  final String fazAdi;
  final double minBasinc;
  final double maxBasinc;
  final double toplamPompaSuresi;
  final int vitesSayisi;
  final int puan; // 0–20 arası
  final String sonuc; // Mükemmel / Orta / Zayıf
  double faz0Sure;
  Map<String, double> faz2Sonuclar;
  Map<String, double> faz3Sonuclar;
  double faz4PompaSuresi;

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
    required this.faz0Sure,
    required this.faz2Sonuclar,
    required this.faz3Sonuclar,
    required this.faz4PompaSuresi,
  });

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
    'faz0Sure': faz0Sure,
    'faz2Sonuclar': faz2Sonuclar,
    'faz3Sonuclar': faz3Sonuclar,
    'faz4PompaSuresi': faz4PompaSuresi,
  };

  factory TestVerisi.fromJson(Map<String, dynamic> json) {
    return TestVerisi(
      testAdi: json['testAdi'],
      tarih: DateTime.parse(json['tarih']),
      fazAdi: json['fazAdi'],
      minBasinc: (json['minBasinç'] ?? 0).toDouble(),
      maxBasinc: (json['maxBasinç'] ?? 0).toDouble(),
      toplamPompaSuresi: (json['toplamPompaSuresi'] ?? 0).toDouble(),
      vitesSayisi: json['vitesSayisi'] ?? 0,
      puan: json['puan'] ?? 0,
      sonuc: json['sonuc'] ?? "Bilinmiyor",
      faz0Sure: json['faz0Sure'] ?? 0.0,
      faz2Sonuclar: Map<String, double>.from(json['faz2Sonuclar'] ?? {}),
      faz3Sonuclar: Map<String, double>.from(json['faz3Sonuclar'] ?? {}),
      faz4PompaSuresi: json['faz4PompaSuresi'] ?? 0.0,
    );
  }

  String get formattedDate {
    return DateFormat('dd.MM.yyyy HH:mm').format(tarih);
  }
}
