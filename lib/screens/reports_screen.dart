import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_verisi.dart';
import '../providers/app_state.dart';
import 'rapor_detay_ekrani.dart';
import 'package:intl/intl.dart';

class RaporlarEkrani extends StatelessWidget {
  const RaporlarEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);

    // ✅ GELİŞTİRİLMİŞ DEBUG: Detaylı bilgi
    print('📋 [REPORTS DEBUG] =================================');
    print('   - Toplam test sayısı: ${app.completedTests.length}');
    print('   - Veritabanı test sayısı: ${app.completedTests.length}');

    // Testleri ID'ye göre sırala ve debug et
    final sortedTests =
    app.completedTests.toList()..sort((a, b) => b.tarih.compareTo(a.tarih));

    print('   - Sıralanmış testler:');
    for (int i = 0; i < sortedTests.length; i++) {
      print(
        '     ${i + 1}. ${sortedTests[i].testAdi} - ${sortedTests[i].tarih} - ID: ${sortedTests[i].id}',
      );
    }

    // Testleri ters çevir (en son test en yukarıda)
    final reversedTests = sortedTests; // Zaten sıralı, ters çevirmeye gerek yok
    print('📋 [REPORTS] Gösterilecek test sayısı: ${reversedTests.length}');
    print('📋 [REPORTS DEBUG] =================================');

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
        actions: [
          // ✅ VERİTABANI BİLGİ BUTONU
          IconButton(
            icon: const Icon(Icons.info, color: Colors.white),
            tooltip: 'Veritabanı Bilgisi',
            onPressed: () => _showDatabaseInfo(context, app),
          ),
          if (app.completedTests.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              tooltip: 'Tüm Raporları Sil',
              onPressed: () => _showDeleteConfirmationDialog(context, app),
            ),
          // ✅ GELİŞTİRİLMİŞ YENİLE BUTONU
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Yenile',
            onPressed: () async {
              print('🔄 Manuel yenileme başlatıldı');

              // Veritabanından yeniden yükle
              await app.loadTestsFromLocal();

              // State'i güncelle
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${app.completedTests.length} test yüklendi'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF003366), Color(0xFF004C99), Color(0xFF001F3F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: reversedTests.isEmpty
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Henüz test raporu bulunmuyor',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 20),
            // ✅ GELİŞTİRİLMİŞ MANUEL YÜKLEME
            Column(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    print('🔄 Testleri yeniden yükle butonu tıklandı');
                    await app.loadTestsFromLocal();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${app.completedTests.length} test yüklendi',
                          ),
                          backgroundColor: app.completedTests.isEmpty
                              ? Colors.orange
                              : Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('Testleri Yeniden Yükle'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _showDatabaseInfo(context, app),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                  ),
                  child: const Text('Veritabanı Bilgisi'),
                ),
              ],
            ),
          ],
        )
            : ListView.separated(
          itemCount: reversedTests.length,
          separatorBuilder: (context, index) => const Divider(
            color: Colors.white24,
            height: 1,
            thickness: 1,
          ),
          itemBuilder: (context, index) {
            final t = reversedTests[index];
            print(
              '📋 [REPORTS] Gösterilen test: ${t.testAdi} - ${t.tarih}',
            );
            return _buildTestItem(context, t, app);
          },
        ),
      ),
    );
  }

  // ✅ DÜZELTİLDİ: Veritabanı bilgisi göster - async metod
  void _showDatabaseInfo(BuildContext context, AppState app) async {
    try {
      final dbInfo = await app.getDatabaseInfo();
      final tableExists = await app.isTableExists();

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Veritabanı Bilgisi'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Toplam Test: ${dbInfo['totalTests']}'),
                Text('Son Test: ${dbInfo['latestTestName'] ?? "YOK"}'),
                if (dbInfo['latestTestDate'] != null)
                  Text(
                    'Son Test Tarihi: ${DateFormat('dd.MM.yyyy HH:mm').format(dbInfo['latestTestDate']!)}',
                  ),
                const SizedBox(height: 10),
                Text('UI Liste: ${app.completedTests.length} test'),
                const SizedBox(height: 10),
                Text('Tablo Var Mı: ${tableExists ? "EVET" : "HAYIR"}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('❌ Veritabanı bilgisi alma hatası: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veritabanı bilgisi alınamadı: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTestItem(BuildContext context, dynamic t, AppState app) {
    return Dismissible(
      key: Key('${t.testAdi}_${t.tarih.millisecondsSinceEpoch}'),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteSingleDialog(context, t.testAdi);
      },
      onDismissed: (direction) {
        _deleteSingleTest(context, app, t);
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getStatusColor(t.sonuc),
            shape: BoxShape.circle,
          ),
          child: Icon(_getStatusIcon(t.sonuc), color: Colors.white, size: 20),
        ),
        title: Text(
          t.testAdi,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              DateFormat('dd.MM.yyyy HH:mm').format(t.tarih),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  'Puan: ${t.puan}/100',
                  style: TextStyle(
                    color: _getScoreColor(t.puan),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  t.sonuc,
                  style: TextStyle(
                    color: _getStatusColor(t.sonuc),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.white.withOpacity(0.7),
          size: 16,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RaporDetayEkrani(test: t)),
        ),
      ),
    );
  }

  Color _getStatusColor(String sonuc) {
    switch (sonuc) {
      case '✅ MÜKEMMEL':
        return Colors.green;
      case '⚙️ İYİ':
        return Colors.lightGreen;
      case '⚠️ ORTA':
        return Colors.orange;
      case '❌ ZAYIF':
        return Colors.red;
      case 'TAM TEST':
        return Colors.blue;
      case 'KISMI TEST':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Color _getScoreColor(int puan) {
    if (puan >= 90) return Colors.green;
    if (puan >= 75) return Colors.lightGreen;
    if (puan >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _getStatusIcon(String sonuc) {
    switch (sonuc) {
      case '✅ MÜKEMMEL':
        return Icons.check_circle;
      case '⚙️ İYİ':
        return Icons.thumb_up;
      case '⚠️ ORTA':
        return Icons.warning;
      case '❌ ZAYIF':
        return Icons.error;
      case 'TAM TEST':
        return Icons.assignment_turned_in;
      case 'KISMI TEST':
        return Icons.assignment;
      default:
        return Icons.help;
    }
  }

  Future<bool> _showDeleteSingleDialog(
      BuildContext context,
      String testName,
      ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Raporu Sil'),
        content: Text(
          '"$testName" raporunu silmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _showDeleteConfirmationDialog(BuildContext context, AppState app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tüm Raporları Sil'),
        content: const Text(
          'Tüm test raporlarını silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              _deleteAllTests(context, app);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Tümünü Sil'),
          ),
        ],
      ),
    );
  }

  void _deleteSingleTest(
      BuildContext context,
      AppState app,
      TestVerisi test,
      ) async {
    try {
      await app.deleteTest(test);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${test.testAdi}" raporu silindi'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Silme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteAllTests(BuildContext context, AppState app) async {
    try {
      await app.clearTests();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tüm raporlar silindi'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Silme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}