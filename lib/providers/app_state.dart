import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/test_verisi.dart';
import '../models/testmode_verisi.dart';
import '../services/bluetooth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../utils/mekatronik_puanlama.dart';

enum TestPhase { idle, phase0, phase1, phase2, phase3, phase4, completed }

enum TestState {
  idle,           // Hazır
  starting,       // Başlıyor
  running,        // Çalışıyor
  paused,         // Duraklatıldı
  waitingReport,  // Rapor Bekleniyor
  parsingReport,  // Rapor Parse Ediliyor
  completed,      // Tamamlandı
  error,          // Hata
  cancelled       // İptal Edildi
}

class AppState extends ChangeNotifier {
  final BluetoothService bt = BluetoothService();

  // Live values
  bool get isTestRunning => _currentTestState == TestState.running;
  bool get isTestPaused => _currentTestState == TestState.paused;
  bool get canStartTest => _currentTestState == TestState.idle ||
      _currentTestState == TestState.completed ||
      _currentTestState == TestState.error;

  bool get canPauseTest => _currentTestState == TestState.running;
  bool get canResumeTest => _currentTestState == TestState.paused;
  bool get canStopTest => _currentTestState == TestState.running ||
      _currentTestState == TestState.paused ||
      _currentTestState == TestState.waitingReport;
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
  bool _waitingForReport = false;
  String _collectedReport = '';
  String _currentVites = 'BOŞ';
  String _currentFaz = 'HAZIR';
  int _toplamTekrar = 0;
  int get toplamTekrar => _toplamTekrar;
  Timer? _testModeValveUpdateTimer;
  TestModuRaporu? _sonTestModuRaporu;
  TestModuRaporu? get sonTestModuRaporu => _sonTestModuRaporu;
  final int _maxLogCount = 200; // Maksimum log sayısı
  bool _valveUpdateInProgress = false;
  bool _testModuRaporuCallbackRegistered = false;
  TestState _currentTestState = TestState.idle;
  TestState get currentTestState => _currentTestState;

  // State geçişleri için timer
  Timer? _stateTimeoutTimer;
  final Duration _stateTimeout = Duration(minutes: 2); // State timeout

  // Önceki state (geri dönüş için)
  TestState? _previousState;

  // YENİ: Test modu raporu callback'i
  Function(TestModuRaporu)? onTestModuRaporuAlindi;

  // Getter metodları
  String get currentVites => _currentVites;
  String get currentFaz => _currentFaz;

  bool isReconnecting = false;
  Timer? _connectionMonitorTimer;
  Timer? _testModeTimer; // 🔹 BU SATIRI EKLEYİN - Test modu timer'ı

  final Map<int, Map<String, dynamic>> fazBilgileri = {
    0: {'sure': '20 saniye', 'aciklama': 'Pompa Yükseliş'},
    1: {'sure': '3 dakika', 'aciklama': 'Isınma'},
    2: {'sure': '4 dakika', 'aciklama': 'Basınç Valf Testi'},
    3: {'sure': '6 dakika', 'aciklama': 'Vites Valfleri Testi'},
    4: {'sure': '10 dakika', 'aciklama': 'Otomatik Vites Testi'},
    5: {'sure': '2 dakika', 'aciklama': 'K1 ve K2 Basınç Testi'},
  };

  int get currentFazNo {
    switch (currentPhase) {
      case TestPhase.phase0:
        return 0;
      case TestPhase.phase1:
        return 1;
      case TestPhase.phase2:
        return 2;
      case TestPhase.phase3:
        return 3;
      case TestPhase.phase4:
        return 4;
      case TestPhase.completed:
        return 5; // Tamamlandığında FAZ 5 göster
      default:
        return -1;
    }
  }

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
  Timer? _uiUpdateTimer;
  final List<Function(String)> _reportCallbacks = [];

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

  void _setTestState(TestState newState, {String? message}) {
    if (_currentTestState == newState) return;

    _previousState = _currentTestState;
    _currentTestState = newState;

    // Önceki state timer'ını temizle
    _stateTimeoutTimer?.cancel();

    // Log ekle
    logs.add('[STATE] ${_stateToString(_previousState)} → ${_stateToString(newState)} ${message ?? ''}');

    // State'e özel işlemler
    _handleStateTransition(newState);

    notifyListeners();
  }

  String _stateToString(TestState? state) {
    switch (state) {
      case TestState.idle: return 'HAZIR';
      case TestState.starting: return 'BAŞLATILIYOR';
      case TestState.running: return 'ÇALIŞIYOR';
      case TestState.paused: return 'DURAKLATILDI';
      case TestState.waitingReport: return 'RAPOR BEKLENİYOR';
      case TestState.parsingReport: return 'RAPOR İŞLENİYOR';
      case TestState.completed: return 'TAMAMLANDI';
      case TestState.error: return 'HATA';
      case TestState.cancelled: return 'İPTAL EDİLDİ';
      default: return 'BİLİNMEYEN';
    }
  }

  void _handleStateTransition(TestState newState) {
    switch (newState) {
      case TestState.starting:
        _onTestStarting();
        break;
      case TestState.running:
        _onTestRunning();
        break;
      case TestState.waitingReport:
        _onWaitingReport();
        break;
      case TestState.parsingReport:
        _onParsingReport();
        break;
      case TestState.completed:
        _onTestCompleted();
        break;
      case TestState.error:
        _onTestError();
        break;
      case TestState.cancelled:
        _onTestCancelled();
        break;
      case TestState.paused:
        _onTestPaused();
        break;
      default:
        break;
    }
  }

  void _onTestStarting() {
    logs.add('Test başlatılıyor...');
    _resetTestVariables();
    _startTestTimer();

    // State timeout başlat
    _startStateTimeout();
  }

  void _onTestRunning() {
    logs.add('Test çalışıyor...');
    isTesting = true;
    testFinished = false;

    // Bluetooth listener başlat
    _startBluetoothTestListener();
  }

  void _onWaitingReport() {
    logs.add('Cihaz raporu bekleniyor...');
    _waitingForReport = true;
    _collectedReport = '';

    // 2 dakika içinde rapor gelmezse timeout
    _startStateTimeout();
  }

  void _onParsingReport() {
    logs.add('Rapor parsing başlıyor...');

    try {
      _parseCompleteReport(_collectedReport);

      // ✅ BU DOĞRU - state machine zaten _parseCompleteReport içinde güncellenecek
      // _setTestState(TestState.completed, message: 'Rapor başarıyla işlendi');

    } catch (e) {
      logs.add('Rapor parsing hatası: $e');
      _setTestState(TestState.error, message: 'Rapor parsing hatası: $e');
    }
  }

