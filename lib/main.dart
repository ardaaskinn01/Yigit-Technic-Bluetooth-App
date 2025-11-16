import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'providers/app_state.dart';
import 'screens/main_home.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'services/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ ÖNCE: İzinleri kontrol et
  await checkBluetoothPermissions();

  // ✅ SONRA: AppState'i oluştur ve initialize et
  final appState = AppState(mockMode: false);
  await appState.initializeApp(); // ⭐ BU ÖNCE GELMELİ

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
  // Bluetooth izinleri
  if (await Permission.bluetoothScan.isDenied) {
    await Permission.bluetoothScan.request();
  }
  if (await Permission.bluetoothConnect.isDenied) {
    await Permission.bluetoothConnect.request();
  }
  if (await Permission.location.isDenied) {
    await Permission.location.request();
  }

  // ✅ YENİ: Storage izinleri
  if (await Permission.storage.isDenied) {
    await Permission.storage.request();
  }
  if (await Permission.manageExternalStorage.isDenied) {
    await Permission.manageExternalStorage.request();
  }

  // İzin durumunu kontrol et
  final bluetoothGranted = await Permission.bluetoothConnect.isGranted;
  final storageGranted = await Permission.storage.isGranted;

  print("✅ Bluetooth izni: $bluetoothGranted");
  print("✅ Storage izni: $storageGranted");

  if (!bluetoothGranted || !storageGranted) {
    print("⚠️ Gerekli izinler eksik!");
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