// lib/screens/insights_screen.dart
// EcoRouteX – Insights (Enhanced with Mobility Score Breakdown)

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/app_theme.dart';
import '../widgets/mobility_widgets.dart';
import '../services/api_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late Future<Map<String, dynamic>> _insightsData;

  @override
  void initState() {
    super.initState();
    _insightsData = ApiService.fetchInsightsData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _insightsData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (snapshot.hasData) {
              final data = snapshot.data!;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 20),
                    _buildSummaryRow(data),
                    const SizedBox(height: 22),
                    const SectionHeader(title: '📈 Weekly Travel Distance'),
                    const SizedBox(height: 12),
                    _buildLineChart(data),
                    const SizedBox(height: 22),
                    const SectionHeader(title: '🚌 Transport Mode Usage'),
                    const SizedBox(height: 12),
                    _buildModeBreakdown(context, data),
                    const SizedBox(height: 22),
                    const SectionHeader(title: '🌱 Eco Impact Trend'),
                    const SizedBox(height: 12),
                    _buildEcoTrend(context, data),
                    const SizedBox(height: 22),
                    const SectionHeader(title: '🎯 Mobility Score Breakdown'),
                    const SizedBox(height: 12),
                    _buildMobilityScoreBreakdown(context, data),
                    const SizedBox(height: 22),
                    const SectionHeader(title: '🏆 Monthly Goals'),
                    const SizedBox(height: 12),
                    _buildGoals(),
                  ],
                ),
              );
            } else {
              return const Center(child: Text('No data'));
            }
          },
        ),
      ),
    );
  }
}

Widget _buildHeader(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Insights', style: Theme.of(context).textTheme.displayMedium),
      const Text('Your travel behavior analytics',
          style: TextStyle(color: AppTheme.textSoft, fontSize: 13)),
    ],
  );
}

Widget _buildSummaryRow(Map<String, dynamic> data) {
  final summary = data['weekly_summary'] as Map<String, dynamic>;
  final trend = data['trend'] as double;
  final dailyAvg = summary['distance'] / 7;
  return Row(
    children: [
      Expanded(
          child: QuickStat(
              value: '${summary['distance']}',
              label: 'km\nWeek',
              icon: Icons.route_rounded,
              color: AppTheme.accentBlue)),
      const SizedBox(width: 8),
      Expanded(
          child: QuickStat(
              value: '${dailyAvg.toStringAsFixed(1)}',
              label: 'km\nDaily Avg',
              icon: Icons.today_rounded,
              color: AppTheme.primaryGreen)),
      const SizedBox(width: 8),
      Expanded(
          child: QuickStat(
              value: '${trend > 0 ? '+' : ''}${trend.toStringAsFixed(0)}%',
              label: 'vs Last\nWeek',
              icon: trend > 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: trend > 0 ? AppTheme.warningAmber : AppTheme.success)),
    ],
  );
}

