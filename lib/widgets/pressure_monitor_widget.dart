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
  double criticalThreshold = 42.0; // ✅ DÜZELTİLDİ: Kritik eşik 42 bar
  List<double> pressureHistory = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      final app = context.read<AppState>();

      if (app.pressure > 0) {
        setState(() {
          double safePressure = app.pressure;

          if (safePressure < minPressure) safePressure = minPressure;

          pressureHistory.add(safePressure);
          if (pressureHistory.length > 25) pressureHistory.removeAt(0);
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
        // 42-60 -> 42-52 (Dar aralık)
        currentMode = PressureMode.mode42_52;
        minPressure = 42.0; // ✅ DÜZELTİLDİ: minPressure hala 42
        context.read<AppState>().setPressureToggle(true); // true = dar aralık (42-52)
      } else {
        // 42-52 -> 42-60 (Geniş aralık)
        currentMode = PressureMode.mode42_60;
        minPressure = 42.0;
        context.read<AppState>().setPressureToggle(false); // false = geniş aralık (42-60)
      }
      pressureHistory.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    double currentPressure = app.pressure;

    // ✅ DÜZELTİLDİ: Renk mantığı - 42 bar'ın altı kırmızı
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
          // 🧭 Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📈 Basınç Monitörü',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              // ✅ DÜZELTİLDİ: Header'daki aralık bilgisi
              Text(
                currentMode == PressureMode.mode42_60 ? '42-60 bar' : '42-52 bar',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 🔢 ANLIK BASINÇ GÖSTERGESİ
          Center(
            child: Text(
              '${currentPressure.toStringAsFixed(1)} bar',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: pressureColor, // ✅ DÜZELTİLDİ: Tek renk mantığı
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 📊 Grafik
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                clipData: const FlClipData.all(),
                minY: minPressure,
                maxY: currentMode == PressureMode.mode42_60 ? 60.0 : 52.0, // ✅ DÜZELTİLDİ: Max değer moda göre değişir
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withOpacity(0.15),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, _) {
                        // ✅ DÜZELTİLDİ: Sadece önemli değerleri göster
                        if (value == 42.0 ||
                            value == 52.0 ||
                            value == 60.0) {
                          return Text(
                            '${value.toInt()} bar',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 10),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: pressureHistory.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value);
                    }).toList(),
                    isCurved: true,
                    color: pressureColor, // ✅ DÜZELTİLDİ: Aynı renk mantığı
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    // ✅ DÜZELTİLDİ: Kritik eşik çizgisi 42 bar
                    HorizontalLine(
                      y: 42.0,
                      color: Colors.red.withOpacity(0.5),
                      strokeWidth: 2,
                      dashArray: [5, 5],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 🎚 Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('42-60 bar',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Switch(
                value: currentMode == PressureMode.mode42_52, // ✅ DÜZELTİLDİ: Doğru mod kontrolü
                onChanged: (_) => togglePressureMode(),
                activeColor: Colors.lightBlueAccent,
                inactiveThumbColor: Colors.white54,
              ),
              const Text('42-52 bar', // ✅ DÜZELTİLDİ: Doğru açıklama
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}