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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _app = Provider.of<AppState>(context, listen: false);
      _app.onTestCompleted = _onTestCompleted;
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

  void _onTestCompleted(TestVerisi test) {
    print('[DEBUG] _onTestCompleted called:');
    print('  - Test Adı: ${test.testAdi}');
    print('  - Puan: ${test.puan}');
    print('  - Sonuç: ${test.sonuc}');
    print('  - _isDialogShowing: $_isDialogShowing');

    if (!_isDialogShowing) {
      _isDialogShowing = true;

      print('[DEBUG] Showing completion dialog for: ${test.testAdi}');

      if (_app.mockMode) {
        _showMockResultDialog(test);
      } else {
        _showDeviceResultDialog(test);
      }
    }
  }

  void _showMockResultDialog(TestVerisi test) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF003366),
          title: const Text("Test Tamamlandı!",
              style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Text(
            "Test Adı: ${test.testAdi}\n"
                "Sonuç: ${test.sonuc} (${test.puan} / 100)\n"
                "Durum: ${test.fazAdi}\n"
                "\nRaporu görüntülemek ister misiniz?",
            style: TextStyle(color: MekatronikPuanlama.renk(test.puan)),
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
      print('[DEBUG] Mock dialog closed');
    });
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
          title: const Text("Test Tamamlandı!",
              style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Test Adı: ${test.testAdi}",
                  style: TextStyle(color: Colors.white)),
              SizedBox(height: 10),
              Text("Cihaz puanı alınıyor...",
                  style: TextStyle(color: Colors.amber)),
              SizedBox(height: 10),
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text("25 dakika timeout aktif",
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("İPTAL",
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _isDialogShowing = false;
                // Testi manuel durdur
                _app.sendCommand("TEST_STOP");
              },
            ),
          ],
        );
      },
    );

    // Cihaz puanı için listener - 25 dakika timeout
    _app.onDeviceReportReceived = (String report) {
      if (_isDialogShowing && (report.contains("PUAN:") || _parseScoreFromReport(report) != null)) {
        Navigator.of(context).pop();
        _showDeviceReportDialog(test, report);
      }
    };

    // 25 dakika timeout
    Future.delayed(Duration(minutes: 25), () {
      if (_isDialogShowing) {
        Navigator.of(context).pop();
        _showTimeoutDialog(test);
      }
    });
  }

  void _showTimeoutDialog(TestVerisi test) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF003366),
          title: const Text("Timeout!",
              style: TextStyle(color: Colors.red, fontSize: 16)),
          content: Text(
            "Test 25 dakika içinde tamamlanmadı.\n\n"
                "Test Adı: ${test.testAdi}\n"
                "Son durum: ${test.fazAdi}\n\n"
                "Yerel raporu görüntülemek ister misiniz?",
            style: TextStyle(color: Colors.white70),
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
                _showMockResultDialog(test);
              },
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  void _showDeviceReportDialog(TestVerisi test, String report) {
    // Puan ve durumu parse et
    final puan = _parseScoreFromReport(report) ?? test.puan;
    final durum = _parseDurumFromReport(report) ?? test.sonuc;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF003366),
          title: Text("Test Tamamlandı - $durum",
              style: TextStyle(
                  color: MekatronikPuanlama.renk(puan),
                  fontSize: 16
              )),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Test Adı: ${test.testAdi}",
                    style: TextStyle(color: Colors.white)),
                SizedBox(height: 8),
                Text("Puan: $puan/100",
                    style: TextStyle(
                        color: MekatronikPuanlama.renk(puan),
                        fontWeight: FontWeight.bold
                    )),
                SizedBox(height: 8),
                Text("Durum: $durum",
                    style: TextStyle(color: Colors.white70)),
                SizedBox(height: 12),
                Text("Detaylı raporu görüntülemek ister misiniz?",
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          // ... actions aynı kalabilir
        );
      },
    );
  }

  String? _parseDurumFromReport(String report) {
    if (report.contains("DURUM: MÜKEMMEL")) return "MÜKEMMEL";
    if (report.contains("DURUM: İYİ")) return "İYİ";
    if (report.contains("DURUM: ORTA")) return "ORTA";
    if (report.contains("DURUM: SORUNLU")) return "SORUNLU";
    if (report.contains("DURUM: KÖTÜ")) return "KÖTÜ";
    return null;
  }

  int? _parseScoreFromReport(String report) {
    try {
      // İki farklı puan formatını kontrol et
      final mekatronikMatch = RegExp(r'TOPLAM PUAN:\s*(\d+)/100').firstMatch(report);
      if (mekatronikMatch != null) {
        return int.parse(mekatronikMatch.group(1)!);
      }

      final genelMatch = RegExp(r'GENEL PUAN:\s*([\d.]+)/100').firstMatch(report);
      if (genelMatch != null) {
        return double.parse(genelMatch.group(1)!).round();
      }

      final puanMatch = RegExp(r'PUAN:\s*(\d+)/100').firstMatch(report);
      if (puanMatch != null) {
        return int.parse(puanMatch.group(1)!);
      }
    } catch (e) {
      print('Puan parse error: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _app.onTestCompleted = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        final isRunning = app.isTesting;
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

              const SizedBox(height: 16),

              // Test bilgileri
              Container(
                padding: const EdgeInsets.all(12),
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
                            Icon(Icons.timer_outlined, color: Colors.blueAccent),
                            Text("Süre", style: TextStyle(color: Colors.white70)),
                            Text(_formatDuration(app.elapsedSeconds), // app.elapsedSeconds kullanıldı
                                style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16
                                )),
                          ],
                        ),

                        Column(
                          children: [
                            Icon(Icons.format_list_numbered_outlined, color: Colors.green),
                            Text("Faz", style: TextStyle(color: Colors.white70)),
                            Text(app.currentFaz.split(':')[0],
                                style: TextStyle(
                                    color: Colors.white,
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