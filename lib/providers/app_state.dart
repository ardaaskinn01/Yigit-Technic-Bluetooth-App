import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/test_verisi.dart';
import '../services/bluetooth_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../utils/mekatronik_puanlama.dart';

enum TestPhase {
  idle,         // Test duruyor
  phase0,       // Pompa testi
  phase1,       // Basınç dengeleme
  phase2,       // Valf testleri
  phase3,       // Vites testleri
  phase4,       // Dayanıklılık
  completed,    // Test tamamlandı
}

class AppState extends ChangeNotifier {
  final BluetoothService bt = BluetoothService();

  // Live values
  double pressure = 0;
  String gear = '-';
  bool pumpOn = false;
  String lastMessage = '';
  bool pressureToggle = true;
  Map<String, dynamic> testResults = {};
  dynamic myPressureSensor;
  dynamic myPump;
  dynamic myGearSensor;
  bool isK1K2Mode = false;
  double _currentMinPressure = double.infinity;
  double _currentMaxPressure = 0.0;
  bool isPaused = false;
  bool testFinished = false;
  List<TestVerisi> completedTests = [];
  bool get testPaused => isPaused;
  String _currentTestName = '';
  double faz0Sure = 0;
  Map<String, double> faz2Sonuclar = {}; // Anahtarlar: N436, N440, N436+N440, Kapali
  Map<String, double> faz3Sonuclar = {}; // Anahtarlar: V1, V2, V3_7, V4_6, V5, VR
  double faz4PompaSuresi = 0;
  String autoCycleMode = '0';

  bool isReconnecting = false;
  Timer? _connectionMonitorTimer;
  Timer? _testModeTimer; // 🔹 BU SATIRI EKLEYİN - Test modu timer'ı

// Getter metodları ekle
  int get elapsedSeconds => _elapsedTestSeconds;
  double get minBasinc => _currentMinPressure;
  double get maxBasinc => _currentMaxPressure;

  bool n436Active = false;
  bool n440Active = false;
  double faz1Pompa = 0;
  double faz2Pompa = 0;
  Map<String, double> faz3Vitesler = {};
  double faz4Pompa = 0;
  TestPhase currentPhase = TestPhase.idle;
  bool isTesting = false;
  double phaseProgress = 0.0;
  String phaseStatusMessage = "";
  Timer? _phaseTimer;
  List<BluetoothDevice> discoveredDevices = [];
  // Test fazları için timer
  Timer? _testTimer;
  int _elapsedTestSeconds = 0;

// Test verileri
  double _faz0Sure = 0.0;
  Map<String, double> _faz2Sonuclar = {};
  Map<String, double> _faz3Sonuclar = {};
  double _faz4PompaSuresi = 0.0;
  int _faz4VitesSayisi = 0;
  // Yeni eklenen değişkenler
  bool isConnected = false;
  String operationTime = '0sn'; // Çalışma süresi
  String selectedGear = 'BOŞ'; // Seçili vites
  int testDuration = 0; // Test süresi (saniye)
  String testStatus = 'Hazır'; // Test durumu
  final List<Map<String, dynamic>> testRecords = [];
  bool isScanning = false;
  String connectionMessage = "";
  String? connectingAddress;
  int selectedMode = 0; // 0 = Kapalı
  int currentTestMode = 0; // 0 = kapalı, 1-7 = test modları
  bool isTestModeActive = false;
  final Map<int, double> testModeDelays = {
    1: 1.0,
    2: 1.2,
    3: 0.4,
    4: 0.7,
    5: 2.0,
    6: 5.0,
    7: 0.1,
  };
  final Map<int, String> testModeDescriptions = {
    1: "Çok Hızlı - Yüksek hız testi",
    2: "Çok Hızlı - Orta-yüksek hız",
    3: "Ultra Hızlı - FAZ 0/2 pompa kontrolü",
    4: "Hızlı - FAZ 4 standart test",
    5: "Normal - Genel kontrol",
    6: "Yavaş - Detaylı gözlem",
    7: "En Hızlı - SÖKME modu",
  };

  void setMode(int mode) {
    selectedMode = mode;
    notifyListeners();
  }

  Map<String, bool> valveStates = {
    'N440': false,
    'N436': false,
    'N436': false,
    'K1': false,
    'K2': false,
    'N433': false,
    'N438': false,
    'N434': false,
    'N437': false,
  };

