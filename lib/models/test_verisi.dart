import 'dart:convert';

import 'package:intl/intl.dart';

class TestVerisi {
  int? id; // ✅ SQLite için primary key
  final String testAdi;
  final DateTime tarih;
  final double minBasinc;
  final double maxBasinc;
  final double toplamPompaSuresi;
  final int puan;
  final String sonuc;
  final Map<String, int> fazPuanlari;
  final Map<String, dynamic> detayliFazVerileri;

  TestVerisi({
    this.id,
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

  // 🔹 SQLite Database Map'ine çevirme
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'testAdi': testAdi,
      'tarih': tarih.millisecondsSinceEpoch,
      'minBasinc': minBasinc,
      'maxBasinc': maxBasinc,
      'toplamPompaSuresi': toplamPompaSuresi,
      'puan': puan,
      'sonuc': sonuc,
      'fazPuanlari': _mapToJsonString(fazPuanlari),
      'DetayliFazVerileri': _mapToJsonString(detayliFazVerileri), // ✅ BÜYÜK HARFLE
    };
  }

  // 🔹 SQLite Database Map'inden nesne oluşturma
  factory TestVerisi.fromDbMap(Map<String, dynamic> map) {
    return TestVerisi(
      id: map['id'],
      testAdi: map['testAdi'],
      tarih: DateTime.fromMillisecondsSinceEpoch(map['tarih']),
      minBasinc: map['minBasinc']?.toDouble() ?? 0.0,
      maxBasinc: map['maxBasinc']?.toDouble() ?? 0.0,
      toplamPompaSuresi: map['toplamPompaSuresi']?.toDouble() ?? 0.0,
      puan: map['puan'] ?? 0,
      sonuc: map['sonuc'] ?? "Bilinmiyor",
      fazPuanlari: _jsonStringToMap<int>(map['fazPuanlari']),
      detayliFazVerileri: _jsonStringToMap<dynamic>(map['DetayliFazVerileri']), // ✅ BÜYÜK HARFLE
    );
  }

  // 🔹 JSON string'den Map'e çevirme (generic)
  static Map<String, T> _jsonStringToMap<T>(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return {};
    try {
      final decoded = json.decode(jsonString);
      return Map<String, T>.from(decoded);
    } catch (e) {
      print('JSON decode hatası: $e');
      return {};
    }
  }

  // 🔹 Map'den JSON string'e çevirme
  static String _mapToJsonString(Map<String, dynamic> map) {
    try {
      return json.encode(map);
    } catch (e) {
      print('JSON encode hatası: $e');
      return '{}';
    }
  }

  // 🔹 Eski JSON metodları (geriye uyumluluk için)
  Map<String, dynamic> toJson() {
    return {
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
  }

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

  // 🔹 copyWith metodu
  TestVerisi copyWith({
    int? id,
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
      id: id ?? this.id,
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

  // 🔹 Diğer yardımcı metodlar
  String get formattedDate {
    return DateFormat('dd.MM.yyyy HH:mm').format(tarih);
  }

  String get formattedTime {
    return DateFormat('HH:mm').format(tarih);
  }

  bool get detayliFazPuanlariMevcut {
    return fazPuanlari.isNotEmpty;
  }

  Map<String, dynamic> get faz0Detaylari {
    return detayliFazVerileri['faz0'] ?? {};
  }

  Map<String, dynamic> get faz2Detaylari {
    return detayliFazVerileri['faz2'] ?? {};
  }

  Map<String, dynamic> get faz3Detaylari {
    return detayliFazVerileri['faz3'] ?? {};
  }

  Map<String, dynamic> get faz4Detaylari {
    return detayliFazVerileri['faz4'] ?? {};
  }

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
    return 'TestVerisi{id: $id, testAdi: $testAdi, puan: $puan, sonuc: $sonuc, tarih: $formattedDate}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestVerisi &&
        other.id == id &&
        other.testAdi == testAdi &&
        other.tarih == tarih;
  }

  @override
  int get hashCode {
    return id.hashCode ^ testAdi.hashCode ^ tarih.hashCode;
  }
}