Widget _buildLineChart(Map<String, dynamic> data) {
  final rawWeeklyTrips = data['weekly_trips'] as List<dynamic>? ?? [];
  final weeklyTotals = <String, double>{
    for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) day: 0,
  };
  for (final trip in rawWeeklyTrips) {
    final day = trip['day'] as String?;
    if (day != null && weeklyTotals.containsKey(day)) {
      weeklyTotals[day] =
          weeklyTotals[day]! + (trip['distance_km'] as num).toDouble();
    }
  }
  final weeklyTrips = [
    for (final day in weeklyTotals.keys)
      {
        'day': day,
        'distance_km': (weeklyTotals[day]! * 10).round() / 10,
      }
  ];
  if (weeklyTrips.isEmpty) {
    return const GlowCard(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text('No trip data available',
            style: TextStyle(color: AppTheme.textSoft)),
      ),
    );
  }

  // Calculate dynamic Y range based on data
  final maxDistance = weeklyTrips
      .map((t) => (t['distance_km'] as num).toDouble())
      .fold<double>(0, (prev, curr) => curr > prev ? curr : prev);
  final maxY = ((maxDistance * 1.2) / 5).ceil() *
      5; // Round up to nearest 5 with 20% padding
  final adjustedMaxY = maxY < 10 ? 10 : maxY; // Minimum 10 to show scale

  return GlowCard(
    padding: const EdgeInsets.fromLTRB(10, 18, 14, 10),
    child: SizedBox(
      height: 170,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(
                color: AppTheme.textFaint.withOpacity(0.15), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: adjustedMaxY / 4,
              getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                  style:
                      const TextStyle(color: AppTheme.textFaint, fontSize: 9)),
            )),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (v != i.toDouble() || i < 0 || i >= weeklyTrips.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(weeklyTrips[i]['day'] as String,
                      style: const TextStyle(
                          color: AppTheme.textSoft, fontSize: 9)),
                );
              },
            )),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                final day = weeklyTrips[spot.x.toInt()]['day'];
                final distance = spot.y.toStringAsFixed(1);
                return LineTooltipItem(
                  '$day\n$distance km',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                  weeklyTrips.length,
                  (i) => FlSpot(i.toDouble(),
                      (weeklyTrips[i]['distance_km'] as num).toDouble())),
              isCurved: true,
              curveSmoothness: 0.3,
              preventCurveOverShooting: true,
              color: AppTheme.primaryGreen,
              barWidth: 2.5,
              dotData: FlDotData(
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 4,
                      color: AppTheme.primaryGreen,
                      strokeWidth: 2,
                      strokeColor: AppTheme.primaryDark)),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryGreen.withOpacity(0.25),
                    AppTheme.primaryGreen.withOpacity(0.0)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          minY: 0,
          maxY: adjustedMaxY.toDouble(),
          minX: 0,
          maxX: (weeklyTrips.length - 1).toDouble(),
          clipData: const FlClipData.all(),
        ),
      ),
    ),
  );
}

Widget _buildModeBreakdown(BuildContext context, Map<String, dynamic> data) {
  final modeMap = {0: 'Car', 1: 'Bus', 2: 'Train', 3: 'Bike', 4: 'Walk'};
  final modeDistribution = data['mode_distribution'] as Map<String, dynamic>;
  final colors = [
    AppTheme.accentBlue,
    AppTheme.primaryGreen,
    AppTheme.accentAmber,
    AppTheme.success,
    AppTheme.danger
  ];
  final modes = modeDistribution.entries
      .map((e) => MapEntry(modeMap[int.parse(e.key)]!, e.value as double))
      .toList();

  return GlowCard(
    child: Column(
      children: List.generate(modes.length, (i) {
        final color = colors[i % colors.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Text(_modeEmoji(modes[i].key),
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(modes[i].key,
                          style: const TextStyle(
                              color: AppTheme.textWhite,
                              fontWeight: FontWeight.w500,
                              fontSize: 13))),
                  Text('${modes[i].value.toInt()}%',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: modes[i].value / 100,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 7,
                ),
              ),
            ],
          ),
        );
      }),
    ),
  );
}

String _modeEmoji(String mode) {
  const map = {
    'Metro': '🚆',
    'Bike': '🚲',
    'Bus': '🚌',
    'Walk': '🚶',
    'Car': '🚗'
  };
  return map[mode] ?? '🚌';
}

Widget _buildEcoTrend(BuildContext context, Map<String, dynamic> data) {
  final ecoTrend = data['eco_trend'] as Map<String, dynamic>? ?? {};
  final weeks = ecoTrend['weeks'] as List<dynamic>? ?? ['W1', 'W2', 'W3', 'W4'];
  final values = (ecoTrend['values'] as List<dynamic>?)
          ?.map((v) => (v as num).toDouble())
          .toList() ??
      [0.0, 0.0, 0.0, 0.0];

  // Calculate percentage change
  final pctChange = values.isNotEmpty && values.length > 1
      ? ((values.last - values.first) /
              (values.first > 0 ? values.first : 1) *
              100)
          .toInt()
      : 0;
  return GlowCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('CO₂ Avoided (kg)',
                style: TextStyle(color: AppTheme.textSoft, fontSize: 11)),
            InfoChip(
                label: '↑ 43% this month',
                color: AppTheme.primaryGreen,
                icon: Icons.trending_up_rounded),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (i) {
            final h = (values[i] / 6.0) * 80;
            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('${values[i]}',
                    style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  width: 40,
                  height: h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryGreen.withOpacity(0.4),
                        AppTheme.primaryGreen
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                ),
                const SizedBox(height: 5),
                Text(weeks[i],
                    style: const TextStyle(
                        color: AppTheme.textSoft, fontSize: 10)),
              ],
            );
          }),
        ),
      ],
    ),
  );
}