  void startTestMode(int mode) {
    if (mode < 1 || mode > 7) return;

    currentTestMode = mode;
    isTestModeActive = true;

    // Test modu komutunu gönder
    sendCommand(mode.toString());

    // Test 7 için özel mesaj
    if (mode == 7) {
      connectionMessage = "SÖKME MODU AKTİF - Basınç düşürülüyor";
      logs.add("🚨 SÖKME Modu başlatıldı (0.1ms) - Sistem boşaltılıyor");
    } else {
      connectionMessage = "Test Mod $mode aktif: ${testModeDescriptions[mode]}";
      logs.add("Test Mod $mode başlatıldı (${testModeDelays[mode]}ms bekleme)");
    }

    notifyListeners();
  }

// Test modunu durdur
  void stopTestMode() {
    // Test 7 için özel log
    if (currentTestMode == 7) {
      logs.add("✅ SÖKME Modu durduruldu - Sistem güvenli");
    }

    currentTestMode = 0;
    isTestModeActive = false;

    // Test modu timer'ını temizle
    _testModeTimer?.cancel();
    _testModeTimer = null;

    // Test modu kapatma komutunu gönder
    sendCommand("0");

    // Pompayı kapat (test modu bitince)
    pumpOn = false;

    // Vitesi BOŞ'a al
    gear = 'BOŞ';
    updateValvesByGear(gear);

    connectionMessage = "Test modu kapatıldı";
    logs.add("Test modu durduruldu - Tüm sistem sıfırlandı");

    notifyListeners();
  }
  Future<void> loadTestsFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('saved_tests') ?? [];
    completedTests = saved
        .map((s) => TestVerisi.fromJson(Map<String, dynamic>.from(json.decode(s))))
        .toList();
    notifyListeners();
  }

  Future<void> startAutoTest(String testAdi) async {
    if (isTesting) return;

    testStatus = 'Test Başlatılıyor...';
    isTesting = true;
    _elapsedTestSeconds = 0;
    _faz0Sure = 0.0;
    _faz2Sonuclar.clear();
    _faz3Sonuclar.clear();
    _faz4PompaSuresi = 0.0;
    _faz4VitesSayisi = 0;

    notifyListeners();

    // TEST komutunu gönder
    sendCommand("TEST");

    // Timer başlat
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedTestSeconds++;
      _updateTestStatus();
      notifyListeners();
    });
  }


  void _updateTestStatus() {
    // Test durumunu güncelle
    if (_elapsedTestSeconds < 10) {
      testStatus = 'FAZ 0: Pompa Testi';
    } else if (_elapsedTestSeconds < 70) {
      testStatus = 'FAZ 2: Basınç Valf Testleri';
    } else if (_elapsedTestSeconds < 340) { // 70 + (6*45) = 340
      testStatus = 'FAZ 3: Vites Testleri';
    } else {
      testStatus = 'FAZ 4: Dayanıklılık Testi';
    }
  }

  void _completeTest() {
    _testTimer?.cancel();
    isTesting = false;
    testStatus = 'Test Tamamlandı';

    // Puan hesapla
    final puan = _calculateTotalScore();
    final sonuc = _getTestResult(puan);

    // Test verisini oluştur
    final test = TestVerisi(
      testAdi: _currentTestName,
      tarih: DateTime.now(),
      fazAdi: "Otomatik Tam Test",
      minBasinc: _currentMinPressure,
      maxBasinc: _currentMaxPressure,
      toplamPompaSuresi: _faz0Sure + _faz4PompaSuresi,
      vitesSayisi: _faz4VitesSayisi,
      puan: puan,
      sonuc: sonuc,
      mockModu: mockMode,
      faz0Sure: _faz0Sure,
      faz2Sonuclar: _faz2Sonuclar,
      faz3Sonuclar: _faz3Sonuclar,
      faz4PompaSuresi: _faz4PompaSuresi,
    );

    // Kaydet ve callback gönder
    _saveTestAndShowResult(test);
  }

  Future<void> startFullTest(String testAdi) async {
    if (isTesting) return;

    // Durumları sıfırla
    isTesting = true;
    testFinished = false;
    currentPhase = TestPhase.idle; // Başlangıçta IDLE
    final startTime = DateTime.now();

    // Sonuç değişkenlerini sıfırla
    double minPressure = double.infinity;
    double maxPressure = 0;
    double totalPumpSeconds = 0;
    int gearChanges = 0;
    faz0Sure = 0;
    faz2Sonuclar = {};
    faz3Sonuclar = {};
    faz4PompaSuresi = 0;

    phaseStatusMessage = "Tam Otomatik Test Başlatılıyor: $testAdi";
    testStatus = 'Çalışıyor';
    logs.add(phaseStatusMessage);
    notifyListeners();

    // -----------------------------------------------------
    // Simülasyon: TEST komutunu gönder
    // -----------------------------------------------------
    sendCommand("TEST"); // Cihaz otomatik fazlara başlar varsayılır

    try {
      // -----------------------------------------------------
      // FAZ 0: POMPA YÜKSELME TESTİ (10 Puan)
      // -----------------------------------------------------
      currentPhase = TestPhase.phase0;
      phaseStatusMessage = "FAZ 0: Pompa Yükselme Testi (Hedef: 60 bar)";
      logs.add(phaseStatusMessage);
      notifyListeners();
      faz0Sure = await _runPhase0(minPressure, maxPressure); // Süre simülasyonu
      logs.add("Faz 0 Tamamlandı. Süre: ${faz0Sure.toStringAsFixed(2)} sn");


      // -----------------------------------------------------
      // FAZ 2: BASINÇ VALFİ TESTLERİ (20 Puan)
      // -----------------------------------------------------
      currentPhase = TestPhase.phase2;
      phaseStatusMessage = "FAZ 2: Basınç Valfi Sızdırmazlık Testleri";
      logs.add(phaseStatusMessage);
      notifyListeners();
      faz2Sonuclar = await _runPhase2();
      logs.add("Faz 2 Tamamlandı. Sonuçlar: $faz2Sonuclar");

      // -----------------------------------------------------
      // FAZ 3: VİTES TESTLERİ (35 Puan)
      // -----------------------------------------------------
      currentPhase = TestPhase.phase3;
      phaseStatusMessage = "FAZ 3: Vites Basınç Tutma Testleri";
      logs.add(phaseStatusMessage);
      notifyListeners();
      faz3Sonuclar = await _runPhase3();
      logs.add("Faz 3 Tamamlandı. Sonuçlar: $faz3Sonuclar");


      // -----------------------------------------------------
      // FAZ 4: DAYANIKLILIK TESTİ (20 Puan)
      // -----------------------------------------------------
      currentPhase = TestPhase.phase4;
      phaseStatusMessage = "FAZ 4: Dayanıklılık Testi (10 dk)";
      logs.add(phaseStatusMessage);
      notifyListeners();

      // Bu fazda tüm pompa/vites istatistiklerini toplayalım
      final stats = await _runPhase4();
      totalPumpSeconds = stats['pumpSeconds'];
      gearChanges = stats['gearChanges'];
      minPressure = stats['minPressure'];
      maxPressure = stats['maxPressure'];
      faz4PompaSuresi = totalPumpSeconds; // Faz 4 özel pompa süresi

      logs.add("Faz 4 Tamamlandı. Pompa Süresi: ${totalPumpSeconds.toStringAsFixed(1)} sn");

      // -----------------------------------------------------
      // TEST BİTİRME & PUANLAMA & KAYDETME
      // -----------------------------------------------------

      // Toplam Pompa Süresi (Faz 0, 2, 3, 4'ten toplanan kısım kullanılabilir, ancak kılavuz Faz 4 pompa süresini puanlıyor. Faz 4'ü kullanalım.)
      // Diğer fazların pompa sürelerini kaydetmediğimiz için sadece Faz 4'ü kullanıyoruz.
      // Toplam vites değişimi de Faz 4'ten geliyor.

      // Puan Hesaplama (Faz 0, 2, 3 ve 4 verileri ile)
      final puan = MekatronikPuanlama.hesapla(
        faz0Sure,
        faz2Sonuclar['Kapali'] ?? 0.0, // Faz 2 için toplam sızdırmazlık verisini al
        faz3Sonuclar,
        faz4PompaSuresi,
      );

      final sonuc = MekatronikPuanlama.durum(puan);

      final test = TestVerisi(
        testAdi: testAdi,
        tarih: startTime,
        fazAdi: "Tam Otomatik Protokol", // Genel bir isim
        minBasinc: minPressure,
        maxBasinc: maxBasinc,
        toplamPompaSuresi: totalPumpSeconds,
        vitesSayisi: gearChanges,
        puan: puan,
        sonuc: sonuc,
        mockModu: mockMode,
        faz0Sure: faz0Sure,
        faz2Sonuclar: faz2Sonuclar,
        faz3Sonuclar: faz3Sonuclar,
        faz4PompaSuresi: faz4PompaSuresi,
      );

      // Puanlama, sonuç oluşturma ve kaydetme
      await saveTest(test);
      testStatus = 'Tamamlandı';
      currentPhase = TestPhase.completed;
      phaseStatusMessage = "Test tamamlandı ($sonuc - Puan: $puan)";
      logs.add(phaseStatusMessage);

    } catch (e) {
      logs.add("TEST HATASI: $e");
      testStatus = 'Hata';
      phaseStatusMessage = "Test hata ile sonlandı: $e";
    } finally {
      sendCommand("TEST_STOP");
      isTesting = false;
      testFinished = true;

      // ✅ CRITICAL: Callback tetikle
      if (onTestCompleted != null && completedTests.isNotEmpty) {
        onTestCompleted!(completedTests.last);
      }
      notifyListeners();
    }
  }

  // Faz 0 Simülasyonu
  // Faz 0 Simülasyonu - Gerçekçi süre (8-15 saniye)
  Future<double> _runPhase0(double minP, double maxP) async {
    phaseProgress = 0.0;
    const int totalDuration = 12; // Ortalama 12 saniye

    for (int i = 0; i <= totalDuration; i++) {
      if (!isTesting || isPaused) break;

      await Future.delayed(const Duration(seconds: 1));
      phaseProgress = i / totalDuration;

      // Basınç artışını simüle et
      pressure = 20.0 + (i / totalDuration) * 40.0;
      _currentMinPressure = min(_currentMinPressure, pressure);
      _currentMaxPressure = max(_currentMaxPressure, pressure);

      phaseStatusMessage = "FAZ 0: Pompa Yükselme Testi - ${pressure.toStringAsFixed(1)} bar";
      notifyListeners();
    }

    return 8.0 + Random().nextDouble() * 7.0; // 8.0 - 15.0 sn
  }

