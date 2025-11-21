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

  TestModuRaporu parseTestModuRaporu(String report, int currentTestMode) {
    try {
      // 1. Pressure Values
      // Uses .*? to skip timestamp at start of line
      final minP = _extractDouble(report, r'.*?Min Basınç:.*?([\d.]+)');
      final maxP = _extractDouble(report, r'.*?Max Basınç:.*?([\d.]+)');
      final avgP = _extractDouble(report, r'.*?Ortalama Basınç:.*?([\d.]+)');

      // 2. Pump Duration
      // Matches: "14:48:03.379 Toplam Pompa Çalışma Süresi: 0 dk 6 sn"
      int pompaSn = 0;
      final pompaMatch = RegExp(r'.*?Pompa.*?Süresi:.*?(\d+)\s*dk.*?(\d+)\s*sn').firstMatch(report);

      if (pompaMatch != null) {
        pompaSn = (int.parse(pompaMatch.group(1) ?? '0') * 60) + int.parse(pompaMatch.group(2) ?? '0');
      }

      // 3. Low Pressure Stats
      // Matches: "Düşük Basınç (<40 bar) Sayısı: 2"
      final dusukBasincSayisi = _extractInt(report, r'.*?Düşük Basınç.*?Sayısı:.*?(\d+)');
      final dusukBasincSure = _extractInt(report, r'.*?Düşük Basınç Süresi:.*?(\d+)');

      // 4. Total Gear Shifts
      final toplamVites = _extractInt(report, r'.*?Toplam Vites Geçişi Sayısı:.*?(\d+)');

      // 5. Gear Shift Details (CRITICAL FIX)
      final vitesGecisleri = <String, int>{};

      // Regex Explanation:
      // .*?        -> Match any character (timestamp, whitespace) lazily until...
      // (\d+)      -> Capture the Gear Number (1, 2, etc.)
      // \.         -> Literal dot
      // \s*Vites:  -> Whitespace followed by "Vites:"
      // \s*(\d+)   -> Capture the count value

      final vitesRegex = RegExp(r'.*?(\d+)\.\s*Vites:\s*(\d+)');
      for (final match in vitesRegex.allMatches(report)) {
        vitesGecisleri['V${match.group(1)}'] = int.parse(match.group(2)!);
      }

      // Special Regex for Reverse Gear (R)
      // Matches: "14:48:03.381    R Vites: 1"
      final rVitesMatch = RegExp(r'.*?R\s*Vites:\s*(\d+)', caseSensitive: false).firstMatch(report);
      if (rVitesMatch != null) {
        vitesGecisleri['VR'] = int.parse(rVitesMatch.group(1)!);
      }

      // Fallback: If Total Count is 0 but we found details, sum them up
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
      // Return safe empty object on error
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

  // Helper: Extract Double safely
  double _extractDouble(String text, String pattern) {
    try {
      final match = RegExp(pattern, caseSensitive: false, multiLine: true).firstMatch(text);
      if (match != null) {
        return double.tryParse(match.group(1) ?? '0') ?? 0.0;
      }
    } catch (_) {}
    return 0.0;
  }

  // Helper: Extract Int safely
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