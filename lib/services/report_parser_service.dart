import '../models/test_verisi.dart';
import '../models/testmode_verisi.dart';
import '../utils/mekatronik_puanlama.dart';

class ReportParserService {

  /// Tam Test Raporunu parse eder ve TestVerisi nesnesi döndürür.
  TestVerisi parseFullReport(String report, String testName, double currentMinPressure, double currentMaxPressure) {
    try {
      // Genel bilgiler
      final minBasincMatch = RegExp(r'Min Basınç:\s*([\d.]+)').firstMatch(report);
      final maxBasincMatch = RegExp(r'Max Basınç:\s*([\d.]+)').firstMatch(report);
      final pompaSureMatch = RegExp(r'Toplam Pompa:\s*(\d+)\s*dk\s*(\d+)\s*sn').firstMatch(report);

      // FAZ puanları
      final fazPuanlari = <String, int>{};
      final fazPuanRegex = RegExp(r'FAZ\s*(\d+):\s*(\d+)/(\d+)');
      for (final match in fazPuanRegex.allMatches(report)) {
        fazPuanlari['faz${match.group(1)}'] = int.parse(match.group(2)!);
      }

      // Puan hesaplama
      final genelPuanMatch = RegExp(r'GENEL PUAN:\s*([\d.]+)/100').firstMatch(report);
      final mekatronikPuanMatch = RegExp(r'TOPLAM PUAN:\s*(\d+)/100').firstMatch(report);

      int finalPuan = 0;
      if (mekatronikPuanMatch != null) {
        finalPuan = int.parse(mekatronikPuanMatch.group(1)!);
      } else if (genelPuanMatch != null) {
        finalPuan = double.parse(genelPuanMatch.group(1)!).round();
      }

      // Pompa süresi hesapla
      double toplamPompaSuresi = 0;
      if (pompaSureMatch != null) {
        final dakika = int.tryParse(pompaSureMatch.group(1) ?? '0') ?? 0;
        final saniye = int.tryParse(pompaSureMatch.group(2) ?? '0') ?? 0;
        toplamPompaSuresi = (dakika * 60 + saniye).toDouble();
      }

      return _parseFullReportLogic(report, testName, currentMinPressure, currentMaxPressure);
    } catch (e) {
      throw Exception("Rapor parse hatası: $e");
    }
  }

  TestVerisi _parseFullReportLogic(String report, String testName, double minP, double maxP) {
    // ... Eski kodlarınız buraya ...
    // Sadece örnek olması için boş bir return koyuyorum, siz eski kodu koruyun.
    // Eğer tam rapor parsing kodu lazım ise belirtin, onu da atarım.
    final minBasincMatch = RegExp(r'Min Basınç:\s*([\d.]+)').firstMatch(report);
    // ...
    return TestVerisi(
        testAdi: testName,
        tarih: DateTime.now(),
        minBasinc: double.tryParse(minBasincMatch?.group(1) ?? '0') ?? minP,
        maxBasinc: maxP,
        toplamPompaSuresi: 0,
        puan: 0,
        sonuc: "BELİRSİZ"
    );
  }

