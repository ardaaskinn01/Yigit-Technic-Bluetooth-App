import 'package:bluetooth/screens/rapor_detay_ekrani.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/test_verisi.dart';
import '../utils/mekatronik_puanlama.dart';

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {

        final bool isRunning = app.isTesting;
        final String fazAdi = app.currentPhase.name.toUpperCase();

        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Test Modu: ",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    dropdownColor: const Color(0xFF002244),
                    value: app.selectedMode,
                    style: const TextStyle(color: Colors.white),
                    items:
                        app.testModlari.entries.map((entry) {
                          return DropdownMenuItem<int>(
                            value: entry.key,
                            child: Text("${entry.key} - ${entry.value}"),
                          );
                        }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        app.setMode(val);
                      }
                    },
                  ),
                ],
              ),
              Text(
                isRunning ? "Aktif Faz: $fazAdi" : "Test Başlatmaya Hazır",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                app.phaseStatusMessage,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),

              // 🔹 Faz ilerleme çubuğu
              LinearProgressIndicator(
                value: app.phaseProgress,
                backgroundColor: Colors.white12,
                color: Colors.lightBlueAccent,
                minHeight: 10,
              ),
              const SizedBox(height: 30),

              // 🔹 Başlat / Durdur butonu
              ElevatedButton.icon(
                onPressed: () async {
                  final app = Provider.of<AppState>(context, listen: false);
                  if (app.isTesting) {
                    final nameController = TextEditingController();
                    final reportName = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF003366),
                        title: const Text("Test Adı Girin", style: TextStyle(color: Colors.white)),
                        content: TextField(
                          controller: nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "örnek: Test 1",
                            hintStyle: TextStyle(color: Colors.white54),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, null),
                            child: const Text("İptal", style: TextStyle(color: Colors.white70)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, nameController.text.trim()),
                            child: const Text("Kaydet", style: TextStyle(color: Colors.lightBlueAccent)),
                          ),
                        ],
                      ),
                    );

                    if (reportName != null && reportName.isNotEmpty) {
                      app.stopTest();

                      // ✅ Testi tamamla ve kaydet
                      await app.completeTest(reportName);

                      // PDF rapor oluşturma ve paylaşma seçeneği
                      final sharePdf = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF003366),
                          title: const Text("Rapor Oluştur", style: TextStyle(color: Colors.white)),
                          content: const Text(
                            "Test tamamlandı. PDF rapor oluşturulsun mu?",
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hayır")),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Evet")),
                          ],
                        ),
                      );

                      if (sharePdf == true) {
                        await RaporDetayEkrani(test: app.testler.last).sharePdf(context);
                      }
                    }
                  } else {
                    app.startTest();
                  }
                },
                icon: Icon(app.isTesting ? Icons.stop : Icons.play_arrow, color: Colors.white),
                label: Text(app.isTesting ? "Testi Durdur" : "Testi Başlat"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: app.isTesting ? Colors.redAccent : Colors.greenAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),

              const SizedBox(height: 30),

              // 🔹 Test logları
              Expanded(
                child: ListView(
                  children:
                      app.testRecords.map((record) {
                        return Text(
                          record.toString(),
                          style: const TextStyle(color: Colors.white70),
                        );
                      }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
