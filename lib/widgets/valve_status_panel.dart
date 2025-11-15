import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class ValveStatusPanel extends StatelessWidget {
  const ValveStatusPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final states = app.valveStates;
    final isK1K2Mode = app.isK1K2Mode;
    final currentGear = app.gear;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0f2027), Color(0xFF203a43), Color(0xFF2c5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🔧 8 Valf Durumu - Vites: $currentGear',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 4.8,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              // Basınç Valfleri (Üst Grup)
              _valveItem('N436', 'Basınç Valfi 1\n(1,3,5,7. Vitesler)',
                  states['N436'] ?? false, isK1K2Mode, currentGear, 'N436'),
              _valveItem('N440', 'Basınç Valfi 2\n(2,4,6,R Vitesler)',
                  states['N440'] ?? false, isK1K2Mode, currentGear, 'N440'),

              // K1/K2 Kavrama Valfleri
              _valveItem('N435', 'K1 Kavraması\n(1,3,5,7. Vitesler)',
                  states['N435'] ?? false, isK1K2Mode, currentGear, 'K1'),
              _valveItem('N439', 'K2 Kavraması\n(2,4,6,R Vitesler)',
                  states['N439'] ?? false, isK1K2Mode, currentGear, 'K2'),

              // Vites Valfleri - Grup 1
              _valveItem('N433', '1. Vites Valfi',
                  states['N433'] ?? false, isK1K2Mode, currentGear, 'N433'),
              _valveItem('N437', '2. Vites Valfi',
                  states['N437'] ?? false, isK1K2Mode, currentGear, 'N437'),

              // Vites Valfleri - Grup 2
              _valveItem('N434', '5. Vites Valfi',
                  states['N434'] ?? false, isK1K2Mode, currentGear, 'N434'),
              _valveItem('N438', 'R Vites Valfi',
                  states['N438'] ?? false, isK1K2Mode, currentGear, 'N438'),
            ],
          ),

          // Açıklama Notları
          const SizedBox(height: 12),
          _buildInfoNotes(isK1K2Mode),
        ],
      ),
    );
  }

  Widget _buildInfoNotes(bool isK1K2Mode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isK1K2Mode)
          Text('ℹ️ K1/K2 modu kapalı - Kavrama valfleri devre dışı',
              style: TextStyle(color: Colors.orange[300], fontSize: 10)),
        Text('💚 Yeşil: Doğru durum | 🟠 Turuncu: Eksik aktif | 🔴 Kırmızı: Fazla aktif',
            style: TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _valveItem(String name, String func, bool isActive, bool isK1K2Mode, String currentGear, String displayName) {
    Color statusColor;
    String valveDisplayName = displayName;

    // Vitese göre bu valfin aktif olması gerekiyor mu?
    bool shouldBeActive = _shouldValveBeActiveForGear(name, currentGear, isK1K2Mode);

    // K1/K2 valfleri için özel işlem
    if (name == 'N435' || name == 'N439') {
      if (!isK1K2Mode) {
        // K1K2 modu kapalıysa gri göster (devre dışı)
        statusColor = Colors.grey.withOpacity(0.5);
      } else {
        // K1K2 modu açıksa, vites kurallarına göre renk belirle
        statusColor = _calculateStatusColor(shouldBeActive, isActive);
      }
    } else {
      // Normal valfler için vites kurallarına göre renk belirle
      statusColor = _calculateStatusColor(shouldBeActive, isActive);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.15) : Colors.white10,
        border: Border(
          left: BorderSide(
            color: statusColor,
            width: 4,
          ),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // Durum göstergesi
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 8),

          // Valf bilgisi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(valveDisplayName,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: (name == 'N435' || name == 'N439') && !isK1K2Mode
                            ? Colors.grey
                            : Colors.white,
                        fontSize: 13)),
                Text(func,
                    style: TextStyle(
                        fontSize: 10,
                        color: (name == 'N435' || name == 'N439') && !isK1K2Mode
                            ? Colors.grey
                            : Colors.white70),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),

          // Uyarı/Error ikonları
          if (shouldBeActive && !isActive)
            Icon(Icons.warning_amber, color: Colors.orange, size: 12),
          if (!shouldBeActive && isActive)
            Icon(Icons.error_outline, color: Colors.red, size: 12),
        ],
      ),
    );
  }

  Color _calculateStatusColor(bool shouldBeActive, bool isActive) {
    if (shouldBeActive && isActive) {
      return Colors.greenAccent; // Doğru: aktif olması gereken ve aktif
    } else if (shouldBeActive && !isActive) {
      return Colors.orange; // Uyarı: aktif olması gerekirken pasif
    } else if (!shouldBeActive && isActive) {
      return Colors.red; // Hata: pasif olması gerekirken aktif
    } else {
      return Colors.grey; // Doğru: pasif olması gereken ve pasif
    }
  }

  // AppState'teki updateValvesByGear kurallarına göre valf aktivasyon kontrolü
  bool _shouldValveBeActiveForGear(String valveName, String gear, bool isK1K2Mode) {
    switch (valveName) {
      case 'N433': // 1. Vites Valfi
        return gear == '1';
      case 'N434': // 5. Vites Valfi
        return gear == '5';
      case 'N437': // 2. Vites Valfi
        return gear == '2';
      case 'N438': // R Vites Valfi
        return gear == 'R';
      case 'N436': // Basınç Valfi 1
        return ['1', '3', '5', '7'].contains(gear);
      case 'N440': // Basınç Valfi 2
        return ['2', '4', '6', 'R'].contains(gear);
      case 'N435': // K1 Kavraması
        return isK1K2Mode && ['1', '3', '5', '7'].contains(gear);
      case 'N439': // K2 Kavraması
        return isK1K2Mode && ['2', '4', '6', 'R'].contains(gear);
      default:
        return false;
    }
  }
}