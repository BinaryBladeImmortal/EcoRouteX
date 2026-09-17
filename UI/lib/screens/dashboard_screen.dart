// lib/screens/dashboard_screen.dart
// EcoRouteX – Dashboard (Enhanced: compact stats, badge chips, eco impact)

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/mobility_widgets.dart';
import '../models/mobility_model.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _profileData;

  @override
  void initState() {
    super.initState();
    _profileData = ApiService.fetchProfileData();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasError) {
          return Scaffold(
              body: Center(child: Text('Error: ${snapshot.error}')));
        } else if (snapshot.hasData) {
          final data = snapshot.data!;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Dashboard'),
              centerTitle: true,
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHero(context, data),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildCompactStatsGrid(data),
                        const SizedBox(height: 20),
                        const SectionHeader(title: '🏆 Achievements'),
                        const SizedBox(height: 12),
                        _buildCompactBadges(context, data),
                        const SizedBox(height: 20),
                        const SectionHeader(title: '🌱 Eco Impact'),
                        const SizedBox(height: 12),
                        _buildEcoImpactCard(context, data),
                        const SizedBox(height: 20),
                        const SectionHeader(title: '📊 Travel Summary'),
                        const SizedBox(height: 12),
                        _buildTravelSummary(data),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          return const Scaffold(body: Center(child: Text('No data')));
        }
      },
    );
  }

  // ── Hero ──────────────────────────────────────────────────
  Widget _buildHero(BuildContext context, Map<String, dynamic> data) {
    final userLevel = data['user_level'] as Map<String, dynamic>? ?? {};
    final level = userLevel['level'] ?? 1;
    final primaryBadge = userLevel['primary_badge'] ?? '🌍 Beginner';
    final streakBadge = userLevel['streak_badge'];
    
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A1628), Color(0xFF0D2030), Color(0xFF142030)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      gradient: AppTheme.greenGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.greenGlow,
                    ),
                    child: const Center(
                        child: Text('🌱', style: TextStyle(fontSize: 36))),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  InfoChip(label: '🏆 Level $level', color: AppTheme.accentAmber),
                  InfoChip(
                      label: primaryBadge, color: AppTheme.primaryGreen),
                  if (streakBadge != null)
                    InfoChip(label: streakBadge, color: AppTheme.danger),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Compact 2x2 Stats Grid ────────────────────────────────
  Widget _buildCompactStatsGrid(Map<String, dynamic> data) {
    final stats = [
      _StatItem('${data['distance']} km', 'Total Distance', Icons.route_rounded,
          AppTheme.accentBlue),
      _StatItem('${data['trips']}', 'Trips Logged', Icons.directions_rounded,
          AppTheme.primaryGreen),
      _StatItem('${data['best_score']}', 'Best Score', Icons.star_rounded,
          AppTheme.accentAmber),
      _StatItem('${data['co2']} kg', 'Total CO₂', Icons.eco_rounded,
          AppTheme.warningAmber),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.8,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) {
        final s = stats[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: s.color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: s.color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: s.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(s.icon, color: s.color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(s.value,
                        style: TextStyle(
                            color: s.color,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                    Text(s.label,
                        style: const TextStyle(
                            color: AppTheme.textSoft, fontSize: 9),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Compact Badge Chips (4 per row) ───────────────────────
  Widget _buildCompactBadges(BuildContext context, Map<String, dynamic> data) {
    final achievements = data['achievements'] as List<dynamic>? ?? [];
    
    if (achievements.isEmpty) {
      return const GlowCard(
        padding: EdgeInsets.all(14),
        child: Center(
          child: Text(
            'No achievements yet. Start planning trips to earn badges!',
            style: TextStyle(color: AppTheme.textSoft, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    return GlowCard(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: achievements.map((a) => _badgeChipFromData(a as Map<String, dynamic>)).toList(),
      ),
    );
  }

  Widget _badgeChipFromData(Map<String, dynamic> a) {
    final earned = a['earned'] as bool? ?? false;
    final emoji = a['emoji'] as String? ?? '🏆';
    final title = a['title'] as String? ?? 'Achievement';
    final progress = a['progress'] as int? ?? 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: earned
            ? AppTheme.primaryGreen.withOpacity(0.12)
            : AppTheme.mapDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: earned
              ? AppTheme.primaryGreen.withOpacity(0.4)
              : AppTheme.textFaint.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: earned
            ? [
                BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.15),
                    blurRadius: 6)
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            title,
            style: TextStyle(
              color: earned ? AppTheme.primaryGreen : AppTheme.textSoft,
              fontSize: 11,
              fontWeight: earned ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          if (!earned) ...[
            const SizedBox(width: 4),
            SizedBox(
              width: 20,
              child: Text(
                '$progress%',
                style: const TextStyle(fontSize: 8, color: AppTheme.textFaint),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Keep for backward compatibility
  Widget _badgeChip(Achievement a) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: a.earned
            ? AppTheme.primaryGreen.withOpacity(0.12)
            : AppTheme.mapDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: a.earned
              ? AppTheme.primaryGreen.withOpacity(0.4)
              : AppTheme.textFaint.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: a.earned
            ? [
                BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.15),
                    blurRadius: 6)
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(a.emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            a.title,
            style: TextStyle(
              color: a.earned ? AppTheme.primaryGreen : AppTheme.textSoft,
              fontSize: 11,
              fontWeight: a.earned ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          if (!a.earned) ...[
            const SizedBox(width: 4),
            const Icon(Icons.lock_rounded, size: 9, color: AppTheme.textFaint),
          ],
        ],
      ),
    );
  }

  // ── Eco Impact Card ───────────────────────────────────────
  Widget _buildEcoImpactCard(BuildContext context, Map<String, dynamic> data) {
    final co2 = (data['co2'] as num?)?.toDouble() ?? 0.0;
    final totalDistance = (data['distance'] as num?)?.toDouble() ?? 0.0;
    final trees = (co2 / 20).round(); // rough estimate
    final carTrips = (totalDistance / 10).round(); // rough estimate
    
    // Calculate CO2 avoided vs car baseline (car ~0.12 kg/km)
    final carBaseline = totalDistance * 0.12;
    final co2Avoided = (carBaseline - co2).clamp(0, double.infinity);
    final treesEquivalent = (co2Avoided / 20).toStringAsFixed(1);
    
    return GlowCard(
      glowColor: AppTheme.primaryGreen,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _impactStat('🌳', '$trees', 'Trees\nEquivalent')),
              Container(
                  height: 44,
                  width: 1,
                  color: AppTheme.textFaint.withOpacity(0.25)),
              Expanded(
                  child: _impactStat(
                      '⛽', '${co2.toStringAsFixed(1)} kg', 'CO₂\nEmitted')),
              Container(
                  height: 44,
                  width: 1,
                  color: AppTheme.textFaint.withOpacity(0.25)),
              Expanded(
                  child: _impactStat(
                      '🚗', '$carTrips km', 'Car Trips\nEquivalent')),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Text('🌍', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                  co2Avoided > 0
                      ? 'Your eco-travel choices avoided ${co2Avoided.toStringAsFixed(1)} kg CO₂ — equal to planting $treesEquivalent trees! 🎉'
                      : 'Start planning eco-friendly trips to reduce your carbon footprint! �',
                  style: const TextStyle(
                      color: AppTheme.textWhite, fontSize: 12, height: 1.4),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _impactStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                color: AppTheme.primaryGreen,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSoft, fontSize: 9)),
      ],
    );
  }

  // ── Travel Summary ────────────────────────────────────────
  Widget _buildTravelSummary(Map<String, dynamic> data) {
    const modeMap = {
      0: 'Car 🚗',
      1: 'Bus 🚌',
      2: 'Train 🚆',
      3: 'Bike 🚲',
      4: 'Walk 🚶',
    };
    final favMode = modeMap[data['favourite_mode']] ?? 'Unknown';
    return GlowCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _summaryRow(
              'Total Distance', '${data['distance']} km', AppTheme.accentBlue),
          _summaryRow('Total Trips', '${data['trips']}', AppTheme.primaryGreen),
          _summaryRow('Total Cost', '₹${data['cost']}', AppTheme.accentAmber),
          _summaryRow('Total CO₂', '${data['co2']} kg', AppTheme.warningAmber),
          Divider(height: 20, color: AppTheme.textFaint.withOpacity(0.2)),
          _summaryRow('Favourite Mode', favMode, AppTheme.accentBlue),
          _summaryRow('Best Eco Score', '${data['best_score']}/100',
              AppTheme.primaryGreen),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppTheme.textSoft, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }

}

class _StatItem {
  final String value, label;
  final IconData icon;
  final Color color;
  _StatItem(this.value, this.label, this.icon, this.color);
}
