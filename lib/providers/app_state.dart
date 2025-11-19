import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/test_verisi.dart';
import '../models/testmode_verisi.dart';
import '../services/bluetooth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database.dart';
import '../services/report_parser_service.dart';
import '../services/timer_service.dart';
import '../utils/mekatronik_puanlama.dart';

enum TestPhase { idle, phase0, phase1, phase2, phase3, phase4, completed }

enum TestState {
  idle, // Hazır
  starting, // Başlıyor
  running, // Çalışıyor
  paused, // Duraklatıldı
  waitingReport, // Rapor Bekleniyor
  parsingReport, // Rapor Parse Ediliyor
  completed, // Tamamlandı
  error, // Hata
  cancelled, // İptal Edildi
}

class AppState extends ChangeNotifier {
  final BluetoothService bt = BluetoothService();

  // ✅ YENİ SERVİSLER
  final TimerService _timerService = TimerService();
  final ReportParserService _parserService = ReportParserService();

  // Live values
  bool get isTestRunning => _currentTestState == TestState.running;
  bool get isTestPaused => _currentTestState == TestState.paused;
  bool get canStartTest =>
      _currentTestState == TestState.idle ||
      _currentTestState == TestState.completed ||
      _currentTestState == TestState.error;

  bool get canPauseTest => _currentTestState == TestState.running;
  bool get canResumeTest => _currentTestState == TestState.paused;
  bool get canStopTest =>
      _currentTestState == TestState.running ||
      _currentTestState == TestState.paused ||
      _currentTestState == TestState.waitingReport;
  bool _testCompletionCallbackFired = false;
  double pressure = 0;
  String gear = '-';
  final DatabaseService _dbService = DatabaseService();
  bool pumpOn = false;
  String lastMessage = '';
  bool pressureToggle = true;
  bool _testResultSaved = false;
  Map<String, dynamic> testResults = {};
  dynamic myPressureSensor;
  dynamic myPump;
  dynamic myGearSensor;
  bool isK1K2Mode = false;
  double _currentMinPressure = double.infinity;
  double _currentMaxPressure = 0.0;
  bool isPaused = false;
  bool _isSavingProcessActive = false;
  bool testFinished = false;
  List<TestVerisi> completedTests = [];
  bool get testPaused => isPaused;
  String _currentTestName = '';
  double faz0Sure = 0;
  double faz2Puan = 0; // Anahtarlar: N436, N440, N436+N440, Kapali
  double faz3Puan = 0; // Anahtarlar: V1, V2, V3_7, V4_6, V5, VR
  double faz4PompaSuresi = 0;
  String autoCycleMode = '0';
  Duration _testTimeout = Duration(minutes: 25); // 25 dakika timeout
  Map<String, double> _deviceScores = {};
  Completer<void>? _testCompletionCompleter;
  bool _waitingForReport = false;
  String _collectedReport = '';
  String _currentVites = 'BOŞ';
  String _currentFaz = 'HAZIR';
  int _toplamTekrar = 0;
  int get toplamTekrar => _toplamTekrar;

  TestModuRaporu? _sonTestModuRaporu;
  TestModuRaporu? get sonTestModuRaporu => _sonTestModuRaporu;
  final int _maxLogCount = 200; // Maksimum log sayısı
  bool _valveUpdateInProgress = false;
  bool _testModuRaporuCallbackRegistered = false;
  TestState _currentTestState = TestState.idle;
  TestState get currentTestState => _currentTestState;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  TestPhase _currentPhase = TestPhase.idle;
  TestPhase get currentPhase => _currentPhase;

  // Önceki state (geri dönüş için)
  TestState? _previousState;

  // YENİ: Test modu raporu callback'i
  Function(TestModuRaporu)? onTestModuRaporuAlindi;

  // Getter metodları
  String get currentVites => _currentVites;
  String get currentFaz => _currentFaz;

  bool isReconnecting = false;
  final Map<int, Map<String, dynamic>> fazBilgileri = {
    0: {'sure': '20 saniye', 'aciklama': 'Pompa Yükseliş'},
    1: {'sure': '3 dakika', 'aciklama': 'Isınma'},
    2: {'sure': '4 dakika', 'aciklama': 'Basınç Valf Testi'},
    3: {'sure': '6 dakika', 'aciklama': 'Vites Valfleri Testi'},
    4: {'sure': '10 dakika', 'aciklama': 'Otomatik Vites Testi'},
    5: {'sure': '2 dakika', 'aciklama': 'K1 ve K2 Basınç Testi'},
  };

  void _parseToplamTekrar(String msg) {
    // "Toplam tekrar: XXXX" formatını yakala
    final toplamTekrarMatch = RegExp(
      r'Toplam\s+tekrar:\s*(\d+)',
    ).firstMatch(msg);
    if (toplamTekrarMatch != null) {
      _toplamTekrar =
          int.tryParse(toplamTekrarMatch.group(1)!) ?? _toplamTekrar;
      logs.add('Toplam tekrar güncellendi: $_toplamTekrar');
      notifyListeners();
      return;
    }

    // "Döngü tamamlandı: X | Toplam tekrar: Y" formatını yakala
    final donguTekrarMatch = RegExp(
      r'Döngü\s+tamamlandı:\s*\d+\s*\|\s*Toplam\s+tekrar:\s*(\d+)',
    ).firstMatch(msg);
    if (donguTekrarMatch != null) {
      _toplamTekrar = int.tryParse(donguTekrarMatch.group(1)!) ?? _toplamTekrar;
      logs.add('Döngü tamamlandı - Toplam tekrar: $_toplamTekrar');
      notifyListeners();
    }
  }

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