  void _onTestCompleted() {
    logs.add('Test tamamlandı!');
    isTesting = false;
    testFinished = true;
    testStatus = 'Tamamlandı';

    _resetSystemAfterTest();

    // ✅ Async işlemi bekle ve callback tetikle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveFullTest().then((_) {
        logs.add('Test kaydedildi ve callback tetiklendi');
      });
    });
  }

  void _onTestError() {
    logs.add('Test hatayla sonlandı!');
    isTesting = false;
    testFinished = true;
    testStatus = 'Hata';

    // Hata durumunda sistem sıfırlama
    _resetSystemAfterTest();
  }

  void _onTestCancelled() {
    logs.add('Test kullanıcı tarafından iptal edildi!');
    isTesting = false;
    testFinished = true;
    testStatus = 'İptal Edildi';

    // Sistem sıfırlama
    _resetSystemAfterTest();
  }

  void _onTestPaused() {
    logs.add('Test duraklatıldı');
    isPaused = true;
    testStatus = 'Duraklatıldı';
  }

  void _startStateTimeout() {
    _stateTimeoutTimer?.cancel();
    _stateTimeoutTimer = Timer(_stateTimeout, () {
      _onStateTimeout();
    });
  }

  void _onStateTimeout() {
    logs.add('[STATE TIMEOUT] ${_stateToString(_currentTestState)} state\'i timeouta uğradı');

    switch (_currentTestState) {
      case TestState.waitingReport:
        logs.add('Rapor timeout - manuel isteniyor');
        _requestDeviceScore();

        // ✅ DÜZELTİLDİ: Timeout durumunda da testi kaydet
        _saveTimeoutTest();
        break;

      case TestState.starting:
        logs.add('Test başlatma timeout');
        _setTestState(TestState.error, message: 'Başlatma timeout');
        _saveErrorTest('Başlatma timeout');
        break;

      default:
        _setTestState(TestState.error, message: 'State timeout');
        _saveErrorTest('State timeout');
    }
  }

// ✅ YENİ: Timeout testi kaydetme
  void _saveTimeoutTest() {
    final test = TestVerisi(
      testAdi: _currentTestName.isNotEmpty ? _currentTestName : "Timeout Test",
      tarih: DateTime.now(),
      minBasinc: _currentMinPressure,
      maxBasinc: _currentMaxPressure,
      toplamPompaSuresi: faz0Sure + faz4PompaSuresi,
      puan: _calculateScoreFromFazScores(), // Mevcut puanları kullan
      sonuc: "TIMEOUT",
    );

    _saveTestAndTriggerCallback(test);
  }

// ✅ YENİ: Hata testi kaydetme
  void _saveErrorTest(String errorMessage) {
    final test = TestVerisi(
      testAdi: _currentTestName.isNotEmpty ? _currentTestName : "Hatalı Test",
      tarih: DateTime.now(),
      minBasinc: _currentMinPressure,
      maxBasinc: _currentMaxPressure,
      toplamPompaSuresi: faz0Sure + faz4PompaSuresi,
      puan: 0,
      sonuc: "HATA: $errorMessage",
    );

    _saveTestAndTriggerCallback(test);
  }

