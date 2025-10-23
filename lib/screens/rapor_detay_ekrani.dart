import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/test_verisi.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/mekatronik_puanlama.dart';

class RaporDetayEkrani extends StatelessWidget {
  final TestVerisi test;

  const RaporDetayEkrani({super.key, required this.test});

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Header(
              level: 0,
              child: pw.Text(test.testAdi, style: pw.TextStyle(fontSize: 26))),
          pw.Text('Tarih: ${test.tarih.toLocal()}'),
          pw.SizedBox(height: 12),
          pw.Text('FAZ 0: Pompa Yükselme → ${test.faz0Sure.toStringAsFixed(1)}s'),
          pw.Text('FAZ 1: Isınma → ${test.faz1Pompa.toStringAsFixed(0)}s'),
          pw.Text('FAZ 2: Basınç Valfi → ${test.faz2Pompa.toStringAsFixed(0)}s'),
          ...test.faz3Vitesler.entries.map((e) => pw.Text(
              '${e.key}: ${e.value.toStringAsFixed(1)} bar düşüş → ${MekatronikPuanlama.vitesBasincPuani(e.value)}/5')),
          pw.Text('FAZ 3 Toplam Puan: ${MekatronikPuanlama.faz3ToplamPuan(test.faz3Vitesler)}/35'),
          pw.Text('FAZ 4: Test Modu → ${test.faz4Pompa.toStringAsFixed(0)}s'),
          pw.Text(
              'Toplam Puan: ${MekatronikPuanlama.toplamPuan(
                faz0Sure: test.faz0Sure,
                faz1Pompa: test.faz1Pompa,
                faz2Pompa: test.faz2Pompa,
                faz3Vitesler: test.faz3Vitesler,
                faz4Pompa: test.faz4Pompa,
              )}/100'),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> sharePdf(BuildContext context) async {
    final pdfData = await _generatePdf();
    await Printing.sharePdf(bytes: pdfData, filename: '${test.testAdi}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          test.testAdi,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'PDF İndir',
            onPressed: () async {
              final pdfData = await _generatePdf();
              await Printing.layoutPdf(onLayout: (format) async => pdfData);
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Paylaş',
            onPressed: () => sharePdf(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF001F3F), Color(0xFF003366), Color(0xFF004C99)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                _fazSatiri("FAZ 0: Pompa Yükselme", "${test.faz0Sure.toStringAsFixed(1)}s",
                    MekatronikPuanlama.faz0Puan(test.faz0Sure), 10),
                _fazSatiri("FAZ 1: Isınma", "${test.faz1Pompa.toStringAsFixed(0)}s",
                    MekatronikPuanlama.faz1Puan(test.faz1Pompa), 15),
                _fazSatiri("FAZ 2: Basınç Valfi", "${test.faz2Pompa.toStringAsFixed(0)}s",
                    MekatronikPuanlama.faz2Puan(test.faz2Pompa), 20),
                Card(
                  color: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("FAZ 3: Vites Testleri",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...test.faz3Vitesler.entries.map((e) => Text(
                            "${e.key}: ${e.value.toStringAsFixed(1)} bar düşüş → ${MekatronikPuanlama.vitesBasincPuani(e.value)}/5",
                            style: const TextStyle(color: Colors.white))),
                        const Divider(color: Colors.white30),
                        Text(
                          "TOPLAM: ${MekatronikPuanlama.faz3ToplamPuan(test.faz3Vitesler)}/35",
                          style: const TextStyle(
                              color: Colors.lightGreenAccent,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                _fazSatiri("FAZ 4: Test Modu", "${test.faz4Pompa.toStringAsFixed(0)}s",
                    MekatronikPuanlama.faz4Puan(test.faz4Pompa), 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fazSatiri(String ad, String deger, int puan, int max) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      child: ListTile(
        title: Text(ad, style: const TextStyle(color: Colors.white)),
        subtitle: Text(deger, style: const TextStyle(color: Colors.white70)),
        trailing: Text(
          "$puan/$max",
          style: const TextStyle(color: Colors.greenAccent),
        ),
      ),
    );
  }
}
