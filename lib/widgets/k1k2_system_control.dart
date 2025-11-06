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
          Switch(
            value: isK1K2Active,
            activeColor: Colors.lightGreenAccent,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            inactiveThumbColor: Colors.grey[400],
            onChanged: (value) {
              // AppState üzerinden merkezi olarak yönet
              widget.app.setK1K2Mode(value);
            },
          ),

          // K1 K2 Butonları - HER ZAMAN TIKLANABİLİR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildValveButton('K1', k1Active),
              _buildValveButton('K2', k2Active),
            ],
          ),
          const SizedBox(height: 4),

          // Durum bilgisi
          Text(
            isK1K2Active
                ? "Debriyaj aktif"
                : "Debriyaj deaktif",
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

  Widget _buildValveButton(String valve, bool isActive) {
    return ElevatedButton(
      onPressed: () => widget.app.toggleValve(valve), // ✅ HER ZAMAN TIKLANABİLİR
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive
            ? Colors.lightBlueAccent.withOpacity(0.8)
            : Colors.white.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isActive ? Colors.lightBlueAccent : Colors.grey.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      child: Text(
        valve,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.white70, // ✅ Her zaman görünür
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}