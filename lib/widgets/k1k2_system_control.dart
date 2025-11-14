import 'package:flutter/material.dart';
import '../providers/app_state.dart';

class K1K2SystemControl extends StatefulWidget {
  final AppState app;

  const K1K2SystemControl({
    super.key,
    required this.app,
  });

  @override
  _K1K2SystemControlState createState() => _K1K2SystemControlState();
}

class _K1K2SystemControlState extends State<K1K2SystemControl> {
  bool _isProcessing = false; // ⭐ YENİ: İşlem flag'i

  void _handleValveToggle(String actualValveKey, bool isK1K2ModeEnabled) async {
    if (_isProcessing) return; // ⭐ Çoklu tıklamayı önle

    _isProcessing = true;

    try {
      if (!isK1K2ModeEnabled) {
        widget.app.setK1K2Mode(true);
        await Future.delayed(Duration(milliseconds: 300));
      }

      if (widget.app.isK1K2Mode) {
        widget.app.toggleValve(actualValveKey);
        print('[DEBUG] ToggleValve çağrıldı: $actualValveKey'); // ⭐ Debug
      }

      await Future.delayed(Duration(milliseconds: 200)); // ⭐ Minimum bekleme
    } finally {
      _isProcessing = false;
    }
  }
  @override
  Widget build(BuildContext context) {
    final isK1K2Active = widget.app.isK1K2Mode;
    final k1Active = widget.app.valveStates['N435'] ?? false;
    final k2Active = widget.app.valveStates['N439'] ?? false;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.0),
      ),
      child: Column(
        children: [
          const Text(
            '⚙️ K1K2 Sistemi',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white
            ),
          ),
          const SizedBox(height: 10),

          // Ana Switch - K1K2 Modu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'K1K2 Modu:',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              Switch(
                value: isK1K2Active,
                activeColor: Colors.lightGreenAccent,
                inactiveTrackColor: Colors.white.withOpacity(0.3),
                inactiveThumbColor: Colors.grey[400],
                onChanged: (value) {
                  widget.app.setK1K2Mode(value);
                },
              ),
            ],
          ),

          // K1 K2 Butonları
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildValveButton('K1', k1Active, isK1K2Active),
              _buildValveButton('K2', k2Active, isK1K2Active),
            ],
          ),
          const SizedBox(height: 4),

          // Durum bilgisi
          Text(
            isK1K2Active
                ? "K1: ${k1Active ? 'Aktif' : 'Pasif'}, K2: ${k2Active ? 'Aktif' : 'Pasif'}"
                : "K1K2 Modu Kapalı",
            style: TextStyle(
              fontSize: 10,
              color: isK1K2Active ? Colors.lightGreenAccent : Colors.orangeAccent,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValveButton(String valve, bool isActive, bool isK1K2ModeEnabled) {
    // Butonun gerçek valve key'ini belirle
    String actualValveKey = valve == 'K1' ? 'N435' : 'N439';
    bool actualState = widget.app.valveStates[actualValveKey] ?? false;

    Color backgroundColor;
    Color borderColor;

    if (!isK1K2ModeEnabled) {
      backgroundColor = Colors.grey.withOpacity(0.3);
      borderColor = Colors.grey;
    } else if (actualState) {
      backgroundColor = Colors.lightBlueAccent.withOpacity(0.8);
      borderColor = Colors.lightBlueAccent;
    } else {
      backgroundColor = Colors.white.withOpacity(0.15);
      borderColor = Colors.grey.withOpacity(0.5);
    }

    return ElevatedButton(
      onPressed: () {
        // ⭐ YENİ: Aynı state'deki butona basmayı önle
        if (actualState == (valve == 'K1')) {
          return; // Zaten istenen state'de
        }

        _handleValveToggle(actualValveKey, isK1K2ModeEnabled);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: borderColor,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      child: Text(
        valve,
        style: TextStyle(
          color: isK1K2ModeEnabled ? Colors.white : Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}