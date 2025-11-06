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
  final int _maxHistoryPoints = 300; // 5 dakika (300 * 1sn)
  final int _visiblePoints = 60; // 2 dakika görünüm

  // 🆕 YENİ: Kaydırma için değişkenler
  double _lastDragX = 0.0;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final app = context.read<AppState>();

      if (app.pressure > 0) {
        setState(() {
          double actualPressure = app.pressure;

          // Tüm geçmişi kaydet
          pressureHistory.add(actualPressure);
          if (pressureHistory.length > _maxHistoryPoints) {
            pressureHistory.removeAt(0);
          }

          // Otomatik olarak en sona kaydır (kullanıcı kaydırmıyorsa)
          if (!_isScrolling) {
            _currentScrollPosition = lerpDouble(
              _currentScrollPosition,
              pressureHistory.length.toDouble(),
              0.2,
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

  // Kaydırılabilir grafik için spotlar
  List<FlSpot> _getChartSpots() {
    if (pressureHistory.isEmpty) return [];

    final spots = <FlSpot>[];

    // Görünür aralığı hesapla
    int startIndex = (_currentScrollPosition - _visiblePoints).clamp(0, pressureHistory.length - 1).toInt();
    int endIndex = _currentScrollPosition.clamp(0, pressureHistory.length).toInt();

    for (int i = startIndex; i < endIndex; i++) {
      // Zamanı saniye cinsinden hesapla (en solda en eski, en sağda en yeni)
      double timeFromStart = (i - startIndex).toDouble();
      spots.add(FlSpot(timeFromStart, pressureHistory[i]));
    }

    return spots;
  }

  // 🆕 DÜZELTİLDİ: Doğru event handler
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

      _currentScrollPosition -= (deltaX / context.size!.width) * _visiblePoints; // Duyarlılık ayarı

      // Sınırları kontrol et
      _currentScrollPosition = _currentScrollPosition.clamp(
          _visiblePoints.toDouble(),
          pressureHistory.length.toDouble()
      );

      _lastDragX = details.localPosition.dx;
    });
  }

  void _onChartDragEnd(DragEndDetails details) {
    // Kaydırma bittiğinde otomatik olarak canlıya dönmesin
    setState(() {
      _isScrolling = true; // Kayıtlı modda kalmaya devam et
    });
  }

  // En sona git butonu
  void _scrollToLatest() {
    setState(() {
      _currentScrollPosition = pressureHistory.length.toDouble();
      _isScrolling = false;
    });
  }

  // Zaman etiketleri (kaydırılabilir)
  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    if (value % 30 == 0 && value >= 0) {
      // Gerçek zamanı hesapla
      int startIndex = (_currentScrollPosition - _visiblePoints).clamp(0, pressureHistory.length - 1).toInt();
      int dataIndex = startIndex + value.toInt();

      String timeText;
      if (dataIndex >= pressureHistory.length - 1) {
        timeText = 'Şimdi';
      } else {
        int secondsAgo = pressureHistory.length - 1 - dataIndex;
        if (secondsAgo < 60) {
          timeText = '${secondsAgo}s';
        } else if (secondsAgo < 3600) {
          timeText = '${secondsAgo ~/ 60}d';
        } else {
          timeText = '${secondsAgo ~/ 3600}s';
        }
      }

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

  // Y ekseni etiketleri
  Widget _rightTitleWidgets(double value, TitleMeta meta) {
    if (value == 42.0 || value == 52.0 || value == 60.0) {
      return Text(
        '${value.toInt()}',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
        ),
      );
    }
    return const SizedBox();
  }

  double _calculateVisibleMinPressure() {
    try {
      int startIndex = (_currentScrollPosition - _visiblePoints).clamp(0, pressureHistory.length - 1).toInt();
      int endIndex = _currentScrollPosition.clamp(0, pressureHistory.length).toInt();

      // Görünür aralıktaki verileri al
      List<double> visibleData = pressureHistory.sublist(startIndex, endIndex);

      // Liste boşsa varsayılan değer döndür
      if (visibleData.isEmpty) return minPressure;

      // Minimum değeri bul ve margin ekle
      double minVisible = visibleData.reduce((a, b) => a < b ? a : b);
      return (minVisible - 2).clamp(0, 60);
    } catch (e) {
      // Hata durumunda varsayılan değer
      return minPressure;
    }
  }

// 🆕 YENİ: Güvenli maximum basınç hesaplama (opsiyonel, daha iyi görünüm için)
  double _calculateVisibleMaxPressure() {
    try {
      int startIndex = (_currentScrollPosition - _visiblePoints).clamp(0, pressureHistory.length - 1).toInt();
      int endIndex = _currentScrollPosition.clamp(0, pressureHistory.length).toInt();

      List<double> visibleData = pressureHistory.sublist(startIndex, endIndex);

      if (visibleData.isEmpty) {
        return currentMode == PressureMode.mode42_60 ? 60.0 : 52.0;
      }

      double maxVisible = visibleData.reduce((a, b) => a > b ? a : b);
      return (maxVisible + 2).clamp(0, currentMode == PressureMode.mode42_60 ? 60.0 : 52.0);
    } catch (e) {
      return currentMode == PressureMode.mode42_60 ? 60.0 : 52.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    double currentPressure = app.pressure;

    Color pressureColor = currentPressure < 42.0 ? Colors.redAccent : Colors.greenAccent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ÜST BİLGİ SATIRI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Sol: Min/Max istatistikleri ve başlık
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Min değer
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
                      // Max değer
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
                      // Kaydırma durumu
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _isScrolling ? Colors.blue.withOpacity(0.3) : Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _isScrolling ? '📜 Kayıtlı' : '⏱️ Canlı',
                          style: TextStyle(
                            color: _isScrolling ? Colors.blueAccent : Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Kaydırma bilgisi
                  Row(
                    children: [
                      if (_isScrolling)
                        Text(
                          '${pressureHistory.length - _currentScrollPosition.toInt()}s önce',
                          style: const TextStyle(
                            color: Colors.blueAccent,
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
                      else
                        Text(
                          '📈 Basınç Monitörü (${_maxHistoryPoints ~/ 60}dakika)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Mevcut basınç
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

              // Sağ: Toggle Switch ve En sona git butonu
              Column(
                children: [
                  // Toggle Switch
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
                  // En sona git butonu
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

          // 📊 KAYDIRILABİLİR GRAFİK - DÜZELTİLDİ
          SizedBox(
            height: 200,
            child: GestureDetector(
              onHorizontalDragStart: _onChartDragStart,
              onHorizontalDragUpdate: _onChartDragUpdate,
              onHorizontalDragEnd: _onChartDragEnd,
              child: LineChart(
                LineChartData(
                  clipData: const FlClipData.all(),
                  // 🆕 DÜZELTME: Güvenli minY hesaplama
                  minY: pressureHistory.isNotEmpty
                      ? _calculateVisibleMinPressure() // Yeni metod
                      : minPressure,
                  maxY: currentMode == PressureMode.mode42_60 ? 60.0 : 52.0,
                  minX: 0,
                  maxX: _visiblePoints.toDouble(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: true,
                    horizontalInterval: 5,
                    verticalInterval: 30,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.white.withOpacity(0.15),
                      strokeWidth: 1,
                    ),
                    getDrawingVerticalLine: (_) => FlLine(
                      color: Colors.white.withOpacity(0.08),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: _rightTitleWidgets,
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        interval: 30,
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
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 42.0,
                        color: Colors.red.withOpacity(0.7),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                      ),
                      if (pressureHistory.isNotEmpty && pressureHistory.any((p) => p < 42.0))
                        HorizontalLine(
                          y: pressureHistory.reduce((a, b) => a < b ? a : b),
                          color: Colors.orange.withOpacity(0.7),
                          strokeWidth: 1,
                          dashArray: [3, 3],
                        ),
                    ],
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((spot) {
                          // Gerçek zamanı hesapla
                          int startIndex = (_currentScrollPosition - _visiblePoints).clamp(0, pressureHistory.length - 1).toInt();
                          int dataIndex = startIndex + spot.x.toInt();
                          int secondsAgo = pressureHistory.length - 1 - dataIndex;

                          String timeText;
                          if (secondsAgo == 0) {
                            timeText = 'Şimdi';
                          } else if (secondsAgo < 60) {
                            timeText = '$secondsAgo saniye önce';
                          } else if (secondsAgo < 3600) {
                            timeText = '${secondsAgo ~/ 60} dakika önce';
                          } else {
                            timeText = '${secondsAgo ~/ 3600} saat önce';
                          }

                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)} bar\n$timeText',
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
          // Kaydırma kılavuzu
          if (pressureHistory.length > _visiblePoints)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swipe_left, size: 14, color: Colors.white54),
                  SizedBox(width: 4),
                  Text(
                    'Sağa kaydırarak geçmişe gidebilirsiniz',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}