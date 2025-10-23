import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_verisi.dart';
import '../providers/app_state.dart';
import '../utils/mekatronik_puanlama.dart';
import '../widgets/k1k2_system_control.dart';
import '../widgets/log_console.dart';
import '../widgets/pressure_monitor_widget.dart';
import '../widgets/pressure_valve_controls.dart';
import '../widgets/valve_status_panel.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onInit;
  const HomeScreen({super.key, this.onInit});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool showLog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onInit?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);

    // Scaffold ve SafeArea kaldırıldı, scroll MainHomeScreen'den yönetilecek
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (app.isConnected) ...[
            SizedBox(child: _buildGearSelection(app)),
            const SizedBox(height: 8),
            K1K2SystemControl(
              value: app.isK1K2Mode,
              onChanged: (val) => app.setK1K2Mode(val),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "ÖZEL MODLAR",
                    style: TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 🧯 SÖKME
                      ElevatedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: const Color(0xFF003366),
                              title: const Text("Sökme Modu", style: TextStyle(color: Colors.white)),
                              content: const Text(
                                "Bu işlem basıncı boşaltacaktır.\nEmin misiniz?",
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal")),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Evet")),
                              ],
                            ),
                          );
                          if (confirm == true) app.startSokmeModu();
                        },
                        icon: const Icon(Icons.build_circle, color: Colors.white),
                        label: const Text("SÖKME", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.8),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),

                      // 🧼 TEMİZLEME
                      ElevatedButton.icon(
                        onPressed: () => app.startTemizlemeModu(),
                        icon: const Icon(Icons.cleaning_services, color: Colors.white),
                        label: const Text("TEMİZLE", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent.withOpacity(0.8),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else
            _buildConnectButton(app),
        ],
      ),
    );
  }

  Widget _buildConnectButton(AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (app.isConnected) ...[
          const Icon(Icons.bluetooth_connected, color: Colors.lightBlueAccent, size: 40),
          const SizedBox(height: 8),
          Text("Bağlı: ${app.deviceName}", style: const TextStyle(color: Colors.white)),
        ] else if (app.isScanning) ...[
          const CircularProgressIndicator(color: Colors.blueAccent),
          const SizedBox(height: 12),
          const Text("Cihazlar taranıyor...", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          _buildDeviceList(app),
        ] else if (app.discoveredDevices.isNotEmpty) ...[
          const Text("Bulunan cihazlar:", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          _buildDeviceList(app),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async => await app.initConnection(),
            icon: const Icon(Icons.refresh),
            label: const Text("Yeniden Tara"),
          ),
        ] else ...[
          Text(app.connectionMessage, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async => await app.initConnection(),
            icon: const Icon(Icons.bluetooth_searching, color: Colors.white),
            label: const Text('Cihaz Ara / Bağlan', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeviceList(AppState app) {
    return SizedBox(
      height: 250,
      child: ListView.builder(
        itemCount: app.discoveredDevices.length,
        itemBuilder: (context, index) {
          final device = app.discoveredDevices[index];
          final isConnecting = app.connectingAddress == device.address;

          return Card(
            color: Colors.white10,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.bluetooth, color: Colors.blueAccent),
              title: Text(device.name ?? "Bilinmeyen Cihaz", style: const TextStyle(color: Colors.white)),
              subtitle: Text(device.address, style: const TextStyle(color: Colors.white54)),
              trailing: isConnecting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                icon: const Icon(Icons.link, color: Colors.lightBlueAccent),
                onPressed: () async => await app.tryConnect(device.address, device.name ?? "Cihaz"),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGearSelection(AppState app) {
    final gears = ['BOŞ', '1', '2', '3', '4', '5', '6', '7', 'R'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 4,
        childAspectRatio: 1.3,
      ),
      itemCount: gears.length,
      itemBuilder: (context, index) {
        final gear = gears[index];
        final isSelected = app.gear.toString() == gear;
        return ElevatedButton(
          onPressed: () => app.sendCommand('V${gear == 'BOŞ' ? '0' : gear}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: isSelected ? Colors.blueAccent : Colors.transparent, width: 1.5),
            ),
          ),
          child: Text(gear, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        );
      },
    );
  }
}