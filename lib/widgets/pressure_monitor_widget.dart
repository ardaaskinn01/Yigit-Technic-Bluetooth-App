import 'dart:async';
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
  double criticalThreshold = 42.0;
  List<double> pressureHistory = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      final app = context.read<AppState>();

      if (app.pressure > 0) {
        setState(() {
          double safePressure = app.pressure;

          if (safePressure < minPressure) safePressure = minPressure;

          pressureHistory.add(safePressure);
          if (pressureHistory.length > 150) pressureHistory.removeAt(0);
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

  // 🆕 DÜZELTME: Doğru sıralama için spotları oluştur
  List<FlSpot> _getChartSpots() {
    if (pressureHistory.isEmpty) return [];

    final spots = <FlSpot>[];
    final totalPoints = pressureHistory.length;

    // 🆕 DÜZELTME: En eski veri solda (0s), en yeni veri sağda (60s)
    for (int i = 0; i < totalPoints; i++) {
      // Zamanı saniye cinsinden hesapla (en eski 60, en yeni 0)
      double timeInSeconds = 60 - (totalPoints - 1 - i) * 0.5;
      spots.add(FlSpot(timeInSeconds, pressureHistory[i]));
    }

    return spots;
  }

  // 🆕 DÜZELTME: Zaman etiketleri (0s solda, 60s sağda)
  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    // Sadece tam sayı saniyelerde etiket göster
    if (value % 10 == 0 && value >= 0) {
      return SideTitleWidget(
        axisSide: meta.axisSide,
        child: Text(
          '${value.toInt()}s',
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
          // 🧭 ÜST BİLGİ SATIRI - Tüm bilgiler burada
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
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                      // Geçmiş süresi
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${pressureHistory.length ~/ 2}s',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '📈 Basınç Monitörü (60sn)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
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
                        fontSize: 36, // 🆕 DAHA DA BÜYÜK (32'den 36'ya)
                        fontWeight: FontWeight.bold,
                        color: pressureColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'bar',
                      style: TextStyle(
                        fontSize: 20, // 🆕 DAHA DA BÜYÜK (18'den 20'ye)
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // Sağ: Toggle Switch
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
            ],
          ),
          const SizedBox(height: 4),

          // 📊 DEV GRAFİK
          SizedBox(
            height: 200, // 🆕 ÇOK DAHA YÜKSEK (180'den 220'ye)
            child: LineChart(
              LineChartData(
                clipData: const FlClipData.all(),
                minY: minPressure,
                maxY: currentMode == PressureMode.mode42_60 ? 60.0 : 52.0,
                minX: 0,
                maxX: 60,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  drawHorizontalLine: true,
                  horizontalInterval: 5,
                  verticalInterval: 10,
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
                      reservedSize: 30, // 🆕 DAHA KÜÇÜK
                      getTitlesWidget: _rightTitleWidgets,
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 16, // 🆕 DAHA KÜÇÜK
                      interval: 10,
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
                    barWidth: 3.5, // 🆕 DAHA KALIN
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
                  ],
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final secondsFromStart = spot.x;
                        String timeText;
                        if (secondsFromStart == 60) {
                          timeText = 'Şimdi';
                        } else {
                          timeText = '${(60 - secondsFromStart).toInt()}s önce';
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
        ],
      ),
    );
  }
}