// Faz 2 Simülasyonu - Gerçekçi süre (60 saniye)
  Future<Map<String, double>> _runPhase2() async {
    phaseProgress = 0.0;
    final results = <String, double>{};
    final random = Random();
    const int totalDuration = 60; // 60 saniye
    const List<String> tests = ['N436', 'N440', 'N436+N440', 'Kapali'];

    for (int testIndex = 0; testIndex < tests.length; testIndex++) {
      String testName = tests[testIndex];
      phaseStatusMessage = "FAZ 2: $testName Testi Yapılıyor...";
      phaseProgress = testIndex / tests.length;
      notifyListeners();

      // Her test için 15 saniye simülasyon
      for (int i = 0; i < 15; i++) {
        if (!isTesting || isPaused) break;
        await Future.delayed(const Duration(seconds: 1));

        // Basınç düşüşünü simüle et
        pressure = 60.0 - (i / 15.0) * 10.0;
        phaseStatusMessage = "FAZ 2: $testName - ${pressure.toStringAsFixed(1)} bar";
        notifyListeners();
      }

      // Test sonucunu kaydet
      switch (testName) {
        case 'N436':
          results['N436'] = 1.5 + random.nextDouble() * 4.0;
          break;
        case 'N440':
          results['N440'] = 1.0 + random.nextDouble() * 3.0;
          break;
        case 'N436+N440':
          results['N436+N440'] = 2.0 + random.nextDouble() * 5.0;
          break;
        case 'Kapali':
          results['Kapali'] = 0.5 + random.nextDouble() * 1.5;
          break;
      }

      if (!isTesting) break;
    }

    phaseProgress = 1.0;
    return results;
  }

