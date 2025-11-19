import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_verisi.dart';
import '../providers/app_state.dart';
import '../utils/mekatronik_puanlama.dart';
import 'rapor_detay_ekrani.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isDialogShowing = false;
  TestVerisi? _lastCompletedTest;
  bool _callbackRegistered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupCallbacks();
    });
  }

  void _setupCallbacks() {
    if (_callbackRegistered) return;

    final app = Provider.of<AppState>(context, listen: false);
    app.onTestCompleted = _onTestCompleted;
    _callbackRegistered = true;
    print('[DEBUG] TestScreen: Callback ayarlandı');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupCallbacks();
  }


  @override
  void dispose() {
    // Memory leak'i önle
    final app = Provider.of<AppState>(context, listen: false);
    super.dispose();
  }

  void _onTestCompleted(TestVerisi test) {
    print('[DEBUG] _onTestCompleted called: ${test.testAdi}');

    // 🛡️ KORUMA 1: Eğer widget ekranda değilse işlemi durdur
    if (!mounted) return;

    // Aynı test için callback birden fazla kez tetiklenirse engelle
    if (_lastCompletedTest?.testAdi == test.testAdi &&
        _lastCompletedTest!.tarih.difference(test.tarih).inSeconds < 5) {
      return;
    }

    _lastCompletedTest = test;

    if (_isDialogShowing) return;

    _isDialogShowing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 🛡️ KORUMA 2: Callback çalışana kadar ekran kapanmış olabilir
      if (!mounted) return;
      _showDeviceResultDialog(test);
    });
  }

  String _getPhaseName(TestPhase phase) {
    switch (phase) {
      case TestPhase.idle:
        return "HAZIR";
      case TestPhase.phase0:
        return "FAZ 0: POMPA TESTİ";
      case TestPhase.phase1:
        return "FAZ 1: BASINÇ DENGELEME";
      case TestPhase.phase2:
        return "FAZ 2: BASINÇ VALF TESTLERİ";
      case TestPhase.phase3:
        return "FAZ 3: VİTES TESTLERİ";
      case TestPhase.phase4:
        return "FAZ 4: DAYANIKLILIK TESTİ";
      case TestPhase.completed:
        return "TEST TAMAMLANDI";
      default:
        return "BEKLENİYOR";
    }
  }

  void _showLastTestResult() {
    if (_lastCompletedTest != null && !_isDialogShowing) {
      _isDialogShowing = true;
      _showDeviceResultDialog(_lastCompletedTest!);
    } else if (_lastCompletedTest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Henüz tamamlanmış bir test bulunmuyor"),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _showDeviceResultDialog(TestVerisi test) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF003366),
          title: Text("Test Tamamlandı - ${test.sonuc}",
              style: TextStyle(
                  color: MekatronikPuanlama.renk(test.puan),
                  fontSize: 16
              )),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Test Adı: ${test.testAdi}",
                  style: TextStyle(color: Colors.white)),
              SizedBox(height: 10),
              Text("Puan: ${test.puan}/100",
                  style: TextStyle(
                      color: MekatronikPuanlama.renk(test.puan),
                      fontWeight: FontWeight.bold,
                      fontSize: 18
                  )),
              SizedBox(height: 10),
              Text("Durum: ${test.sonuc}",
                  style: TextStyle(color: Colors.white70)),
              SizedBox(height: 10),
              Text("Detaylı raporu görüntülemek ister misiniz?",
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("KAPAT"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _isDialogShowing = false;
              },
            ),
            TextButton(
              child: const Text("RAPORU GÖRÜNTÜLE"),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Dialog context'i güvenlidir
                _isDialogShowing = false;

                // 🛡️ KORUMA 4: Ana ekrana push yapmadan önce kontrol
                if (!mounted) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RaporDetayEkrani(test: test)),
                );
              },
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing = false;
      print('[DEBUG] Dialog kapandı, flag sıfırlandı');
    });
  }

  String _getActiveValvesCount(Map<String, bool> valveStates) {
    int activeCount = valveStates.values.where((state) => state).length;
    return '$activeCount/8';
  }

  String _getActiveValvesText(Map<String, bool> valveStates) {
    List<String> activeValves = [];
    valveStates.forEach((key, value) {
      if (value) activeValves.add(key);
    });
    return activeValves.isNotEmpty ? activeValves.join(', ') : 'Tüm valfler kapalı';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        if (kDebugMode) {
          print('[DEBUG] Mock Mode: ${app.mockMode}');
        }
        // ✅ DOĞRU STATE KONTROLLERİ
        final isRunning = app.currentTestState == TestState.starting ||
            app.currentTestState == TestState.running ||
            app.currentTestState == TestState.waitingReport ||
            app.currentTestState == TestState.parsingReport;

        final isPaused = app.currentTestState == TestState.paused;

        final canStartTest = app.currentTestState == TestState.idle ||
            app.currentTestState == TestState.completed ||
            app.currentTestState == TestState.error ||
            app.currentTestState == TestState.cancelled;

        final canStopTest = isRunning || isPaused;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Test Adı Girişi
              TextField(
                controller: _nameController,
                enabled: !isRunning && !isPaused,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Test Adı",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Son Test Sonucu Butonu
              if (_lastCompletedTest != null && !isRunning && !isPaused)
                ElevatedButton.icon(
                  onPressed: _showLastTestResult,
                  icon: const Icon(Icons.assignment, color: Colors.white),
                  label: const Text("SON TEST SONUCUNU GÖSTER",
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),

              if (_lastCompletedTest != null && !isRunning && !isPaused)
                const SizedBox(height: 10),

              // Ana Kontrol Butonları
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // BAŞLAT Butonu
                  ElevatedButton.icon(
                    onPressed: canStartTest ? () async {
                      final name = _nameController.text.trim();
                      if (name.isEmpty) {
                        // Burası senkron olduğu için sorun yok
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Lütfen test adı girin"),
                          ),
                        );
                        return;
                      }

                      // Asenkron işlem başlıyor
                      await app.startFullTest(name);

                      // 🛡️ KORUMA 3: startFullTest bittiğinde kullanıcı hala burada mı?
                      if (!mounted) return;

                      // Eğer burada context kullanan (SnackBar, Dialog vs) bir kod yazacaksanız
                      // mutlaka yukarıdaki mounted kontrolünden sonra yazmalısınız.
                    } : null,
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text("Başlat",
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),

                  ElevatedButton.icon(
                    onPressed: () {
                      app.sendCommand("amk");
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Faz atlama komutu gönderildi"),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    label: const Text("Fazı Atla",
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),

                  // DURDUR Butonu
                  ElevatedButton.icon(
                    onPressed: canStopTest ? () => app.stopTest() : null,
                    icon: const Icon(Icons.stop, color: Colors.white),
                    label: const Text("Durdur",
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Test Durumu Container'ı
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[800],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blueAccent),
                ),
                child: Column(
                  children: [
                    Text("TEST DURUMU",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        )),
                    SizedBox(height: 8),

                    // Faz ve Vites Bilgileri
                    Row(
                      children: [
                        // SOL: FAZ Bilgisi
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey[900],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _getPhaseName(app.currentPhase),
                                  style: TextStyle(
                                    color: Colors.yellow,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 4),
                                if (app.currentFazBilgisi != null) ...[
                                  Text(
                                    "Süre: ${app.currentFazBilgisi!['sure']}",
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  Text(
                                    "${app.currentFazBilgisi!['aciklama']}",
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        SizedBox(width: 8),

                        // SAĞ: Vites ve Valf Bilgisi
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey[900],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        Icon(Icons.speed, color: Colors.orange),
                                        Text("Vites", style: TextStyle(color: Colors.white70)),
                                        Text(app.currentVites,
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18
                                            )),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        Icon(Icons.engineering, color: Colors.green),
                                        Text("Valfler", style: TextStyle(color: Colors.white70)),
                                        Text(_getActiveValvesCount(app.valveStates),
                                            style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16
                                            )),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _getActiveValvesText(app.valveStates),
                                  style: TextStyle(color: Colors.white70, fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12),

                    // Diğer Bilgiler
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Icon(Icons.timer_outlined, color: Colors.blueAccent),
                            Text("Süre", style: TextStyle(color: Colors.white70)),
                            Text(_formatDuration(app.elapsedSeconds),
                                style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16
                                )),
                          ],
                        ),
                        Column(
                          children: [
                            Icon(
                                app.pumpOn ? Icons.power : Icons.power_off,
                                color: app.pumpOn ? Colors.green : Colors.red
                            ),
                            Text("Pompa", style: TextStyle(color: Colors.white70)),
                            Text(app.pumpOn ? "AÇIK" : "KAPALI",
                                style: TextStyle(
                                    color: app.pumpOn ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold
                                )),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}