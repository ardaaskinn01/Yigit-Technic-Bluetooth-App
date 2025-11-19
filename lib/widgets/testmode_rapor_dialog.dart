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
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.blueAccent.withOpacity(0.3), width: 1),
      ),
      elevation: 10,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BAŞLIK
              _buildHeader(),
              const SizedBox(height: 20),

              // TEMEL BİLGİLER
              _buildSection(
                title: "TEMEL BİLGİLER",
                icon: Icons.info_outline,
                children: [
                  _buildInfoRow("Test Modu", "T${widget.rapor.testModu}"),
                  _buildInfoRow("Tarih", widget.rapor.formattedDate),
                  _buildInfoRow("Süre", widget.rapor.pompaSureFormatted),
                ],
              ),

              // BASINÇ BİLGİLERİ
              _buildSection(
                title: "BASINÇ BİLGİLERİ",
                icon: Icons.speed,
                children: [
                  _buildPressureInfo(),
                ],
              ),

              // SİSTEM DURUMU
              _buildSection(
                title: "SİSTEM DURUMU",
                icon: Icons.assessment,
                children: [
                  _buildSystemStatus(),
                ],
              ),

              // VİTES GEÇİŞLERİ - YENİ KOMPAKT TASARIM
              _buildSection(
                title: "VİTES GEÇİŞLERİ",
                icon: Icons.directions_car,
                children: [
                  _buildCompactVitesGecisleri(widget.rapor.vitesGecisleri),
                ],
              ),

              const SizedBox(height: 16),

              // KAPATMA BUTONU
              _buildCloseButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent.shade700, Colors.blueAccent.shade400],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.assignment, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            "TEST MODU ${widget.rapor.testModu} RAPORU",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4), // Biraz boşluk
          // ✅ GÜNCELLENMİŞ KISIM: Daha belirgin font ve kutucuk
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Toplam Geçiş: ${widget.rapor.toplamVitesGecisSayisi}",
              style: const TextStyle(
                color: Colors.yellowAccent, // Dikkat çekici renk
                fontSize: 14, // Biraz daha büyük
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blueAccent, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPressureInfo() {
    return Row(
      children: [
        Expanded(
          child: _buildPressureCard("Min", widget.rapor.minBasinc, Colors.orange),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildPressureCard("Max", widget.rapor.maxBasinc, Colors.green),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildPressureCard("Ort", widget.rapor.ortalamaBasinc, Colors.blue),
        ),
      ],
    );
  }

  Widget _buildPressureCard(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${value.toStringAsFixed(1)} bar",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Row(
      children: [
        Expanded(
          child: _buildStatusCard(
            "Düşük Basınç",
            widget.rapor.dusukBasincSayisi.toString(),
            Icons.warning,
            widget.rapor.dusukBasincSayisi > 0 ? Colors.orange : Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatusCard(
            "Düşük Süre",
            widget.rapor.dusukBasincSureFormatted,
            Icons.timer,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactVitesGecisleri(Map<String, int> vitesGecisleri) {
    final vitesler = ['V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V7', 'VR'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // VİTES BAŞLIKLARI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: vitesler.map((vites) {
              return Text(
                vites.replaceAll('V', ''),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // VİTES DEĞERLERİ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: vitesler.map((vites) {
              final sayi = vitesGecisleri[vites] ?? 0;
              return Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _getVitesBackgroundColor(sayi),
                  shape: BoxShape.circle,
                  border: Border.all(color: _getVitesBorderColor(sayi)),
                ),
                child: Center(
                  child: Text(
                    sayi.toString(),
                    style: TextStyle(
                      color: _getVitesTextColor(sayi),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // İLERİ/GERİ TOPLAMLARI
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDirectionTotal("İleri Vitesler", vitesGecisleri, ['V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V7']),
              _buildDirectionTotal("Geri Vites", vitesGecisleri, ['VR']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionTotal(String label, Map<String, int> vitesGecisleri, List<String> vitesList) {
    final toplam = vitesList.fold(0, (sum, vites) => sum + (vitesGecisleri[vites] ?? 0));

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          toplam.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getVitesBackgroundColor(int sayi) {
    if (sayi == 0) return Colors.red.withOpacity(0.2);
    if (sayi < 5) return Colors.orange.withOpacity(0.2);
    return Colors.green.withOpacity(0.2);
  }

  Color _getVitesBorderColor(int sayi) {
    if (sayi == 0) return Colors.red;
    if (sayi < 5) return Colors.orange;
    return Colors.green;
  }

  Color _getVitesTextColor(int sayi) {
    if (sayi == 0) return Colors.red;
    if (sayi < 5) return Colors.orange;
    return Colors.green;
  }

  Widget _buildCloseButton() {
    return SizedBox(
      width: double.infinity,
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check, size: 18),
            SizedBox(width: 8),
            Text("TAMAM", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}