// Faz 3 Simülasyonu - Gerçekçi süre (270 saniye = 4.5 dakika)
  Future<Map<String, double>> _runPhase3() async {
    phaseProgress = 0.0;
    final results = <String, double>{};
    final random = Random();
    const List<String> vitesler = ['V1', 'V2', 'V3_7', 'V4_6', 'V5', 'VR'];
    const int testPerGear = 45; // Her vites için 45 saniye

    for (int gearIndex = 0; gearIndex < vitesler.length; gearIndex++) {
      String vites = vitesler[gearIndex];
      phaseStatusMessage = "FAZ 3: $vites Vites Testi";
      phaseProgress = gearIndex / vitesler.length;
      notifyListeners();

      // Vites değişimi simülasyonu
      gear = vites.replaceAll('V', '').replaceAll('_', '/');
      updateValvesByGear(gear);

      // 45 saniyelik test
      for (int i = 0; i < testPerGear; i++) {
        if (!isTesting || isPaused) break;
        await Future.delayed(const Duration(seconds: 1));

        // Basınç tutma simülasyonu
        double pressureDrop = (i / testPerGear) * 8.0;
        pressure = 60.0 - pressureDrop;

        phaseStatusMessage = "FAZ 3: $vites - ${pressure.toStringAsFixed(1)} bar";
        phaseProgress = (gearIndex + (i / testPerGear)) / vitesler.length;
        notifyListeners();
      }

      // Test sonucunu kaydet
      switch (vites) {
        case 'V1':
          results['V1'] = 1.0 + random.nextDouble() * 5.0;
          break;
        case 'V2':
          results['V2'] = 1.5 + random.nextDouble() * 5.0;
          break;
        case 'V3_7':
          results['V3_7'] = 2.0 + random.nextDouble() * 5.0;
          break;
        case 'V4_6':
          results['V4_6'] = 1.0 + random.nextDouble() * 5.0;
          break;
        case 'V5':
          results['V5'] = 0.5 + random.nextDouble() * 4.0;
          break;
        case 'VR':
          results['VR'] = 2.5 + random.nextDouble() * 6.0;
          break;
      }

      if (!isTesting) break;
    }

    phaseProgress = 1.0;
    return results;
  }

// Faz 4 Simülasyonu - Gerçekçi süre (120 saniye = 2 dakika)
  Future<Map<String, dynamic>> _runPhase4() async {
    phaseProgress = 0.0;
    const int totalDuration = 120; // 2 dakika
    final random = Random();

    double pumpTime = 0;
    int gearChanges = 0;
    double minP = double.infinity;
    double maxP = 0;

    for (int i = 0; i <= totalDuration; i++) {
      if (!isTesting || isPaused) break;

      await Future.delayed(const Duration(seconds: 1));
      phaseProgress = i / totalDuration;

      // Dayanıklılık testi simülasyonu
      if (i % 10 == 0) { // Her 10 saniyede bir vites değişimi
        gearChanges++;
        List<String> gears = ['1', '2', '3', '4', '5', '6', 'R'];
        gear = gears[random.nextInt(gears.length)];
        updateValvesByGear(gear);
      }

      // Pompa çalışma süresi (rastgele aç/kapa)
      if (random.nextDouble() > 0.3) { // %70 ihtimalle pompa açık
        pumpOn = true;
        pumpTime++;
        pressure = 50.0 + random.nextDouble() * 15.0;
      } else {
        pumpOn = false;
        pressure = 45.0 + random.nextDouble() * 10.0;
      }

      minP = min(minP, pressure);
      maxP = max(maxP, pressure);

      phaseStatusMessage = "FAZ 4: Dayanıklılık Testi - ${gearChanges} vites değişimi";
      notifyListeners();
    }

    return {
      'pumpSeconds': 40.0 + random.nextDouble() * 50.0,
      'gearChanges': 100 + random.nextInt(50),
      'minPressure': minP,
      'maxPressure': maxP,
    };
  }

  int _calculateTotalScore() {
    int toplam = 0;

    // FAZ 0 Puanı (10 puan)
    if (_faz0Sure <= 8) toplam += 10;
    else if (_faz0Sure <= 12) toplam += 7;
    else toplam += 3;

    // FAZ 2 Puanı (20 puan)
    double faz2Ortalama = _faz2Sonuclar.values.fold(0.0, (a, b) => a + b) / _faz2Sonuclar.length;
    if (faz2Ortalama < 2) toplam += 20;
    else if (faz2Ortalama <= 5) toplam += 15;
    else toplam += 5;

    // FAZ 3 Puanı (35 puan)
    double faz3Ortalama = _faz3Sonuclar.values.fold(0.0, (a, b) => a + b) / _faz3Sonuclar.length;
    if (faz3Ortalama < 3) toplam += 35;
    else if (faz3Ortalama <= 6) toplam += 25;
    else toplam += 10;

    // FAZ 4 Puanı (20 puan)
    if (_faz4PompaSuresi < 55) toplam += 20;
    else if (_faz4PompaSuresi <= 80) toplam += 15;
    else toplam += 5;

    // Bonus puan (15 puan)
    if (toplam >= 80) toplam += 15;
    else if (toplam >= 60) toplam += 8;

    return toplam.clamp(0, 100);
  }

  String _getTestResult(int puan) {
    if (puan >= 85) return "MÜKEMMEL";
    if (puan >= 70) return "İYİ";
    if (puan >= 50) return "ORTA";
    return "ZAYIF";
  }