Widget _buildMobilityScoreBreakdown(
    BuildContext context, Map<String, dynamic> data) {
  final mobilityScore = data['mobility_score'] as Map<String, dynamic>? ?? {};
  final overallScore = mobilityScore['overall_score'] as int? ?? 50;
  final categories = (mobilityScore['breakdown'] as List<dynamic>? ?? [])
      .map((c) => _ScoreItem(
          c['label'] as String,
          (c['value'] as num).toDouble(),
          _getCategoryColor(c['label'] as String),
          c['emoji'] as String))
      .toList();

  if (categories.isEmpty) {
    return const GlowCard(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text('No mobility data available',
            style: TextStyle(color: AppTheme.textSoft)),
      ),
    );
  }

  return GlowCard(
    glowColor: AppTheme.primaryGreen,
    child: Column(
      children: [
        Row(
          children: [
            EcoRing(score: overallScore, radius: 38, lineWidth: 6),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overall Mobility Score',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 3),
                  const Text('Based on eco impact, efficiency, cost and health',
                      style: TextStyle(
                          color: AppTheme.textSoft, fontSize: 11, height: 1.3)),
                  const SizedBox(height: 8),
                  InfoChip(
                      label: 'Score: $overallScore/100',
                      color: AppTheme.primaryGreen),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ...categories.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(c.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 7),
                      Expanded(
                          child: Text(c.label,
                              style: const TextStyle(
                                  color: AppTheme.textWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500))),
                      Text('${(c.value * 100).toInt()}%',
                          style: TextStyle(
                              color: c.color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: c.value,
                      backgroundColor: c.color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(c.color),
                      minHeight: 7,
                    ),
                  ),
                ],
              ),
            )),
      ],
    ),
  );
}

Color _getCategoryColor(String label) {
  switch (label) {
    case 'Eco Impact':
      return AppTheme.primaryGreen;
    case 'Travel Efficiency':
      return AppTheme.accentBlue;
    case 'Cost Efficiency':
      return AppTheme.accentAmber;
    case 'Health Benefit':
      return AppTheme.success;
    default:
      return AppTheme.primaryGreen;
  }
}

Widget _buildGoals() {
  return GlowCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Track your progress! Plan trips to improve your scores.',
          style: TextStyle(color: AppTheme.textSoft, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _buildGoalRow('🎯 Reduce CO₂', 0.75, AppTheme.primaryGreen),
        const SizedBox(height: 8),
        _buildGoalRow('💰 Save Money', 0.60, AppTheme.accentAmber),
        const SizedBox(height: 8),
        _buildGoalRow('⚡ Improve Efficiency', 0.45, AppTheme.accentBlue),
      ],
    ),
  );
}

Widget _buildGoalRow(String label, double progress, Color color) {
  return Row(
    children: [
      Expanded(
        flex: 3,
        child: Text(label,
            style: const TextStyle(color: AppTheme.textWhite, fontSize: 12)),
      ),
      Expanded(
        flex: 5,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text('${(progress * 100).toInt()}%',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    ],
  );
}

class _GoalItem {
  final String label;
  final double progress;
  final Color color;
  _GoalItem(this.label, this.progress, this.color);
}

class _ScoreItem {
  final String label, emoji;
  final double value;
  final Color color;
  _ScoreItem(this.label, this.value, this.color, this.emoji);
}
