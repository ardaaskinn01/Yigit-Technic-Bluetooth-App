// widgets/test_modu_raporu_dialog.dart
import 'package:flutter/material.dart';
import '../models/testmode_verisi.dart';

class TestModuRaporuDialog extends StatefulWidget {
  final TestModuRaporu rapor;
  final VoidCallback onKapat;

  const TestModuRaporuDialog({
    super.key,
    required this.rapor,
    required this.onKapat,
  });

  @override
  State<TestModuRaporuDialog> createState() => _TestModuRaporuDialogState();
}

class _TestModuRaporuDialogState extends State<TestModuRaporuDialog> {
  bool _kapatildi = false;

  @override
  Widget build(BuildContext context) {

    return Dialog(
      backgroundColor: Colors.blueGrey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BAŞLIK
              Center(
                child: Text(
                  "TEST MODU ${widget.rapor.testModu} RAPORU",
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // TARİH VE MOD BİLGİSİ
              _buildInfoRow("Test Modu", "T${widget.rapor.testModu}"),
              _buildInfoRow("Tarih", widget.rapor.formattedDate),
              const Divider(color: Colors.grey),

              // BASINÇ BİLGİLERİ
              const Text("BASINÇ BİLGİLERİ",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildInfoRow("Minimum Basınç", "${widget.rapor.minBasinc.toStringAsFixed(1)} bar"),
              _buildInfoRow("Maksimum Basınç", "${widget.rapor.maxBasinc.toStringAsFixed(1)} bar"),
              _buildInfoRow("Ortalama Basınç", "${widget.rapor.ortalamaBasinc.toStringAsFixed(1)} bar"),
              const SizedBox(height: 8),

              // POMPA BİLGİLERİ
              const Text("POMPA BİLGİLERİ",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildInfoRow("Toplam Çalışma Süresi", widget.rapor.pompaSureFormatted),
              _buildInfoRow("Düşük Basınç Sayısı", widget.rapor.dusukBasincSayisi.toString()),
              _buildInfoRow("Düşük Basınç Süresi", widget.rapor.dusukBasincSureFormatted),
              const SizedBox(height: 8),

              // VİTES BİLGİLERİ
              const Text("VİTES GEÇİŞLERİ",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildInfoRow("Toplam Geçiş Sayısı", widget.rapor.toplamVitesGecisSayisi.toString()),
              const SizedBox(height: 8),

              // VİTES GEÇİŞ DETAYLARI
              _buildVitesGecisleri(widget.rapor.vitesGecisleri),

              const SizedBox(height: 20),

              // KAPATMA BUTONU
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (!_kapatildi) {
                      _kapatildi = true;
                      widget.onKapat();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text("KAPAT"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildVitesGecisleri(Map<String, int> vitesGecisleri) {
    final vitesler = ['V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V7', 'VR'];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.5,
      ),
      itemCount: vitesler.length,
      itemBuilder: (context, index) {
        final vites = vitesler[index];
        final sayi = vitesGecisleri[vites] ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.blueGrey[800],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                vites.replaceAll('V', ''),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                sayi.toString(),
                style: TextStyle(
                  color: _getVitesSayiColor(sayi),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getVitesSayiColor(int sayi) {
    if (sayi == 0) return Colors.red;
    if (sayi < 5) return Colors.orange;
    return Colors.green;
  }
}