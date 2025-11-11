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
    String path = join(await getDatabasesPath(), 'mekatronik_tests.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
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
        fazPuanlari TEXT
      )
    ''');
  }

  // Test ekleme
  Future<int> insertTest(TestVerisi test) async {
    final db = await database;
    final id = await db.insert('tests', test.toDbMap());

    print('[DATABASE] Test kaydedildi: ${test.testAdi} (ID: $id)');

    // ✅ YENİ: Kayıt sonrası test et
    final verify = await db.query('tests', where: 'id = ?', whereArgs: [id]);
    if (verify.isEmpty) {
      print('[DATABASE HATA] Test kaydı doğrulanamadı!');
    } else {
      print('[DATABASE] Test kaydı doğrulandı');
    }

    return id;
  }

  // Tüm testleri getir
  Future<List<TestVerisi>> getTests() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tests', orderBy: 'tarih DESC');

    return List.generate(maps.length, (i) {
      return TestVerisi.fromDbMap(maps[i]);
    });
  }

  // Test silme
  Future<void> deleteTest(int id) async {
    final db = await database;
    await db.delete('tests', where: 'id = ?', whereArgs: [id]);
  }

  // Tüm testleri silme
  Future<void> deleteAllTests() async {
    final db = await database;
    await db.delete('tests');
  }

  // ✅ YENİ: Veritabanı bilgilerini getir
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;

    try {
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

      return {
        'totalTests': totalTests,
        'latestTestName': latestTestName,
        'latestTestDate': latestTestDate,
      };
    } catch (e) {
      print('Veritabanı bilgisi alma hatası: $e');
      return {
        'totalTests': 0,
        'latestTestName': null,
        'latestTestDate': null,
      };
    }
  }

  // ✅ YENİ: Tablo var mı kontrol et
  Future<bool> isTableExists() async {
    final db = await database;
    try {
      final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='tests'"
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

}