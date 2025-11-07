import 'package:intl/intl.dart';

class TestVerisi {
  final String testAdi;
  final DateTime tarih;
  final double minBasinc;
  final double maxBasinc;
  final double toplamPompaSuresi;
  final int puan; // 0–100 arası
  final String sonuc; // Mükemmel / İyi / Orta / Zayıf / Sorunlu / Kötü
  final Map<String, int> fazPuanlari; // FAZ 0: 2, FAZ 1: 4, FAZ 2: 5, FAZ 3: 0, FAZ 4: 5
  final Map<String, dynamic> detayliFazVerileri; // YENİ: Tüm detaylı veriler

  TestVerisi({
    required this.testAdi,
    required this.tarih,
    required this.minBasinc,
    required this.maxBasinc,
    required this.toplamPompaSuresi,
    required this.puan,
    required this.sonuc,
    Map<String, int>? fazPuanlari,
    Map<String, dynamic>? detayliFazVerileri,
  }) : fazPuanlari = fazPuanlari ?? {},
        detayliFazVerileri = detayliFazVerileri ?? {};

  // 🔹 copyWith metodu
  TestVerisi copyWith({
    String? testAdi,
    DateTime? tarih,
    double? minBasinc,
    double? maxBasinc,
    double? toplamPompaSuresi,
    int? puan,
    String? sonuc,
    Map<String, int>? fazPuanlari,
    Map<String, dynamic>? detayliFazVerileri,
  }) {
    return TestVerisi(
      testAdi: testAdi ?? this.testAdi,
      tarih: tarih ?? this.tarih,
      minBasinc: minBasinc ?? this.minBasinc,
      maxBasinc: maxBasinc ?? this.maxBasinc,
      toplamPompaSuresi: toplamPompaSuresi ?? this.toplamPompaSuresi,
      puan: puan ?? this.puan,
      sonuc: sonuc ?? this.sonuc,
      fazPuanlari: fazPuanlari ?? this.fazPuanlari,
      detayliFazVerileri: detayliFazVerileri ?? this.detayliFazVerileri,
    );
  }

  Map<String, dynamic> toJson() => {
    'testAdi': testAdi,
    'tarih': tarih.toIso8601String(),
    'minBasinc': minBasinc,
    'maxBasinc': maxBasinc,
    'toplamPompaSuresi': toplamPompaSuresi,
    'puan': puan,
    'sonuc': sonuc,
    'fazPuanlari': fazPuanlari,
    'detayliFazVerileri': detayliFazVerileri,
  };

  factory TestVerisi.fromJson(Map<String, dynamic> json) {
    return TestVerisi(
      testAdi: json['testAdi'],
      tarih: DateTime.parse(json['tarih']),
      minBasinc: (json['minBasinc'] ?? json['minBasinç'] ?? 0).toDouble(),
      maxBasinc: (json['maxBasinc'] ?? json['maxBasinç'] ?? 0).toDouble(),
      toplamPompaSuresi: (json['toplamPompaSuresi'] ?? 0).toDouble(),
      puan: json['puan'] ?? 0,
      sonuc: json['sonuc'] ?? "Bilinmiyor",
      fazPuanlari: Map<String, int>.from(json['fazPuanlari'] ?? {}),
      detayliFazVerileri: Map<String, dynamic>.from(json['detayliFazVerileri'] ?? {}),
    );
  }

  String get formattedDate {
    return DateFormat('dd.MM.yyyy HH:mm').format(tarih);
  }

  // 🔹 Detaylı faz puanları mevcut mu?
  bool get detayliFazPuanlariMevcut {
    return fazPuanlari.isNotEmpty;
  }

  // 🔹 FAZ 0 detayları
  Map<String, dynamic> get faz0Detaylari {
    return detayliFazVerileri['faz0'] ?? {};
  }

  // 🔹 FAZ 2 detayları
  Map<String, dynamic> get faz2Detaylari {
    return detayliFazVerileri['faz2'] ?? {};
  }

  // 🔹 FAZ 3 detayları
  Map<String, dynamic> get faz3Detaylari {
    return detayliFazVerileri['faz3'] ?? {};
  }

  // 🔹 FAZ 4 detayları
  Map<String, dynamic> get faz4Detaylari {
    return detayliFazVerileri['faz4'] ?? {};
  }

  // 🔹 Rapor özeti
  String get raporOzeti {
    return '''
Test: $testAdi
Tarih: $formattedDate
Puan: $puan/100 - $sonuc
Basınç: ${minBasinc.toStringAsFixed(1)}-${maxBasinc.toStringAsFixed(1)} bar
Pompa Süresi: ${toplamPompaSuresi.toStringAsFixed(1)} sn
''';
  }

  @override
  String toString() {
    return 'TestVerisi{testAdi: $testAdi, puan: $puan, sonuc: $sonuc, tarih: $formattedDate}';
  }
}