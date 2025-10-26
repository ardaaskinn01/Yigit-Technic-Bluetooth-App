import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/main_home.dart';       // 🔹 sekmeli ana ekran (Home/Test/Log)
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Önce izinleri kontrol et
  await checkBluetoothPermissions();

  final appState = AppState(mockMode: false);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => appState),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> checkBluetoothPermissions() async {
  // Bluetooth tarama izni
  if (await Permission.bluetoothScan.isDenied) {
    await Permission.bluetoothScan.request();
  }

  // Bluetooth bağlantı izni
  if (await Permission.bluetoothConnect.isDenied) {
    await Permission.bluetoothConnect.request();
  }

  // Konum izni (bazı cihazlarda gerekli)
  if (await Permission.location.isDenied) {
    await Permission.location.request();
  }

  // Reddedildiyse tekrar dene
  if (!await Permission.bluetoothScan.isGranted ||
      !await Permission.bluetoothConnect.isGranted ||
      !await Permission.location.isGranted) {
    print("⚠️ Bluetooth izinleri eksik!");
  } else {
    print("✅ Bluetooth izinleri verildi.");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    return MaterialApp(
      title: 'DQ200 Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),
      initialRoute: '/',
      routes: {
        // 🔹 Artık Home yerine MainHomeScreen açılıyor
        '/': (_) => MainHomeScreen(),
        '/reports': (_) => const RaporlarEkrani(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }


}