// Test sonucu callback'i
  Function(TestVerisi)? onTestCompleted;

  void _saveTestAndShowResult(TestVerisi test) async {
    await saveTest(test);
    if (onTestCompleted != null) {
      onTestCompleted!(test);
    }
  }

// Test durdurma
  void stopAutoTest() {
    _testTimer?.cancel();
    isTesting = false;
    testStatus = 'Test Durduruldu';
    sendCommand("TEST_DURDUR");
    notifyListeners();
  }

  Future<void> saveTest(TestVerisi test) async {
    completedTests.add(test);
    final prefs = await SharedPreferences.getInstance();
    final encoded = completedTests.map((t) => json.encode(t.toJson())).toList();
    await prefs.setStringList('saved_tests', encoded);
    notifyListeners();
  }

  void pauseTest() {
    if (!isTesting) return;
    isPaused = !isPaused;
    testStatus = isPaused ? 'Duraklatıldı' : 'Çalışıyor';
    notifyListeners();
  }

  void stopTest() {
    if (!isTesting) return;
    isTesting = false;
    testStatus = 'Tamamlandı';
    testFinished = true;
    currentPhase = TestPhase.completed;
    notifyListeners();
  }

  void toggleValve(String key) {
    if (!valveStates.containsKey(key)) return;

    // Eğer mod kapalıysa K1/K2 değiştirilemez
    if (!isK1K2Mode && (key == 'K1' || key == 'K2')) return;

    valveStates[key] = !(valveStates[key] ?? false);
    sendCommand(valveStates[key]! ? key : key);

    enforceK1K2Rules(); // güvenlik
    notifyListeners();
  }

  void startSokmeModu() {
    sendCommand("SOKME");
    connectionMessage = "Sökme modu başlatıldı (basınç boşaltılıyor)";
    notifyListeners();
  }

  void startTemizlemeModu() {
    sendCommand("TEMIZLE");
    connectionMessage = "Temizleme modu başlatıldı (10 döngü çalışıyor)";
    notifyListeners();
  }

