class TestModuRaporu {
  final DateTime tarih;
  final int testModu;
  final double minBasinc;
  final double maxBasinc;
  final double ortalamaBasinc;
  final int toplamPompaCalismaSuresiSn;
  final int dusukBasincSayisi;
  final int toplamDusukBasincSuresiSn;
  final int toplamVitesGecisSayisi;
  final Map<String, int> vitesGecisleri;

  TestModuRaporu({
    required this.tarih,
    required this.testModu,
    required this.minBasinc,
    required this.maxBasinc,
    required this.ortalamaBasinc,
    required this.toplamPompaCalismaSuresiSn,
    required this.dusukBasincSayisi,
    required this.toplamDusukBasincSuresiSn,
    required this.toplamVitesGecisSayisi,
    required this.vitesGecisleri,
  });

  String get formattedDate {
    return '${tarih.day}.${tarih.month}.${tarih.year} ${tarih.hour}:${tarih.minute}';
  }

  String get pompaSureFormatted {
    final dakika = toplamPompaCalismaSuresiSn ~/ 60;
    final saniye = toplamPompaCalismaSuresiSn % 60;
    return '${dakika}dk ${saniye}sn';
  }

  String get dusukBasincSureFormatted {
    return '${toplamDusukBasincSuresiSn}sn';
  }

  Map<String, dynamic> toJson() => {
    'tarih': tarih.toIso8601String(),
    'testModu': testModu,
    'minBasinc': minBasinc,
    'maxBasinc': maxBasinc,
    'ortalamaBasinc': ortalamaBasinc,
    'toplamPompaCalismaSuresiSn': toplamPompaCalismaSuresiSn,
    'dusukBasincSayisi': dusukBasincSayisi,
    'toplamDusukBasincSuresiSn': toplamDusukBasincSuresiSn,
    'toplamVitesGecisSayisi': toplamVitesGecisSayisi,
    'vitesGecisleri': vitesGecisleri,
  };

  factory TestModuRaporu.fromJson(Map<String, dynamic> json) {
    return TestModuRaporu(
      tarih: DateTime.parse(json['tarih']),
      testModu: json['testModu'],
      minBasinc: json['minBasinc'].toDouble(),
      maxBasinc: json['maxBasinc'].toDouble(),
      ortalamaBasinc: json['ortalamaBasinc'].toDouble(),
      toplamPompaCalismaSuresiSn: json['toplamPompaCalismaSuresiSn'],
      dusukBasincSayisi: json['dusukBasincSayisi'],
      toplamDusukBasincSuresiSn: json['toplamDusukBasincSuresiSn'],
      toplamVitesGecisSayisi: json['toplamVitesGecisSayisi'],
      vitesGecisleri: Map<String, int>.from(json['vitesGecisleri']),
    );
  }
}