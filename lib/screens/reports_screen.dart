import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'rapor_detay_ekrani.dart';
import 'package:intl/intl.dart';

class RaporlarEkrani extends StatelessWidget {
  const RaporlarEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context); // TestProvider yerine AppState

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Raporlar',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF003366), Color(0xFF004C99), Color(0xFF001F3F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView.builder(
          itemCount: app.completedTests.length,
          itemBuilder: (context, index) {
            final t = app.completedTests[index];
            return ListTile(
              title: Text(
                t.testAdi,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '${t.formattedDate} • ${t.sonuc}',
                style: const TextStyle(color: Colors.white70),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RaporDetayEkrani(test: t),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