// 🧱 Yeni eklendi
  void startPistonKacagiModu() {
    sendCommand("PK");
    connectionMessage = "Piston kaçağı testi başlatıldı";
    notifyListeners();
  }

  // Logs & reports
  final List<String> logs = [];

  StreamSubscription<String>? _sub;

  // configuration (defaults)
  String deviceName = 'DQ200-MasterControl';
  String deviceAddress = ''; // set device MAC from settings
  bool autoConnect = true;

  // Timer for operation time
  Timer? _operationTimer;
  int _operationSeconds = 0;

  final bool mockMode; // <- yeni

  void updateValvesFromMessage(String msg) {
    if (!msg.startsWith('VALVES:')) return;

    final data = msg.replaceFirst('VALVES:', '').split(',');
    for (var pair in data) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        final key = parts[0].trim();
        final val = parts[1].trim();
        if (valveStates.containsKey(key)) {
          // Eğer K1/K2 ise ve mod kapalıysa uygulama yapma
          if (!isK1K2Mode && (key == 'K1' || key == 'K2')) {
            valveStates[key] = false;
          } else {
            valveStates[key] = (val == '1' || val.toLowerCase() == 'on');
          }
        }
      }
    }

    enforceK1K2Rules();
    notifyListeners();
  }

  AppState({this.mockMode = false}) {
    _startOperationTimer();
    _init();

    if (mockMode) {
      _simulateConnection();
    }
  }


  Future<void> _init() async {
    await _loadPrefs();
    notifyListeners();
  }

  void clearTests() async {
    testResults.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_tests');
    notifyListeners();
  }

  void setPressureToggle(bool value) {
    pressureToggle = value;
    notifyListeners();
  }

  void _startOperationTimer() {
    _operationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _operationSeconds++;
      operationTime = '${_operationSeconds}sn';
      notifyListeners();
    });
  }

  void setValveState(String valve, bool state) {
    if (!valveStates.containsKey(valve)) return;

    // Eğer K1/K2 modu kapalıysa K1 veya K2 elle değiştirilmesin
    if (!isK1K2Mode && (valve == 'K1' || valve == 'K2')) {
      return; // ignore
    }

    valveStates[valve] = state;
    enforceK1K2Rules();
    notifyListeners();
  }


  void setK1K2Mode(bool value) {
    isK1K2Mode = value;

    notifyListeners();
  }

  void _simulateConnection() {
    isConnected = true;
    pressure = 50;
    gear = '1';
    pumpOn = false;
    testStatus = 'Hazır';
    lastMessage = '[MOCK] Cihaz simülasyonu başladı';
    logs.add(lastMessage);
    notifyListeners();

    final random = Random();
    int mechatronicScore = 0;
    Timer? _testModeTimer;

    // 🔁 Ana simülasyon döngüsü
    Timer.periodic(const Duration(seconds: 2), (t) {
      if (!isConnected) return;

      // Test modu aktifse özel işlemler yap
      if (isTestModeActive && currentTestMode > 0) {
        // Test modu simülasyonu burada yapılacak
        _simulateTestMode();
        return; // Test modu aktifken normal simülasyonu atla
      }

      // 1️⃣ Normal modda basınç değeri
      double minPressure = pressureToggle ? 52 : 42;
      double maxPressure = 60;
      pressure = minPressure + random.nextDouble() * (maxPressure - minPressure);

      // 2️⃣ Vites durumuna göre valfleri ayarla
      _updateValvesByGear(gear);

      // 3️⃣ Basınç Valfi manuel kontrol bilgisi
      lastMessage =
      '[MOCK] Güncel basınç: ${pressure.toStringAsFixed(2)} bar | N436=${valveStates['N436']} N440=${valveStates['N440']} | Vites=$gear';

      // 4️⃣ Mekatronik Puan
      if (testStatus == 'Çalışıyor') {
        mechatronicScore = min(100, mechatronicScore + random.nextInt(3));
        lastMessage += ' | Mekatronik Puan: $mechatronicScore';
      }

      enforceK1K2Rules();
      logs.add(lastMessage);
      notifyListeners();
    });
  }

  void _simulateTestMode() {
    if (!isTestModeActive || currentTestMode == 0) return;

    // Test moduna göre vites döngüsü hızı
    final delaySeconds = _getTestModeDelay();

    // Test modu timer'ını başlat (eğer başlatılmadıysa)
    _testModeTimer ??= Timer.periodic(Duration(milliseconds: (delaySeconds * 1000).round()), (timer) {
      if (!isTestModeActive) {
        timer.cancel();
        _testModeTimer = null;
        return;
      }

      // Otomatik vites döngüsü
      _cycleGearsAutomatically();

      // Pompayı otomatik aç (test modlarında pompa genellikle açık olur)
      pumpOn = true;

      // Basınç simülasyonu - test moduna göre değişken
      pressure = _simulateTestModePressure();

      lastMessage = '[MOCK] Test Mod $currentTestMode - Vites: $gear | ${testModeDescriptions[currentTestMode]}';
      logs.add('Test modu aktif: Vites $gear, Pompa: ${pumpOn ? "Açık" : "Kapalı"}');

      notifyListeners();
    });
  }

// Test moduna göre gecikme süresi (saniye cinsinden)
  double _getTestModeDelay() {
    switch (currentTestMode) {
      case 1: return 0.5;  // Çok Hızlı - 1.0ms yerine 0.5s (simülasyon için)
      case 2: return 0.6;  // Çok Hızlı - 1.2ms yerine 0.6s
      case 3: return 0.2;  // Ultra Hızlı - 0.4ms yerine 0.2s
      case 4: return 0.35; // Hızlı - 0.7ms yerine 0.35s
      case 5: return 1.0;  // Normal - 2.0ms yerine 1.0s
      case 6: return 2.5;  // Yavaş - 5.0ms yerine 2.5s
      case 7: return 0.05; // En Hızlı - 0.1ms yerine 0.05s
      default: return 1.0;
    }
  }

// Otomatik vites döngüsü
  void _cycleGearsAutomatically() {
    final gears = ['1', '2', '3', '4', '5', '6', '7', 'R'];
    final currentIndex = gears.indexOf(gear);
    final nextIndex = (currentIndex + 1) % gears.length;

    gear = gears[nextIndex];

    // Vites değişince valfleri güncelle
    updateValvesByGear(gear);

    logs.add('Test Mod $currentTestMode: Vites $gear\'a geçildi');
  }

// Test moduna göre basınç simülasyonu
  double _simulateTestModePressure() {
    final random = Random();
    double basePressure;

    switch (currentTestMode) {
      case 1: // Yüksek hız testi - yüksek basınç
      case 2: // Orta-yüksek hız
        basePressure = 55 + random.nextDouble() * 10;
        break;
      case 3: // FAZ 0/2 pompa kontrolü - değişken basınç
        basePressure = 40 + random.nextDouble() * 25;
        break;
      case 4: // FAZ 4 standart test - stabil basınç
        basePressure = 50 + random.nextDouble() * 5;
        break;
      case 5: // Genel kontrol - normal basınç
        basePressure = 48 + random.nextDouble() * 8;
        break;
      case 6: // Detaylı gözlem - yavaş değişen basınç
        basePressure = 45 + random.nextDouble() * 12;
        break;
      case 7: // SÖKME modu - düşük basınç (0-10 bar arası)
        basePressure = random.nextDouble() * 10;
        break;
      default:
        basePressure = 50 + random.nextDouble() * 10;
    }

    return basePressure;
  }

