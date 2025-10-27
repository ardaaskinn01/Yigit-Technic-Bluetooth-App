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
  // 💡 ÇÖZÜM: Diyalogun zaten açık olup olmadığını kontrol eden bayrak
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _app = Provider.of<AppState>(context, listen: false);
      _app.addListener(_onTestFinished);
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

  // TestScreen.dart'da _onTestFinished metodunu güncelleyin
  void _onTestFinished() {
    // Debug için log ekleyin
    print('[DEBUG] _onTestFinished called:');
    print('  - testFinished: ${_app.testFinished}');
    print('  - completedTests: ${_app.completedTests.length}');
    print('  - currentPhase: ${_app.currentPhase}');
    print('  - _isDialogShowing: $_isDialogShowing');

    // Koşulları genişletin
    if (_app.testFinished &&
        _app.completedTests.isNotEmpty &&
        !_isDialogShowing &&
        _app.currentPhase == TestPhase.completed) {

      _isDialogShowing = true;
      final lastTest = _app.completedTests.last;

      // Debug
      print('[DEBUG] Showing completion dialog for: ${lastTest.testAdi}');

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text("Test Tamamlandı!",
                style: TextStyle(color: Colors.white, fontSize: 16)),
            content: Text(
              "Test Adı: ${lastTest.testAdi}\n"
                  "Sonuç: ${lastTest.sonuc} (${lastTest.puan} / 100)\n"
                  "Durum: ${lastTest.fazAdi}\n"
                  "\nRaporu görüntülemek ister misiniz?",
              style: TextStyle(color: MekatronikPuanlama.renk(lastTest.puan)),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text("KAPAT",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
              TextButton(
                child: const Text("RAPORU GÖRÜNTÜLE",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RaporDetayEkrani(test: lastTest),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ).then((_) {
        _app.testFinished = false;
        _isDialogShowing = false;
        print('[DEBUG] Dialog closed, flags reset');
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _app.removeListener(_onTestFinished);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        final isRunning = app.isTesting;
        final isPaused = app.isPaused;

        // Görünen Durum Mesajı: Faz adı ve faz durumu birleştirilebilir
        final displayStatus = isRunning
            ? "${app.currentPhase.toString().split('.').last.toUpperCase()}: ${app.phaseStatusMessage}"
            : app.testStatus;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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

                      // Test adını AppState'e kaydet
                      _app.setCurrentTestName(name);

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
                    // stopTest metodu güncellendi: isTesting=false ve testFinished=true yapılıyor
                    onPressed: isRunning
                        ? () => app.stopTest()
                        : null,
                    icon: const Icon(Icons.stop, color: Colors.white),
                    label: const Text("Bitir",
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Test Kontrol Butonları - YENİ EKLENDİ
              if (isRunning) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Fazı Atla Butonu
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

                    // Testi İptal Et Butonu
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("Testi İptal Et",
                                  style: TextStyle(color: Colors.white)),
                              content: const Text("Testi iptal etmek istediğinizden emin misiniz?",
                                  style: TextStyle(color: Colors.white70)),
                              backgroundColor: const Color(0xFF003366),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text("Hayır",
                                      style: TextStyle(color: Colors.white)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    app.sendCommand("aq");
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Test iptal komutu gönderildi"),
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
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    // AKTİF FAZ BİLGİSİ
                    if (app.isTesting) ...[
                      Text(
                        "AKTİF FAZ: ${_getPhaseName(app.currentPhase)}",
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                    ],

                    Text("DURUM: ${app.testStatus}",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),

                    if (app.isTesting) ...[
                      SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: app.phaseProgress,
                        backgroundColor: Colors.grey[800],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                      SizedBox(height: 4),
                      Text("İlerleme: ${(app.phaseProgress * 100).toStringAsFixed(1)}%",
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      SizedBox(height: 4),
                      Text("Faz Durumu: ${app.phaseStatusMessage}",
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],

                    Text("Basınç: ${app.pressure.toStringAsFixed(1)} bar",
                        style: const TextStyle(color: Colors.white)),
                    Text("Vites: ${app.gear}",
                        style: const TextStyle(color: Colors.white)),
                    Text("Pompa: ${app.pumpOn ? "Açık" : "Kapalı"}",
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    Text("Min Basınç: ${app.minBasinc.toStringAsFixed(1)} bar",
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text("Max Basınç: ${app.maxBasinc.toStringAsFixed(1)} bar",
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
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