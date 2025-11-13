import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

enum PressureMode { mode42_52, mode42_60 }

class PressureMonitorWidget extends StatefulWidget {
  const PressureMonitorWidget({super.key});

  @override
  State<PressureMonitorWidget> createState() => _PressureMonitorWidgetState();
}

class _PressureMonitorWidgetState extends State<PressureMonitorWidget> {
  PressureMode currentMode = PressureMode.mode42_60;
  double minPressure = 42.0;
  List<double> pressureHistory = [];
  Timer? _timer;

  // Kaydırma için değişkenler
  double _currentScrollPosition = 0.0;
  bool _isScrolling = false;
  final int _maxHistoryPoints = 2250;
  final int _visiblePoints = 150;

  // 🆕 YENİ: Ölçeklendirme fonksiyonu
  double _transformY(double originalY) {
    if (originalY <= 20) {
      // 0-20 -> 0-0.1 arası
      return (originalY / 20) * 0.1;
    } else if (originalY <= 40) {
      // 20-40 -> 0.1-0.3 arası
      return 0.1 + ((originalY - 20) / 20) * 0.2;
    } else if (originalY <= 60) {
      // 40-60 -> 0.3-0.8 arası
      return 0.3 + ((originalY - 40) / 20) * 0.5;
    } else {
      // 60-70 -> 0.8-1.0 arası
      return 0.8 + ((originalY - 60) / 10) * 0.2;
    }
  }

  // 🆕 YENİ: Ters dönüşüm fonksiyonu (tooltip için)
  double _inverseTransformY(double transformedY) {
    if (transformedY <= 0.1) {
      // 0-0.1 -> 0-20
      return (transformedY / 0.1) * 20;
    } else if (transformedY <= 0.3) {
      // 0.1-0.3 -> 20-40
      return 20 + ((transformedY - 0.1) / 0.2) * 20;
    } else if (transformedY <= 0.8) {
      // 0.3-0.8 -> 40-60
      return 40 + ((transformedY - 0.3) / 0.5) * 20;
    } else {
      // 0.8-1.0 -> 60-70
      return 60 + ((transformedY - 0.8) / 0.2) * 10;
    }
  }

  // Kaydırma için değişkenler
  double _lastDragX = 0.0;