// ✅ YENİ: Ortak kaydetme metodu
  void _saveTestAndTriggerCallback(TestVerisi test) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      saveTest(test).then((_) {
        if (onTestCompleted != null) {
          onTestCompleted!(test);
        }
      });
    });
  }

  void startTestMode(int mode) {
    if (mode < 1 || mode > 8) return;

    // ÖNCE: Valf güncellemesini durdur
    _valveUpdateInProgress = true;

    try {
      currentTestMode = mode;
      isTestModeActive = true;

      // Test modu başlangıç durumu
      if (mode == 7) {
        // SÖKME modu - tüm valfleri aç
        valveStates.forEach((key, value) {
          valveStates[key] = true;
        });
      } else if (mode == 8) {
        // ACİL DURDUR - tüm valfleri kapat
        valveStates.forEach((key, value) {
          valveStates[key] = false;
        });
      } else {
        // Normal test modları - mevcut vitese göre ayarla
        _updateValvesFromBluetoothData();
      }

      // Bluetooth komutunu gönder
      sendCommand(mode.toString());

      // Tüm valf durumlarını gönder
      _sendAllValveStatesToBluetooth();

      // Bluetooth modunda valf güncelleme timer'ını başlat
      if (!mockMode) {
        _startTestModeValveUpdateTimer();
      }

      // Mesajları ayarla
      if (mode == 7) {
        connectionMessage = "SÖKME MODU AKTİF - Basınç düşürülüyor";
        logs.add("🚨 SÖKME Modu başlatıldı");
      } else if (mode == 8) {
        connectionMessage = "ACİL DURDUR AKTİF - Sistem durduruluyor";
        logs.add("🛑 ACİL DURDUR Modu başlatıldı");
      } else {
        connectionMessage = "Test Mod $mode aktif: ${testModeDescriptions[mode]}";
        logs.add("Test Mod $mode başlatıldı");
      }

      notifyListeners();

    } finally {
      _valveUpdateInProgress = false;
    }
  }


  void _startTestModeValveUpdateTimer() {
    _testModeValveUpdateTimer?.cancel();

    final updateInterval = _getTestModeValveUpdateInterval();

    _testModeValveUpdateTimer = Timer.periodic(updateInterval, (timer) {
      if (!isTestModeActive || !isConnected || mockMode || _valveUpdateInProgress) {
        return;
      }

      _valveUpdateInProgress = true;

      try {
        // Bluetooth'tan güncel valf durumlarını al ve güncelle
        _updateValvesFromBluetoothData();

        // UI'ı güncelle
        notifyListeners();
      } finally {
        _valveUpdateInProgress = false;
      }
    });
  }

  void _updateValvesFromBluetoothData() {
    if (!isConnected || mockMode) return;

    try {
      // Mevcut vitese göre valf durumlarını hesapla
      Map<String, bool> newValveStates = _calculateValveStatesForCurrentGear();

      // YENİ: Valf durumlarını karşılaştır, sadece değişenleri güncelle
      bool hasChanges = false;
      newValveStates.forEach((key, newState) {
        if (valveStates[key] != newState) {
          valveStates[key] = newState;
          hasChanges = true;

          // Bluetooth'a valf durumunu gönder (sadece değişenler için)
          _sendSingleValveStateToBluetooth(key, newState);
        }
      });

      if (hasChanges) {
        logs.add('[VALF] Valf durumları güncellendi - Vites: $gear');
      }

    } catch (e) {
      logs.add('[HATA] Valf güncelleme hatası: $e');
    }
  }


  // ✅ YENİ EKLENDİ: Mevcut valf durumlarını Bluetooth'a gönder
  Map<String, bool> _calculateValveStatesForCurrentGear() {
    // Mevcut vitese göre valf durumlarını hesapla
    Map<String, bool> states = Map.from(valveStates);

    // Önce tüm vites valflerini sıfırla
    states['N433'] = false;
    states['N434'] = false;
    states['N437'] = false;
    states['N438'] = false;
    states['N436'] = false;
    states['N440'] = false;
    states['N435'] = false;
    states['N439'] = false;

    // Vites -> Valf eşleştirmesi
    switch (gear) {
      case '1':
        states['N436'] = true;
        states['N433'] = true;
        states['N435'] = isK1K2Mode;
        break;
      case '2':
        states['N440'] = true;
        states['N437'] = true;
        states['N439'] = isK1K2Mode;
        break;
      case '3':
        states['N436'] = true;
        states['N435'] = isK1K2Mode;
        break;
      case '4':
        states['N440'] = true;
        states['N439'] = isK1K2Mode;
        break;
      case '5':
        states['N436'] = true;
        states['N434'] = true;
        states['N435'] = isK1K2Mode;
        break;
      case '6':
        states['N440'] = true;
        states['N439'] = isK1K2Mode;
        break;
      case '7':
        states['N436'] = true;
        states['N435'] = isK1K2Mode;
        break;
      case 'R':
        states['N440'] = true;
        states['N438'] = true;
        states['N439'] = isK1K2Mode;
        break;
      default: // 'BOŞ'
        break;
    }

    enforceK1K2Rules();
    return states;
  }

  void _sendSingleValveStateToBluetooth(String valveKey, bool state) {
    try {
      String bluetoothCommand = valveKey;
      if (valveKey == 'N436') bluetoothCommand = 'N36';
      if (valveKey == 'N440') bluetoothCommand = 'N40';

      String command = state ? "1" : "0";
      sendCommand("$bluetoothCommand=$command");

    } catch (e) {
      logs.add('[HATA] Valf durumu gönderilemedi $valveKey: $e');
    }
  }

  Duration _getTestModeValveUpdateInterval() {
    switch (currentTestMode) {
      case 1:
        return Duration(milliseconds: 100); // Çok Hızlı
      case 2:
        return Duration(milliseconds: 120); // Çok Hızlı
      case 3:
        return Duration(milliseconds: 40); // Ultra Hızlı
      case 4:
        return Duration(milliseconds: 70); // Hızlı
      case 5:
        return Duration(milliseconds: 200); // Normal
      case 6:
        return Duration(milliseconds: 500); // Yavaş
      case 7:
        return Duration(milliseconds: 10); // En Hızlı
      default:
        return Duration(milliseconds: 100);
    }
  }

  void stopTestMode(int mode) {
    // Valf güncellemelerini durdur
    _valveUpdateInProgress = true;
    _testModeValveUpdateTimer?.cancel();
    _testModeValveUpdateTimer = null;

    try {
      // Sistem durumunu sıfırla
      currentTestMode = 0;
      isTestModeActive = false;
      pumpOn = false;
      gear = 'BOŞ';

      // Valf durumlarını sıfırla
      _updateValvesFromBluetoothData();

      // Bluetooth komutlarını gönder
      sendCommand("S");
      Future.delayed(const Duration(milliseconds: 100), () {
        sendCommand("s");
        _sendAllValveStatesToBluetooth();
      });

      connectionMessage = "Test modu kapatıldı";
      logs.add("Test modu durduruldu - Sistem sıfırlandı");

      notifyListeners();

    } finally {
      _valveUpdateInProgress = false;
    }
  }

  Future<void> loadTestsFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('saved_tests') ?? [];
    completedTests =
        saved
            .map(
              (s) => TestVerisi.fromJson(
                Map<String, dynamic>.from(json.decode(s)),
              ),
            )
            .toList();
    notifyListeners();
  }

  Future<void> startFullTest(String testAdi) async {
    if (isTesting) return;

    _setTestState(TestState.starting, message: testAdi);

    try {
      _currentTestName = testAdi;
      _resetAllTimers();
      _resetTestVariables();
      _resetValvesForTestStart();

      _setTestState(TestState.running);

      await _runBluetoothTestWithTimeout(testAdi, DateTime.now());

    } catch (e) {
      _setTestState(TestState.error, message: e.toString());
    }
  }

  void _resetValvesForTestStart() {
    // Tüm valfleri kapat
    valveStates.forEach((key, value) {
      valveStates[key] = false;
    });

    // Vitesi BOŞ'a al ve valfleri güncelle
    gear = 'BOŞ';
    _currentVites = 'BOŞ';
    selectedGear = 'BOŞ';
    updateValvesByGear('BOŞ');

    // Pompayı kapat
    pumpOn = false;

    // K1K2 modunu kapat
    isK1K2Mode = false;

    logs.add('Test başlangıcı - Tüm valfler sıfırlandı, vites BOŞ');
  }

  void _startTestTimer() {
    _testTimer?.cancel();
    _elapsedTestSeconds = 0;
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isTesting && !isPaused) {
        _elapsedTestSeconds++;
        notifyListeners();
      }
    });
  }

  Future<void> _runBluetoothTestWithTimeout(String testAdi, DateTime startTime) async {
    _testCompletionCompleter = Completer<void>();

    // Testi starting state'ine al
    _setTestState(TestState.starting, message: 'Timeout timer başlatıldı');

    _testTimeoutTimer = Timer(_testTimeout, () {
      if (!_testCompletionCompleter!.isCompleted) {
        _setTestState(TestState.error, message: 'Test timeout');
        _testCompletionCompleter!.completeError(
          Exception("Test timeout (${_testTimeout.inMinutes} dakika)"),
        );
      }
    });

    _startBluetoothTestListener();
    sendCommand("TEST");

    logs.add("TEST komutu gönderildi - State: ${_stateToString(_currentTestState)}");

    try {
      await _testCompletionCompleter!.future;
      logs.add("Test completer tamamlandı");

    } catch (e) {
      _setTestState(TestState.error, message: e.toString());
      throw e;
    } finally {
      _testTimeoutTimer?.cancel();
      _testCompletionCompleter = null;
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
    print('[BLUETOOTH_TEST] Mesaj alındı: $message');

    // State machine'e göre mesajı işle
    _processMessageBasedOnState(message);

    // Orijinal listener callback'i (eğer varsa)
    if (onDeviceReportReceived != null) {
      onDeviceReportReceived!(message);
    }

    notifyListeners();
  }

  void _processMessageBasedOnState(String message) {
    // Önce callback'lere bildir
    if (message.contains("PUAN:") ||
        message.contains("RAPOR:") ||
        message.contains("/100")) {
      _handleDeviceReport(message);
    }

    // Sonra state'e göre işle
    switch (_currentTestState) {
      case TestState.running:
        _processRunningStateMessage(message);
        break;
      case TestState.waitingReport:
        _processWaitingReportStateMessage(message);
        break;
      case TestState.parsingReport:
        _processParsingReportStateMessage(message);
        break;
      default:
        _processDefaultStateMessage(message);
        break;
    }
  }

  void _processRunningStateMessage(String message) {
    // Test çalışırken gelen mesajları işle
    if (message.contains("FAZ 4 tamamlandı") || message.contains("FAZ 4 tamamlandi")) {
      logs.add('FAZ 4 tamamlandı');
      currentPhase = TestPhase.phase4;

      // ✅ DÜZELTİLDİ: FAZ 4 bittiğinde hemen waitingReport'a geç
      _setTestState(TestState.waitingReport, message: 'FAZ 4 tamamlandı');
    }

    // ✅ GELİŞTİRİLDİ: Daha güvenli rapor tespiti
    if (message.contains("MEKATRONİK SAĞLIK RAPORU") ||
        message.contains("GENEL PUAN:") ||
        message.contains("TOPLAM PUAN:") ||
        message.contains("FAZ 0:") && message.contains("FAZ 4:")) {

      logs.add('Rapor başlangıcı tespit edildi - waitingReport state\'ine geçiliyor');
      _setTestState(TestState.waitingReport, message: 'Rapor başlangıcı alındı');
    }

    if (message.contains("HATA:") || message.contains("TIMEOUT")) {
      _setTestState(TestState.error, message: 'Cihaz hatası: $message');
      _saveErrorTest('Cihaz hatası: $message');
    }
  }

  void _processWaitingReportStateMessage(String message) {
    // Rapor beklerken mesajları topla
    _collectedReport += message + '\n';
    logs.add('[RAPOR TOPLANIYOR] ${message.length} karakter eklendi');

    // Rapor tamamlandı mı?
    if (_isReportComplete(_collectedReport)) {
      logs.add('Rapor tamamlandı, parsing state\'ine geçiliyor');
      _setTestState(TestState.parsingReport, message: 'Rapor tamamlandı');
    }
  }

  void _processParsingReportStateMessage(String message) {
    // Parsing sırasında gelen ek mesajları işle (gerekirse)
    _collectedReport += message + '\n';
  }

  void _processDefaultStateMessage(String message) {
    // Diğer state'lerde genel mesaj işleme
    _parsePressureData(message);
    _parseGearData(message);
    _parseValveStates(message);
  }

  void _parsePressureData(String message) {
    final pressureMatch = RegExp(r'([\d.]+)\s*bar').firstMatch(message);
    if (pressureMatch != null) {
      pressure = double.tryParse(pressureMatch.group(1)!) ?? pressure;

      // Min/Max basınç güncelle
      if (pressure < _currentMinPressure) _currentMinPressure = pressure;
      if (pressure > _currentMaxPressure) _currentMaxPressure = pressure;
    }
  }

  void _parseGearData(String message) {
    // Vites parsing işlemleri - mevcut _parseVitesDurumu'nun basitleştirilmiş hali
    if (message.contains('1. vites') || message.contains('1.vites')) {
      _updateGear('1');
    }
    else if (message.contains('2. vites') || message.contains('2.vites')) {
      _updateGear('2');
    }
    else if (message.contains('3. vites') || message.contains('3.vites')) {
      _updateGear('3');
    }
    else if (message.contains('4. vites') || message.contains('4.vites')) {
      _updateGear('4');
    }
    else if (message.contains('5. vites') || message.contains('5.vites')) {
      _updateGear('5');
    }
    else if (message.contains('6. vites') || message.contains('6.vites')) {
      _updateGear('6');
    }
    else if (message.contains('7. vites') || message.contains('7.vites')) {
      _updateGear('7');
    }
    else if (message.contains('r vites') || message.contains('r.vites') ||
        message.contains('R vites') || message.contains('R.vites')) {
      _updateGear('R');
    }
  }

  void _updateGear(String newGear) {
    if (gear != newGear) {
      gear = newGear;
      _currentVites = newGear;
      selectedGear = newGear;

      // Test modu aktif değilse valfleri güncelle
      if (!isTestModeActive || mockMode) {
        updateValvesByGear(newGear);
      }

      logs.add('Vites değişti: $newGear');
    }
  }

  void _parseValveStates(String message) {
    if (message.startsWith('VALVES:')) {
      updateValvesFromMessage(message);
    }
  }


  bool _isReportComplete(String report) {
    // "MEKATRONİK SAĞLIK RAPORU" içeriyorsa tamamlandı say
    if (report.contains("MEKATRONİK SAĞLIK RAPORU")) {
      return true;
    }

    // Alternatif olarak FAZ puanları ve toplam puan kontrolü
    bool hasFazPuanlari = report.contains("FAZ 0:") &&
        report.contains("FAZ 1:") &&
        report.contains("FAZ 2:") &&
        report.contains("FAZ 3:") &&
        report.contains("FAZ 4:");

    bool hasToplamPuan = report.contains("TOPLAM PUAN:") ||
        report.contains("GENEL PUAN:");

    return hasFazPuanlari && hasToplamPuan;
  }

  void _parseTestModuRaporu(String report) {
    logs.add("TEST MODU RAPORU PARSE EDİLİYOR");

    try {
      // Genel bilgiler
      final minBasincMatch = RegExp(r'Min Basınç:\s*([\d.]+)').firstMatch(report);
      final maxBasincMatch = RegExp(r'Max Basınç:\s*([\d.]+)').firstMatch(report);
      final ortalamaBasincMatch = RegExp(r'Ortalama Basınç:\s*([\d.]+)').firstMatch(report);

      // Pompa süresi: "0 dk 15 sn"
      final pompaSureMatch = RegExp(r'Toplam Pompa Çalışma Süresi:\s*(\d+)\s*dk\s*(\d+)\s*sn').firstMatch(report);
      final dusukBasincSayisiMatch = RegExp(r'Düşük Basınç.*Sayısı:\s*(\d+)').firstMatch(report);
      final dusukBasincSureMatch = RegExp(r'Toplam Düşük Basınç Süresi:\s*(\d+)\s*sn').firstMatch(report);
      final toplamVitesGecisMatch = RegExp(r'Toplam Vites Geçişi Sayısı:\s*(\d+)').firstMatch(report);

      // Vites geçişleri
      final vitesGecisleri = <String, int>{};
      final vitesRegex = RegExp(r'(\d+)\.\s*Vites:\s*(\d+)');
      for (final match in vitesRegex.allMatches(report)) {
        vitesGecisleri['V${match.group(1)}'] = int.parse(match.group(2)!);
      }
      final rVitesMatch = RegExp(r'R\s*Vites:\s*(\d+)').firstMatch(report);
      if (rVitesMatch != null) {
        vitesGecisleri['VR'] = int.parse(rVitesMatch.group(1)!);
      }

      // Pompa süresini saniyeye çevir
      int toplamPompaSuresiSn = 0;
      if (pompaSureMatch != null) {
        final dakika = int.tryParse(pompaSureMatch.group(1) ?? '0') ?? 0;
        final saniye = int.tryParse(pompaSureMatch.group(2) ?? '0') ?? 0;
        toplamPompaSuresiSn = dakika * 60 + saniye;
      }

      final rapor = TestModuRaporu(
        tarih: DateTime.now(),
        testModu: currentTestMode,
        minBasinc: double.tryParse(minBasincMatch?.group(1) ?? '0') ?? 0,
        maxBasinc: double.tryParse(maxBasincMatch?.group(1) ?? '0') ?? 0,
        ortalamaBasinc: double.tryParse(ortalamaBasincMatch?.group(1) ?? '0') ?? 0,
        toplamPompaCalismaSuresiSn: toplamPompaSuresiSn,
        dusukBasincSayisi: int.tryParse(dusukBasincSayisiMatch?.group(1) ?? '0') ?? 0,
        toplamDusukBasincSuresiSn: int.tryParse(dusukBasincSureMatch?.group(1) ?? '0') ?? 0,
        toplamVitesGecisSayisi: int.tryParse(toplamVitesGecisMatch?.group(1) ?? '0') ?? 0,
        vitesGecisleri: vitesGecisleri,
      );

      _sonTestModuRaporu = rapor;
      logs.add("TEST MODU RAPORU OLUŞTURULDU: Mod ${rapor.testModu}");

      // ✅ YENİ: Callback'i sadece bir kez tetikle
      if (onTestModuRaporuAlindi != null && !_testModuRaporuCallbackRegistered) {
        _testModuRaporuCallbackRegistered = true;
        onTestModuRaporuAlindi!(rapor);

        // 1 saniye sonra callback kaydını sıfırla
        Future.delayed(Duration(seconds: 1), () {
          _testModuRaporuCallbackRegistered = false;
        });
      }

      notifyListeners();

    } catch (e) {
      logs.add("TEST MODU RAPORU PARSE HATASI: $e");
    }
  }


  void _parseCompleteReport(String report) {
    logs.add("TAM RAPOR PARSE EDİLİYOR: ${report.length} karakter");

    try {
      // Genel bilgiler
      final minBasincMatch = RegExp(r'Min Basınç:\s*([\d.]+)').firstMatch(report);
      final maxBasincMatch = RegExp(r'Max Basınç:\s*([\d.]+)').firstMatch(report);
      final pompaSureMatch = RegExp(r'Toplam Pompa:\s*(\d+)\s*dk\s*(\d+)\s*sn').firstMatch(report);

      // FAZ puanları - YENİ FORMAT
      final fazPuanlari = <String, int>{};

      // "FAZ 0: 2/10" formatını parse et
      final fazPuanRegex = RegExp(r'FAZ\s*(\d+):\s*(\d+)/(\d+)');
      for (final match in fazPuanRegex.allMatches(report)) {
        fazPuanlari['faz${match.group(1)}'] = int.parse(match.group(2)!);
      }

      // Genel puan - İKİ FARKLI FORMAT
      final genelPuanMatch = RegExp(r'GENEL PUAN:\s*([\d.]+)/100').firstMatch(report);
      final mekatronikPuanMatch = RegExp(r'TOPLAM PUAN:\s*(\d+)/100').firstMatch(report);

      // HANGİ PUANI KULLANACAĞIMIZA KARAR VER
      int finalPuan = 0;
      if (mekatronikPuanMatch != null) {
        finalPuan = int.parse(mekatronikPuanMatch.group(1)!); // TOPLAM PUAN: 16/100
      } else if (genelPuanMatch != null) {
        finalPuan = int.parse(genelPuanMatch.group(1)!); // GENEL PUAN: 40.9/100
      }

      // TestVerisi'ni güncelle
      final updatedTest = TestVerisi(
        testAdi: _currentTestName,
        tarih: DateTime.now(),
        minBasinc: double.tryParse(minBasincMatch?.group(1) ?? '0') ?? _currentMinPressure,
        maxBasinc: double.tryParse(maxBasincMatch?.group(1) ?? '0') ?? _currentMaxPressure,
        toplamPompaSuresi: _calculateTotalPumpSeconds(pompaSureMatch),
        puan: finalPuan,
        sonuc: _parseSonuc(report),
        fazPuanlari: fazPuanlari,
      );

      // ✅ YENİ: Testi hemen kaydet ve callback tetikle
      _saveParsedTest(updatedTest);

      // ✅ State'i completed'e geçir
      if (_currentTestState == TestState.parsingReport) {
        _setTestState(TestState.completed, message: 'Rapor parse edildi');
      }

      logs.add("RAPOR BAŞARIYLA PARSE EDİLDİ: ${updatedTest.puan}/100 puan");

      // ✅ YENİ: State machine ile test tamamlanma işlemini tetikle
      if (_testCompletionCompleter != null && !_testCompletionCompleter!.isCompleted) {
        logs.add("Rapor parsing tamamlandı - Test completer tamamlanıyor");
        _testCompletionCompleter!.complete();
      }

      // ✅ YENİ: State'i completed'e geçir (eğer parsing state'inde isek)
      if (_currentTestState == TestState.parsingReport) {
        _setTestState(TestState.completed, message: 'Rapor parse edildi - Puan: $finalPuan');
      }

    } catch (e) {
      logs.add("RAPOR PARSE HATASI: $e");

      // ✅ YENİ: Hata durumunda state machine'i güncelle
      if (_testCompletionCompleter != null && !_testCompletionCompleter!.isCompleted) {
        _testCompletionCompleter!.completeError(Exception("Rapor parse hatası: $e"));
      }

      _setTestState(TestState.error, message: 'Rapor parse hatası: $e');
    }
  }


  double _calculateTotalPumpSeconds(RegExpMatch? match) {
    if (match == null) return 0;
    final dakika = int.tryParse(match.group(1) ?? '0') ?? 0;
    final saniye = int.tryParse(match.group(2) ?? '0') ?? 0;
    return (dakika * 60 + saniye).toDouble();
  }

  String _parseSonuc(String report) {
    if (report.contains("DURUM: KÖTÜ")) return "KÖTÜ";
    if (report.contains("DURUM: SORUNLU")) return "SORUNLU";
    if (report.contains("DURUM: ORTA")) return "ORTA";
    if (report.contains("DURUM: İYİ")) return "İYİ";
    if (report.contains("DURUM: MÜKEMMEL")) return "MÜKEMMEL";
    return "BELİRSİZ";
  }

  Future<void> _saveParsedTest(TestVerisi test) async {
    await saveTest(test);

    // ✅ YENİ: Callback'i hemen tetikle
    if (onTestCompleted != null) {
      onTestCompleted!(test);
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

        // ✅ YENİ: FAZ 4 puanı geldiğinde state machine ile işle
        logs.add("FAZ 4 puanı alındı: $puan - Test tamamlanıyor");

        if (_testCompletionCompleter != null && !_testCompletionCompleter!.isCompleted) {
          _testCompletionCompleter!.complete();
        }

        // Eğer running state'inde isek waitingReport'a geç
        if (_currentTestState == TestState.running) {
          _setTestState(TestState.waitingReport, message: 'FAZ 4 tamamlandı - Puan: $puan');
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
    if (puan >= maxPuan * 0.8) {
      // 80-100% = çok iyi
      return 8.0 + Random().nextDouble() * 2.0; // 8-10 saniye
    } else if (puan >= maxPuan * 0.6) {
      // 60-79% = iyi
      return 10.0 + Random().nextDouble() * 3.0; // 10-13 saniye
    } else {
      // 0-59% = kötü
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

  int _parsePuanFromCollectedData() {
    if (_deviceScores.containsKey('total')) {
      return _deviceScores['total']!.round();
    }

    // Loglardan puanı bulmaya çalış
    for (String log in logs.reversed) {
      final mekatronikMatch = RegExp(r'TOPLAM PUAN:\s*(\d+)/100').firstMatch(log);
      if (mekatronikMatch != null) {
        return int.parse(mekatronikMatch.group(1)!);
      }

      final genelMatch = RegExp(r'GENEL PUAN:\s*([\d.]+)/100').firstMatch(log);
      if (genelMatch != null) {
        return double.parse(genelMatch.group(1)!).round();
      }
    }

    return 0; // Varsayılan puan
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
    if (_currentTestState != TestState.running) return;

    _setTestState(TestState.paused);
    sendCommand("DUR");
  }

  void resumeTest() {
    if (_currentTestState != TestState.paused) return;

    _setTestState(TestState.running);
    sendCommand("DEVAM");
  }

  void stopTest() {
    // ✅ DÜZELTİLDİ: State machine üzerinden kontrol et
    if (_currentTestState == TestState.idle ||
        _currentTestState == TestState.completed ||
        _currentTestState == TestState.error) {
      return;
    }

    _setTestState(TestState.cancelled);
    sendCommand("aq");

    // ✅ YENİ: İptal edilen testi de kaydet
    _saveCancelledTest();

    _resetAllTimers();
    _resetSystemAfterTest();
  }

  // ✅ YENİ: İptal edilen testi kaydetme metodu
  void _saveCancelledTest() {
    final test = TestVerisi(
      testAdi: _currentTestName.isNotEmpty ? _currentTestName : "İptal Edilen Test",
      tarih: DateTime.now(),
      minBasinc: _currentMinPressure,
      maxBasinc: _currentMaxPressure,
      toplamPompaSuresi: faz0Sure + faz4PompaSuresi,
      puan: 0, // İptal edildiği için 0 puan
      sonuc: "İPTAL EDİLDİ",
    );

    // Testi kaydet ve callback tetikle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      saveTest(test).then((_) {
        if (onTestCompleted != null) {
          onTestCompleted!(test);
        }
      });
    });
  }

  Future<void> _saveFullTest() async {
    final toplamPuan = _deviceScores['total'] ?? _calculateScoreFromFazScores();
    final sonuc = MekatronikPuanlama.durum(toplamPuan.round());

    final test = TestVerisi(
      testAdi: _currentTestName.isNotEmpty ? _currentTestName : "Tam Test",
      tarih: DateTime.now(),
      minBasinc: _currentMinPressure,
      maxBasinc: _currentMaxPressure,
      toplamPompaSuresi: faz0Sure + faz4PompaSuresi,
      puan: toplamPuan.round(),
      sonuc: sonuc,
    );

    await saveTest(test);

    // ✅ CRITICAL: Callback'i burada tetikle
    if (onTestCompleted != null) {
      logs.add('onTestCompleted callback tetikleniyor: ${test.testAdi}');
      onTestCompleted!(test);
    }
  }

  void _resetSystemAfterTest() {
    pumpOn = false;
    gear = 'BOŞ';
    updateValvesByGear(gear);
    isPaused = false;

    // ✅ YENİ: Sadece completed state'inde değil, tüm bitişlerde timer'ları temizle
    _resetAllTimers();

    // ❌ BURAYI KALDIRIN: Test kaydı artık ayrı metodlarda yapılıyor
    // _saveFullTest();
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
    // ✅ YENİ EKLENDİ: Valf güncelleme timer'ını temizle
    _testModeValveUpdateTimer?.cancel();
    _testModeValveUpdateTimer = null;
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

    // 🆕 YENİ: Bluetooth komutunu güncelle
    if (value) {
      sendCommand("K1K2ON");  // true ise K1K2ON gönder
    } else {
      sendCommand("K1K2OFF"); // false ise K1K2OFF gönder
    }

    // K1/K2 valflerini güncelle
    if (!value) {
      // K1K2 modu kapatıldığında K1 ve K2 valflerini kapat
      valveStates['N435'] = false;
      valveStates['N439'] = false;
    }

    logs.add('K1K2 Modu: ${value ? "Açıldı (K1K2ON)" : "Kapatıldı (K1K2OFF)"}');
    notifyListeners();
  }

  // AppState.dart dosyasında _simulateConnection metodunu bulun ve şu şekilde değiştirin:

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

    // 🔁 DEĞİŞTİRİLDİ: 2 saniye yerine 200ms (saniyede 5 kez)
    Timer.periodic(const Duration(milliseconds: 333), (t) {
      // Bluetooth modunda simülasyon yapma
      if (!mockMode) {
        t.cancel();
        return;
      }

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
        // Dar aralık modu (42-52 bar)
        pressure = 47.0 + random.nextDouble() * 5.0; // 47-52 bar arası
      } else {
        // Geniş aralık modu (42-60 bar)
        pressure = minPressure + random.nextDouble() * (maxPressure - minPressure);
      }

      // 2️⃣ Vites durumuna göre valfleri ayarla (daha seyrek yapabiliriz)
      if (random.nextInt(10) == 0) { // %10 ihtimalle vites değiştir
        final gears = ['1', '2', '3', '4', '5', '6', '7', 'R', 'BOŞ'];
        gear = gears[random.nextInt(gears.length)];
        updateValvesByGear(gear);
      }

      // 3️⃣ Basınç Valfi manuel kontrol bilgisi (daha seyrek log)
      if (random.nextInt(25) == 0) { // %4 ihtimalle log ekle
        lastMessage =
        '[MOCK] Güncel basınç: ${pressure.toStringAsFixed(2)} bar | N436=${valveStates['N436']} N440=${valveStates['N440']} | Vites=$gear';
      }

      // 4️⃣ Mekatronik Puan (test sırasında)
      if (testStatus == 'Çalışıyor' && random.nextInt(50) == 0) {
        mechatronicScore = min(100, mechatronicScore + random.nextInt(3));
      }

      enforceK1K2Rules();

      // Sadece değişiklik olduğunda log ekle ve notify et
      if (random.nextInt(10) == 0) { // %10 ihtimalle notify
        notifyListeners();
      }
    });
  }

  void _simulateTestMode() {
    // Bluetooth modunda simülasyon yapma
    if (!mockMode) return;

    if (!isTestModeActive || currentTestMode == 0) return;

    // Test moduna göre vites döngüsü hızı
    final delaySeconds = _getTestModeDelay();

    // Test modu timer'ını başlat (eğer başlatılmadıysa)
    _testModeTimer ??= Timer.periodic(
      Duration(milliseconds: (delaySeconds * 1000).round()),
      (timer) {
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
        logs.add(
          'Test modu aktif: Vites $gear, Pompa: ${pumpOn ? "Açık" : "Kapalı"}',
        );

        notifyListeners();
      },
    );
  }

  // Test moduna göre gecikme süresi (saniye cinsinden)
  double _getTestModeDelay() {
    switch (currentTestMode) {
      case 1:
        return 1.0; // Çok Hızlı - 1.0ms yerine 0.5s (simülasyon için)
      case 2:
        return 1.2; // Çok Hızlı - 1.2ms yerine 0.6s
      case 3:
        return 0.4; // Ultra Hızlı - 0.4ms yerine 0.2s
      case 4:
        return 0.7; // Hızlı - 0.7ms yerine 0.35s
      case 5:
        return 2.0; // Normal - 2.0ms yerine 1.0s
      case 6:
        return 5.0; // Yavaş - 5.0ms yerine 2.5s
      case 7:
        return 0.1; // En Hızlı - 0.1ms yerine 0.05s
      default:
        return 1.0;
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

    logs.add(
      'Test Mod $currentTestMode: Vites $gear\'a geçildi - Tüm valfler güncellendi',
    );
  }

  // Test moduna göre basınç simülasyonu
  double _simulateTestModePressure() {
    final random = Random();
    double basePressure;

    switch (currentTestMode) {
      case 1: // Yüksek hız testi - yüksek basınç
      case 2: // Orta-yüksek hız
        basePressure =
            pressureToggle
                ? 47.0 + random.nextDouble() * 5.0
                : // Dar aralık: 47-52
                50.0 + random.nextDouble() * 10.0; // Geniş aralık: 50-60
        break;
      case 3: // FAZ 0/2 pompa kontrolü - değişken basınç
        basePressure =
            pressureToggle
                ? 44.0 + random.nextDouble() * 8.0
                : // Dar aralık: 44-52
                42.0 + random.nextDouble() * 18.0; // Geniş aralık: 42-60
        break;
      case 4: // FAZ 4 standart test - stabil basınç
        basePressure =
            pressureToggle
                ? 47.0 + random.nextDouble() * 5.0
                : // Dar aralık: 47-52
                48.0 + random.nextDouble() * 7.0; // Geniş aralık: 48-55
        break;
      case 5: // Genel kontrol - normal basınç
        basePressure =
            pressureToggle
                ? 45.0 + random.nextDouble() * 7.0
                : // Dar aralık: 45-52
                46.0 + random.nextDouble() * 9.0; // Geniş aralık: 46-55
        break;
      case 6: // Detaylı gözlem - yavaş değişen basınç
        basePressure =
            pressureToggle
                ? 43.0 + random.nextDouble() * 9.0
                : // Dar aralık: 43-52
                42.0 + random.nextDouble() * 13.0; // Geniş aralık: 42-55
        break;
      case 7: // SÖKME modu - düşük basınç (0-10 bar arası)
        basePressure = random.nextDouble() * 10;
        break;
      default:
        basePressure =
            pressureToggle
                ? 47.0 + random.nextDouble() * 5.0
                : // Dar aralık: 47-52
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

    // K1/K2 valflerini de sıfırla
    valveStates['N435'] = false;
    valveStates['N439'] = false;

    // Vites -> Valf eşleştirmesi (DQ200 GERÇEK KURALLARI)
    switch (gear) {
      case '1':
        // 1. Vites: n436 ve n433 aktif
        valveStates['N436'] = true;
        valveStates['N433'] = true;
        valveStates['N435'] = isK1K2Mode; // K1 kavraması
        break;

      case '2':
        // 2. Vites: n440 ve n437 aktif
        valveStates['N440'] = true;
        valveStates['N437'] = true;
        valveStates['N439'] = isK1K2Mode; // K2 kavraması
        break;

      case '3':
        // 3. Vites: SADECE n436 aktif
        valveStates['N436'] = true;
        valveStates['N435'] = isK1K2Mode; // K1 kavraması
        break;

      case '4':
        // 4. Vites: SADECE n440 aktif
        valveStates['N440'] = true;
        valveStates['N439'] = isK1K2Mode; // K2 kavraması
        break;

      case '5':
        // 5. Vites: n436 ve n434 aktif
        valveStates['N436'] = true;
        valveStates['N434'] = true;
        valveStates['N435'] = isK1K2Mode; // K1 kavraması
        break;

      case '6':
        // 6. Vites: SADECE n440 aktif
        valveStates['N440'] = true;
        valveStates['N439'] = isK1K2Mode; // K2 kavraması
        break;

      case '7':
        // 7. Vites: SADECE n436 aktif
        valveStates['N436'] = true;
        valveStates['N435'] = isK1K2Mode; // K1 kavraması
        break;

      case 'R':
        // R Vitesi: n440 ve n438 aktif
        valveStates['N440'] = true;
        valveStates['N438'] = true;
        valveStates['N439'] =
            isK1K2Mode; // K2 kavraması - R vitesi K2 ile çalışıyor!
        break;

      default: // 'BOŞ' veya diğer durumlar
        // Tüm valfler kapalı kalacak
        break;
    }

    // K1/K2 kurallarını uygula
    enforceK1K2Rules();

    // Log kaydı
    logs.add(
      'Vites $gear: Valf durumları güncellendi - '
      'N433:${valveStates['N433']}, '
      'N434:${valveStates['N434']}, '
      'N437:${valveStates['N437']}, '
      'N438:${valveStates['N438']}, '
      'N436:${valveStates['N436']}, '
      'N440:${valveStates['N440']}, '
      'K1:${valveStates['N435']}, '
      'K2:${valveStates['N439']}',
    );
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

  Future<bool> tryConnect(
    String address,
    String name, {
    int timeout = 15,
  }) async {
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
      final subscription = FlutterBluetoothSerial.instance
          .startDiscovery()
          .listen((r) {
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
        orElse:
            () => BluetoothDiscoveryResult(
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
        connectionMessage =
            "DQ200 cihazı bulunamadı. Listeden elle seçebilirsiniz.";
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
    // ❌ BU SATIRI SİLİN - çift loglamaya neden oluyor
    // logs.add('[${DateTime.now().toIso8601String()}] $msg');

    lastMessage = msg;
    updateValvesFromMessage(msg);
    _parseLineContent(msg); // Tek log kaynağı bu olacak
    notifyListeners();
  }

// YENİ: Zaman damgası olmadan mesaj içeriğini parse eden fonksiyon
  void _parseLineContent(String msg) {
    // ✅ SADECE state machine'in kaçırdığı acil mesajları işle
    // Örneğin: Bağlantı durumu, acil durumlar vb.

    // Acil basınç güncellemesi (her durumda gerekli)
    final pressureMatch = RegExp(r'([\d.]+)\s*bar').firstMatch(msg);
    if (pressureMatch != null) {
      pressure = double.tryParse(pressureMatch.group(1)!) ?? pressure;

      // Min/Max basınç güncelle (her durumda)
      if (pressure < _currentMinPressure) _currentMinPressure = pressure;
      if (pressure > _currentMaxPressure) _currentMaxPressure = pressure;
    }

    // ✅ Test modu raporu hala burada işlenmeli
    if (msg.contains("===== TEST BİTİŞ RAPORU =====") && !_waitingForTestModuRaporu) {
      logs.add("TEST BİTİŞ RAPORU ALINDI - Parse ediliyor");
      _waitingForTestModuRaporu = true;
      _collectedTestModuRaporu = '';
    }

    // Test modu raporu toplama
    if (_waitingForTestModuRaporu) {
      _collectedTestModuRaporu += msg + '\n';
      if (msg.contains("R Vites:") || _isTestModuRaporuComplete(_collectedTestModuRaporu)) {
        logs.add("TEST MODU RAPORU TAMAMLANDI");
        _parseTestModuRaporu(_collectedTestModuRaporu);
        _waitingForTestModuRaporu = false;
        _collectedTestModuRaporu = '';
      }
    }

    // ✅ State machine'e mesajı ilet
    _processMessageBasedOnState(msg);
  }

  bool _isTestModuRaporuComplete(String report) {
    // Raporun tamamlandığını anlamak için gerekli alanları kontrol et
    return report.contains("Min Basınç:") &&
        report.contains("Max Basınç:") &&
        report.contains("Toplam Vites Geçişi Sayısı:") &&
        report.contains("R Vites:");
  }

  // YENİ: Test modu raporu değişkenleri
  bool _waitingForTestModuRaporu = false;
  String _collectedTestModuRaporu = '';


  Map<String, dynamic>? get currentFazBilgisi {
    if (currentFazNo >= 0 && fazBilgileri.containsKey(currentFazNo)) {
      return fazBilgileri[currentFazNo];
    }
    return null;
  }

  void _sendAllValveStatesToBluetooth() {
    try {
      String valveCommand = "VALVES:";
      valveStates.forEach((key, value) {
        String btKey = key;
        if (key == 'N436') btKey = 'N36';
        if (key == 'N440') btKey = 'N40';
        valveCommand += "$btKey=${value ? '1' : '0'},";
      });

      valveCommand = valveCommand.substring(0, valveCommand.length - 1);
      sendCommand(valveCommand);

    } catch (e) {
      logs.add('[HATA] Tüm valf durumları gönderilemedi: $e');
    }
  }

  void addDeviceReportCallback(Function(String) callback) {
    _reportCallbacks.add(callback);
  }

  void _handleDeviceReport(String report) {
    for (var callback in _reportCallbacks) {
      callback(report);
    }
    _reportCallbacks.clear(); // Sadece bir kere temizle
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
      if (gearValue == '0')
        selectedGear = 'BOŞ';
      else if (gearValue == 'R')
        selectedGear = 'R';
      else
        selectedGear = gearValue;

      gear = selectedGear;

      // 🔹 Vites değişince valfleri güncelle
      updateValvesByGear(gear);
    } else if (cmd == 'TEST') {
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

    // ✅ Log sayısını sınırla
    if (logs.length > _maxLogCount) {
      logs.removeRange(0, logs.length - _maxLogCount);
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
    _testModeTimer?.cancel();
    // ✅ YENİ EKLENDİ: Valf güncelleme timer'ını temizle
    _testModeValveUpdateTimer?.cancel();
    _sub?.cancel();
    _operationTimer?.cancel();
    _testTimer?.cancel();
    _phaseTimer?.cancel();
    bt.dispose();
    super.dispose();
  }
}
