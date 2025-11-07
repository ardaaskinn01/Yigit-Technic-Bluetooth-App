import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/test_verisi.dart';
import 'package:share_plus/share_plus.dart';

class RaporDetayEkrani extends StatelessWidget {
  final TestVerisi test;

  const RaporDetayEkrani({super.key, required this.test});

  // 📄 PDF oluşturucu - GELİŞMİŞ VERSİYON
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
                // BAŞLIK
                pw.Center(
                  child: pw.Text(
                    "DQ200 MEKATRONİK TEST RAPORU",
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),

                // GENEL BİLGİLER
                pw.Text("GENEL BİLGİLER",
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  children: [
                    _buildPdfRow("Test Adı", test.testAdi),
                    _buildPdfRow("Tarih", dateFormatted),
                    _buildPdfRow("Genel Puan", "${test.puan}/100"),
                    _buildPdfRow("Durum", test.sonuc),
                    _buildPdfRow("Minimum Basınç", "${test.minBasinc.toStringAsFixed(1)} bar"),
                    _buildPdfRow("Maksimum Basınç", "${test.maxBasinc.toStringAsFixed(1)} bar"),
                    _buildPdfRow("Toplam Pompa Süresi", "${test.toplamPompaSuresi.toStringAsFixed(1)} sn"),
                  ],
                ),

                pw.SizedBox(height: 20),

                // FAZ PUANLARI TABLOSU
                pw.Text("FAZ PUANLARI",
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  children: [
                    _buildPdfRow("FAZ 0 - Pompa Yükselme", "${test.fazPuanlari['faz0'] ?? 0}/10 Puan"),
                    _buildPdfRow("FAZ 1 - Isınma", "${test.fazPuanlari['faz1'] ?? 0}/15 Puan"),
                    _buildPdfRow("FAZ 2 - Basınç Valf Testi", "${test.fazPuanlari['faz2'] ?? 0}/20 Puan"),
                    _buildPdfRow("FAZ 3 - Vites Testleri", "${test.fazPuanlari['faz3'] ?? 0}/35 Puan"),
                    _buildPdfRow("FAZ 4 - Dayanıklılık Testi", "${test.fazPuanlari['faz4'] ?? 0}/20 Puan"),
                  ],
                ),

                pw.SizedBox(height: 20),

                // DETAYLI FAZ BİLGİLERİ
                _buildFazDetaylariPdf(),

                // DEĞERLENDİRME
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("DEĞERLENDİRME",
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 8),
                      pw.Text(_getDegerlendirmeNotu(),
                          style: pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildFazDetaylariPdf() {
    final fazDetaylari = <pw.Widget>[];

    // FAZ 0 Detayları
    if (test.faz0Detaylari.isNotEmpty) {
      fazDetaylari.addAll([
        pw.SizedBox(height: 15),
        pw.Text("FAZ 0 - POMPA YÜKSELME DETAYLARI",
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text("Ölçüm: ${test.faz0Detaylari['olcum'] ?? 'N/A'} s | Referans: ${test.faz0Detaylari['referans'] ?? 'N/A'} s"),
      ]);
    }

    // FAZ 2 Detayları
    if (test.faz2Detaylari.isNotEmpty) {
      fazDetaylari.addAll([
        pw.SizedBox(height: 15),
        pw.Text("FAZ 2 - BASINÇ VALF TESTİ DETAYLARI",
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text("N436: ${test.faz2Detaylari['n436'] ?? 'N/A'} bar/dk"),
        pw.Text("N440: ${test.faz2Detaylari['n440'] ?? 'N/A'} bar/dk"),
        pw.Text("Her İkisi: ${test.faz2Detaylari['her_ikisi'] ?? 'N/A'} bar/dk"),
        pw.Text("Kapalı: ${test.faz2Detaylari['kapali'] ?? 'N/A'} bar/dk"),
      ]);
    }

    // FAZ 3 Detayları
    if (test.faz3Detaylari.isNotEmpty) {
      fazDetaylari.addAll([
        pw.SizedBox(height: 15),
        pw.Text("FAZ 3 - VİTES TESTLERİ DETAYLARI",
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
      ]);

      final vitesler = ['1', '2', '3', '4', '5', '6', '7', 'R'];
      for (final vites in vitesler) {
        final vitesData = test.faz3Detaylari['v$vites'];
        if (vitesData != null) {
          fazDetaylari.add(pw.Text(
              "Vites $vites: ${vitesData['olcum']} bar | Referans: ${vitesData['referans']} bar | Puan: ${vitesData['puan']}"));
        }
      }
    }

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: fazDetaylari);
  }

  String _getDegerlendirmeNotu() {
    if (test.puan >= 80) return "Mekatronik ünite mükemmel durumda. Tüm testler başarıyla tamamlandı.";
    if (test.puan >= 60) return "Mekatronik ünite iyi durumda. Küçük ayarlar gerekebilir.";
    if (test.puan >= 40) return "Mekatronik ünite orta durumda. Detaylı inceleme önerilir.";
    if (test.puan >= 20) return "Mekatronik ünite sorunlu. Acil müdahale gerekli.";
    return "Mekatronik ünite kötü durumda. Değişim önerilir.";
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
    await Printing.sharePdf(bytes: pdfData, filename: '${test.testAdi}_rapor.pdf');
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
                // BAŞLIK
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

                // GENEL BİLGİLER KARTI
                Card(
                  color: Colors.white.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Genel Bilgiler",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        _buildInfoRow("Test Adı", test.testAdi),
                        _buildInfoRow("Tarih", dateFormatted),
                        _buildInfoRow("Genel Puan", "${test.puan}/100"),
                        _buildInfoRow("Durum", test.sonuc),
                        _buildInfoRow("Minimum Basınç", "${test.minBasinc.toStringAsFixed(1)} bar"),
                        _buildInfoRow("Maksimum Basınç", "${test.maxBasinc.toStringAsFixed(1)} bar"),
                        _buildInfoRow("Pompa Süresi", "${test.toplamPompaSuresi.toStringAsFixed(1)} sn"),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // FAZ PUANLARI KARTI
                Card(
                  color: Colors.white.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Faz Puanları",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        ..._buildFazPuanlari(test),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // DETAYLI FAZ BİLGİLERİ
                if (test.detayliFazVerileri.isNotEmpty) ...[
                  Card(
                    color: Colors.white.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Detaylı Faz Bilgileri",
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          ..._buildDetayliFazBilgileri(test),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // DEĞERLENDİRME KARTI
                Card(
                  color: Colors.white.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Değerlendirme",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text(_getDegerlendirmeNotu(),
                            style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // PDF BUTONLARI
                ElevatedButton.icon(
                  onPressed: () async {
                    final pdfData = await _generatePdf();
                    await Printing.layoutPdf(onLayout: (format) async => pdfData);
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("PDF Görüntüle / İndir", style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => sharePdf(context),
                  icon: const Icon(Icons.share),
                  label: const Text("PDF Paylaş", style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFazPuanlari(TestVerisi test) {
    final fazlar = [
      {'label': 'FAZ 0 - Pompa Yükselme', 'key': 'faz0', 'max': 10},
      {'label': 'FAZ 1 - Isınma', 'key': 'faz1', 'max': 15},
      {'label': 'FAZ 2 - Basınç Valf Testi', 'key': 'faz2', 'max': 20},
      {'label': 'FAZ 3 - Vites Testleri', 'key': 'faz3', 'max': 35},
      {'label': 'FAZ 4 - Dayanıklılık Testi', 'key': 'faz4', 'max': 20},
    ];

    return fazlar.map((faz) {
      final puan = test.fazPuanlari[faz['key']] ?? 0;
      final maxPuan = faz['max'] as int;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 2,
              child: Text("${faz['label']}:",
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ),
            Expanded(
              flex: 1,
              child: Text("$puan/$maxPuan",
                  style: TextStyle(
                      color: _getPuanColor(puan, maxPuan),
                      fontWeight: FontWeight.bold,
                      fontSize: 14
                  )),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildDetayliFazBilgileri(TestVerisi test) {
    final detaylar = <Widget>[];

    // FAZ 0 Detayları
    if (test.faz0Detaylari.isNotEmpty) {
      detaylar.addAll([
        const SizedBox(height: 10),
        const Text("FAZ 0 - Pompa Yükselme:",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text("  Ölçüm: ${test.faz0Detaylari['olcum'] ?? 'N/A'} s", style: const TextStyle(color: Colors.white70)),
        Text("  Referans: ${test.faz0Detaylari['referans'] ?? 'N/A'} s", style: const TextStyle(color: Colors.white70)),
      ]);
    }

    // FAZ 2 Detayları
    if (test.faz2Detaylari.isNotEmpty) {
      detaylar.addAll([
        const SizedBox(height: 10),
        const Text("FAZ 2 - Basınç Valf Testi:",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text("  N436: ${test.faz2Detaylari['n436'] ?? 'N/A'} bar/dk", style: const TextStyle(color: Colors.white70)),
        Text("  N440: ${test.faz2Detaylari['n440'] ?? 'N/A'} bar/dk", style: const TextStyle(color: Colors.white70)),
        Text("  Her İkisi: ${test.faz2Detaylari['her_ikisi'] ?? 'N/A'} bar/dk", style: const TextStyle(color: Colors.white70)),
        Text("  Kapalı: ${test.faz2Detaylari['kapali'] ?? 'N/A'} bar/dk", style: const TextStyle(color: Colors.white70)),
      ]);
    }

    // FAZ 3 Detayları
    if (test.faz3Detaylari.isNotEmpty) {
      detaylar.addAll([
        const SizedBox(height: 10),
        const Text("FAZ 3 - Vites Testleri:",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ]);

      final vitesler = ['1', '2', '3', '4', '5', '6', '7', 'R'];
      for (final vites in vitesler) {
        final vitesData = test.faz3Detaylari['v$vites'];
        if (vitesData != null) {
          detaylar.add(Text(
            "  Vites $vites: ${vitesData['olcum']} bar | Ref: ${vitesData['referans']} bar | Puan: ${vitesData['puan']}",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ));
        }
      }
    }

    return detaylar;
  }

  Color _getPuanColor(int puan, int maxPuan) {
    final yuzde = (puan / maxPuan) * 100;
    if (yuzde >= 80) return Colors.green;
    if (yuzde >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Text(value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}