  /// Test Modu Raporunu parse eder.
  TestModuRaporu parseTestModuRaporu(String report, int currentTestMode) {
    try {
      // 1. Basınç Değerleri
      // "Min Basınç: 38.0 bar" satırını bulur, baştaki saati yutar (.*?)
      final minP = _extractDouble(report, r'Min Basınç:.*?([\d.]+)');
      final maxP = _extractDouble(report, r'Max Basınç:.*?([\d.]+)');
      final avgP = _extractDouble(report, r'Ortalama Basınç:.*?([\d.]+)');

      // 2. Pompa Süresi
      // "Toplam Pompa Çalışma Süresi: 0 dk 6 sn"
      int pompaSn = 0;
      final pompaMatch = RegExp(r'Pompa.*?Süresi:.*?(\d+)\s*dk.*?(\d+)\s*sn').firstMatch(report);

      if (pompaMatch != null) {
        pompaSn = (int.parse(pompaMatch.group(1) ?? '0') * 60) + int.parse(pompaMatch.group(2) ?? '0');
      }

      // 3. Düşük Basınç Verileri
      // "(<40 bar)" ifadesini atlayıp sayıyı alır
      final dusukBasincSayisi = _extractInt(report, r'Düşük Basınç.*?Sayısı:.*?(\d+)');
      final dusukBasincSure = _extractInt(report, r'Düşük Basınç Süresi:.*?(\d+)');

      // 4. Toplam Vites Geçişi
      final toplamVites = _extractInt(report, r'Toplam Vites Geçişi Sayısı:.*?(\d+)');

      // 5. Vites Geçiş Detayları (EN ÖNEMLİ KISIM)
      final vitesGecisleri = <String, int>{};

      // Regex Açıklaması:
      // .*?       -> Satır başındaki tarih ve her şeyi yut
      // (\d+)     -> Vites numarasını yakala (1, 2, 3...)
      // \.        -> Nokta
      // \s*Vites: -> " Vites:" kelimesi
      // \s*(\d+)  -> Sonuç sayısını yakala

      final vitesRegex = RegExp(r'.*?(\d+)\.\s*Vites:\s*(\d+)');
      for (final match in vitesRegex.allMatches(report)) {
        vitesGecisleri['V${match.group(1)}'] = int.parse(match.group(2)!);
      }

      // R Vites için özel kontrol (Tarih saat olsa bile yakalar)
      // Örnek: "14:48:03.379     R Vites: 1"
      final rVitesMatch = RegExp(r'.*?R\s*Vites:\s*(\d+)', caseSensitive: false).firstMatch(report);
      if (rVitesMatch != null) {
        vitesGecisleri['VR'] = int.parse(rVitesMatch.group(1)!);
      }

      // Eğer ana toplam 0 geldiyse (okunamadıysa), detayları toplayarak düzelt
      int finalToplamVites = toplamVites;
      if (finalToplamVites == 0 && vitesGecisleri.isNotEmpty) {
        finalToplamVites = vitesGecisleri.values.fold(0, (sum, val) => sum + val);
      }

      return TestModuRaporu(
        tarih: DateTime.now(),
        testModu: currentTestMode,
        minBasinc: minP,
        maxBasinc: maxP,
        ortalamaBasinc: avgP,
        toplamPompaCalismaSuresiSn: pompaSn,
        dusukBasincSayisi: dusukBasincSayisi,
        toplamDusukBasincSuresiSn: dusukBasincSure,
        toplamVitesGecisSayisi: finalToplamVites,
        vitesGecisleri: vitesGecisleri,
      );

    } catch (e) {
      print("Test modu raporu parse hatası: $e");
      // Hata durumunda güvenli boş nesne döndür
      return TestModuRaporu(
        tarih: DateTime.now(),
        testModu: currentTestMode,
        minBasinc: 0, maxBasinc: 0, ortalamaBasinc: 0,
        toplamPompaCalismaSuresiSn: 0, dusukBasincSayisi: 0,
        toplamDusukBasincSuresiSn: 0, toplamVitesGecisSayisi: 0,
        vitesGecisleri: {},
      );
    }
  }

  // Yardımcı: Double parse (Hata vermez, 0.0 döner)
  double _extractDouble(String text, String pattern) {
    try {
      final match = RegExp(pattern, caseSensitive: false, multiLine: true).firstMatch(text);
      if (match != null) {
        return double.tryParse(match.group(1) ?? '0') ?? 0.0;
      }
    } catch (_) {}
    return 0.0;
  }

  // Yardımcı: Int parse (Hata vermez, 0 döner)
  int _extractInt(String text, String pattern) {
    try {
      final match = RegExp(pattern, caseSensitive: false, multiLine: true).firstMatch(text);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '0') ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  String _parseDurum(String report) {
    if (report.contains("DURUM: KÖTÜ")) return "KÖTÜ";
    if (report.contains("DURUM: SORUNLU")) return "SORUNLU";
    if (report.contains("DURUM: ORTA")) return "ORTA";
    if (report.contains("DURUM: İYİ")) return "İYİ";
    if (report.contains("DURUM: MÜKEMMEL")) return "MÜKEMMEL";
    return "BELİRSİZ";
  }
}