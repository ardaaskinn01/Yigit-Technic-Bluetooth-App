import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

enum PressureMode { mode52_60, mode42_60 }

class PressureMonitorWidget extends StatefulWidget {
  const PressureMonitorWidget({super.key});

  @override
  State<PressureMonitorWidget> createState() => _PressureMonitorWidgetState();
}

class _PressureMonitorWidgetState extends State<PressureMonitorWidget> {
  PressureMode currentMode = PressureMode.mode52_60;
  double minPressure = 52.0;
  double criticalThreshold = 52.0;
  List<double> pressureHistory = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Her 200 ms'de bir güncelleme (daha akıcı)
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final app = context.read<AppState>();
      if (app.pressure > 0) {
        setState(() {
          double safePressure = app.pressure;
          if (safePressure < minPressure) safePressure = minPressure; // 👈 sınırla
          pressureHistory.add(safePressure);
          if (pressureHistory.length > 25) pressureHistory.removeAt(0);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void togglePressureMode() {
    setState(() {
      if (currentMode == PressureMode.mode52_60) {
        currentMode = PressureMode.mode42_60;
        minPressure = 42.0;
        criticalThreshold = 42.0;
        context.read<AppState>().setPressureToggle(false);
      } else {
        currentMode = PressureMode.mode52_60;
        minPressure = 52.0;
        criticalThreshold = 52.0;
        context.read<AppState>().setPressureToggle(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    double currentPressure = app.pressure;

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
              Text(
                '${minPressure.toInt()}-60 bar',
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
                color: currentPressure < criticalThreshold
                    ? Colors.redAccent
                    : Colors.greenAccent,
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
                maxY: 60,
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
                        if (value == 60 ||
                            value == criticalThreshold ||
                            value == minPressure) {
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
                  bottomTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: pressureHistory.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value);
                    }).toList(),
                    isCurved: true,
                    color: currentPressure < criticalThreshold
                        ? Colors.redAccent
                        : Colors.greenAccent,
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: criticalThreshold,
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
              const Text('52-60 bar',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Switch(
                value: currentMode == PressureMode.mode42_60,
                onChanged: (_) => togglePressureMode(),
                activeColor: Colors.lightBlueAccent,
                inactiveThumbColor: Colors.white54,
              ),
              const Text('42-60 bar',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}