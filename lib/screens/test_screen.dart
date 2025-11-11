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
  late AppState _app;
  bool _isDialogShowing = false;
  TestVerisi? _lastCompletedTest; // ✅ YENİ: Son tamamlanan testi sakla

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _app = Provider.of<AppState>(context, listen: false);
      _app.onTestCompleted = _onTestCompleted;

      // ✅ DEBUG: Callback'in atandığını kontrol et
      print('[DEBUG] onTestCompleted callback atandı: ${_app.onTestCompleted != null}');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = Provider.of<AppState>(context);

    // Test state'i değiştiğinde kontrol et
    if (app.currentTestState == TestState.completed &&
        app.completedTests.isNotEmpty &&
        !_isDialogShowing) {

      // Son testi al ve dialog göster
      final lastTest = app.completedTests.first;
      if (lastTest.tarih.isAfter(DateTime.now().subtract(Duration(minutes: 1)))) {
        _onTestCompleted(lastTest);
      }
    }
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

  void _onTestCompleted(TestVerisi test) {
    print('[DEBUG] _onTestCompleted called:');
    print('  - Test Adı: ${test.testAdi}');
    print('  - Puan: ${test.puan}');
    print('  - Sonuç: ${test.sonuc}');
    print('  - _isDialogShowing: $_isDialogShowing');

    // ✅ YENİ: Son testi sakla
    _lastCompletedTest = test;

    // Dialog zaten gösteriliyorsa tekrar gösterme
    if (_isDialogShowing) {
      print('[DEBUG] Dialog already showing, skipping');
      return;
    }

    _isDialogShowing = true;

    print('[DEBUG] Showing completion dialog for: ${test.testAdi}');

    // Hangi dialogu göstereceğimize karar ver
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDeviceResultDialog(test);
    });
  }

  // ✅ YENİ: Manuel olarak son testi göster
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
              child: const Text("KAPAT",
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _isDialogShowing = false;
              },
            ),
            TextButton(
              child: const Text("RAPORU GÖRÜNTÜLE",
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _isDialogShowing = false;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RaporDetayEkrani(test: test),
                  ),
                );
              },
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing = false;
      print('[DEBUG] Device dialog closed');
    });
  }

  String _getActiveValvesCount(Map<String, bool> valveStates) {
    int activeCount = valveStates.values.where((state) => state).length;
    return '$activeCount/8';
  }

// Aktif valflerin listesini al
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
        if (app.completedTests.isNotEmpty && _lastCompletedTest == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final lastTest = app.completedTests.first;
            if (lastTest.tarih.isAfter(DateTime.now().subtract(Duration(minutes: 1)))) {
              _onTestCompleted(lastTest);
            }
          });
        }
        final currentPhase = app.currentPhase;
        final phaseName = _getPhaseName(currentPhase);
        // ✅ DÜZELTİLDİ: Tüm aktif test durumlarını kontrol et
        final isRunning = app.isTesting ||
            app.currentTestState == TestState.starting ||
            app.currentTestState == TestState.running ||
            app.currentTestState == TestState.paused ||
            app.currentTestState == TestState.waitingReport ||
            app.currentTestState == TestState.parsingReport;

        final isPaused = app.isPaused;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Test Adı Girişi
              TextField(
                controller: _nameController,
                enabled: !isRunning,
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

              // ✅ YENİ: Son Test Sonucu Butonu
              if (_lastCompletedTest != null && !isRunning)
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

              if (_lastCompletedTest != null && !isRunning)
                const SizedBox(height: 10),

              // Ana Kontrol Butonları
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: isRunning
                        ? null
                        : () async {
                      final name = _nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Lütfen test adı girin"),
                          ),
                        );
                        return;
                      }
                      await app.startFullTest(name);
                    },
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text("Başlat",
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: isRunning ? () => app.pauseTest() : null,
                    icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white),
                    label: Text(isPaused ? "Devam" : "Duraklat",
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: isRunning ? () => app.stopTest() : null,
                    icon: const Icon(Icons.stop, color: Colors.white),
                    label: const Text("Bitir",
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Test Kontrol Butonları
              if (isRunning) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // Faz atlama komutu - Bluetooth modunda çalışacak
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
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: const Color(0xFF003366),
                              title: const Text("Testi İptal Et",
                                  style: TextStyle(color: Colors.white)),
                              content: const Text("Testi iptal etmek istediğinizden emin misiniz?",
                                  style: TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(
                                  onPressed: () => app.stopTest(),
                                  child: const Text("Hayır",
                                      style: TextStyle(color: Colors.white)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    app.sendCommand("aq");
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Test iptal edildi"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  },
                                  child: const Text("Evet",
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.cancel, color: Colors.white),
                      label: const Text("Testi İptal Et",
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

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

                    // ✅ YENİ: İki container'ı yan yana yerleştir
                    Row(
                      children: [
                        // SOL: FAZ Bilgisi Container'ı
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
                                  _getPhaseName(app.currentPhase), // Bu satırı ekleyin
                                  style: TextStyle(
                                    color: Colors.yellow,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 4), // Biraz boşluk ekleyin
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

                        SizedBox(width: 8), // Ara boşluk

                        // SAĞ: Vites ve Valf Container'ı
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
                                // Aktif valfleri göster
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