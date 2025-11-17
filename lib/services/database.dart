import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/test_verisi.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      String path = join(await getDatabasesPath(), 'mekatronik_tests.db');
      print('[DATABASE] Veritabanı yolu: $path');

      // Dizin erişimini test et
      final databaseDir = await getDatabasesPath();
      print('[DATABASE] Dizin erişilebilir: $databaseDir');

      return await openDatabase(
        path,
        version: 1,
        onCreate: _createDatabase,
        onOpen: (db) {
          print('[DATABASE] Veritabanı başarıyla açıldı');
        },
      );
    } catch (e) {
      print('[DATABASE] ❌ Veritabanı başlatma hatası: $e');

      // Daha spesifik hata mesajları
      if (e.toString().contains('permission') || e.toString().contains('izin')) {
        print('[DATABASE] ⚠️ STORAGE İZİN HATASI! Lütfen uygulama izinlerini kontrol edin.');
      }

      rethrow;
    }
  }

  Future<void> createDatabase(Database db, int version) async {
    await _createDatabase(db, version);
  }

  Future<void> _createDatabase(Database db, int version) async {
    print('[DATABASE] Tablo oluşturuluyor...');
    await db.execute('''
    CREATE TABLE tests(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      testAdi TEXT NOT NULL,
      tarih INTEGER NOT NULL,
      minBasinc REAL NOT NULL,
      maxBasinc REAL NOT NULL,
      toplamPompaSuresi REAL NOT NULL,
      puan INTEGER NOT NULL,
      sonuc TEXT NOT NULL,
      fazPuanlari TEXT,
      DetayliFazVerileri TEXT
    )
  ''');
    print('[DATABASE] Tablo başarıyla oluşturuldu');
  }

  // Test ekleme
  Future<int> insertTest(TestVerisi test) async {
    final db = await database;

    print('[DATABASE] Test kaydediliyor: ${test.testAdi}');
    print('[DATABASE] Test verisi: ${test.toDbMap()}');

    try {
      final id = await db.insert('tests', test.toDbMap());
      print('[DATABASE] ✅ Test kaydedildi: ${test.testAdi} (ID: $id)');

      // ✅ GÜÇLENDİRİLMİŞ DOĞRULAMA
      final verify = await db.query('tests', where: 'id = ?', whereArgs: [id]);
      if (verify.isEmpty) {
        print('[DATABASE] ❌ HATA: Test kaydı doğrulanamadı!');
        throw Exception('Test kaydı doğrulanamadı');
      } else {
        print('[DATABASE] ✅ Test kaydı doğrulandı - ID: $id');

        // Kayıt detaylarını logla
        final record = verify.first;
        print('[DATABASE] 📋 Kayıt detayları:');
        print('   - Test Adı: ${record['testAdi']}');
        print('   - Puan: ${record['puan']}');
        print('   - Tarih: ${DateTime.fromMillisecondsSinceEpoch(record['tarih'] as int)}');
      }

      return id;
    } catch (e) {
      print('[DATABASE] ❌ Kayıt hatası: $e');

      // Hatayı daha detaylı logla
      if (e is DatabaseException) {
        print('[DATABASE] ❌ DatabaseException: ${e.toString()}');
        print('[DATABASE] ❌ Result: ${e.getResultCode()}');
      }

      rethrow;
    }
  }

  // Tüm testleri getir
  Future<List<TestVerisi>> getTests() async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> maps = await db.query(
          'tests',
          orderBy: 'tarih DESC',
          limit: 150
      );

      print('[DATABASE] 📊 ${maps.length} test yüklendi');

      // Debug için tüm kayıtları göster
      for (int i = 0; i < maps.length; i++) {
        print('[DATABASE]   ${i + 1}. ID:${maps[i]['id']} - ${maps[i]['testAdi']}');
      }

      return List.generate(maps.length, (i) {
        return TestVerisi.fromDbMap(maps[i]);
      });
    } catch (e) {
      print('[DATABASE] ❌ Yükleme hatası: $e');
      return [];
    }
  }

  Future<void> recreateTable() async {
    final db = await database;
    try {
      await db.execute('DROP TABLE IF EXISTS tests');
      await _createDatabase(db, 1);
      print('[DATABASE] Tablo başarıyla yeniden oluşturuldu');

      // Tablo oluştuktan sonra kontrol et
      final exists = await isTableExists();
      print('[DATABASE] Tablo kontrolü: ${exists ? "VAR" : "YOK"}');

      if (exists) {
        // Tablo sütunlarını kontrol et
        final columns = await db.rawQuery('PRAGMA table_info(tests)');
        print('[DATABASE] Tablo sütunları:');
        for (final column in columns) {
          print('   - ${column['name']} (${column['type']})');
        }
      }
    } catch (e) {
      print('[DATABASE] ❌ Tablo yeniden oluşturma hatası: $e');
      rethrow;
    }
  }

  // Test silme
  Future<void> deleteTest(int id) async {
    final db = await database;
    await db.delete('tests', where: 'id = ?', whereArgs: [id]);
    print('[DATABASE] Test silindi: ID $id');
  }

  // Tüm testleri silme
  Future<void> deleteAllTests() async {
    final db = await database;
    await db.delete('tests');
    print('[DATABASE] Tüm testler silindi');
  }

  // ✅ VERİTABANI BİLGİLERİNİ GETİR
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;

    try {
      print('[DATABASE] Veritabanı bilgisi alınıyor...');

      // Toplam test sayısı
      final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM tests');
      final totalTests = countResult.first['count'] as int? ?? 0;

      // En son test tarihi
      final latestResult = await db.rawQuery('''
        SELECT testAdi, tarih FROM tests 
        ORDER BY tarih DESC 
        LIMIT 1
      ''');

      String? latestTestName;
      DateTime? latestTestDate;

      if (latestResult.isNotEmpty) {
        latestTestName = latestResult.first['testAdi'] as String?;
        final timestamp = latestResult.first['tarih'] as int?;
        if (timestamp != null) {
          latestTestDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      }

      // Tüm tablo bilgisi
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");

      print('[DATABASE] 📊 Veritabanı bilgisi:');
      print('   - Toplam test: $totalTests');
      print('   - Son test: $latestTestName');
      print('   - Son test tarihi: $latestTestDate');
      print('   - Tablolar: ${tables.map((t) => t['name']).toList()}');

      return {
        'totalTests': totalTests,
        'latestTestName': latestTestName,
        'latestTestDate': latestTestDate,
        'tables': tables.map((t) => t['name'] as String).toList(),
      };
    } catch (e) {
      print('[DATABASE] ❌ Veritabanı bilgisi alma hatası: $e');
      return {
        'totalTests': 0,
        'latestTestName': null,
        'latestTestDate': null,
        'tables': [],
      };
    }
  }

  // ✅ TABLO VAR MI KONTROL ET
  Future<bool> isTableExists() async {
    final db = await database;
    try {
      final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='tests'"
      );
      final exists = result.isNotEmpty;
      print('[DATABASE] Tablo kontrolü: ${exists ? "VAR" : "YOK"}');
      return exists;
    } catch (e) {
      print('[DATABASE] ❌ Tablo kontrol hatası: $e');
      return false;
    }
  }

  // ✅ VERİTABANI YOLUNU GETİR (Debug için)
  Future<String> getDatabasePath() async {
    final db = await database;
    return db.path;
  }
}