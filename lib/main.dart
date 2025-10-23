import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/main_home.dart';       // 🔹 sekmeli ana ekran (Home/Test/Log)
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appState = AppState(mockMode: true);
  await appState.loadTestsFromLocal();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => appState),
      ],
      child: const MyApp(),
    ),
  );
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