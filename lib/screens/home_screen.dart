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
            _buildK1K2Buttons(app), // 🔹 Yeni buton satırı
            const SizedBox(height: 8),
            K1K2SystemControl(
              value: app.isK1K2Mode,
              onChanged: (val) => app.setK1K2Mode(val),
            ),
            const SizedBox(height: 12),
            _buildPumpControls(app),
            const SizedBox(height: 8),
            _buildValfSection(app),
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
                      // 🔹 Piston Kaçağı testi
                      ElevatedButton.icon(
                        onPressed: () {
                          app.startPistonKacagiModu();
                        },
                        icon: const Icon(Icons.speed, color: Colors.white),
                        label: const Text(
                          "PİSTON KAÇAĞI TESTİ",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent.withOpacity(0.8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      // 🔹 Valf Temizleme
                      ElevatedButton.icon(
                        onPressed: () => app.startTemizlemeModu(),
                        icon: const Icon(
                          Icons.cleaning_services,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "VALF TEMİZLE",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent.withOpacity(0.8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 🧯 Alt satır: Sökme butonu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder:
                                (_) => AlertDialog(
                                  backgroundColor: const Color(0xFF003366),
                                  title: const Text(
                                    "Sökme Modu",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: const Text(
                                    "Bu işlem basıncı boşaltacaktır.\nEmin misiniz?",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, false),
                                      child: const Text("İptal"),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, true),
                                      child: const Text("Evet"),
                                    ),
                                  ],
                                ),
                          );
                          if (confirm == true) app.startSokmeModu();
                        },
                        icon: const Icon(
                          Icons.build_circle,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "SÖKME KONUMUNA GETİR",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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
        // Bağlantı durumu göstergesi
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                app.isConnected
                    ? Colors.green.withOpacity(0.2)
                    : app.isReconnecting
                    ? Colors.orange.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  app.isConnected
                      ? Colors.green
                      : app.isReconnecting
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                app.isConnected
                    ? Icons.bluetooth_connected
                    : app.isReconnecting
                    ? Icons.bluetooth_searching
                    : Icons.bluetooth_disabled,
                color:
                    app.isConnected
                        ? Colors.green
                        : app.isReconnecting
                        ? Colors.orange
                        : Colors.red,
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                app.isConnected
                    ? "BAĞLI"
                    : app.isReconnecting
                    ? "YENİDEN BAĞLANIYOR..."
                    : "BAĞLANTI KOPUK",
                style: TextStyle(
                  color:
                      app.isConnected
                          ? Colors.green
                          : app.isReconnecting
                          ? Colors.orange
                          : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),

        if (app.isConnected) ...[
          const Icon(
            Icons.bluetooth_connected,
            color: Colors.lightBlueAccent,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            "Bağlı: ${app.deviceName}",
            style: const TextStyle(color: Colors.white),
          ),
        ] else if (app.isScanning) ...[
          const CircularProgressIndicator(color: Colors.blueAccent),
          const SizedBox(height: 12),
          const Text(
            "Cihazlar taranıyor...",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          _buildDeviceList(app),
        ] else if (app.discoveredDevices.isNotEmpty) ...[
          const Text(
            "Bulunan cihazlar:",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          _buildDeviceList(app),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async => await app.initConnection(),
            icon: const Icon(Icons.refresh),
            label: const Text("Yeniden Tara"),
          ),
        ] else ...[
          Text(
            app.connectionMessage,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async => await app.initConnection(),
            icon: const Icon(Icons.bluetooth_searching, color: Colors.white),
            label: const Text(
              'Cihaz Ara / Bağlan',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ],
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
              () => app.sendCommand("A"),
            ),
            _buildControlButton(
              'Pompa Kapat',
              Icons.stop,
              Colors.redAccent,
              () => app.sendCommand("K"),
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
      children: const [PressureValveControls()],
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.bluetooth, color: Colors.blueAccent),
              title: Text(
                device.name ?? "Bilinmeyen Cihaz",
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                device.address,
                style: const TextStyle(color: Colors.white54),
              ),
              trailing:
                  isConnecting
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : IconButton(
                        icon: const Icon(
                          Icons.link,
                          color: Colors.lightBlueAccent,
                        ),
                        onPressed:
                            () async => await app.tryConnect(
                              device.address,
                              device.name ?? "Cihaz",
                            ),
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
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 2,
        childAspectRatio: 1.8,
      ),
      itemCount: gears.length,
      itemBuilder: (context, index) {
        final gear = gears[index];
        final isSelected = app.gear.toString() == gear;
        return ElevatedButton(
          onPressed: () => app.sendCommand('V${gear == 'BOŞ' ? '0' : gear}'),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isSelected ? Colors.blueAccent : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
          child: Text(
            gear,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  Widget _buildK1K2Buttons(AppState app) {
    final isDisabled = !app.isK1K2Mode; // false ise butonlar pasif olacak

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildValveButton(app, 'K1', isDisabled),
        _buildValveButton(app, 'K2', isDisabled),
      ],
    );
  }

  Widget _buildValveButton(AppState app, String valve, bool isDisabled) {
    final isActive = app.valveStates[valve] ?? false;

    return ElevatedButton(
      onPressed:
          isDisabled
              ? null // Pasifse buton tıklanamaz
              : () => app.toggleValve(valve),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isActive
                ? Colors.lightBlueAccent.withOpacity(0.8)
                : Colors.white.withOpacity(isDisabled ? 0.05 : 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isActive ? Colors.lightBlueAccent : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Text(
        valve,
        style: TextStyle(
          color: isDisabled ? Colors.white38 : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
