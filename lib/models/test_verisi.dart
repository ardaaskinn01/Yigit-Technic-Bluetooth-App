class TestVerisi {
  String testAdi;
  DateTime tarih;
  int score;
  List<String> lines; // ham log
  double faz0Sure;
  double faz1Pompa;
  double faz2Pompa;
  Map<String, double> faz3Vitesler;
  double faz4Pompa;

  TestVerisi({
    required this.testAdi,
    required this.tarih,
    required this.score,
    required this.lines,
    required this.faz0Sure,
    required this.faz1Pompa,
    required this.faz2Pompa,
    required this.faz3Vitesler,
    required this.faz4Pompa,
  });
}