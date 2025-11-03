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

    // Bluetooth'a gerçek komutu gönder (N36, N40)
    app.sendCommand(value ? bluetoothKey : bluetoothKey);

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
                      'N436',
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
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 🔹 İkisi birden kontrolü
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'İkisi Birden',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CustomToggle(
                      value: bothActive,
                      onChanged: (v) {
                        _setValve('N436', 'N36', v);
                        _setValve('N440', 'N40', v);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 🔹 N440 kontrolü (Bluetooth: N40)
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'N440',
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
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}