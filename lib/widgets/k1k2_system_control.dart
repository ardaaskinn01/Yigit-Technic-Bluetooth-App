import 'package:flutter/material.dart';

import '../providers/app_state.dart';

class K1K2SystemControl extends StatefulWidget {
  final bool value;
  final Function(bool) onChanged;
  final AppState app; // AppState'i parametre olarak alıyoruz

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

  Widget _buildValveButton(String valve, bool isDisabled) {
    final isActive = widget.app.valveStates[valve] ?? false;

    return ElevatedButton(
      onPressed: isDisabled ? null : () => widget.app.toggleValve(valve),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive
            ? Colors.lightBlueAccent.withOpacity(0.8)
            : Colors.white.withOpacity(isDisabled ? 0.05 : 0.15),
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
          color: isDisabled ? Colors.white38 : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = !k1k2Active;

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
            },
          ),
          const SizedBox(height: 4),
          Text(
            k1k2Active ? 'Açık (Dış Vites Test)' : 'Kapalı (İç Vites Test)',
            style: TextStyle(
              fontSize: 12,
              color: k1k2Active ? Colors.lightGreenAccent : Colors.white70,
            ),
          ),

          const SizedBox(height: 12),

          // K1 K2 Butonları
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildValveButton('K1', isDisabled),
              _buildValveButton('K2', isDisabled),
            ],
          ),

          const SizedBox(height: 4),
          Text(
            isDisabled ? "K1/K2 butonları devre dışı" : "K1/K2 butonları aktif",
            style: TextStyle(
              fontSize: 10,
              color: isDisabled ? Colors.white38 : Colors.lightGreenAccent,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}