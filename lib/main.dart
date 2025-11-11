import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/main_home.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'services/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Önce izinleri kontrol et
  await checkBluetoothPermissions();

  // ✅ Veritabanını başlat
  await _initializeDatabase();

  // ✅ AppState'i oluştur
  final appState = AppState(mockMode: false);

  // ✅ Testleri veritabanından yükle (async olarak devam et)
  _loadInitialData(appState);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => appState),
      ],
      child: const MyApp(),
    ),
  );
}

// ✅ Veritabanı başlatma (basitleştirilmiş)
Future<void> _initializeDatabase() async {
  try {
    final dbService = DatabaseService();
    await dbService.database; // Database'i aç

    // Tablo var mı kontrol et
    final tableExists = await dbService.isTableExists();
    print('✅ SQLite veritabanı başlatıldı - Tablo mevcut: $tableExists');

    // Basit test sayısı kontrolü
    final tests = await dbService.getTests();
    print('📊 Veritabanında ${tests.length} test kaydı bulundu');

  } catch (e) {
    print('❌ Veritabanı başlatma hatası: $e');
  }
}

// ✅ Async veri yükleme - uygulamanın başlamasını beklemez
void _loadInitialData(AppState appState) async {
  try {
    await appState.loadTestsFromLocal();
    print('✅ Başlangıç verileri yüklendi: ${appState.completedTests.length} test');
  } catch (e) {
    print('❌ Başlangıç veri yükleme hatası: $e');
  }
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
    return MaterialApp(
      title: 'DQ200 Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => MainHomeScreen(),
        '/reports': (_) => const RaporlarEkrani(),
        '/settings': (_) => const SettingsScreen(),
      },
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: 1.0,
          ),
          child: child!,
        );
      },
    );
  }
}