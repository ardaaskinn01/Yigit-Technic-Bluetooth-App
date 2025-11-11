import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'custom_toggle.dart';

class PressureValveControls extends StatefulWidget {
  const PressureValveControls({super.key});

  @override
  State<PressureValveControls> createState() => _PressureValveControlsState();
}

class _PressureValveControlsState extends State<PressureValveControls> {
  bool n436Active = false;
  bool n440Active = false;
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inited) {
      final app = Provider.of<AppState>(context, listen: false);
      n436Active = app.valveStates['N436'] ?? false;
      n440Active = app.valveStates['N440'] ?? false;
      _inited = true;
    }
  }

  void _setValve(String displayKey, String bluetoothKey, bool value) {
    final app = Provider.of<AppState>(context, listen: false);

    setState(() {
      if (displayKey == 'N436') n436Active = value;
      if (displayKey == 'N440') n440Active = value;
    });

    // AppState'teki valveStates'i güncelle (arayüz için)
    app.valveStates[displayKey] = value;

    // ✅ YENİ: ON/OFF komutları - K1K2 gibi
    if (value) {
      app.sendCommand("${bluetoothKey}ON");  // Açık: N36ON, N40ON
    } else {
      app.sendCommand("${bluetoothKey}OFF"); // Kapalı: N36OFF, N40OFF
    }

    app.notifyListeners();
  }

  // ✅ YENİ: NB Komutu - İki valfi birden kontrol eder
  void _setNBCommand(bool value) {
    final app = Provider.of<AppState>(context, listen: false);

    setState(() {
      n436Active = value;
      n440Active = value;
    });

    // AppState'teki valveStates'i güncelle
    app.valveStates['N436'] = value;
    app.valveStates['N440'] = value;

    // ✅ NB komutunu gönder (tek komutla iki valf)
    if (value) {
      app.sendCommand("NBON");  // NB Açık: N436 ve N440'ı açar
    } else {
      app.sendCommand("NBOFF"); // NB Kapalı: N436 ve N440'ı kapatır
    }

    app.logs.add('NB Komutu: ${value ? "AÇIK" : "KAPALI"} - N436: $value, N440: $value');
    app.notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final bothActive = n436Active && n440Active;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              // 🔹 N436 kontrolü (Bluetooth: N36)
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'N436 (N36)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CustomToggle(
                      value: n436Active,
                      onChanged: (v) => _setValve('N436', 'N36', v),
                    ),
                    Text(
                      n436Active ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 10,
                        color: n436Active ? Colors.greenAccent : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // 🔹 NB KOMUTU - İkisi Birden
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'NB\n(İkisi Birden)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CustomToggle(
                      value: bothActive,
                      onChanged: _setNBCommand, // ✅ NB komutunu tetikle
                    ),
                    Text(
                      bothActive ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 10,
                        color: bothActive ? Colors.greenAccent : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // 🔹 N440 kontrolü (Bluetooth: N40)
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'N440 (N40)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CustomToggle(
                      value: n440Active,
                      onChanged: (v) => _setValve('N440', 'N40', v),
                    ),
                    Text(
                      n440Active ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 10,
                        color: n440Active ? Colors.greenAccent : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 🔹 Durum Bilgisi
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  bothActive ? Icons.power : Icons.power_off,
                  color: bothActive ? Colors.greenAccent : Colors.grey,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'NB: ${bothActive ? "İkisi Açık" : "İkisi Kapalı"}',
                  style: TextStyle(
                    fontSize: 10,
                    color: bothActive ? Colors.greenAccent : Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}