// Valfleri güncelleme metodunu ayrı bir metoda taşı
  void _updateValvesByGear(String currentGear) {
    // Önce tüm valfleri false yap
    for (var key in ['N433', 'N434', 'N437', 'N438']) {
      valveStates[key] = false;
    }

    // Vites -> Valf eşleştirmesi
    switch (currentGear) {
      case '1':
      case '3':
        valveStates['N433'] = true;
        break;
      case '2':
      case '4':
        valveStates['N437'] = true;
        break;
      case '5':
      case '7':
        valveStates['N434'] = true;
        break;
      case '6':
      case 'R':
        valveStates['N438'] = true;
        break;
      default:
      // 'BOŞ' veya diğer durumlarda hepsi kapalı
        break;
    }

    // Vites durumuna göre K1 / K2 seçimi
    if (['1', '3', '5', '7'].contains(currentGear)) {
      valveStates['K1'] = true;
      valveStates['K2'] = false;
    } else if (['2', '4', '6', 'R'].contains(currentGear)) {
      valveStates['K1'] = false;
      valveStates['K2'] = true;
    } else {
      // 'BOŞ' durumunda her ikisi de kapalı
      valveStates['K1'] = false;
      valveStates['K2'] = false;
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    autoConnect = true;
    deviceAddress = prefs.getString('deviceAddress') ?? '';
    deviceName = prefs.getString('deviceName') ?? 'Bilinmeyen Cihaz';

    if (deviceAddress.isNotEmpty) {
      connectionMessage = "Kayıtlı cihaza bağlanılıyor: $deviceName";
      notifyListeners();

      bool success = await tryConnect(deviceAddress, deviceName, timeout: 12);
      if (!success) {
        connectionMessage = "Bağlantı başarısız, tarama başlatılıyor...";
        notifyListeners();
        await initConnection();
      }
    } else {
      await initConnection();
    }
  }

  Future<bool> tryConnect(String address, String name, {int timeout = 15}) async {
    connectingAddress = address;
    connectionMessage = "Bağlanılıyor: $name";
    notifyListeners();

    try {
      final connectFuture = bt.connectTo(address);
      await connectFuture.timeout(Duration(seconds: timeout));

      isConnected = true;
      _sub = bt.lines.listen(_onLine);
      connectionMessage = "Bağlantı başarılı: $name";
      connectingAddress = null;

      // Bağlantı monitorünü başlat
      _startConnectionMonitor();

      notifyListeners();
      return true;
    } catch (e) {
      connectionMessage = "Bağlanılamadı ($e)";
      connectingAddress = null;
      isConnected = false;
      notifyListeners();
      return false;
    }
  }

  void _startConnectionMonitor() {
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (!bt.isConnected && isConnected && !isReconnecting) {
        _handleConnectionLost();
      }
    });
  }

  void _handleConnectionLost() {
    isReconnecting = true;
    isConnected = false;
    connectionMessage = "Bağlantı koptu, yeniden bağlanılıyor...";
    logs.add('[WARN] Bağlantı koptu, yeniden bağlanılıyor...');
    notifyListeners();

    // 3 saniye bekle ve yeniden dene
    Future.delayed(Duration(seconds: 3), () {
      if (deviceAddress.isNotEmpty) {
        tryConnect(deviceAddress, deviceName).then((success) {
          isReconnecting = false;
          if (!success) {
            connectionMessage = "Yeniden bağlanılamadı, lütfen manuel bağlanın";
            notifyListeners();
          }
        });
      }
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (deviceAddress != null) await prefs.setString('deviceAddress', deviceAddress!);
    if (deviceName != null) await prefs.setString('deviceName', deviceName!);
  }

  Future<void> initConnection() async {
    isScanning = true;
    discoveredDevices.clear();
    connectionMessage = "Cihazlar taranıyor...";
    notifyListeners();

    try {
      List<BluetoothDiscoveryResult> results = [];
      final subscription = FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
        if (!results.any((x) => x.device.address == r.device.address)) {
          results.add(r);
          discoveredDevices.add(r.device);
          notifyListeners();
        }
      });

      await Future.delayed(const Duration(seconds: 10));
      await subscription.cancel();

      // 🔍 Hedef cihazı bul
      final dqDevice = results.firstWhere(
            (r) => (r.device.name ?? "").toLowerCase().contains("dq200"),
        orElse: () => BluetoothDiscoveryResult(
          device: BluetoothDevice(address: '', name: ''),
          rssi: 0,
        ),
      );

      if (dqDevice.device.address.isNotEmpty) {
        deviceAddress = dqDevice.device.address;
        deviceName = dqDevice.device.name ?? 'Bilinmeyen Cihaz';
        await _savePrefs();
        await tryConnect(deviceAddress, deviceName);
      } else {
        connectionMessage = "DQ200 cihazı bulunamadı. Listeden elle seçebilirsiniz.";
      }
    } catch (e) {
      connectionMessage = "Tarama hatası: $e";
    }

    isScanning = false;
    notifyListeners();
  }

  void _onLine(String line) {
    logs.add('[${DateTime.now().toIso8601String()}] $line');
    lastMessage = line;

    updateValvesFromMessage(line);
    _parseLine(line);
    notifyListeners();
  }

  // ✅ Cihaz seçildiğinde kaydet
  void setDevice(String address, String? name) {
    deviceAddress = address;
    deviceName = name ?? 'Bilinmeyen Cihaz';
    _savePrefs();
    notifyListeners();
  }

  void _parseLine(String msg) {
    // Pressure & gear parsing
    final pressureMatch = RegExp(r'([\d.]+)\s*bar').firstMatch(msg);
    if (pressureMatch != null) {
      pressure = double.tryParse(pressureMatch.group(1)!) ?? pressure;
    }

    final gearMatch = RegExp(r'Vites[:\s]*([0-7RBOŞ]+)', caseSensitive: false).firstMatch(msg);
    if (gearMatch != null) {
      String gearValue = gearMatch.group(1)!.trim().toUpperCase();
      if (gearValue == '0') {
        selectedGear = 'BOŞ';
      } else if (gearValue == 'R') {
        selectedGear = 'R';
      } else {
        selectedGear = gearValue;
      }
      gear = selectedGear;
    }

    // Pompa durumu parsing
    if (msg.toLowerCase().contains('pompa aç') || msg.toLowerCase().contains('pump on')) {
      pumpOn = true;
      _addLog('Pompa açıldı');
    }
    if (msg.toLowerCase().contains('pompa kapat') || msg.toLowerCase().contains('pump off')) {
      pumpOn = false;
      _addLog('Pompa kapatıldı');
    }

    // Test durumu parsing
    if (msg.toLowerCase().contains('test başlat') || msg.toLowerCase().contains('test start')) {
      testStatus = 'Çalışıyor';
      _addLog('Test başlatıldı');
    }
    if (msg.toLowerCase().contains('test durdur') || msg.toLowerCase().contains('test stop')) {
      testStatus = 'Tamamlandı';
    }

    // Bağlantı durumu parsing
    if (msg.toLowerCase().contains('bağlandı') || msg.toLowerCase().contains('connected')) {
      isConnected = true;
    }
    if (msg.toLowerCase().contains('bağlantı kesildi') || msg.toLowerCase().contains('disconnected')) {
      isConnected = false;
    }
  }


  void sendCommand(String cmd) {
    logs.add('[${DateTime.now().toIso8601String()}] -> $cmd');
    bt.send(cmd);

    if (cmd == 'A') {
      pumpOn = true;
    } else if (cmd == 'K') {
      pumpOn = false;
    } else if (cmd.startsWith('V')) {
      String gearValue = cmd.substring(1);
      if (gearValue == '0') selectedGear = 'BOŞ';
      else if (gearValue == 'R') selectedGear = 'R';
      else selectedGear = gearValue;

      gear = selectedGear;

      // 🔹 Vites değişince valfleri güncelle
      updateValvesByGear(gear);
    }
    else if (cmd == 'TEST') {
      testStatus = 'Çalışıyor';
      logs.add('[${DateTime.now().toIso8601String()}] Test başlatıldı');
    } else if (cmd == 'TEST_STOP') {
      testStatus = 'Hazır';
      logs.add('[${DateTime.now().toIso8601String()}] Test durduruldu');
    }

    notifyListeners();
  }

  void updateValvesByGear(String gear) {
    // önce ilgili vites valflerini kapat
    valveStates['N433'] = false;
    valveStates['N434'] = false;
    valveStates['N437'] = false;
    valveStates['N438'] = false;

    // N436 / N440 basınç valfleri: aktif kavrama hattına göre değişir
    valveStates['N436'] = false;
    valveStates['N440'] = false;

    switch (gear) {
      case '1':
      case '3':
      case '5':
      case '7':
        valveStates['N436'] = true; // K1 hattı aktif
        valveStates['K1'] = true;
        valveStates['K2'] = false;
        break;
      case '2':
      case '4':
      case '6':
      case 'R':
        valveStates['N440'] = true; // K2 hattı aktif
        valveStates['K1'] = false;
        valveStates['K2'] = true;
        break;
      default:
      // boşta ise tümü kapalı
        valveStates['K1'] = false;
        valveStates['K2'] = false;
        valveStates['N436'] = false;
        valveStates['N440'] = false;
        break;
    }

    enforceK1K2Rules();
    notifyListeners();
  }


  void enforceK1K2Rules() {
    // Eğer mod pasifse K1 ve K2 daima false olmalı
    if (!isK1K2Mode) {
      valveStates['K1'] = false;
      valveStates['K2'] = false;
    }
  }

  void _addLog(String message) {
    logs.add('[${DateTime.now().toIso8601String()}] $message');
    if (logs.length > 100) {
      logs.removeAt(0); // Eski logları temizle
    }
    notifyListeners();
  }

  void clearLogs() {
    logs.clear();
    _addLog('Loglar temizlendi');
    notifyListeners();
  }

  @override
  void dispose() {
    _connectionMonitorTimer?.cancel();
    _testModeTimer?.cancel(); // 🔹 BU SATIRI EKLEYİN - Timer'ı temizle
    _sub?.cancel();
    _operationTimer?.cancel();
    _testTimer?.cancel();
    _phaseTimer?.cancel();
    bt.dispose();
    super.dispose();
  }
}