import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/test_verisi.dart';
import '../services/bluetooth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../utils/mekatronik_puanlama.dart';

enum TestPhase {
  idle, phase0, phase1, phase2, phase3, phase4, completed,
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
  double faz2Puan = 0; // Anahtarlar: N436, N440, N436+N440, Kapali
  double faz3Puan = 0; // Anahtarlar: V1, V2, V3_7, V4_6, V5, VR
  double faz4PompaSuresi = 0;
  String autoCycleMode = '0';
  Timer? _testTimeoutTimer;
  Duration _testTimeout = Duration(minutes: 25); // 25 dakika timeout
  Map<String, double> _deviceScores = {};
  Completer<void>? _testCompletionCompleter;

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
  Function(String)? onDeviceReportReceived;

// Test verileri
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
    8: 0.0,
  };
  final Map<int, String> testModeDescriptions = {
    1: "Çok Hızlı - Yüksek hız testi",
    2: "Çok Hızlı - Orta-yüksek hız",
    3: "Ultra Hızlı - FAZ 0/2 pompa kontrolü",
    4: "Hızlı - FAZ 4 standart test",
    5: "Normal - Genel kontrol",
    6: "Yavaş - Detaylı gözlem",
    7: "En Hızlı - SÖKME modu",
    8: "Durdur - Acil Durdurma",
  };

  void setMode(int mode) {
    selectedMode = mode;
    notifyListeners();
  }

  Map<String, bool> valveStates = {
    'N440': false,
    'N436': false,
    'K1': false,
    'K2': false,
    'N433': false,
    'N438': false,
    'N434': false,
    'N437': false,
  };

  void startTestMode(int mode) {
    if (mode < 1 || mode > 8) return;
    setK1K2Mode(true);
    currentTestMode = mode;
    isTestModeActive = true;

    // Test modu komutunu gönder
    sendCommand(mode.toString());

    // Test 7 ve 8 için özel mesajlar
    if (mode == 7) {
      connectionMessage = "SÖKME MODU AKTİF - Basınç düşürülüyor";
      logs.add("🚨 SÖKME Modu başlatıldı (0.1ms) - Sistem boşaltılıyor");
    } else if (mode == 8) {
      connectionMessage = "ACİL DURDUR AKTİF - Sistem durduruluyor";
      logs.add("🛑 ACİL DURDUR Modu başlatıldı - Sistem sıfırlanıyor");
    } else {
      connectionMessage = "Test Mod $mode aktif: ${testModeDescriptions[mode]}";
      logs.add("Test Mod $mode başlatıldı (${testModeDelays[mode]}ms bekleme)");
    }

    notifyListeners();
  }

  void stopTestMode() {
    // Test 7 ve 8 için özel loglar
    if (currentTestMode == 7) {
      logs.add("✅ SÖKME Modu durduruldu - Sistem güvenli");
    } else if (currentTestMode == 8) {
      logs.add("✅ ACİL DURDUR Modu tamamlandı - Sistem sıfırlandı");
    }

    currentTestMode = 0;
    isTestModeActive = false;

    // Test modu timer'ını temizle
    _testModeTimer?.cancel();
    _testModeTimer = null;

    // Test modu kapatma komutunu gönder
    sendCommand("8");
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

  Future<void> startFullTest(String testAdi) async {
    if (isTesting) return;

    _currentTestName = testAdi;
    _resetAllTimers();
    _resetTestVariables();

    isTesting = true;
    testFinished = false;
    currentPhase = TestPhase.idle;

    phaseStatusMessage = "Tam Otomatik Test Başlatılıyor: $testAdi";
    testStatus = 'Çalışıyor';
    logs.add(phaseStatusMessage);
    notifyListeners();

    try {
      await _runBluetoothTestWithTimeout(testAdi, DateTime.now());
    } catch (e) {
      logs.add("TEST HATASI: $e");
      testStatus = 'Hata';
      phaseStatusMessage = "Test hata ile sonlandı: $e";
      isTesting = false;
      testFinished = true;
      notifyListeners();
    }
  }

  Future<void> _runBluetoothTestWithTimeout(String testAdi, DateTime startTime) async {
    _testCompletionCompleter = Completer<void>();

    _testTimeoutTimer = Timer(_testTimeout, () {
      if (!_testCompletionCompleter!.isCompleted) {
        _testCompletionCompleter!.completeError(
          Exception("Test timeout (${_testTimeout.inMinutes} dakika)"),
        );
      }
    });

    _startBluetoothTestListener();

    sendCommand("TEST");
    logs.add("TEST komutu gönderildi - Tüm fazlar otomatik başlayacak");

    try {
      await _testCompletionCompleter!.future;

      // Test tamamlandı, son puanları bekle
      await Future.delayed(Duration(seconds: 2));
      await _requestDeviceScore();

      await _saveFullTest();

    } catch (e) {
      logs.add("TEST HATASI: $e");
      throw e;
    } finally {
      _testTimeoutTimer?.cancel();
      _testCompletionCompleter = null;
      isTesting = false;
      testFinished = true;
    }
  }

  void _startBluetoothTestListener() {
    Function(String)? originalListener = onDeviceReportReceived;

    onDeviceReportReceived = (String message) {
      print('[BLUETOOTH_TEST] Mesaj alındı: $message');
      _handleBluetoothTestMessage(message);

      if (originalListener != null) {
        originalListener(message);
      }
    };
  }

  void _handleBluetoothTestMessage(String message) {
    // Sadece faz başlangıçlarını göster (isteğe bağlı)
    if (message.contains("FAZ0") || message.toLowerCase().contains("faz 0")) {
      currentPhase = TestPhase.phase0;
      phaseStatusMessage = "FAZ 0: Pompa Yükselme Testi";
      logs.add("FAZ 0 başladı");
    }
    else if (message.contains("FAZ1") || message.toLowerCase().contains("faz 1")) {
      currentPhase = TestPhase.phase1;
      phaseStatusMessage = "FAZ 1: Basınç Dengeleme Testi";
      logs.add("FAZ 1 başladı");
    }
    else if (message.contains("FAZ2") || message.toLowerCase().contains("faz 2")) {
      currentPhase = TestPhase.phase2;
      phaseStatusMessage = "FAZ 2: Basınç Valfi Testleri";
      logs.add("FAZ 2 başladı");
    }
    else if (message.contains("FAZ3") || message.toLowerCase().contains("faz 3")) {
      currentPhase = TestPhase.phase3;
      phaseStatusMessage = "FAZ 3: Vites Testleri";
      logs.add("FAZ 3 başladı");
    }
    else if (message.contains("FAZ4") || message.toLowerCase().contains("faz 4")) {
      currentPhase = TestPhase.phase4;
      phaseStatusMessage = "FAZ 4: Dayanıklılık Testi";
      logs.add("FAZ 4 başladı");
    }

    // FAZ Puanlarını parse et ve değişkenleri doldur
    else if (message.contains("PUAN:") ||
        (message.contains("FAZ") && message.contains("PUAN")) ||
        message.contains("/100") || message.contains("/10")) {
      _parseFazScores(message);
    }

    // Test tamamlanma kontrolü (FAZ4 puanı geldiğinde veya toplam puan geldiğinde)
    else if (message.contains("TEST_TAMAM") ||
        message.contains("TEST_COMPLETE") ||
        message.toLowerCase().contains("test bitti") ||
        (_deviceScores.containsKey('faz4') && !_testCompletionCompleter!.isCompleted)) {
      _handleTestCompletion(message);
    }

    // Hata durumu
    else if (message.contains("HATA") || message.contains("ERROR")) {
      logs.add("ESP32 HATASI: $message");
      _handleTestError(message);
    }

    // Basınç değerini güncelle
    final pressureMatch = RegExp(r'([\d.]+)\s*bar').firstMatch(message);
    if (pressureMatch != null) {
      pressure = double.tryParse(pressureMatch.group(1)!) ?? pressure;
      _currentMinPressure = min(_currentMinPressure, pressure);
      _currentMaxPressure = max(_currentMaxPressure, pressure);
    }

    notifyListeners();
  }

  void _parseFazScores(String message) {
    Map<String, double> scores = _parseScoringData(message);

    if (scores.isNotEmpty) {
      _deviceScores.addAll(scores);
      logs.add("Puanlar alındı: $scores");

      // Faz değişkenlerini doldur
      if (scores.containsKey('faz0')) {
        // FAZ 0 puanı - pompa yükselme süresi için kullanabiliriz
        double puan = scores['faz0']!;
        // Puanı süreye çevir (10 puan = 8 saniye, 7 puan = 12 saniye, vb.)
        faz0Sure = _convertScoreToDuration(puan, 10);
      }

      if (scores.containsKey('faz2')) {
        // FAZ 2 puanı - basınç valfi test sonuçları
        double puan = scores['faz2']!;
        // Puanı basınç kaybı değerlerine çevir
        faz2Puan = puan;
      }

      if (scores.containsKey('faz3')) {
        // FAZ 3 puanı - vites test sonuçları
        double puan = scores['faz3']!;
        // Puanı vites basınç kayıplarına çevir
        faz3Puan = puan;
      }

      if (scores.containsKey('faz4')) {
        // FAZ 4 puanı - dayanıklılık testi
        double puan = scores['faz4']!;
        // Puanı pompa süresine çevir
        faz4PompaSuresi = _convertScoreToDuration(puan, 20);

        // FAZ 4 puanı geldiğinde test tamamlanmış demektir
        if (!_testCompletionCompleter!.isCompleted) {
          _handleTestCompletion("FAZ4 tamamlandı - Puan: $puan");
        }
      }

      // Toplam puan
      if (scores.containsKey('total')) {
        logs.add("Toplam Puan: ${scores['total']}/100");
      }

      notifyListeners();
    }
  }

// Puanı süreye çeviren yardımcı metod
  double _convertScoreToDuration(double puan, int maxPuan) {
    if (puan >= maxPuan * 0.8) { // 80-100% = çok iyi
      return 8.0 + Random().nextDouble() * 2.0; // 8-10 saniye
    } else if (puan >= maxPuan * 0.6) { // 60-79% = iyi
      return 10.0 + Random().nextDouble() * 3.0; // 10-13 saniye
    } else { // 0-59% = kötü
      return 13.0 + Random().nextDouble() * 7.0; // 13-20 saniye
    }
  }

  Map<String, double> _parseScoringData(String data) {
    Map<String, double> scores = {};

    // "PUAN:86/100" formatı
    RegExp puanRegex = RegExp(r'PUAN:(\d+)/100');
    Match? match = puanRegex.firstMatch(data);
    if (match != null) {
      scores['total'] = double.parse(match.group(1)!);
    }

    // "FAZ 0: ... | PUAN: 10/10"
    RegExp fazRegex = RegExp(r'FAZ\s*(\d+):.*PUAN:\s*(\d+)/(\d+)');
    for (Match m in fazRegex.allMatches(data)) {
      int fazNo = int.parse(m.group(1)!);
      double score = double.parse(m.group(2)!);
      scores['faz$fazNo'] = score;
    }

    // Alternatif format: "FAZ1_PUAN:8/10"
    RegExp fazAltRegex = RegExp(r'FAZ(\d+)_PUAN:(\d+)/(\d+)');
    for (Match m in fazAltRegex.allMatches(data)) {
      int fazNo = int.parse(m.group(1)!);
      double score = double.parse(m.group(2)!);
      scores['faz$fazNo'] = score;
    }

    return scores;
  }

  void _handleTestCompletion(String message) {
    logs.add("TEST TAMAMLANDI: $message");

    isTesting = false;
    testFinished = true;
    currentPhase = TestPhase.completed;
    testStatus = 'Tamamlandı';
    phaseStatusMessage = "Test tamamlandı";

    if (_testCompletionCompleter != null && !_testCompletionCompleter!.isCompleted) {
      _testCompletionCompleter!.complete();
    }

    notifyListeners();
  }

  void _handleTestError(String message) {
    logs.add("TEST HATASI: $message");

    isTesting = false;
    testFinished = true;
    testStatus = 'Hata';
    phaseStatusMessage = "Test hatayla sonlandı: $message";

    // Test completion completer'ı hata ile tamamla
    if (_testCompletionCompleter != null && !_testCompletionCompleter!.isCompleted) {
      _testCompletionCompleter!.completeError(Exception(message));
    }

    notifyListeners();
  }

// Cihazdan puan iste
  Future<void> _requestDeviceScore() async {
    logs.add("Cihazdan puan isteniyor...");
    sendCommand("PUAN");

    // Puan cevabını bekle (5 saniye timeout)
    final completer = Completer<void>();
    Timer? scoreTimeoutTimer;

    Function(String)? originalListener = onDeviceReportReceived;

    onDeviceReportReceived = (String message) {
      if (message.contains("PUAN:") || _parseScoringData(message).isNotEmpty) {
        _parseFazScores(message);

        if (!completer.isCompleted) {
          completer.complete();
        }
      }

      if (originalListener != null) {
        originalListener(message);
      }
    };

    scoreTimeoutTimer = Timer(Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        completer.complete();
        logs.add("Puan timeout - cihaz cevap vermedi");
      }
    });

    await completer.future;
    scoreTimeoutTimer.cancel();
    onDeviceReportReceived = originalListener;
  }

  // Faz puanlarından toplam puan hesapla
  int _calculateScoreFromFazScores() {
    int total = 0;
    total += (_deviceScores['faz0'] ?? 0).round();
    total += (_deviceScores['faz1'] ?? 0).round();
    total += (_deviceScores['faz2'] ?? 0).round();
    total += (_deviceScores['faz3'] ?? 0).round();
    total += (_deviceScores['faz4'] ?? 0).round();
    return total.clamp(0, 100);
  }

  void _resetTestVariables() {
    _currentMinPressure = double.infinity;
    _currentMaxPressure = 0.0;
    faz0Sure = 0;
    faz2Puan = 0;
    faz3Puan = 0;
    faz4PompaSuresi = 0;
    _faz4VitesSayisi = 0;
    testStatus = 'Hazır';
  }

  void setCurrentTestName(String name) {
    _currentTestName = name;
  }

