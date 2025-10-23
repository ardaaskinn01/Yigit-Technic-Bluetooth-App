import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'home_screen.dart';
import 'test_screen.dart';
import 'log_screen.dart';
import '../widgets/pressure_monitor_widget.dart';
import '../widgets/valve_status_panel.dart';
import '../widgets/pressure_valve_controls.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF001F3F), Color(0xFF003366), Color(0xFF004C99)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 🔹 Sol kısım: Raporlar ve Ayarlar
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.assignment, color: Colors.white),
                    tooltip: "Raporlar",
                    onPressed: () => Navigator.pushNamed(context, '/reports'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    tooltip: "Ayarlar",
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                  ),
                ],
              ),

              // 🔹 Orta kısım: Başlık
              const Text(
                "DQ200 Kontrol Sistemi",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),

              // 🔹 Sağ kısım: TabBar
              SizedBox(
                width: 400, // genişlik kontrolü
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.lightBlueAccent,
                  tabs: const [
                    Tab(icon: Icon(Icons.task_alt), text: "Kontroller"),
                    Tab(icon: Icon(Icons.bolt), text: "Test"),
                    Tab(icon: Icon(Icons.terminal), text: "Log"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Row(
        children: [
          // 🔹 Sol taraf (%65)
          Expanded(
            flex: 65,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF001F3F), Color(0xFF003366), Color(0xFF004C99)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const PressureMonitorWidget(),
                    const SizedBox(height: 12),
                    _buildPumpControls(app),
                    const SizedBox(height: 12),
                    _buildValfSection(app),
                  ],
                ),
              ),
            ),
          ),

          // 🔹 Sağ taraf (%35)
          Expanded(
            flex: 35,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF002B55), Color(0xFF003E77)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  HomeScreen(onInit: () => app.initConnection()),
                  const TestScreen(),
                  const LogScreen(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPumpControls(AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildControlButton(
              'Pompa Aç',
              Icons.play_arrow,
              Colors.greenAccent,
                  () => app.sendCommand('A'),
            ),
            _buildControlButton(
              'Pompa Kapat',
              Icons.stop,
              Colors.redAccent,
                  () => app.sendCommand('K'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              app.pumpOn ? Icons.water_drop : Icons.water_drop_outlined,
              color: app.pumpOn ? Colors.lightBlueAccent : Colors.white38,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              app.pumpOn ? 'Pompa Açık' : 'Pompa Kapalı',
              style: TextStyle(
                color: app.pumpOn ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildValfSection(AppState app) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        ValveStatusPanel(),
        SizedBox(height: 8),
        PressureValveControls(),
      ],
    );
  }

  Widget _buildControlButton(
      String text,
      IconData icon,
      Color color,
      VoidCallback onPressed,
      ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(text, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }
}