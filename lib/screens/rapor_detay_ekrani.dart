import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/test_verisi.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/mekatronik_puanlama.dart'; // puan hesaplama fonksiyonu varsa

class RaporDetayEkrani extends StatelessWidget {
  final TestVerisi test;

  const RaporDetayEkrani({super.key, required this.test});

  // 📄 PDF oluşturucu
  // 📄 PDF oluşturucu
  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    final dateFormatted = DateFormat('dd.MM.yyyy HH:mm').format(test.tarih);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    "DQ200 TEST RAPORU",
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.Text("Test Adi: ${test.testAdi}", style: pw.TextStyle(fontSize: 16)),
                pw.Text("Tarih: $dateFormatted", style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 20),

                pw.Text(
                  "Ölcüm Sonuclari",
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  children: [
                    _buildPdfRow("Minimum Basinc", "${test.minBasinc.toStringAsFixed(2)} bar"),
                    _buildPdfRow("Maksimum Basinc", "${test.maxBasinc.toStringAsFixed(2)} bar"),
                    _buildPdfRow("Pompa Calisma Suresi (Genel)", "${test.toplamPompaSuresi.toStringAsFixed(1)} sn"),
                    _buildPdfRow("Puan", "${test.puan}/100"),
                  ],
                ),

                pw.SizedBox(height: 20),

                // FAZ PUANLARI TABLOSU EKLENDİ
                pw.Text(
                  "Faz Puanlari",
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  children: [
                    _buildPdfRow("FAZ 0 - Pompa Yükselme", "/10 Puan"),
                    _buildPdfRow("FAZ 2 - Sizdirmazlik Testi", "/20 Puan"),
                    _buildPdfRow("FAZ 3 - Vites Testleri", "/35 Puan"),
                    _buildPdfRow("FAZ 4 - Dayaniklilik Testi", "/20 Puan"),
                    _buildPdfRow("Bonus Puan", "/15 Puan"),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // PDF tablo satırı
  pw.TableRow _buildPdfRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value),
        ),
      ],
    );
  }

  // 📤 Paylaş
  Future<void> sharePdf(BuildContext context) async {
    final pdfData = await _generatePdf();
    await Printing.sharePdf(bytes: pdfData, filename: '${test.testAdi}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatted = DateFormat('dd.MM.yyyy HH:mm').format(test.tarih);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          test.testAdi,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
            colors: [Color(0xFF003366), Color(0xFF004C99), Color(0xFF001F3F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Center(
                  child: Text(
                    "DQ200 Test Raporu",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.lightBlueAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildInfoRow("Test Adı", test.testAdi),
                _buildInfoRow("Tarih", dateFormatted),
                _buildInfoRow("Faz", test.fazAdi),
                _buildInfoRow("Min Basınç", "${test.minBasinc.toStringAsFixed(2)} bar"),
                _buildInfoRow("Max Basınç", "${test.maxBasinc.toStringAsFixed(2)} bar"),
                _buildInfoRow("Pompa Süresi", "${test.toplamPompaSuresi.toStringAsFixed(1)} sn"),
                _buildInfoRow("Puan", "${test.puan}/100"),
                _buildInfoRow("Sonuç", test.sonuc),

                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () async {
                    final pdfData = await _generatePdf();
                    await Printing.layoutPdf(onLayout: (format) async => pdfData);
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("PDF Görüntüle / İndir", style: const TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => sharePdf(context),
                  icon: const Icon(Icons.share),
                  label: const Text("PDF Paylaş", style: const TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          Text(value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}