// Test sonucu callback'i
  Function(TestVerisi)? onTestCompleted;

// Test durdurma
  void stopAutoTest() {
    _testTimer?.cancel();
    isTesting = false;
    testStatus = 'Test Durduruldu';
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

    _resetAllTimers();

    // 🔹 Eğer test zaten tamamlandıysa (örneğin faz4 bittiğinde)
    if (currentPhase == TestPhase.completed || testFinished) {
      _saveFullTest(); // normal tam test olarak kaydet
      testStatus = 'Tamamlandı';
    } else {
      testStatus = 'Kullanıcı Tarafından Durduruldu';
    }

    isTesting = false;
    testFinished = true;

    notifyListeners();
  }

  Future<void> _saveFullTest() async {
    // Bluetooth testinden gelen puanları kullan
    final toplamPuan = _deviceScores['total'] ?? _calculateScoreFromFazScores();
    final bonusPuan = _calculateBonusPuan(toplamPuan);
    final sonuc = MekatronikPuanlama.durum(toplamPuan.round());

    final test = TestVerisi(
      testAdi: _currentTestName.isNotEmpty ? _currentTestName : "Tam Test",
      tarih: DateTime.now(),
      fazAdi: "Bluetooth Tam Test",
      minBasinc: _currentMinPressure,
      maxBasinc: _currentMaxPressure,
      toplamPompaSuresi: faz0Sure + faz4PompaSuresi,
      vitesSayisi: _faz4VitesSayisi,
      puan: toplamPuan.round(),
      sonuc: sonuc,
      faz0Puan: _deviceScores['faz0'] ?? 0,
      faz2Puan: _deviceScores['faz2'] ?? 0,
      faz3Puan: _deviceScores['faz3'] ?? 0,
      faz4Puan: _deviceScores['faz4'] ?? 0,
      bonusPuan: bonusPuan,
    );

    await saveTest(test);

    if (onTestCompleted != null) {
      onTestCompleted!(test);
    }
  }

  int _calculateBonusPuan(num toplamPuan) {
    final fazPuanlariToplami =
        (_deviceScores['faz0'] ?? 0) +
            (_deviceScores['faz1'] ?? 0) +
            (_deviceScores['faz2'] ?? 0) +
            (_deviceScores['faz3'] ?? 0) +
            (_deviceScores['faz4'] ?? 0);

    final bonus = toplamPuan - fazPuanlariToplami;
    return bonus.round().clamp(0, 15); // Bonus puan max 15 olabilir
  }


  void toggleValve(String key) {
    if (!valveStates.containsKey(key)) return;

    bool newState = !(valveStates[key] ?? false);
    valveStates[key] = newState;

    // Bluetooth komutunu gönder
    String bluetoothCommand = key;

    // Özel durum: N436 ve N440 için Bluetooth komutları farklı
    if (key == 'N436') {
      bluetoothCommand = 'N36';
    } else if (key == 'N440') {
      bluetoothCommand = 'N40';
    }

    sendCommand(newState ? bluetoothCommand : bluetoothCommand);

    enforceK1K2Rules();
    notifyListeners();
  }

  void startSokmeModu() {
    sendCommand("SOKME");
    connectionMessage = "Sökme modu başlatıldı (basınç boşaltılıyor)";
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

  void _resetAllTimers() {
    _testTimer?.cancel();
    _testTimer = null;
    _phaseTimer?.cancel();
    _phaseTimer = null;
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = null;
    _testModeTimer?.cancel();
    _testModeTimer = null;
    _testTimeoutTimer?.cancel();
    _testTimeoutTimer = null;
  }

  void updateValvesFromMessage(String msg) {
    if (!msg.startsWith('VALVES:')) return;

    final data = msg.replaceFirst('VALVES:', '').split(',');
    for (var pair in data) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        String key = parts[0].trim();
        final val = parts[1].trim();

        // Bluetooth'tan gelen N36 -> N436, N40 -> N440 mapping
        if (key == 'N36') key = 'N436';
        if (key == 'N40') key = 'N440';

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

  void setPressureToggle(bool isNarrowRange) {
    pressureToggle = isNarrowRange;
    if (isNarrowRange) {
      _addLog("Basınç Monitörü: 42-52 bar moduna geçildi."); // GÜNCELLENDİ
    } else {
      _addLog("Basınç Monitörü: 42-60 bar moduna geçildi."); // GÜNCELLENDİ
    }
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

    valveStates[valve] = state;

    // Bluetooth komutunu gönder
    String bluetoothCommand = valve;
    if (valve == 'N436') bluetoothCommand = 'N36';
    if (valve == 'N440') bluetoothCommand = 'N40';

    sendCommand(state ? bluetoothCommand : bluetoothCommand);

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

      // 1️⃣ Normal modda basınç değeri - GÜNCELLENDİ: 42-60 bar aralığı
      double minPressure = 42.0; // Sabit minimum basınç
      double maxPressure = 60.0;

      // Basınç toggle durumuna göre farklı dağılım
      if (pressureToggle) {
        // Dar aralık modu (52-60 bar) - GÜNCELLENDİ: 52-60 yerine 42-52
        pressure = 47.0 + random.nextDouble() * 5.0; // 47-52 bar arası
      } else {
        // Geniş aralık modu (42-60 bar)
        pressure = minPressure + random.nextDouble() * (maxPressure - minPressure);
      }

      // 2️⃣ Vites durumuna göre valfleri ayarla
      updateValvesByGear(gear);

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

      // Otomatik vites döngüsü - TÜM valfler güncellenecek
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
      case 1: return 1.0;  // Çok Hızlı - 1.0ms yerine 0.5s (simülasyon için)
      case 2: return 1.2;  // Çok Hızlı - 1.2ms yerine 0.6s
      case 3: return 0.4;  // Ultra Hızlı - 0.4ms yerine 0.2s
      case 4: return 0.7; // Hızlı - 0.7ms yerine 0.35s
      case 5: return 2.0;  // Normal - 2.0ms yerine 1.0s
      case 6: return 5.0;  // Yavaş - 5.0ms yerine 2.5s
      case 7: return 0.1; // En Hızlı - 0.1ms yerine 0.05s
      default: return 1.0;
    }
  }

// Otomatik vites döngüsü
  void _cycleGearsAutomatically() {
    final gears = ['1', '2', '3', '4', '5', '6', '7', 'R'];
    final currentIndex = gears.indexOf(gear);
    final nextIndex = (currentIndex + 1) % gears.length;

    gear = gears[nextIndex];

    // Vites değişince TÜM valfleri güncelle (manuel davranış gibi)
    updateValvesByGear(gear);

    logs.add('Test Mod $currentTestMode: Vites $gear\'a geçildi - Tüm valfler güncellendi');
  }

// Test moduna göre basınç simülasyonu
  double _simulateTestModePressure() {
    final random = Random();
    double basePressure;

    switch (currentTestMode) {
      case 1: // Yüksek hız testi - yüksek basınç
      case 2: // Orta-yüksek hız
        basePressure = pressureToggle ?
        47.0 + random.nextDouble() * 5.0 : // Dar aralık: 47-52
        50.0 + random.nextDouble() * 10.0; // Geniş aralık: 50-60
        break;
      case 3: // FAZ 0/2 pompa kontrolü - değişken basınç
        basePressure = pressureToggle ?
        44.0 + random.nextDouble() * 8.0 : // Dar aralık: 44-52
        42.0 + random.nextDouble() * 18.0; // Geniş aralık: 42-60
        break;
      case 4: // FAZ 4 standart test - stabil basınç
        basePressure = pressureToggle ?
        47.0 + random.nextDouble() * 5.0 : // Dar aralık: 47-52
        48.0 + random.nextDouble() * 7.0; // Geniş aralık: 48-55
        break;
      case 5: // Genel kontrol - normal basınç
        basePressure = pressureToggle ?
        45.0 + random.nextDouble() * 7.0 : // Dar aralık: 45-52
        46.0 + random.nextDouble() * 9.0; // Geniş aralık: 46-55
        break;
      case 6: // Detaylı gözlem - yavaş değişen basınç
        basePressure = pressureToggle ?
        43.0 + random.nextDouble() * 9.0 : // Dar aralık: 43-52
        42.0 + random.nextDouble() * 13.0; // Geniş aralık: 42-55
        break;
      case 7: // SÖKME modu - düşük basınç (0-10 bar arası)
        basePressure = random.nextDouble() * 10;
        break;
      default:
        basePressure = pressureToggle ?
        47.0 + random.nextDouble() * 5.0 : // Dar aralık: 47-52
        48.0 + random.nextDouble() * 7.0; // Geniş aralık: 48-55
    }

    return basePressure;
  }

// Valfleri güncelleme metodunu ayrı bir metoda taşı
  void updateValvesByGear(String gear) {
    // Önce tüm vites valflerini sıfırla
    valveStates['N433'] = false;
    valveStates['N434'] = false;
    valveStates['N437'] = false;
    valveStates['N438'] = false;

    // Basınç valflerini de sıfırla (vitese göre yeniden ayarlanacak)
    valveStates['N436'] = false;
    valveStates['N440'] = false;

    // Vites -> Valf eşleştirmesi (manuel kurallar)
    switch (gear) {
      case '1':
        valveStates['N433'] = true; // Vites 1-3 valfi
        valveStates['N436'] = true; // K1 hattı basınç valfi
        break;
      case '2':
        valveStates['N437'] = true; // Vites 2-4 valfi
        valveStates['N440'] = true; // K2 hattı basınç valfi
        break;
      case '3':
        valveStates['N433'] = true; // Vites 1-3 valfi
        valveStates['N436'] = true; // K1 hattı basınç valfi
        break;
      case '4':
        valveStates['N437'] = true; // Vites 2-4 valfi
        valveStates['N440'] = true; // K2 hattı basınç valfi
        break;
      case '5':
        valveStates['N434'] = true; // Vites 5-7 valfi
        valveStates['N436'] = true; // K1 hattı basınç valfi
        break;
      case '6':
        valveStates['N438'] = true; // Vites 6-R valfi
        valveStates['N440'] = true; // K2 hattı basınç valfi
        break;
      case '7':
        valveStates['N434'] = true; // Vites 5-7 valfi
        valveStates['N436'] = true; // K1 hattı basınç valfi
        break;
      case 'R':
        valveStates['N438'] = true; // Vites 6-R valfi
        valveStates['N440'] = true; // K2 hattı basınç valfi
        break;
      default: // 'BOŞ' veya diğer durumlar
      // Tüm valfler kapalı kalacak
        break;
    }

    // Vites durumuna göre K1 / K2 seçimi
    if (['1', '3', '5', '7'].contains(gear)) {
      valveStates['N435'] = isK1K2Mode; // Mod açıksa true, değilse false
      valveStates['N439'] = false;
    } else if (['2', '4', '6', 'R'].contains(gear)) {
      valveStates['N435'] = false;
      valveStates['N439'] = isK1K2Mode; // Mod açıksa true, değilse false
    } else {
      // 'BOŞ' durumunda her ikisi de kapalı
      valveStates['N435'] = false;
      valveStates['N439'] = false;
    }

    // K1/K2 kurallarını uygula
    enforceK1K2Rules();

    // Log kaydı
    logs.add('Vites $gear: Valf durumları güncellendi - '
        'N433:${valveStates['N433']}, '
        'N434:${valveStates['N434']}, '
        'N437:${valveStates['N437']}, '
        'N438:${valveStates['N438']}, '
        'N436:${valveStates['N436']}, '
        'N440:${valveStates['N440']}, '
        'K1:${valveStates['N435']}, '
        'K2:${valveStates['N439']}');
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
    await prefs.setString('deviceAddress', deviceAddress);
    await prefs.setString('deviceName', deviceName);
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

    final gearMatch = RegExp(r'V[:\s]*([0-7RBOŞ]+)', caseSensitive: false).firstMatch(msg);
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

    // 🔹 PUAN komutu cevabını yakala
    if (msg.contains("PUAN:") || msg.contains("RAPOR:") ||
        (msg.contains("/100") && (msg.contains("FAZ") || msg.contains("TEST")))) {
      _handleDeviceReport(msg);
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

  void _handleDeviceReport(String report) {
    print('[DEVICE REPORT] $report');

    // Callback varsa tetikle
    if (onDeviceReportReceived != null) {
      onDeviceReportReceived!(report);
      onDeviceReportReceived = null; // Tek kullanımlık
    }

    // Log'a kaydet
    logs.add('[RAPOR] Cihaz raporu alındı: ${report.length} karakter');
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


  void enforceK1K2Rules() {
    // Eğer mod pasifse K1 ve K2 daima false olmalı
    if (!isK1K2Mode) {
      valveStates['N435'] = false;
      valveStates['N439'] = false;
    }

    // Güvenlik: Aynı anda hem K1 hem K2 aktif olamaz
    if (valveStates['N435'] == true && valveStates['N439'] == true) {
      valveStates['N439'] = false;
      logs.add('[GÜVENLİK] K1 ve K2 aynı anda aktif olamaz - K2 kapatıldı');
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