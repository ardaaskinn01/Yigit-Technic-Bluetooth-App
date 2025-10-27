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
  double _temizlemeDegeri = 0.1; // Varsayılan değer: 0.1 saniye
  final List<double> _temizlemeSecenekleri = [0.1, 0.5, 1.0];
  bool _temizlemeAktif = false;

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
              app: app, // AppState'i parametre olarak veriyoruz
            ),
            const SizedBox(height: 12),
            _buildPumpControls(app),
            const SizedBox(height: 8),
            _buildValfSection(app),
            const SizedBox(height: 8),
            _buildTestModeControls(app),
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

                  // 🔹 Valf Temizleme Bölümü - YENİ EKLENDİ
                  // State değişkeni ekleyin (class _HomeScreenState içinde)

                  // Valf Temizleme Bölümü - GÜNCELLENDİ
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _temizlemeAktif
                                ? Colors.redAccent.withOpacity(0.5)
                                : Colors.greenAccent.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _temizlemeAktif
                                  ? Icons.cleaning_services
                                  : Icons.cleaning_services_outlined,
                              color:
                                  _temizlemeAktif
                                      ? Colors.redAccent
                                      : Colors.greenAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "VALF TEMİZLEME",
                              style: TextStyle(
                                color:
                                    _temizlemeAktif
                                        ? Colors.redAccent
                                        : Colors.greenAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Süre Seçimi (sadece temizleme aktif değilken göster)
                        if (!_temizlemeAktif) ...[
                          const Text(
                            "Temizleme Süresi:",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Kaydırma Çubuğu - Sadece 0.1, 0.5, 1.0 değerleri
                          Slider(
                            value: _temizlemeDegeri,
                            min: 0.1,
                            max: 1.0,
                            divisions: 2, // Sadece 3 pozisyon: 0.1, 0.5, 1.0
                            label: "${_temizlemeDegeri.toStringAsFixed(1)}s",
                            activeColor: Colors.greenAccent,
                            inactiveColor: Colors.greenAccent.withOpacity(0.3),
                            onChanged: (value) {
                              setState(() {
                                // Slider'ı en yakın değere yuvarla (0.1, 0.5 veya 1.0)
                                if (value < 0.3) {
                                  _temizlemeDegeri = 0.1;
                                } else if (value < 0.75) {
                                  _temizlemeDegeri = 0.5;
                                } else {
                                  _temizlemeDegeri = 1.0;
                                }
                              });
                            },
                          ),

                          // Değer göstergesi
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "0.1s",
                                style: TextStyle(
                                  color:
                                      _temizlemeDegeri == 0.1
                                          ? Colors.greenAccent
                                          : Colors.white54,
                                  fontSize: 10,
                                  fontWeight:
                                      _temizlemeDegeri == 0.1
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                              Text(
                                "0.5s",
                                style: TextStyle(
                                  color:
                                      _temizlemeDegeri == 0.5
                                          ? Colors.greenAccent
                                          : Colors.white54,
                                  fontSize: 10,
                                  fontWeight:
                                      _temizlemeDegeri == 0.5
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                              Text(
                                "1.0s",
                                style: TextStyle(
                                  color:
                                      _temizlemeDegeri == 1.0
                                          ? Colors.greenAccent
                                          : Colors.white54,
                                  fontSize: 10,
                                  fontWeight:
                                      _temizlemeDegeri == 1.0
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ] else ...[
                          // Temizleme aktifken durum bilgisi
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.redAccent),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.timer,
                                  color: Colors.redAccent,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Aktif: ${_temizlemeDegeri.toStringAsFixed(1)}s",
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Başlat/Durdur Butonu
                        // Başlat/Durdur Butonu - MERKEZDE
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (!_temizlemeAktif) {
                                // BAŞLAT
                                final msDegeri = (_temizlemeDegeri * 1000).round();
                                app.sendCommand("TEMIZAC $msDegeri");

                                setState(() {
                                  _temizlemeAktif = true;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Valf temizleme başlatıldı: ${_temizlemeDegeri.toStringAsFixed(1)}s",
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              } else {
                                // DURDUR
                                app.sendCommand("TEMIZKAPAT");

                                setState(() {
                                  _temizlemeAktif = false;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Valf temizleme durduruldu"),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: Icon(
                              _temizlemeAktif ? Icons.stop : Icons.cleaning_services,
                              color: Colors.white,
                              size: 16,
                            ),
                            label: Text(
                              _temizlemeAktif ? "DURDUR" : "BAŞLAT",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _temizlemeAktif
                                  ? Colors.redAccent.withOpacity(0.8)
                                  : Colors.greenAccent.withOpacity(0.8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

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

  // Diğer metodlar aynı kalacak...
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
    final isDisabled = !app.isK1K2Mode;

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
      onPressed: isDisabled ? null : () => app.toggleValve(valve),
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

  Widget _buildTestModeControls(AppState app) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "OTOMATİK VİTES TEST MODLARI",
            style: TextStyle(
              color: Colors.amber,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // ✅ AKTİF MOD BİLGİSİ
          if (app.isTestModeActive && app.currentTestMode != 8)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Column(
                children: [
                  Text(
                    "AKTİF: Test Mod ${app.currentTestMode}",
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    app.testModeDescriptions[app.currentTestMode] ?? "",
                    style: const TextStyle(color: Colors.amber, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    "Vites: ${app.gear} | Pompa: ${app.pumpOn ? 'AÇIK' : 'KAPALI'}",
                    style: const TextStyle(color: Colors.amber, fontSize: 11),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // ✅ TÜM MOD BUTONLARI HER ZAMAN GÖSTERİLSİN
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1.2,
            ),
            itemCount: 8,
            itemBuilder: (context, index) {
              int mode = index + 1;
              bool isActive = app.currentTestMode == mode;
              bool isTestRunning = app.isTestModeActive && app.currentTestMode != 8;
              bool isTest7 = mode == 7;
              bool isTest8 = mode == 8;

              // ✅ BUTON DAVRANIŞI:
              // - Test çalışmıyorsa: Tüm butonlar tıklanabilir
              // - Test çalışıyorsa (1-7): Sadece T8 tıklanabilir, diğerleri devre dışı
              // - T8 her zaman tıklanabilir (durdurma butonu)
              bool isButtonEnabled = !isTestRunning || isTest8 || isActive;

              Color activeColor = isTest7
                  ? Colors.blueAccent
                  : isTest8
                  ? Colors.redAccent
                  : Colors.amber;
              Color inactiveColor = isTest7
                  ? Colors.blue
                  : isTest8
                  ? Colors.red
                  : Colors.blueGrey.withOpacity(0.7);

              // Buton rengini belirle
              Color buttonColor;
              if (!isButtonEnabled) {
                buttonColor = Colors.grey.withOpacity(0.3); // Devre dışı rengi
              } else if (isActive) {
                buttonColor = activeColor.withOpacity(0.9);
              } else {
                buttonColor = inactiveColor;
              }

              return Tooltip(
                message: !isButtonEnabled
                    ? "Test devam ediyor - Durdurmak için T8'e basın"
                    : app.testModeDescriptions[mode] ?? "",
                child: ElevatedButton(
                  onPressed: isButtonEnabled
                      ? () {
                    if (isActive) {
                      // Aktif modu durdur (sadece T8 için)
                      if (isTest8) {
                        app.stopTestMode();
                      }
                    } else {
                      // Yeni mod başlat veya T8 ile durdur
                      if (isTest8 && app.isTestModeActive) {
                        app.stopTestMode();
                      } else {
                        app.startTestMode(mode);
                      }
                    }
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(
                        color: isActive ? activeColor : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "T$mode",
                        style: TextStyle(
                          color: isButtonEnabled ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        isTest8 ? "ACİL" : "${app.testModeDelays[mode]}ms",
                        style: TextStyle(
                          color: isButtonEnabled ? Colors.white70 : Colors.grey,
                          fontSize: isTest8 ? 8 : 9,
                        ),
                      ),
                      if (isTest7)
                        Text(
                          "SÖKME",
                          style: TextStyle(
                            color: isButtonEnabled ? Colors.white : Colors.grey,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (isTest8)
                        Text(
                          "DURDUR",
                          style: TextStyle(
                            color: isButtonEnabled ? Colors.white : Colors.grey,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ✅ TEST ÇALIŞIRKEN BİLGİ MESAJI
          if (app.isTestModeActive && app.currentTestMode != 8)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Text(
                "Test Mod ${app.currentTestMode} çalışıyor - Durdurmak için T8 (ACİL DURDUR) butonunu kullanın",
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
