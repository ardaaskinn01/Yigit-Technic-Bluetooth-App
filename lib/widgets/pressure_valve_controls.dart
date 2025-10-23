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
      // Başlangıç durumlarını AppState'ten al
      n436Active = app.valveStates['N436'] ?? false;
      n440Active = app.valveStates['N440'] ?? false;
      _inited = true;
    }
  }

  void _setValve(String key, bool value) {
    final app = Provider.of<AppState>(context, listen: false);
    // 1) UI state
    setState(() {
      if (key == 'N436') n436Active = value;
      if (key == 'N440') n440Active = value;
    });
    // 2) AppState'e kaydet (kalıcılık / paylaşım)
    if (app.setValveState != null) {
      // Eğer setValveState fonksiyonu eklediysen:
      app.setValveState(key, value);
    } else {
      // fallback: doğrudan valveStates güncelle
      app.valveStates[key] = value;
      app.notifyListeners();
    }
    // 3) Cihaza komut gönder
    // Komut protokolünü ESP ile kararlaştır. Örnek:
    app.sendCommand(value ? '${key}_ON' : '${key}_OFF');
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context, listen: false);

    return Row(
      children: [
        // N436
        Expanded(
          child: Column(
            children: [
              const Text('N436',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
              const SizedBox(height: 6),
              CustomToggle(
                value: n436Active,
                onChanged: (v) => _setValve('N436', v),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // N440
        Expanded(
          child: Column(
            children: [
              const Text('N440',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
              const SizedBox(height: 6),
              CustomToggle(
                value: n440Active,
                onChanged: (v) => _setValve('N440', v),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // İkisi Birden
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              final bothActive = n436Active && n440Active;
              _setValve('N436', !bothActive);
              _setValve('N440', !bothActive);
              // ayrıca tek komutla ESP'ye de gönder
              app.sendCommand(!bothActive ? 'BOTH_ON' : 'BOTH_OFF');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('İkisi\nBirden',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
