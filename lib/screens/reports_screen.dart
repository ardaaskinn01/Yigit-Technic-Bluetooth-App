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

    final reversedTests = app.testler.reversed.toList();

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
            colors: [Color(0xFF001F3F), Color(0xFF003366), Color(0xFF004C99)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: reversedTests.isEmpty
              ? const Center(
            child: Text(
              "Kaydedilmiş test yok",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reversedTests.length,
            itemBuilder: (context, index) {
              final test = reversedTests[index];
              return Card(
                color: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 6,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  title: Text(
                    test.testAdi,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(test.tarih),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white70,
                    size: 18,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RaporDetayEkrani(test: test), // test.toTestVerisi() yerine direkt test
                      ),
                    );
                  },
                  onLongPress: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Testi sil'),
                        content: const Text('Bu testi silmek istediğinizden emin misiniz?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
                        ],
                      ),
                    );
                    if (confirm ?? false) {
                      final originalIndex = app.testler.indexOf(test);
                      await app.deleteTest(originalIndex); // await ekledik
                    }
                  },
                ),
              );
            },
          )
        ),
      ),
    );
  }
}
