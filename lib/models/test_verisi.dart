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

  // 🔹 FAZ PUANLARI
  final double? faz0Puan;
  final double? faz2Puan;
  final double? faz3Puan;
  final double? faz4Puan;
  final int? bonusPuan;

  // 🔹 YENİ: DETAYLI RAPOR VERİLERİ
  String? cihazRaporu;
  double ortalamaBasinc;
  int dusukBasincSayisi;
  int toplamVitesGecisi;
  Map<String, int> vitesGecisleri;
  Map<String, dynamic> faz0Veriler;
  Map<String, dynamic> faz2Veriler;
  Map<String, dynamic> faz3Veriler;
  Map<String, dynamic> faz4Veriler;
  Map<String, int>
  fazPuanlari; // FAZ 0: 2, FAZ 1: 4, FAZ 2: 5, FAZ 3: 0, FAZ 4: 5

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
    this.faz0Puan,
    this.faz2Puan,
    this.faz3Puan,
    this.faz4Puan,
    this.bonusPuan,

    // 🔹 YENİ: DETAYLI RAPOR ALANLARI
    this.cihazRaporu,
    this.ortalamaBasinc = 0,
    this.dusukBasincSayisi = 0,
    this.toplamVitesGecisi = 0,
    Map<String, int>? vitesGecisleri,
    Map<String, dynamic>? faz0Veriler,
    Map<String, dynamic>? faz2Veriler,
    Map<String, dynamic>? faz3Veriler,
    Map<String, dynamic>? faz4Veriler,
    Map<String, int>? fazPuanlari,
  }) : vitesGecisleri = vitesGecisleri ?? {},
       faz0Veriler = faz0Veriler ?? {},
       faz2Veriler = faz2Veriler ?? {},
       faz3Veriler = faz3Veriler ?? {},
       faz4Veriler = faz4Veriler ?? {},
       fazPuanlari = fazPuanlari ?? {};

  // 🔹 copyWith metodu - nesneyi kopyalayıp güncellemek için
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
    double? faz0Puan,
    double? faz2Puan,
    double? faz3Puan,
    double? faz4Puan,
    int? bonusPuan,

    // 🔹 YENİ: DETAYLI RAPOR ALANLARI
    String? cihazRaporu,
    double? ortalamaBasinc,
    int? dusukBasincSayisi,
    int? toplamVitesGecisi,
    Map<String, int>? vitesGecisleri,
    Map<String, dynamic>? faz0Veriler,
    Map<String, dynamic>? faz2Veriler,
    Map<String, dynamic>? faz3Veriler,
    Map<String, dynamic>? faz4Veriler,
    Map<String, int>? fazPuanlari,
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

      // 🔹 YENİ: DETAYLI RAPOR ALANLARI
      cihazRaporu: cihazRaporu ?? this.cihazRaporu,
      ortalamaBasinc: ortalamaBasinc ?? this.ortalamaBasinc,
      dusukBasincSayisi: dusukBasincSayisi ?? this.dusukBasincSayisi,
      toplamVitesGecisi: toplamVitesGecisi ?? this.toplamVitesGecisi,
      vitesGecisleri: vitesGecisleri ?? this.vitesGecisleri,
      faz0Veriler: faz0Veriler ?? this.faz0Veriler,
      faz2Veriler: faz2Veriler ?? this.faz2Veriler,
      faz3Veriler: faz3Veriler ?? this.faz3Veriler,
      faz4Veriler: faz4Veriler ?? this.faz4Veriler,
      fazPuanlari: fazPuanlari ?? this.fazPuanlari,
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

    // 🔹 YENİ: DETAYLI RAPOR ALANLARI
    'cihazRaporu': cihazRaporu,
    'ortalamaBasinc': ortalamaBasinc,
    'dusukBasincSayisi': dusukBasincSayisi,
    'toplamVitesGecisi': toplamVitesGecisi,
    'vitesGecisleri': vitesGecisleri,
    'faz0Veriler': faz0Veriler,
    'faz2Veriler': faz2Veriler,
    'faz3Veriler': faz3Veriler,
    'faz4Veriler': faz4Veriler,
    'fazPuanlari': fazPuanlari,
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

      // 🔹 YENİ: DETAYLI RAPOR ALANLARI
      cihazRaporu: json['cihazRaporu'],
      ortalamaBasinc: (json['ortalamaBasinc'] ?? 0).toDouble(),
      dusukBasincSayisi: json['dusukBasincSayisi'] ?? 0,
      toplamVitesGecisi: json['toplamVitesGecisi'] ?? 0,
      vitesGecisleri: Map<String, int>.from(json['vitesGecisleri'] ?? {}),
      faz0Veriler: Map<String, dynamic>.from(json['faz0Veriler'] ?? {}),
      faz2Veriler: Map<String, dynamic>.from(json['faz2Veriler'] ?? {}),
      faz3Veriler: Map<String, dynamic>.from(json['faz3Veriler'] ?? {}),
      faz4Veriler: Map<String, dynamic>.from(json['faz4Veriler'] ?? {}),
      fazPuanlari: Map<String, int>.from(json['fazPuanlari'] ?? {}),
    );
  }

  String get formattedDate {
    return DateFormat('dd.MM.yyyy HH:mm').format(tarih);
  }

  // 🔹 Faz puanları toplamını hesapla
  double get fazPuanlariToplami {
    double toplam = 0;
    toplam += faz0Puan ?? 0;
    toplam += faz2Puan ?? 0;
    toplam += faz3Puan ?? 0;
    toplam += faz4Puan ?? 0;
    toplam += (bonusPuan ?? 0).toDouble();
    return toplam;
  }

  // 🔹 Tüm faz puanları mevcut mu?
  bool get tumFazPuanlariMevcut {
    return faz0Puan != null &&
        faz2Puan != null &&
        faz3Puan != null &&
        faz4Puan != null &&
        bonusPuan != null;
  }

  // 🔹 YENİ: Detaylı faz puanları mevcut mu?
  bool get detayliFazPuanlariMevcut {
    return fazPuanlari.isNotEmpty;
  }

  // 🔹 YENİ: Vites geçişleri toplamını hesapla
  int get vitesGecisleriToplam {
    if (vitesGecisleri.isEmpty) return toplamVitesGecisi;
    return vitesGecisleri.values.fold(0, (sum, count) => sum + count);
  }

  // 🔹 YENİ: En çok kullanılan vites
  String get enCokKullanilanVites {
    if (vitesGecisleri.isEmpty) return "Yok";

    final entries = vitesGecisleri.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    return entries.first.key;
  }

  // 🔹 YENİ: Basınç stabilitesi değerlendirmesi
  String get basincStabilitesi {
    final fark = maxBasinc - minBasinc;
    if (fark <= 5) return "Çok İyi";
    if (fark <= 10) return "İyi";
    if (fark <= 15) return "Orta";
    return "Zayıf";
  }

  // 🔹 YENİ: Rapor özeti
  String get raporOzeti {
    return '''
Test: $testAdi
Tarih: $formattedDate
Puan: $puan/100 - $sonuc
Basınç: ${minBasinc.toStringAsFixed(1)}-${maxBasinc.toStringAsFixed(1)} bar
Pompa Süresi: ${toplamPompaSuresi.toStringAsFixed(1)} sn
Vites Geçişleri: $toplamVitesGecisi
''';
  }

  @override
  String toString() {
    return 'TestVerisi{testAdi: $testAdi, puan: $puan, sonuc: $sonuc, tarih: $formattedDate}';
  }
}