  @override
  void initState() {
    super.initState();

    // 🆕 DEĞİŞTİ: Saniyede 5 kez güncelleme (200ms aralıklarla)
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final app = context.read<AppState>();

      if (app.pressure > 0) {
        setState(() {
          double actualPressure = app.pressure;

          // Tüm geçmişi kaydet
          pressureHistory.add(actualPressure);

          // Maksimum geçmiş boyutunu kontrol et (5 dakika)
          if (pressureHistory.length > _maxHistoryPoints) {
            pressureHistory.removeAt(0);
          }

          // Otomatik olarak en sona kaydır (kullanıcı kaydırmıyorsa)
          if (!_isScrolling) {
            _currentScrollPosition = lerpDouble(
              _currentScrollPosition,
              pressureHistory.length.toDouble(),
              0.25, // Daha hızlı kaydırma
            )!;
          }
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().setPressureToggle(false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void togglePressureMode() {
    setState(() {
      if (currentMode == PressureMode.mode42_60) {
        currentMode = PressureMode.mode42_52;
        minPressure = 42.0;
        context.read<AppState>().setPressureToggle(true);
      } else {
        currentMode = PressureMode.mode42_60;
        minPressure = 42.0;
        context.read<AppState>().setPressureToggle(false);
      }
    });
  }

  // 🆕 YENİ: Zaman formatlama fonksiyonu
  String _formatTimeAgo(int dataIndex, int totalPoints) {
    int secondsAgo = ((totalPoints - 1 - dataIndex) / 5).round(); // 5 örnek/saniye
    if (secondsAgo == 0) {
      return 'Şimdi';
    } else if (secondsAgo < 60) {
      return '${secondsAgo}s';
    } else if (secondsAgo < 3600) {
      return '${secondsAgo ~/ 60}d';
    } else {
      return '${secondsAgo ~/ 3600}s';
    }
  }

  // 🆕 YENİ: Detaylı zaman formatı (tooltip için)
  String _formatDetailedTimeAgo(int dataIndex, int totalPoints) {
    int secondsAgo = ((totalPoints - 1 - dataIndex) / 5).round(); // 5 örnek/saniye
    if (secondsAgo == 0) {
      return 'Şimdi';
    } else if (secondsAgo < 60) {
      return '$secondsAgo saniye önce';
    } else if (secondsAgo < 3600) {
      int minutes = secondsAgo ~/ 60;
      int remainingSeconds = secondsAgo % 60;
      return '$minutes dakika ${remainingSeconds > 0 ? '$remainingSeconds saniye' : ''} önce'.trim();
    } else {
      int hours = secondsAgo ~/ 3600;
      int remainingMinutes = (secondsAgo % 3600) ~/ 60;
      return '$hours saat ${remainingMinutes > 0 ? '$remainingMinutes dakika' : ''} önce'.trim();
    }
  }

  // Kaydırılabilir grafik için spotlar - DÖNÜŞTÜRÜLMÜŞ Y değerleri
  List<FlSpot> _getChartSpots() {
    if (pressureHistory.isEmpty) return [];

    final spots = <FlSpot>[];

    // Görünür aralığı hesapla
    int startIndex = (_currentScrollPosition - _visiblePoints).clamp(0, pressureHistory.length - 1).toInt();
    int endIndex = _currentScrollPosition.clamp(0, pressureHistory.length).toInt();

    for (int i = startIndex; i < endIndex; i++) {
      // Zamanı saniye cinsinden hesapla (en solda en eski, en sağda en yeni)
      double timeFromStart = (i - startIndex).toDouble();

      // 🆕 YENİ: Y değerini ölçeklendir
      double transformedY = _transformY(pressureHistory[i]);
      spots.add(FlSpot(timeFromStart, transformedY));
    }

    return spots;
  }

  void _onChartDragStart(DragStartDetails details) {
    setState(() {
      _isScrolling = true;
      _lastDragX = details.localPosition.dx;
    });
  }

  void _onChartDragUpdate(DragUpdateDetails details) {
    setState(() {
      // Kaydırma miktarını hesapla
      double deltaX = details.localPosition.dx - _lastDragX;

      _currentScrollPosition -= (deltaX / context.size!.width) * _visiblePoints;

      // Sınırları kontrol et
      _currentScrollPosition = _currentScrollPosition.clamp(
          _visiblePoints.toDouble(),
          pressureHistory.length.toDouble()
      );

      _lastDragX = details.localPosition.dx;
    });
  }

  void _onChartDragEnd(DragEndDetails details) {
    setState(() {
      _isScrolling = true;
    });
  }

  void _scrollToLatest() {
    setState(() {
      _currentScrollPosition = pressureHistory.length.toDouble();
      _isScrolling = false;
    });
  }

  // Zaman etiketleri (kaydırılabilir)
  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    if (value % 75 == 0 && value >= 0) { // Her 15 saniyede bir (75 nokta)
      int startIndex = (_currentScrollPosition - _visiblePoints).clamp(0, pressureHistory.length - 1).toInt();
      int dataIndex = startIndex + value.toInt();

      String timeText = _formatTimeAgo(dataIndex, pressureHistory.length);

      return SideTitleWidget(
        axisSide: meta.axisSide,
        child: Text(
          timeText,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      );
    }
    return const SizedBox();
  }

  // 🆕 YENİ: Özelleştirilmiş Y ekseni etiketleri
  Widget _rightTitleWidgets(double value, TitleMeta meta) {
    // Dönüştürülmüş değeri gerçek değere çevir
    double realValue = _inverseTransformY(value);

    // Sadece belirli değerleri göster
    List<double> importantValues = [0, 20, 40, 42, 50, 60, 70];

    if (importantValues.any((v) => (realValue - v).abs() < 0.1)) {
      String displayValue;
      if (realValue == 42) {
        displayValue = '42*'; // Kritik seviye
      } else {
        displayValue = realValue.toInt().toString();
      }

      Color textColor = realValue == 42 ? Colors.redAccent : Colors.white70;
      FontWeight fontWeight = realValue == 42 ? FontWeight.bold : FontWeight.normal;

      return SideTitleWidget(
        axisSide: meta.axisSide,
        child: Text(
          displayValue,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: fontWeight,
          ),
        ),
      );
    }
    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    double currentPressure = app.pressure;
    int toplamTekrar = app.toplamTekrar;

    Color pressureColor = currentPressure < 42.0 ? Colors.redAccent : Colors.greenAccent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blueGrey.shade900.withOpacity(0.8),
            Colors.blueGrey.shade800.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ÜST BİLGİ SATIRI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Row(
                        children: [
                          const Text('Min:', style: TextStyle(color: Colors.white60, fontSize: 11)),
                          const SizedBox(width: 2),
                          Text(
                            pressureHistory.isNotEmpty
                                ? pressureHistory.reduce((a, b) => a < b ? a : b).toStringAsFixed(1)
                                : "0.0",
                            style: TextStyle(
                                color: pressureHistory.isNotEmpty &&
                                    pressureHistory.reduce((a, b) => a < b ? a : b) < 42.0
                                    ? Colors.redAccent
                                    : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          const Text('Max:', style: TextStyle(color: Colors.white60, fontSize: 11)),
                          const SizedBox(width: 2),
                          Text(
                            pressureHistory.isNotEmpty
                                ? pressureHistory.reduce((a, b) => a > b ? a : b).toStringAsFixed(1)
                                : "0.0",
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      if (toplamTekrar >= 0)
                        Row(
                          children: [
                            const Text('Tekrar:', style: TextStyle(color: Colors.white60, fontSize: 11)),
                            const SizedBox(width: 2),
                            Text(
                              toplamTekrar.toString(),
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (_isScrolling)
                        Text(
                          '${_formatTimeAgo(_currentScrollPosition.toInt(), pressureHistory.length)} önce',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else if (toplamTekrar > 0)
                        Text(
                          '🔄 Toplam $toplamTekrar tekrar tamamlandı',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else if (pressureHistory.isNotEmpty && pressureHistory.any((p) => p < 42.0))
                          Text(
                            '⚠️ Kritik: Basınç 42 bar altına düştü!',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                    ],
                  ),
                ],
              ),

              Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${currentPressure.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: pressureColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'bar',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '42-60',
                          style: TextStyle(
                            color: currentMode == PressureMode.mode42_60 ? Colors.lightBlueAccent : Colors.white60,
                            fontSize: 10,
                            fontWeight: currentMode == PressureMode.mode42_60 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Transform.scale(
                          scale: 0.7,
                          child: Switch(
                            value: currentMode == PressureMode.mode42_52,
                            onChanged: (_) => togglePressureMode(),
                            activeColor: Colors.lightBlueAccent,
                            inactiveThumbColor: Colors.white54,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '42-52',
                          style: TextStyle(
                            color: currentMode == PressureMode.mode42_52 ? Colors.lightBlueAccent : Colors.white60,
                            fontSize: 10,
                            fontWeight: currentMode == PressureMode.mode42_52 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_isScrolling)
                    GestureDetector(
                      onTap: _scrollToLatest,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.refresh, size: 12, color: Colors.greenAccent),
                            SizedBox(width: 4),
                            Text(
                              'Canlı',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),

          // 📊 ÖZELLEŞTİRİLMİŞ Y EKSENLİ GRAFİK
          SizedBox(
            height: 200,
            child: GestureDetector(
              onHorizontalDragStart: _onChartDragStart,
              onHorizontalDragUpdate: _onChartDragUpdate,
              onHorizontalDragEnd: _onChartDragEnd,
              child: LineChart(
                LineChartData(
                  clipData: const FlClipData.all(),
                  // 🆕 YENİ: Dönüştürülmüş Y ekseni aralığı (0-1 arası)
                  minY: 0.0,
                  maxY: 1.0,
                  minX: 0,
                  maxX: _visiblePoints.toDouble(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: true,
                    horizontalInterval: 0.1, // %10'luk aralıklarla
                    verticalInterval: 75, // Her 15 saniyede bir
                    getDrawingHorizontalLine: (value) {
                      // Önemli seviyeleri vurgula
                      if (value == _transformY(42.0)) {
                        return FlLine(
                          color: Colors.red.withOpacity(0.8),
                          strokeWidth: 2,
                          dashArray: [5, 5],
                        );
                      } else if (value == 0.0 || value == 1.0) {
                        return FlLine(
                          color: Colors.white.withOpacity(0.3),
                          strokeWidth: 1,
                        );
                      } else {
                        return FlLine(
                          color: Colors.white.withOpacity(0.15),
                          strokeWidth: 1,
                        );
                      }
                    },
                    getDrawingVerticalLine: (_) => FlLine(
                      color: Colors.white.withOpacity(0.08),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        interval: 0.1,
                        getTitlesWidget: _rightTitleWidgets,
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        interval: 75, // Her 15 saniyede bir
                        getTitlesWidget: _bottomTitleWidgets,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _getChartSpots(),
                      isCurved: true,
                      color: pressureColor,
                      barWidth: 3.5,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            pressureColor.withOpacity(0.4),
                            pressureColor.withOpacity(0.15),
                            pressureColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      // Kritik basınç seviyesi (42 bar)
                      HorizontalLine(
                        y: _transformY(42.0),
                        color: Colors.red.withOpacity(0.7),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 8),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          labelResolver: (line) => 'Kritik: 42 bar',
                        ),
                      ),
                    ],
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((spot) {
                          int startIndex = (_currentScrollPosition - _visiblePoints).clamp(0, pressureHistory.length - 1).toInt();
                          int dataIndex = startIndex + spot.x.toInt();

                          String timeText = _formatDetailedTimeAgo(dataIndex, pressureHistory.length);

                          // 🆕 YENİ: Gerçek basınç değerini göster
                          double realPressure = _inverseTransformY(spot.y);

                          return LineTooltipItem(
                            '${realPressure.toStringAsFixed(1)} bar\n$timeText\nÖlçek: 0-70 bar*',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}