import 'package:flutter/material.dart';
import '../providers/app_state.dart';

class K1K2SystemControl extends StatefulWidget {
  final bool value;
  final Function(bool) onChanged;
  final AppState app;

  const K1K2SystemControl({
    super.key,
    required this.value,
    required this.onChanged,
    required this.app,
  });

  @override
  _K1K2SystemControlState createState() => _K1K2SystemControlState();
}

class _K1K2SystemControlState extends State<K1K2SystemControl> {
  late bool k1k2Active;

  @override
  void initState() {
    super.initState();
    k1k2Active = widget.value;
  }

  // ✅ GÜNCELLENDİ: Butonlar her zaman tıklanabilir
  Widget _buildValveButton(String valve) {
    final isActive = widget.app.valveStates[valve] ?? false;

    return ElevatedButton(
      onPressed: () => widget.app.toggleValve(valve), // ✅ Her zaman aktif
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive
            ? Colors.lightBlueAccent.withOpacity(0.8)
            : Colors.white.withOpacity(0.15), // ✅ Opacity sabit
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isActive ? Colors.lightBlueAccent : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      child: Text(
        valve,
        style: TextStyle(
          color: Colors.white, // ✅ Her zaman beyaz
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

          // Switch
          Switch(
            value: k1k2Active,
            activeColor: Colors.lightGreenAccent,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            inactiveThumbColor: Colors.grey[400],
            onChanged: (value) {
              setState(() => k1k2Active = value);
              widget.onChanged(value);
              // Açılırken ve kapanırken 'k1k2' komutu gönderiliyor
              widget.app.sendCommand('K1K2');
            },
          ),

          // K1 K2 Butonları
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildValveButton('K1'), // ✅ Parametre kaldırıldı
              _buildValveButton('K2'), // ✅ Parametre kaldırıldı
            ],
          ),
          const SizedBox(height: 4),
          Text(
            k1k2Active ? "Debriyaj aktif edildi" : "Debriyaj deaktif",
            style: TextStyle(
              fontSize: 10,
              color: k1k2Active ? Colors.lightGreenAccent : Colors.white38,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}