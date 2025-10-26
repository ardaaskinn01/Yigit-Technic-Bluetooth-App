import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class ValveStatusPanel extends StatelessWidget {
  const ValveStatusPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final states = app.valveStates;

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
          const Text('🔧 8 Valf Durumu',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 4.8,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _valveItem('N435', 'K1', states['K1'] ?? false),
              _valveItem('N438', 'Vites 6-R', states['N438'] ?? false),
              _valveItem('N434', 'Vites 5-7', states['N434'] ?? false),
              _valveItem('N440', 'Basınç-2', states['N440'] ?? false),
              _valveItem('N436', 'Basınç-1', states['N436'] ?? false),
              _valveItem('N439', 'K2', states['K2'] ?? false),
              _valveItem('N433', 'Vites 1-3', states['N433'] ?? false),
              _valveItem('N437', 'Vites 2-4', states['N437'] ?? false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valveItem(String name, String func, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.1) : Colors.white10,
        border: Border(
          left: BorderSide(
            color: isActive ? Colors.greenAccent : Colors.white24,
            width: 4,
          ),
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: isActive
            ? [BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 10)]
            : [],
      ),
      child: Row(
        children: [
          // 🔵 Durum Noktası
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.greenAccent : Colors.grey,
              boxShadow: isActive
                  ? [BoxShadow(color: Colors.greenAccent, blurRadius: 8)]
                  : [],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 13)),
                Text(func,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.white70),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
