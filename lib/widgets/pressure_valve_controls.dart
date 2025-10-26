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

  void _setValve(String key, bool value) {
    final app = Provider.of<AppState>(context, listen: false);

    setState(() {
      if (key == 'N36') n436Active = value;
      if (key == 'N40') n440Active = value;
    });

    app.valveStates[key] = value;
    app.notifyListeners();

    // ✅ Her valf için kendi komutu ayrı gönderiliyor
    app.sendCommand(value ? '$key' : '$key');
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final bothActive = n436Active && n440Active;

    // Artık her zaman aktif
    final isDisabled = false;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: IgnorePointer(
        ignoring: isDisabled,
        child: Container(
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
                  // 🔹 N436 kontrolü
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
                          onChanged: (v) => _setValve('N36', v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // 🔹 İkisi birden kontrolü (ama ayrı ayrı komut gönderiyor)
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
                            _setValve('N36', v);
                            _setValve('N40', v);
                            // ❌ BOTH_ON / BOTH_OFF komutları artık gönderilmiyor
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // 🔹 N440 kontrolü
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
                          onChanged: (v) => _setValve('N40', v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}