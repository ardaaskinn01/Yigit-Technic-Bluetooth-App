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

// test_screen.dart güncellemesi

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

  void _onTestFinished() {
    // Sadece test bittiğinde (true olduğunda) ve hala ekran açıksa ÇALIŞ ve
    // diyalog zaten AÇIK DEĞİLSE devam et.
    if (_app.testFinished && _app.completedTests.isNotEmpty && !_isDialogShowing) {

      // 1. Bayrağı AÇ: Diyaloğun açılmak üzere olduğunu işaretle
      _isDialogShowing = true;

      final lastTest = _app.completedTests.last;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text("Test Tamamlandı!", // Güncellendi
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            content: Text(
              "Test Adı: ${lastTest.testAdi}\n"
                  "Sonuç: ${lastTest.sonuc} (${lastTest.puan} / 100)\n"
                  "\nRaporu görüntülemek ister misiniz?",
              style: TextStyle(color: MekatronikPuanlama.renk(lastTest.puan)),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text("KAPAT", // Güncellendi
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
              TextButton(
                child: const Text("RAPORU GÖRÜNTÜLE", // Güncellendi
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                onPressed: () {
                  // Dialogu kapat
                  Navigator.of(dialogContext).pop();
                  // Rapor ekranına git
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
        // 2. Diyalog kapandıktan sonra (her iki düğme veya geri dönüş ile) bu blok çalışır.
        // Durumu sıfırla (Böylece geri gelindiğinde tekrar tetiklenmez)
        _app.testFinished = false;
        // 3. Bayrağı KAPAT
        _isDialogShowing = false;

        // Eğer app state'in notifyListeners() metodu bir sonraki aşamada çağrılmazsa,
        // _app.testFinished = false; değişikliğinin arayüze yansıması için manuel bir bildirim
        // gerekebilir. Ancak bu bayrak kontrolü sorunu %99 çözecektir.
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

              // Butonlar
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
                      // startTest yerine startFullTest kullanıldı
                      await app.startFullTest(name);
                    },
                    label: const Text("Başlat", // Güncellendi
                      style: const TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: isRunning ? () => app.pauseTest() : null,
                    label: Text(isPaused ? "Devam" : "Duraklat", // Güncellendi
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                  ElevatedButton.icon(
                    // stopTest metodu güncellendi: isTesting=false ve testFinished=true yapılıyor
                    onPressed: isRunning
                        ? () => app.stopTest()
                        : null,
                    label: const Text("Bitir", // Güncellendi
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Test bilgileri
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    // AKTİF FAZ BİLGİSİ - YENİ EKLENDİ
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
