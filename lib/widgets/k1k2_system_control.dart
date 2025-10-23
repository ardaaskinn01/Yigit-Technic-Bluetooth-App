import 'package:flutter/material.dart';

class K1K2SystemControl extends StatefulWidget {
  final bool value;
  final Function(bool) onChanged;

  const K1K2SystemControl({
    super.key,
    required this.value,
    required this.onChanged,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // ✨ Arka plan rengi, ana temaya uyumlu koyu gri/lacivert tonuna çevrildi.
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        // Kenarlık ekleyerek belirginliğini artırıyoruz.
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.0),
      ),
      child: Column(
        children: [
          const Text(
            '⚙️ K1K2 Sistem',
            // ✨ Metin rengi beyaza çevrildi.
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Switch(
            value: k1k2Active,
            // Açıkken mavi-yeşil tonları kullanarak kontrastı artırıyoruz.
            activeColor: Colors.lightGreenAccent,
            // Kapalıyken daha koyu bir gri kullanıyoruz.
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
              // ✨ Metin rengi, durumuna göre parlak yeşil veya beyazın bir tonu.
              color: k1k2Active ? Colors.lightGreenAccent : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
