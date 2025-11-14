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

  // ✅ Önce izinleri kontrol et
  await checkBluetoothPermissions();

  // ✅ Veritabanını başlat
  await _initializeDatabase();

  // ✅ AppState'i oluştur ve INITIALIZE ET
  final appState = AppState(mockMode: false);
  await appState.initializeApp(); // ⭐ BU SATIRI EKLEYİN

  runApp(
    Provider<AppState>.value(
      value: appState,
      child: const MyApp(),
    ),
  );
}

// ✅ Veritabanı başlatma (DÜZELTİLMİŞ)
Future<void> _initializeDatabase() async {
  try {
    final dbService = DatabaseService();
    await dbService.database; // Database'i aç

    // Tablo yoksa kontrol et
    final tableExists = await dbService.isTableExists();
    if (!tableExists) {
      print('⚠️ Tablo bulunamadı, yeniden oluşturulacak...');
      // ⭐ DÜZELTİLDİ: Sadece veritabanını yeniden başlat
      await dbService.recreateTable(); // Bu metodu DatabaseService'e ekleyeceğiz
    }

    // Basit test sayısı kontrolü
    final tests = await dbService.getTests();
    print('📊 Veritabanında ${tests.length} test kaydı bulundu');

  } catch (e) {
    print('❌ Veritabanı başlatma hatası: $e');
    // Hata durumunda database'i resetle
    await _resetDatabase();
  }
}

// ⭐ YENİ: Database resetleme fonksiyonu
Future<void> _resetDatabase() async {
  try {
    final dbService = DatabaseService();
    final db = await dbService.database;
    await db.close();
    await deleteDatabase(join(await getDatabasesPath(), 'mekatronik_tests.db'));
    print('✅ Veritabanı resetlendi');
  } catch (e) {
    print('❌ Veritabanı resetleme hatası: $e');
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
      // ⭐ YENİ: Navigator observer ekleyerek route değişikliklerini takip et
      navigatorObservers: [RouteObserver<ModalRoute<void>>()],
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