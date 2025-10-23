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

  bool n436Active = false;
  bool n440Active = false;
  double faz0Sure = 0;
  double faz1Pompa = 0;
  double faz2Pompa = 0;
  Map<String, double> faz3Vitesler = {};
  double faz4Pompa = 0;
  List<TestVerisi> _testler = [];
  List<TestVerisi> get testler => _testler;
  TestPhase currentPhase = TestPhase.idle;
  bool isTesting = false;
  double phaseProgress = 0.0;
  String phaseStatusMessage = "";
  int elapsedSeconds = 0;
  Timer? _phaseTimer;
  List<BluetoothDevice> discoveredDevices = [];
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
  final Map<int, String> testModlari = {
    0: "KAPALI",
    1: "Pompa Testi",
    2: "Sızdırmazlık Testi",
    3: "Vites Testi",
    4: "Dayanıklılık",
    5: "Basınç İzleme",
    6: "Sensör Kalibrasyon",
    7: "Manuel Kontrol",
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
          valveStates[key] = (val == '1' || val.toLowerCase() == 'on');
        }
      }
    }
    notifyListeners();
  }

  AppState({this.mockMode = false}) {
    _startOperationTimer();
    _init();

    if (mockMode) {
      _simulateConnection();
    }
  }

  Future<void> loadTestsFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_tests') ?? [];
    _testler = list.map((s) {
      final json = jsonDecode(s);
      return TestVerisi(
        testAdi: json['testAdi'],
        tarih: DateTime.parse(json['tarih']),
        score: json['score'] ?? 0,
        lines: List<String>.from(json['lines'] ?? []),
        faz0Sure: (json['faz0Sure'] ?? 0).toDouble(),
        faz1Pompa: (json['faz1Pompa'] ?? 0).toDouble(),
        faz2Pompa: (json['faz2Pompa'] ?? 0).toDouble(),
        faz3Vitesler: Map<String, double>.from(json['faz3Vitesler'] ?? {}),
        faz4Pompa: (json['faz4Pompa'] ?? 0).toDouble(),
      );
    }).toList();
    notifyListeners();
  }

  Future<void> _init() async {
    await _loadPrefs();
    notifyListeners();
  }

  Future<void> saveTests() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _testler.map((t) => jsonEncode({
      'testAdi': t.testAdi,
      'tarih': t.tarih.toIso8601String(),
      'score': t.score,
      'lines': t.lines,
      'faz0Sure': t.faz0Sure,
      'faz1Pompa': t.faz1Pompa,
      'faz2Pompa': t.faz2Pompa,
      'faz3Vitesler': t.faz3Vitesler,
      'faz4Pompa': t.faz4Pompa,
    })).toList();
    await prefs.setStringList('saved_tests', encoded);
  }

  void addTest(TestVerisi test) {
    _testler.add(test);
    saveTestsToLocal();
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
    if (valveStates.containsKey(valve)) {
      valveStates[valve] = state;
      // istersen burayı SharedPreferences ile kaydet (kalıcılık)
      notifyListeners();
    }
  }

  void setK1K2Mode(bool value) {
    isK1K2Mode = value;

    // ESP’ye gönderilecek komut
    sendCommand(value ? "MODE_OUT" : "MODE_IN");

    notifyListeners();
  }

  Future<void> saveTestsToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _testler.map((t) => jsonEncode({
      'testAdi': t.testAdi,
      'tarih': t.tarih.toIso8601String(),
      'score': t.score,
      'lines': t.lines,
      'faz0Sure': t.faz0Sure,
      'faz1Pompa': t.faz1Pompa,
      'faz2Pompa': t.faz2Pompa,
      'faz3Vitesler': t.faz3Vitesler,
      'faz4Pompa': t.faz4Pompa,
    })).toList();
    await prefs.setStringList('saved_tests', encoded);
  }

  Future<void> deleteTest(int index) async {
    _testler.removeAt(index);
    await saveTestsToLocal();
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

    // 🔁 Simülasyon döngüsü
    Timer.periodic(const Duration(seconds: 2), (t) {
      if (!isConnected) return;

      // 1️⃣ Basınç değeri
      double minPressure = pressureToggle ? 52 : 42;
      double maxPressure = 60;
      pressure = minPressure + random.nextDouble() * (maxPressure - minPressure);

      // 2️⃣ Vites durumuna göre valfleri ayarla
      // Önce tüm valfleri false yap
      for (var key in ['N433', 'N434', 'N437', 'N438']) {
        valveStates[key] = false;
      }

      // 🔧 Vites -> Valf eşleştirmesi
      switch (gear) {
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

      // 3️⃣ Vites durumuna göre K1 / K2 seçimi
      if (['1', '3', '5', '7'].contains(gear)) {
        valveStates['K1'] = true;
        valveStates['K2'] = false;
      } else if (['2', '4', '6', 'R'].contains(gear)) {
        valveStates['K1'] = false;
        valveStates['K2'] = true;
      } else {
        // 'BOŞ' durumunda her ikisi de kapalı
        valveStates['K1'] = false;
        valveStates['K2'] = false;
      }

      // 4️⃣ Basınç Valfi manuel kontrol bilgisi
      lastMessage =
      '[MOCK] Güncel basınç: ${pressure.toStringAsFixed(2)} bar | N436=${valveStates['N436']} N440=${valveStates['N440']} | Vites=$gear';

      // 5️⃣ Mekatronik Puan
      if (testStatus == 'Çalışıyor') {
        mechatronicScore = min(100, mechatronicScore + random.nextInt(3));
        lastMessage += ' | Mekatronik Puan: $mechatronicScore';
      }

      logs.add(lastMessage);
      notifyListeners();
    });
  }


  Future<bool> checkBluetoothPermissions() async {
    if (await Permission.bluetoothScan.isDenied) {
      await Permission.bluetoothScan.request();
    }
    if (await Permission.bluetoothConnect.isDenied) {
      await Permission.bluetoothConnect.request();
    }
    if (await Permission.location.isDenied) {
      await Permission.location.request();
    }

    return await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted &&
        await Permission.location.isGranted;
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

  Future<bool> tryConnect(String address, String name, {int timeout = 12}) async {
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

    updateValvesFromMessage(line); // 🔧 buraya ekle

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
      _startTestTimer();
      _addLog('Test başlatıldı');
    }
    if (msg.toLowerCase().contains('test durdur') || msg.toLowerCase().contains('test stop')) {
      testStatus = 'Tamamlandı';
      _stopTestTimer();
    }

    // Bağlantı durumu parsing
    if (msg.toLowerCase().contains('bağlandı') || msg.toLowerCase().contains('connected')) {
      isConnected = true;
    }
    if (msg.toLowerCase().contains('bağlantı kesildi') || msg.toLowerCase().contains('disconnected')) {
      isConnected = false;
    }
  }

  Timer? _testTimer;
  int _testSeconds = 0;

  void startTest() {
    if (isTesting) return;
    isTesting = true;
    _goToPhase(TestPhase.phase0);
  }

  void stopTest() {
    _phaseTimer?.cancel();
    isTesting = false;
    currentPhase = TestPhase.idle;
    phaseProgress = 0;
    phaseStatusMessage = "Test durduruldu";
    notifyListeners();
  }

  void _goToPhase(TestPhase nextPhase) {
    _phaseTimer?.cancel();
    currentPhase = nextPhase;
    elapsedSeconds = 0;
    phaseProgress = 0;

    switch (nextPhase) {
      case TestPhase.phase0:
        _runPompaYukselmeTesti();
        break;
      case TestPhase.phase2:
        _runBasincValfiTestleri();
        break;
      case TestPhase.phase3:
        _runVitesTestleri();
        break;
      case TestPhase.phase4:
        _runDayaniklilikTesti();
        break;
      case TestPhase.completed:
        _finishTest();
        break;
      default:
        break;
    }
  }

  void _runPompaYukselmeTesti() async {
    phaseStatusMessage = "Pompa Yükselme Testi başlatılıyor...";
    notifyListeners();

    // 🔹 Pompayı çalıştır
    sendCommand("POMPA_ON");

    // Süre sayacı başlat
    elapsedSeconds = 0;
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsedSeconds++;
      phaseProgress = (elapsedSeconds / 12).clamp(0.0, 1.0); // tahmini max süre
      notifyListeners();
    });

    double currentPressure = 0.0;

    // 🔹 Basınç yükselmesini simüle edelim (gerçek cihazdan okuyorsan burayı değiştir)
    while (currentPressure < 60 && isTesting) {
      await Future.delayed(const Duration(milliseconds: 500));
      currentPressure += 5; // örnek artış
      if (currentPressure >= 60) break;
    }

    // 🔹 Pompayı kapat
    sendCommand("POMPA_OFF");

    _phaseTimer?.cancel();

    // 🔹 Sonuç değerlendirme
    String sonuc;
    int puan;
    if (elapsedSeconds <= 8) {
      sonuc = "✅ Mükemmel (${elapsedSeconds}s)";
      puan = 100;
    } else if (elapsedSeconds <= 12) {
      sonuc = "⚠️ İyi (${elapsedSeconds}s)";
      puan = (100 - (elapsedSeconds - 8) * 7).clamp(70, 99).toInt();
    } else {
      sonuc = "❌ Zayıf (${elapsedSeconds}s)";
      puan = 60;
    }

    faz0Sure = elapsedSeconds.toDouble();
    phaseStatusMessage = "Pompa Yükselme Testi tamamlandı → $sonuc";
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));

    // 🔹 Otomatik olarak Faz 2’ye geç
    _goToPhase(TestPhase.phase2);
  }

  void _runDayaniklilikTesti() async {
    phaseStatusMessage = "Dayanıklılık Testi başlatıldı...";
    notifyListeners();

    // Başlangıç değerleri
    double minPressure = double.infinity;
    double maxPressure = 0.0;
    int totalPumpSeconds = 0;
    int totalGearShifts = 0;

    sendCommand("DAYANIKLILIK_START"); // pompa ve test başlat

    const int testDurationSeconds = 10 * 60; // 10 dakika
    elapsedSeconds = 0;

    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsedSeconds++;
      phaseProgress = elapsedSeconds / testDurationSeconds;

      // Simülasyon: Basınç değerini güncelle (gerçek sensörden alın)
      double currentPressure = _getCurrentPressure(); // burayı sensör verisine bağla
      minPressure = currentPressure < minPressure ? currentPressure : minPressure;
      maxPressure = currentPressure > maxPressure ? currentPressure : maxPressure;

      // Pompa çalışıyorsa süreyi ekle
      bool pumpActive = _isPumpActive(); // gerçek duruma göre değiştir
      if (pumpActive) totalPumpSeconds++;

      // Vites değişimleri
      totalGearShifts += _getGearShiftCount(); // bu da sensörden veya simülasyondan

      notifyListeners();

      // Süre tamamlandıysa
      if (elapsedSeconds >= testDurationSeconds) {
        timer.cancel();
        sendCommand("DAYANIKLILIK_STOP");

        // Sonuç değerlendirme
        String sonuc;
        double puan;
        if (totalPumpSeconds < 55) {
          sonuc = "✅ Mükemmel (${totalPumpSeconds}s pompa)";
          puan = 100;
        } else if (totalPumpSeconds <= 80) {
          sonuc = "⚠️ Orta (${totalPumpSeconds}s pompa)";
          puan = 80;
        } else {
          sonuc = "❌ Zayıf (${totalPumpSeconds}s pompa)";
          puan = 60;
        }

        faz4Pompa = totalPumpSeconds as double;
        phaseStatusMessage =
        "Dayanıklılık Testi tamamlandı → $sonuc\nMin basınç: $minPressure bar, Max basınç: $maxPressure bar, Toplam vites: $totalGearShifts";
        notifyListeners();

        // Otomatik olarak testi bitir
        _goToPhase(TestPhase.completed);
      }
    });
  }

  double _getCurrentPressure() {
    if (mockMode) {
      return 50 + (elapsedSeconds % 10); // simülasyon
    } else {
      // son gelen mesajlardan basınç değerini al
      final match = RegExp(r'([\d.]+)\s*bar').firstMatch(lastMessage);
      if (match != null) {
        return double.tryParse(match.group(1)!) ?? 0;
      }
      return 0;
    }
  }

  bool _isPumpActive() {
    if (mockMode) return (elapsedSeconds % 2 == 0);
    // son mesajdan pompa durumu
    if (lastMessage.toLowerCase().contains('pompa aç') ||
        lastMessage.toLowerCase().contains('pump on')) {
      return true;
    }
    if (lastMessage.toLowerCase().contains('pompa kapat') ||
        lastMessage.toLowerCase().contains('pump off')) {
      return false;
    }
    return pumpOn; // son bilinen durum
  }

  int _getGearShiftCount() {
    if (mockMode) return elapsedSeconds ~/ 5;
    // son mesajdan vites değişimlerini say
    final matches = RegExp(r'Vites[:\s]*([0-7RBOŞ]+)', caseSensitive: false)
        .allMatches(lastMessage);
    return matches.length; // basit sayım
  }

  void _runBasincValfiTestleri() async {
    phaseStatusMessage = "Basınç Valfi Testleri başlatılıyor...";
    notifyListeners();

    final List<Map<String, String>> asamalar = [
      {"ad": "Aşama 1 - Sadece N436", "komut": "N436_ONLY"},
      {"ad": "Aşama 2 - Sadece N440", "komut": "N440_ONLY"},
      {"ad": "Aşama 3 - N436+N440", "komut": "N436_N440"},
      {"ad": "Aşama 4 - Tümü Kapalı", "komut": "ALL_OFF"},
    ];

    const int beklemeSuresi = 60; // 1 dakika

    for (int i = 0; i < asamalar.length; i++) {
      if (!isTesting) return; // Durdurulduysa çık

      final asama = asamalar[i];
      phaseStatusMessage = "${asama["ad"]} başlatılıyor...";
      notifyListeners();

      // 🔹 1. 60 bar basınç uygula
      sendCommand("SET_PRESSURE_60");
      await Future.delayed(const Duration(seconds: 3));

      // 🔹 2. Pompayı kapat
      sendCommand("POMPA_OFF");
      await Future.delayed(const Duration(seconds: 1));

      // 🔹 3. 1 dakika bekle ve ilerlemeyi güncelle
      int elapsed = 0;
      while (elapsed < beklemeSuresi && isTesting) {
        await Future.delayed(const Duration(seconds: 1));
        elapsed++;
        phaseProgress = (i + (elapsed / beklemeSuresi)) / asamalar.length;
        notifyListeners();
      }

      // 🔹 4. Basınç düşüşünü ölç (şimdilik simülasyon)
      double dusus = 1.0 + (i * 1.5); // örnek bar düşüşleri
      String sonuc;
      if (dusus < 2) {
        sonuc = "✅ Mükemmel (${dusus.toStringAsFixed(1)} bar)";
      } else if (dusus <= 5) {
        sonuc = "⚠️ Kabul edilebilir (${dusus.toStringAsFixed(1)} bar)";
      } else {
        sonuc = "❌ Sızdırma (${dusus.toStringAsFixed(1)} bar)";
      }

      phaseStatusMessage = "${asama["ad"]} tamamlandı → $sonuc";
      notifyListeners();

      await Future.delayed(const Duration(seconds: 2));
    }

    // 🔹 5. Faz 3'e geç
    _goToPhase(TestPhase.phase3);
  }

  Future<void> completeTest(String testAdi) async {
    final score = MekatronikPuanlama.toplamPuan(
      faz0Sure: faz0Sure,
      faz1Pompa: faz1Pompa,
      faz2Pompa: faz2Pompa,
      faz3Vitesler: faz3Vitesler,
      faz4Pompa: faz4Pompa,
    );

    final newTest = TestVerisi(
      testAdi: testAdi,
      tarih: DateTime.now(),
      score: score,
      lines: testRecords.map((e) =>
      "time:${e['time']} pressure:${e['pressure']} gear:${e['gear']}").toList(),
      faz0Sure: faz0Sure,
      faz1Pompa: faz1Pompa,
      faz2Pompa: faz2Pompa,
      faz3Vitesler: Map.from(faz3Vitesler),
      faz4Pompa: faz4Pompa,
    );

    addTest(newTest);
    notifyListeners();

    // Opsiyonel: SD karta kaydet
    await saveTestToSDCard(newTest);

    // Bluetooth gönder
    sendTestOverBluetooth(newTest);
  }

  void sendTestOverBluetooth(TestVerisi test) {
    final jsonStr = '''
  {
    "testAdi": "${test.testAdi}",
    "tarih": "${test.tarih.toIso8601String()}",
    "score": ${test.score}
  }
  ''';

    bt.send(jsonStr);
    _addLog('Test Bluetooth üzerinden gönderildi');
  }

  Future<void> saveTestToSDCard(TestVerisi test) async {
    try {
      final dir = await getApplicationDocumentsDirectory(); // SD kart için alternatif gerekli olabilir
      final testDir = Directory('${dir.path}/testler');
      if (!await testDir.exists()) await testDir.create(recursive: true);

      final file = File('${testDir.path}/${test.testAdi}_${test.tarih.millisecondsSinceEpoch}.json');
      await file.writeAsString(
          '''
      {
        "testAdi": "${test.testAdi}",
        "tarih": "${test.tarih.toIso8601String()}",
        "score": ${test.score},
        "faz0Sure": ${test.faz0Sure},
        "faz1Pompa": ${test.faz1Pompa},
        "faz2Pompa": ${test.faz2Pompa},
        "faz3Vitesler": ${test.faz3Vitesler},
        "faz4Pompa": ${test.faz4Pompa},
        "lines": ${test.lines}
      }
      '''
      );
      _addLog('Test SD karta kaydedildi: ${file.path}');
    } catch (e) {
      _addLog('SD karta kaydetme hatası: $e');
    }
  }

  void _runVitesTestleri() async {
    phaseStatusMessage = "Vites Testleri başlatılıyor...";
    notifyListeners();

    final List<Map<String, String>> vitesGruplari = [
      {"ad": "V1 Testi", "komut": "N436+V1"},
      {"ad": "V2 Testi", "komut": "N440+V2"},
      {"ad": "V3+7 Grup", "komut": "N436"},
      {"ad": "V4+6 Grup", "komut": "N440"},
      {"ad": "V5 Testi", "komut": "N436+V5"},
      {"ad": "VR Testi", "komut": "N440+VR"},
    ];

    for (int i = 0; i < vitesGruplari.length; i++) {
      if (!isTesting) return; // Durdurulmuşsa çık

      final grup = vitesGruplari[i];
      phaseStatusMessage = "${grup["ad"]} başlatılıyor...";
      notifyListeners();

      // 🔹 1. Pompayı aç
      sendCommand("POMPA_ON");

      // 🔹 2. 55 bar'a çık (örnek: bekleme süresiyle simülasyon)
      await Future.delayed(const Duration(seconds: 5));
      sendCommand("SET_PRESSURE_55");

      // 🔹 3. Pompayı kapat
      await Future.delayed(const Duration(seconds: 2));
      sendCommand("POMPA_OFF");

      // 🔹 4. 45 saniye bekle (basınç düşüşü ölçülüyor)
      int elapsed = 0;
      const int bekleme = 45;
      while (elapsed < bekleme && isTesting) {
        await Future.delayed(const Duration(seconds: 1));
        elapsed++;
        phaseProgress = (i + (elapsed / bekleme)) / vitesGruplari.length;
        notifyListeners();
      }

      // 🔹 5. Basınç düşüşünü kaydet (şu an simülasyon)
      double dusus = 2.0 + (i * 0.8); // örnek değer
      String sonuc;
      if (dusus < 3) {
        sonuc = "✅ Mükemmel (${dusus.toStringAsFixed(1)} bar)";
      } else if (dusus <= 6) {
        sonuc = "⚠️ Orta (${dusus.toStringAsFixed(1)} bar)";
      } else {
        sonuc = "❌ Sızdırma (${dusus.toStringAsFixed(1)} bar)";
      }

      phaseStatusMessage = "${grup["ad"]} tamamlandı → $sonuc";
      notifyListeners();

      await Future.delayed(const Duration(seconds: 2));
    }

    // 🔹 Tüm gruplar tamamlandı
    _goToPhase(TestPhase.phase4);
  }

  void _finishTest() {
    isTesting = false;
    currentPhase = TestPhase.completed;
    phaseProgress = 1.0;
    phaseStatusMessage = "Test tamamlandı ✅";
    notifyListeners();
  }

  void _startTestTimer() {
    _testSeconds = 0;
    testRecords.clear(); // eski kayıtları temizle
    _testTimer?.cancel();
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _testSeconds++;
      testDuration = _testSeconds;

      // Her saniye kaydı
      testRecords.add({
        'time': _testSeconds,
        'pressure': pressure,
        'gear': gear,
        'pumpOn': pumpOn,
      });

      notifyListeners();
    });
  }

  void _stopTestTimer() {
    _testTimer?.cancel();
    _testTimer = null;
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
      _startTestTimer();
      logs.add('[${DateTime.now().toIso8601String()}] Test başlatıldı');
    } else if (cmd == 'TEST_STOP') {
      testStatus = 'Hazır';
      _stopTestTimer();
      logs.add('[${DateTime.now().toIso8601String()}] Test durduruldu');
    }

    notifyListeners();
  }

  void updateValvesByGear(String gear) {
    // Tüm ilgili valfleri kapat
    valveStates['N433'] = false;
    valveStates['N434'] = false;
    valveStates['N437'] = false;
    valveStates['N438'] = false;

    valveStates['K1'] = false;
    valveStates['K2'] = false;

    // 🔹 Vites – valf eşleşmeleri
    switch (gear) {
      case '1':
      case '3':
        valveStates['N433'] = true;
        valveStates['K1'] = true;
        break;
      case '2':
      case '4':
        valveStates['N437'] = true;
        valveStates['K2'] = true;
        break;
      case '5':
      case '7':
        valveStates['N434'] = true;
        valveStates['K1'] = true;
        break;
      case '6':
      case 'R':
        valveStates['N438'] = true;
        valveStates['K2'] = true;
        break;
      default:
      // Boş viteste hiçbir şey aktif olmasın
        break;
    }

    notifyListeners();
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

  void resetTest() {
    _stopTestTimer();
    testDuration = 0;
    testStatus = 'Hazır';
    _testSeconds = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _operationTimer?.cancel();
    _testTimer?.cancel();
    bt.dispose();
    super.dispose();
  }
}