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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0f2027), Color(0xFF203a43), Color(0xFF2c5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 6, // Daha dar
            mainAxisSpacing: 2, // Daha az boşluk
            crossAxisSpacing: 6,
            children: [
              _valveItem('N435', 'K1', states['N435'] ?? false),
              _valveItem('N438', 'Vites 6-R', states['N438'] ?? false),
              _valveItem('N434', 'Vites 5-7', states['N434'] ?? false),
              _valveItem('N440', 'Basınç-2', states['N440'] ?? false),
              _valveItem('N436', 'Basınç-1', states['N436'] ?? false),
              _valveItem('N439', 'K2', states['N439'] ?? false),
              _valveItem('N433', 'Vites 1-3', states['N433'] ?? false),
              _valveItem('N437', 'Vites 2-4', states['N437'] ?? false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valveItem(String name, String func, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.15) : Colors.white10,
        border: Border(
          left: BorderSide(
            color: isActive ? Colors.greenAccent : Colors.white24,
            width: 3,
          ),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.greenAccent : Colors.grey,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
                Text(
                  func,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}