  bool isTesting = false;
  double phaseProgress = 0.0;
  String phaseStatusMessage = "";
  List<BluetoothDevice> discoveredDevices = [];
  // Test fazları için timer
  int _elapsedTestSeconds = 0;
  Function(String)? onDeviceReportReceived;
  final List<Function(String)> _reportCallbacks = [];
  int _faz4VitesSayisi = 0;
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

    // Eğer completed state'ine geçiyorsak ve önceki state de completed değilse
    if (newState == TestState.completed &&
        _currentTestState != TestState.completed) {
      if (_testCompletionCallbackFired) {
        logs.add('[STATE] Test zaten tamamlandı, tekrar kayıt engellendi');
        return;
      }
    }

    _previousState = _currentTestState;
    _currentTestState = newState;

    // Log ekle
    logs.add(
      '[STATE] ${_stateToString(_previousState)} → ${_stateToString(newState)} ${message ?? ''}',
    );

    // State'e özel işlemler
    _handleStateTransition(newState);

    notifyListeners();
  }

  String _stateToString(TestState? state) {
    switch (state) {
      case TestState.idle:
        return 'HAZIR';
      case TestState.starting:
        return 'BAŞLATILIYOR';
      case TestState.running:
        return 'ÇALIŞIYOR';
      case TestState.paused:
        return 'DURAKLATILDI';
      case TestState.waitingReport:
        return 'RAPOR BEKLENİYOR';
      case TestState.parsingReport:
        return 'RAPOR İŞLENİYOR';
      case TestState.completed:
        return 'TAMAMLANDI';
      case TestState.error:
        return 'HATA';
      case TestState.cancelled:
        return 'İPTAL EDİLDİ';
      default:
        return 'BİLİNMEYEN';
    }
  }

  Future<Map<String, dynamic>> getDatabaseInfo() async {
    return await _dbService.getDatabaseInfo();
  }

  Future<bool> isTableExists() async {
    return await _dbService.isTableExists();
  }

  Future<void> deleteTest(TestVerisi test) async {
    if (test.id != null) {
      await _dbService.deleteTest(test.id!);
    }
    completedTests.remove(test);
    notifyListeners();
  }

  // Tüm testleri silme
  Future<void> clearTests() async {
    await _dbService.deleteAllTests();
    completedTests.clear();
    notifyListeners();
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
    if (_testCompletionCallbackFired) return;
    _testCompletionCallbackFired = true;

    logs.add('Test tamamlandı!');
    _currentPhase = TestPhase.completed;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // ✅ DEĞİŞİKLİK BURADA:
        // Eğer test sonucu zaten rapor parsing sırasında kaydedildiyse (_testResultSaved == true),
        // tekrar _saveFullTest() çağırma. Sadece callback tetikle.
        TestVerisi? test;

        if (!_testResultSaved) {
          // Rapor gelmediyse veya parse edilemediyse eldeki verilerle kaydet
          test = await _saveFullTest();
          logs.add('💾 Test eldeki verilerle kaydedildi (Rapor gelmedi).');
        } else {
          // Zaten kaydedilmiş, son testi listeden al
          if (completedTests.isNotEmpty) {
            test = completedTests.first;
            logs.add('⏭️ Test zaten kaydedilmiş, tekrar kayıt atlanıyor.');
          }
        }

        if (test != null && onTestCompleted != null) {
          onTestCompleted!(test);
        }
      } catch (e) {
        logs.add('❌ Test bitirme işlemleri hatası: $e');
      } finally {
        Future.delayed(Duration(seconds: 3), () {
          _testCompletionCallbackFired = false;
        });
      }
    });
  }

  Future<void> initializeApp() async {
    if (_isInitialized) return;

    try {
      print('🔄 AppState initialize başlıyor...');

      // ✅ ÖNCE: Veritabanı bağlantısını kur
      await _dbService.database;

      // ✅ SONRA: Testleri veritabanından yükle
      await _loadTestsFromDatabase();

      print('✅ AppState başarıyla initialize edildi');
      print('📊 Yüklenen test sayısı: ${completedTests.length}');

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('❌ AppState initialize hatası: $e');
      _isInitialized = false;
    }
  }

  void _onTestError() {
    logs.add('Test hatayla sonlandı!');
    isTesting = false;
    testFinished = true;
    testStatus = 'Hata';

    // ✅ YENİ: Hatalı testi kaydet
    _saveErrorTest('Test hatayla sonlandı');

    _resetSystemAfterTest();
  }

  // ✅ YENİ: Hata testi kaydetme metodu
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

  // ✅ YENİ: Ortak kaydetme metodu
  void _saveTestAndTriggerCallback(TestVerisi test) {
    // Önce yerel listede kontrol et
    final isDuplicate = completedTests.any(
      (t) =>
          t.testAdi == test.testAdi &&
          t.tarih.difference(test.tarih).inSeconds.abs() < 5,
    );

    if (isDuplicate) {
      logs.add('⚠️ Yinelenen test kaydı engellendi: ${test.testAdi}');
      return;
    }

    // ✅ HEMEN kaydet, async işlemi bekleme
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await saveTest(test);
        logs.add('✅ Test kaydedildi: ${test.testAdi}');

        // Callback'i tetikle
        if (onTestCompleted != null) {
          onTestCompleted!(test);
        }
      } catch (e) {
        logs.add('❌ Test kaydetme hatası: $e');
        // Hata durumunda bile callback tetikle
        if (onTestCompleted != null) {
          onTestCompleted!(test);
        }
      }
    });
  }

  void startTestMode(int mode) {
    if (mode < 1 || mode > 8) return;

    // ✅ EKLENECEK KOD BLOĞU: Eski rapor kalıntılarını temizle
    _waitingForTestModuRaporu = false;
    _collectedTestModuRaporu = '';
    // -------------------------------------------------------

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
        connectionMessage =
            "Test Mod $mode aktif: ${testModeDescriptions[mode]}";
        logs.add("Test Mod $mode başlatıldı");
      }

      notifyListeners();
    } finally {
      _valveUpdateInProgress = false;
    }
  }

  void _startTestModeValveUpdateTimer() {
    final updateInterval = _getTestModeValveUpdateInterval();

    _timerService.startPeriodic('valve_update', updateInterval, (timer) {
      if (!isTestModeActive ||
          !isConnected ||
          mockMode ||
          _valveUpdateInProgress)
        return;

      _valveUpdateInProgress = true;
      try {
        _updateValvesFromBluetoothData();
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

    // ❌ ESKİ KOD: _testModeValveUpdateTimer?.cancel();
    // ✅ YENİ KOD: Servis üzerinden iptal et
    _timerService.cancel('valve_update');

    // Rapor beklentisini sıfırla
    _waitingForTestModuRaporu = false;
    _collectedTestModuRaporu = '';

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

  Future<void> startFullTest(String testAdi) async {
    if (isTesting) return;

    _testResultSaved = false;
    _isSavingProcessActive = false;
    _setTestState(TestState.starting, message: testAdi);
    _currentPhase = TestPhase.phase0;
    _resetAllTimers(); // ⚠️ Bu timer'ı sıfırlıyor!
    _resetTestVariables();

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
    _elapsedTestSeconds = 0;
    _timerService.startPeriodic('test_timer', const Duration(seconds: 1), (
      timer,
    ) {
      // Timer mantığı aynen kalır
      if (_currentTestState == TestState.starting ||
          _currentTestState == TestState.running ||
          _currentTestState == TestState.waitingReport ||
          _currentTestState == TestState.parsingReport) {
        _elapsedTestSeconds++;
        notifyListeners();
      }
    });
  }

  Future<void> _runBluetoothTestWithTimeout(
    String testAdi,
    DateTime startTime,
  ) async {
    _testCompletionCompleter = Completer<void>();

    // Testi starting state'ine al
    _setTestState(TestState.starting, message: 'Timeout timer başlatıldı');

    // ❌ ESKİ KOD: _testTimeoutTimer = Timer(...
    // ✅ YENİ KOD: TimerService kullanımı
    _timerService.startTimeout('test_timeout', _testTimeout, () {
      if (_testCompletionCompleter != null &&
          !_testCompletionCompleter!.isCompleted) {
        _setTestState(TestState.error, message: 'Test timeout');
        _testCompletionCompleter!.completeError(
          Exception("Test timeout (${_testTimeout.inMinutes} dakika)"),
        );
      }
    });

    _startBluetoothTestListener();
    sendCommand("TEST");

    logs.add(
      "TEST komutu gönderildi - State: ${_stateToString(_currentTestState)}",
    );

    try {
      await _testCompletionCompleter!.future;
      logs.add("Test completer tamamlandı");
    } catch (e) {
      _setTestState(TestState.error, message: e.toString());
      throw e;
    } finally {
      // ❌ ESKİ KOD: _testTimeoutTimer?.cancel();
      // ✅ YENİ KOD: Servis üzerinden iptal
      _timerService.cancel('test_timeout');
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
    // ✅ YEDEK: Eski formatları da destekle (geriye dönük uyumluluk)
    if (message.contains("atlandi!") || message.contains("atlandı!")) {
      logs.add('🔍 Atlanan faz mesajı tespit edildi');
      _handlePhaseTransition(message);
    }
    // Test çalışırken gelen mesajları işle
    else if (message.contains("FAZ 0 tamamlandı") ||
        message.contains("FAZ 0 tamamlandi")) {
      logs.add('🔍 FAZ 0 tamamlandı mesajı tespit edildi');
      _handlePhaseTransition(message);
    } else if (message.contains("FAZ 1 tamamlandı") ||
        message.contains("FAZ 1 tamamlandi")) {
      logs.add('🔍 FAZ 1 tamamlandı mesajı tespit edildi');
      _handlePhaseTransition(message);
    } else if (message.contains("FAZ 2 tamamlandı") ||
        message.contains("FAZ 2 tamamlandi")) {
      logs.add('🔍 FAZ 2 tamamlandı mesajı tespit edildi');
      _handlePhaseTransition(message);
    } else if (message.contains("FAZ 3 tamamlandı") ||
        message.contains("FAZ 3 tamamlandi")) {
      logs.add('🔍 FAZ 3 tamamlandı mesajı tespit edildi');
      _handlePhaseTransition(message);
    } else if (message.contains("FAZ 4 tamamlandı") ||
        message.contains("FAZ 4 tamamlandi")) {
      logs.add('🔍 FAZ 4 tamamlandı mesajı tespit edildi');
      // ✅ DÜZELTİLDİ: FAZ 4 bittiğinde hemen waitingReport'a geç
      _setTestState(TestState.waitingReport, message: 'FAZ 4 tamamlandı');
    }
    // ✅ GELİŞTİRİLDİ: Daha güvenli rapor tespiti
    if (message.contains("MEKATRONİK SAĞLIK RAPORU") ||
        message.contains("GENEL PUAN:") ||
        message.contains("TOPLAM PUAN:")) {
      logs.add(
        'Rapor başlangıcı tespit edildi - waitingReport state\'ine geçiliyor',
      );
      _setTestState(
        TestState.waitingReport,
        message: 'Rapor başlangıcı alındı',
      );
    }

    if (message.contains("HATA:") || message.contains("TIMEOUT")) {
      _setTestState(TestState.error, message: 'Cihaz hatası: $message');
      _saveErrorTest('Cihaz hatası: $message');
    }

    // ✅ GELİŞTİRİLMİŞ: Daha güvenli rapor tespiti
    final raporBaslangicKontrol =
        message.contains("MEKATRONİK SAĞLIK RAPORU") ||
        message.contains("GENEL PUAN:") ||
        message.contains("TOPLAM PUAN:") ||
        (message.contains("FAZ 0:") && message.contains("FAZ 4:")) ||
        message.contains("TEST RAPORU:") ||
        message.contains("========================================");

    if (raporBaslangicKontrol && _currentTestState == TestState.running) {
      logs.add(
        '📊 Rapor başlangıcı tespit edildi - waitingReport state\'ine geçiliyor',
      );
      _setTestState(
        TestState.waitingReport,
        message: 'Rapor başlangıcı alındı',
      );
    }

    // ✅ GELİŞTİRİLMİŞ: Hata tespiti
    final hataKontrol =
        message.contains("HATA:") ||
        message.contains("TIMEOUT") ||
        message.contains("HATALI") ||
        message.contains("BASARISIZ") ||
        (message.contains("Uyarı:") &&
            message.contains("Düşük basınç") &&
            _currentPhase == TestPhase.phase0);

    if (hataKontrol) {
      logs.add('❌ Hata tespit edildi: $message');
      _setTestState(TestState.error, message: 'Cihaz hatası: $message');
      _saveErrorTest('Cihaz hatası: $message');
    }

    if (message.contains("Test protokolu tamamlandi") ||
        message.contains(">>> Test protokolu tamamlandi! <<<")) {
      logs.add('🎉 Test protokolü tamamlandı sinyali alındı.');

      // 🛑 KRİTİK KONTROL:
      // Eğer şu an rapor bekliyorsak, rapor parse ediyorsak veya zaten kayıt yaptıysak
      // state'i 'completed' yapıp akışı bozma! Bırak parsing işlemi kendi bitirsin.
      if (_currentTestState == TestState.waitingReport ||
          _currentTestState == TestState.parsingReport ||
          _testResultSaved ||
          _isSavingProcessActive) {
        logs.add(
          '🛡️ Rapor işlemi sürdüğü için "Tamamlandı" sinyali yutuldu (Erken bitiş engellendi).',
        );
        return; // ⛔️ BURADAN ÇIK, AŞAĞI GİTME
      }

      _setTestState(TestState.completed, message: 'Test protokolü tamamlandı');
    }
  }

  void _handlePhaseTransition(String message) {
    // ✅ YENİ: "atlandı!" mesajını tespit et ve fazı güncelle
    if (message.contains("atlandi!") || message.contains("atlandı!")) {
      _handleSkippedPhase(message);
      return;
    }

    if (message.contains("FAZ 0 tamamlandi") ||
        message.contains("FAZ 0 tamamlandı")) {
      _currentPhase = TestPhase.phase1;
      logs.add('✅ FAZ 0 tamamlandı → FAZ 1 başlıyor');
      notifyListeners();
    } else if (message.contains("FAZ 1 tamamlandi") ||
        message.contains("FAZ 1 tamamlandı")) {
      _currentPhase = TestPhase.phase2;
      logs.add('✅ FAZ 1 tamamlandı → FAZ 2 başlıyor');
      notifyListeners();
    } else if (message.contains("FAZ 2 tamamlandi") ||
        message.contains("FAZ 2 tamamlandı")) {
      _currentPhase = TestPhase.phase3;
      logs.add('✅ FAZ 2 tamamlandı → FAZ 3 başlıyor');
      notifyListeners();
    } else if (message.contains("FAZ 3 tamamlandi") ||
        message.contains("FAZ 3 tamamlandı")) {
      _currentPhase = TestPhase.phase4;
      logs.add('✅ FAZ 3 tamamlandı → FAZ 4 başlıyor');
      notifyListeners();
    } else if (message.contains("FAZ 4 tamamlandi") ||
        message.contains("FAZ 4 tamamlandı")) {
      _currentPhase = TestPhase.completed;
      logs.add('✅ FAZ 4 tamamlandı → TEST TAMAMLANDI');
      notifyListeners();
    } else if (message.contains("TEST TAMAMLANDI") ||
        message.contains("MEKATRONİK SAĞLIK RAPORU")) {
      _currentPhase = TestPhase.completed;
      logs.add('🎉 TEST TAMAMLANDI - Rapor bekleniyor');
      notifyListeners();
    }
  }

  void _handleSkippedPhase(String message) {
    logs.add('🔍 Atlanan faz tespit edildi: $message');

    // Mesajın başındaki FAZ bilgisini bul
    final fazMatch = RegExp(r'FAZ\s*(\d+)').firstMatch(message);
    if (fazMatch != null) {
      int atlananFaz = int.tryParse(fazMatch.group(1)!) ?? -1;

      if (atlananFaz >= 0 && atlananFaz <= 4) {
        // Atlanan fazdan bir sonraki faza geç
        TestPhase yeniFaz;
        String logMesaji;

        switch (atlananFaz) {
          case 0:
            yeniFaz = TestPhase.phase1;
            logMesaji = 'FAZ 0 atlandı → FAZ 1 başlıyor';
            break;
          case 1:
            yeniFaz = TestPhase.phase2;
            logMesaji = 'FAZ 1 atlandı → FAZ 2 başlıyor';
            break;
          case 2:
            yeniFaz = TestPhase.phase3;
            logMesaji = 'FAZ 2 atlandı → FAZ 3 başlıyor';
            break;
          case 3:
            yeniFaz = TestPhase.phase4;
            logMesaji = 'FAZ 3 atlandı → FAZ 4 başlıyor';
            break;
          case 4:
            yeniFaz = TestPhase.completed;
            logMesaji = 'FAZ 4 atlandı → TEST TAMAMLANDI';

            // ✅ FAZ 4 atlandıysa waitingReport state'ine geç
            if (_currentTestState == TestState.running) {
              _setTestState(TestState.waitingReport, message: 'FAZ 4 atlandı');
            }
            break;
          default:
            return;
        }

        _currentPhase = yeniFaz;
        logs.add('⏩ $logMesaji');
        notifyListeners();
      }
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
    } else if (message.contains('2. vites') || message.contains('2.vites')) {
      _updateGear('2');
    } else if (message.contains('3. vites') || message.contains('3.vites')) {
      _updateGear('3');
    } else if (message.contains('4. vites') || message.contains('4.vites')) {
      _updateGear('4');
    } else if (message.contains('5. vites') || message.contains('5.vites')) {
      _updateGear('5');
    } else if (message.contains('6. vites') || message.contains('6.vites')) {
      _updateGear('6');
    } else if (message.contains('7. vites') || message.contains('7.vites')) {
      _updateGear('7');
    } else if (message.contains('r vites') ||
        message.contains('r.vites') ||
        message.contains('R vites') ||
        message.contains('R.vites')) {
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
    // ❌ VALVES: mesajları gelmiyor, bu yüzden bu metodu değiştir
    // Bunun yerine vites mesajlarından valf durumlarını çıkar
    if (message.contains('. vites') || message.contains('R vites')) {
      _updateValvesFromGearMessage(message);
    }
  }

  bool _isReportComplete(String report) {
    // Tam test raporu formatına göre kontrol
    if (report.contains("===== MEKATRONİK SAĞLIK RAPORU =====")) {
      return true;
    }

    // Alternatif kontrol
    bool hasFazPuanlari =
        report.contains("FAZ 0:") &&
        report.contains("FAZ 1:") &&
        report.contains("FAZ 2:") &&
        report.contains("FAZ 3:") &&
        report.contains("FAZ 4:");

    bool hasToplamPuan = report.contains("TOPLAM PUAN:");

    return hasFazPuanlari && hasToplamPuan;
  }

  void _parseTestModuRaporu(String report) {
    logs.add("TEST MODU RAPORU PARSE EDİLİYOR...");

    try {
      // ✅ LOGIC SİLİNDİ -> SERVİSE TAŞINDI
      final rapor = _parserService.parseTestModuRaporu(report, currentTestMode);

      _sonTestModuRaporu = rapor;

      if (onTestModuRaporuAlindi != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onTestModuRaporuAlindi!(rapor);
        });
      }
      notifyListeners();
    } catch (e) {
      logs.add("❌ TEST MODU RAPORU PARSE HATASI: $e");
    }
  }

  void _parseCompleteReport(String report) {
    logs.add("TAM RAPOR PARSE EDİLİYOR...");

    try {
      // Logic servise taşındı
      final updatedTest = _parserService.parseFullReport(
        report,
        _currentTestName,
        _currentMinPressure,
        _currentMaxPressure,
      );

      _saveParsedTest(updatedTest);

      if (_currentTestState == TestState.parsingReport) {
        _setTestState(TestState.completed, message: 'Rapor parse edildi');
      }

      logs.add("RAPOR BAŞARIYLA PARSE EDİLDİ: ${updatedTest.puan}/100 puan");

      // State machine ile test tamamlanma işlemini tetikle
      if (_testCompletionCompleter != null &&
          !_testCompletionCompleter!.isCompleted) {
        logs.add("Rapor parsing tamamlandı - Test completer tamamlanıyor");
        _testCompletionCompleter!.complete();
      }

      // State'i completed'e geçir
      if (_currentTestState == TestState.parsingReport) {
        _setTestState(
          TestState.completed,
          // ❌ ESKİ KOD: Puan: $finalPuan
          // ✅ YENİ KOD: Puan: ${updatedTest.puan}
          message: 'Rapor parse edildi - Puan: ${updatedTest.puan}',
        );
      }
    } catch (e) {
      logs.add("RAPOR PARSE HATASI: $e");

      if (_testCompletionCompleter != null &&
          !_testCompletionCompleter!.isCompleted) {
        _testCompletionCompleter!.completeError(
          Exception("Rapor parse hatası: $e"),
        );
      }

      _setTestState(TestState.error, message: 'Rapor parse hatası: $e');
    }
  }

  // MEVCUT KODU GÜNCELLEYİN:
  void _saveParsedTest(TestVerisi test) async {
    if (_testResultSaved) {
      logs.add(
        '⚠️ Rapor zaten işlendi ve kaydedildi, mükerrer işlem engellendi.',
      );
      return;
    }

    await saveTest(test);
    _testResultSaved = true; // ✅ EKLENECEK: Kaydedildi olarak işaretle
    logs.add('✅ Parsed test kaydedildi: ${test.testAdi}');

    notifyListeners();
  }

  Future<void> saveTest(TestVerisi test) async {
    // 🛡️ KİLİT KONTROLÜ
    if (_testResultSaved) {
      logs.add('🛑 Mükerrer kayıt engellendi (Flag Active): ${test.testAdi}');
      return;
    }

    // İsme ve süreye göre son kontrol (Double Check)
    if (completedTests.any(
      (t) =>
          t.testAdi == test.testAdi &&
          DateTime.now().difference(t.tarih).inSeconds.abs() < 10,
    )) {
      logs.add('🛑 Mükerrer kayıt engellendi (Time Check): ${test.testAdi}');
      return;
    }

    _testResultSaved = true; // 🚩 Bayrağı HEMEN kaldır (await öncesi)

    try {
      final id = await _dbService.insertTest(test);

      // Listeye ekleme işlemleri...
      final testWithId = test.copyWith(id: id);
      completedTests.insert(0, testWithId);

      logs.add('✅ Test TEKİL olarak kaydedildi: ID $id');
      notifyListeners();
    } catch (e) {
      _testResultSaved =
          false; // Hata olursa bayrağı indir ki tekrar denenebilsin
      logs.add('❌ Kayıt hatası: $e');
      rethrow;
    }
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

  void stopTest() {
    // Eğer zaten bittiyse veya kaydedildiyse durdurma komutu işleme
    if (_testResultSaved ||
        _currentTestState == TestState.completed ||
        _currentTestState == TestState.idle) {
      return;
    }

    _setTestState(TestState.cancelled);
    sendCommand("aq");

    // İptal kaydını sadece henüz bir şey kaydedilmediyse yap
    if (!_testResultSaved) {
      _saveCancelledTest();
    }

    _resetAllTimers();
    _resetSystemAfterTest();
  }

  // ✅ YENİ: İptal edilen testi kaydetme metodu
  void _saveCancelledTest() {
    final test = TestVerisi(
      testAdi:
          _currentTestName.isNotEmpty ? _currentTestName : "İptal Edilen Test",
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

  Future<TestVerisi> _saveFullTest() async {
    // Eğer zaten kaydedildiyse veya şu an rapor parse ediliyorsa BURADA DUR.
    if (_testResultSaved || _currentTestState == TestState.parsingReport) {
      logs.add(
        '⚠️ _saveFullTest iptal edildi: Zaten kayıt var veya Rapor bekleniyor.',
      );
      if (completedTests.isNotEmpty) return completedTests.first;
      throw Exception("Kayıt çakışması");
    }

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

    // ✅ TESTİ HEMEN KAYDET
    await saveTest(test);
    _testResultSaved = true;
    logs.add(
      '✅ Test veritabanına kaydedildi: ${test.testAdi} - ${test.puan}/100',
    );

    return test;
  }

  void _resetSystemAfterTest() {
    pumpOn = false;
    gear = 'BOŞ';
    updateValvesByGear(gear);
    isPaused = false;

    // ✅ YENİ: Sadece completed state'inde değil, tüm bitişlerde timer'ları temizle
    _resetAllTimers();
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
    // ✅ DÜZELTİLDİ: K1 ve K2 için SADECE "K1" ve "K2" komutları (toggle)
    else if (key == 'N435') {
      // K1
      bluetoothCommand = 'K1'; // Her tıklamada sadece "K1" komutu
    } else if (key == 'N439') {
      // K2
      bluetoothCommand = 'K2'; // Her tıklamada sadece "K2" komutu
    }

    // Komutu gönder - K1/K2 için sadece komut adı, diğerleri için durum
    if (key == 'N435' || key == 'N439') {
      sendCommand(bluetoothCommand); // Sadece "K1" veya "K2"
    } else {
      sendCommand("$bluetoothCommand=${newState ? '1' : '0'}");
    }

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
    _timerService.cancelAll(); // ✅ TEK SATIRDA HEPSİNİ SIFIRLA

    // UI update timer'ı yeniden başlatmak gerekebilir çünkü cancelAll hepsini sildi
    _startUiUpdateTimer();
    _startOperationTimer();
    _startConnectionMonitor();

    _elapsedTestSeconds = 0;
    notifyListeners();
  }

  void _startUiUpdateTimer() {
    _timerService.startTimeout('test_timeout', _testTimeout, () {
      if (_testCompletionCompleter != null &&
          !_testCompletionCompleter!.isCompleted) {
        _setTestState(TestState.error, message: 'Test timeout');
        _testCompletionCompleter!.completeError(Exception("Test timeout"));
      }
    });
  }

  void updateValvesFromMessage(String msg) {
    // ❌ BU METODU TAMAMEN DEĞİŞTİRİN - VALVES: mesajları gelmiyor
    // Bunun yerine vites mesajlarından valf durumlarını çıkar

    // Vites mesajlarından valf durumlarını güncelle
    if (msg.contains('. vites') || msg.contains('R vites')) {
      _updateValvesFromGearMessage(msg);
    }
  }

  void _updateValvesFromGearMessage(String msg) {
    // Vites mesajından valf durumlarını hesapla
    String detectedGear = 'BOŞ';

    if (msg.contains('1. vites'))
      detectedGear = '1';
    else if (msg.contains('2. vites'))
      detectedGear = '2';
    else if (msg.contains('3. vites'))
      detectedGear = '3';
    else if (msg.contains('4. vites'))
      detectedGear = '4';
    else if (msg.contains('5. vites'))
      detectedGear = '5';
    else if (msg.contains('6. vites'))
      detectedGear = '6';
    else if (msg.contains('7. vites'))
      detectedGear = '7';
    else if (msg.contains('R vites'))
      detectedGear = 'R';

    if (detectedGear != 'BOŞ') {
      // Vites değişti, valfleri güncelle
      updateValvesByGear(detectedGear);
    }
  }

  AppState({this.mockMode = false}) {
    _startOperationTimer();
    _init();
  }

  Future<void> _init() async {
    await _loadPrefs();
    notifyListeners();
  }

  // ✅ YENİ: Sadece veritabanından test yükleme
  Future<void> _loadTestsFromDatabase() async {
    try {
      completedTests = await _dbService.getTests();
      print('📊 Veritabanından ${completedTests.length} test yüklendi');
    } catch (e) {
      print('❌ Veritabanından test yükleme hatası: $e');
      completedTests = [];
    }
  }

  // ❌ ESKİ METODU GÜNCELLEYİN - Sadece SharedPreferences yerine SQLite kullanın
  Future<void> loadTestsFromLocal() async {
    await _loadTestsFromDatabase(); // Artık sadece SQLite kullan
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

    // ✅ DÜZELTİLDİ: K1 ve K2 için SADECE "K1" ve "K2" komutları
    if (valve == 'N435') {
      // K1
      bluetoothCommand = 'K1'; // Sadece "K1" komutu
    } else if (valve == 'N439') {
      // K2
      bluetoothCommand = 'K2'; // Sadece "K2" komutu
    }

    // Komutu gönder - K1/K2 için sadece komut adı
    if (valve == 'N435' || valve == 'N439') {
      sendCommand(bluetoothCommand); // Sadece "K1" veya "K2"
    } else {
      sendCommand("$bluetoothCommand=${state ? '1' : '0'}");
    }

    enforceK1K2Rules();
    notifyListeners();
  }

  void setK1K2Mode(bool value) {
    isK1K2Mode = value;

    // 🆕 DÜZELTİLDİ: Sadece mod açılıp kapanırken ON/OFF komutları
    if (value) {
      sendCommand("K1K2ON"); // Mod açılıyorsa K1K2ON
    } else {
      sendCommand("K1K2OFF"); // Mod kapanıyorsa K1K2OFF

      // K1K2 modu kapatıldığında K1 ve K2 valflerini kapat
      valveStates['N435'] = false;
      valveStates['N439'] = false;
    }

    logs.add('K1K2 Modu: ${value ? "Açıldı (K1K2ON)" : "Kapatıldı (K1K2OFF)"}');
    notifyListeners();
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
    // ❌ ESKİ KOD: _connectionMonitorTimer?.cancel(); ...
    // ✅ YENİ KOD: TimerService kullanımı
    _timerService.startPeriodic(
      'connection_monitor',
      const Duration(seconds: 10),
      (timer) {
        if (!bt.isConnected && isConnected && !isReconnecting) {
          _handleConnectionLost();
        }
      },
    );
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
    // Basınç güncellemesi (her zaman)
    final pressureMatch = RegExp(r'Basınç:\s*([\d.]+)\s*bar').firstMatch(msg);
    if (pressureMatch != null) {
      pressure = double.tryParse(pressureMatch.group(1)!) ?? pressure;
      if (pressure < _currentMinPressure) _currentMinPressure = pressure;
      if (pressure > _currentMaxPressure) _currentMaxPressure = pressure;
    }

    // Vites parsing (her zaman)
    _parseGearData(msg);
    _parseToplamTekrar(msg);

    // ✅ YENİ: Test protokolü çalışırken test modu raporunu parse etme
    if (!isTesting && _currentTestState == TestState.idle) {
      // Test modu raporu başlangıcı (SADECE test protokolü çalışmıyorsa)
      if (msg.contains("===== TEST BİTİŞ RAPORU =====")) {
        // Eğer zaten bekliyorsak bile, yeni başlık geldiyse eskisini çöpe at ve yenisine başla!
        if (_waitingForTestModuRaporu) {
          logs.add("⚠️ Yarım kalan rapor silindi, yeni rapor alınıyor...");
        }

        logs.add("TEST BİTİŞ RAPORU ALINDI - Parse ediliyor");
        _waitingForTestModuRaporu = true;
        _collectedTestModuRaporu = ''; // Buffer'ı temizle
      }

      // Test modu raporu toplama (SADECE test protokolü çalışmıyorsa)
      if (_waitingForTestModuRaporu) {
        _collectedTestModuRaporu += msg + '\n';
        if (msg.contains("==========================") ||
            _isTestModuRaporuComplete(_collectedTestModuRaporu)) {
          // ✅ DÜZELTİLDİ
          logs.add("TEST MODU RAPORU TAMAMLANDI");
          _parseTestModuRaporu(_collectedTestModuRaporu);
          _waitingForTestModuRaporu = false;
          _collectedTestModuRaporu = '';
        }
      }
    }

    // Tam rapor başlangıcı (test protokolü için - her zaman çalışsın)
    if (msg.contains("===== MEKATRONİK SAĞLIK RAPORU =====") &&
        !_waitingForReport) {
      logs.add("TAM RAPOR BAŞLANGICI - Bekleme state'ine geçiliyor");
      _setTestState(
        TestState.waitingReport,
        message: 'Tam rapor başlangıcı alındı',
      );
      _waitingForReport = true;
      _collectedReport = '';
    }

    // Tam rapor toplama (test protokolü için - her zaman çalışsın)
    if (_waitingForReport) {
      _collectedReport += msg + '\n';
      if (msg.contains("====================================") ||
          _isReportComplete(_collectedReport)) {
        logs.add("TAM RAPOR TAMAMLANDI - Parsing state'ine geçiliyor");
        _setTestState(TestState.parsingReport, message: 'Tam rapor tamamlandı');
        _waitingForReport = false;
      }
    }

    _handlePhaseTransition(msg);
    _processMessageBasedOnState(msg);
  }

  bool _isTestModuRaporuComplete(String report) {
    // Raporun tamamlandığını anlamak için gerekli minimum alanları kontrol et
    bool hasEssentialFields =
        report.contains("Min Basınç:") &&
        report.contains("Max Basınç:") &&
        report.contains("Toplam Vites Geçişi Sayısı:");

    // Alternatif: Rapor sonu işaretini kontrol et
    bool hasEndMarker =
        report.contains("==========================") ||
        report.contains("------") ||
        report.contains("Rapor Tamamlandı");

    // Veya belirli bir uzunluk threshold'u
    bool hasMinimumLength = report.length > 100;

    return hasEssentialFields && (hasEndMarker || hasMinimumLength);
  }

  // YENİ: Test modu raporu değişkenleri
  bool _waitingForTestModuRaporu = false;
  String _collectedTestModuRaporu = '';

  Map<String, dynamic>? get currentFazBilgisi {
    final fazNo = currentFazNo;

    // HAZIR durumu için özel işlem
    if (fazNo == -1) {
      return {'sure': 'Test başlatılacak', 'aciklama': 'HAZIR'};
    }

    // TAMAMLANDI durumu için özel işlem
    if (fazNo == 5) {
      return {'sure': 'Test tamamlandı', 'aciklama': 'SONUÇLARI KONTROL EDİN'};
    }

    // Normal fazlar
    if (fazNo >= 0 && fazNo <= 4 && fazBilgileri.containsKey(fazNo)) {
      return fazBilgileri[fazNo];
    }

    // Varsayılan
    return {'sure': 'Bilinmiyor', 'aciklama': 'Aktif faz yok'};
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
    // Eğer mod pasifse K1 ve K2 daima false olmalı (Burası kalmalı)
    if (!isK1K2Mode) {
      valveStates['N435'] = false;
      valveStates['N439'] = false;
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
    _timerService.cancelAll(); // ✅ TEK SATIRDA HEPSİNİ TEMİZLE
    _sub?.cancel();
    bt.dispose();
    super.dispose();
  }
}
