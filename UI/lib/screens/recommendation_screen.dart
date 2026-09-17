// lib/screens/recommendation_screen.dart
// EcoRouteX – AI Recommendation (Enhanced with Decision Analysis)

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/mobility_widgets.dart';
import '../models/mobility_model.dart';

class RecommendationScreen extends StatefulWidget {
  final TripInput input;
  final TripRecommendation result;

  const RecommendationScreen(
      {super.key, required this.input, required this.result});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EcoRouteX Recommendation'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context)),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRouteHeader(),
              const SizedBox(height: 18),
              _buildBestOptionCard(),
              const SizedBox(height: 18),
              _buildAIDecisionAnalysis(),
              const SizedBox(height: 18),
              _buildAllOptionsCards(),
              const SizedBox(height: 18),
              _buildAIExplanationCard(),
              const SizedBox(height: 22),
              _buildActionRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteHeader() {
    return RouteVisualizer(
      origin: widget.input.origin,
      destination: widget.input.destination,
      mode: widget.result.best.mode,
      emoji: widget.result.best.emoji,
    );
  }

  // ── Best Option Card ──────────────────────────────────────
  Widget _buildBestOptionCard() {
    final best = widget.result.best;
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF003D2A), Color(0xFF00C896)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppTheme.greenGlow,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18)),
              child: const Text('🤖 ML BEST RECOMMENDATION',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ),
            const SizedBox(height: 16),
            Text(best.emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 6),
            Text(best.mode,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _bestStat('${best.travelMinutes} min', 'Travel Time',
                    Icons.access_time_rounded),
                _divider(),
                _bestStat(
                    '${best.ecoScore}/100', 'Eco Score', Icons.eco_rounded),
                _divider(),
                _bestStat(
                    best.costRange, 'Est. Cost', Icons.currency_rupee_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bestStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
      ],
    );
  }

  Widget _divider() => Container(height: 36, width: 1, color: Colors.white24);

  // ── AI Decision Analysis ──────────────────────────────────
  Widget _buildAIDecisionAnalysis() {
    final best = widget.result.best;
    final factors = [
      _DecisionFactor('Distance Impact',
          _distanceScore(widget.input.distanceKm), AppTheme.accentBlue),
      _DecisionFactor('Eco Impact', best.ecoScore / 100, AppTheme.primaryGreen),
      _DecisionFactor('Time Efficiency', _timeScore(best.travelMinutes),
          AppTheme.accentAmber),
      _DecisionFactor(
          'Cost Efficiency', _costScore(best.costRange), AppTheme.success),
    ];

    return GlowCard(
      glowColor: AppTheme.accentBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppTheme.accentBlue, size: 16),
              ),
              const SizedBox(width: 8),
              Text('ML Decision Analysis',
                  style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Why this option was selected',
              style: TextStyle(color: AppTheme.textSoft, fontSize: 11)),
          const SizedBox(height: 16),
          ...factors.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(f.label,
                            style: const TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        Text('${(f.value * 100).toInt()}%',
                            style: TextStyle(
                                color: f.color,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: f.value,
                        backgroundColor: f.color.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(f.color),
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

  double _distanceScore(double dist) {
    if (dist <= 2) return 1.0;
    if (dist <= 8) return 0.8;
    if (dist <= 15) return 0.65;
    return 0.5;
  }

  double _timeScore(int mins) {
    if (mins <= 15) return 0.95;
    if (mins <= 25) return 0.80;
    if (mins <= 40) return 0.65;
    return 0.45;
  }

  double _costScore(String costRange) {
    if (costRange == 'Free') return 1.0;
    if (costRange.contains('10')) return 0.9;
    if (costRange.contains('20')) return 0.8;
    if (costRange.contains('50')) return 0.6;
    return 0.35;
  }

  // ── All Options Cards ─────────────────────────────────────
  Widget _buildAllOptionsCards() {
    final all = [widget.result.best, ...widget.result.alternatives];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Best Travel Options',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        ...all.map((opt) {
          final isRecommended = opt.isRecommended;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: isRecommended
                  ? const LinearGradient(
                      colors: [Color(0xFF003D2A), Color(0xFF005C3E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRecommended
                    ? AppTheme.primaryGreen.withOpacity(0.5)
                    : AppTheme.textFaint.withOpacity(0.2),
                width: isRecommended ? 1.5 : 1,
              ),
              boxShadow:
                  isRecommended ? AppTheme.greenGlow : AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Text(opt.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(opt.mode,
                              style: TextStyle(
                                  color: isRecommended
                                      ? AppTheme.primaryGreen
                                      : AppTheme.textWhite,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          if (isRecommended) ...[
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('BEST',
                                  style: TextStyle(
                                      color: AppTheme.primaryGreen,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _optStat('⏱', '${opt.travelMinutes} min'),
                          const SizedBox(width: 10),
                          _optStat('💰', opt.costRange),
                        ],
                      ),
                    ],
                  ),
                ),
                EcoRing(score: opt.ecoScore, radius: 28, lineWidth: 5),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _optStat(String emoji, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 3),
        Text(value,
            style: const TextStyle(color: AppTheme.textSoft, fontSize: 11)),
      ],
    );
  }

  // ── AI Explanation Card ───────────────────────────────────
  Widget _buildAIExplanationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF003D52), Color(0xFF00596E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.blueGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.tips_and_updates_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ML REASONING',
                      style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          letterSpacing: 0.8)),
                  Text('Why this route?',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(widget.result.aiExplanation,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, height: 1.6)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              InfoChip(
                  label: widget.input.timeOfDay,
                  color: AppTheme.accentAmber,
                  icon: Icons.schedule_rounded),
              InfoChip(
                  label: widget.input.weather,
                  color: AppTheme.accentBlue,
                  icon: Icons.cloud_rounded),
              InfoChip(
                  label: widget.input.preference,
                  color: AppTheme.primaryGreen,
                  icon: Icons.tune_rounded),
            ],
          ),
        ],
      ),
    );
  }

  // ── Action Row ────────────────────────────────────────────
  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.edit_rounded, size: 15),
            label: const Text('Edit Trip'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryGreen,
              side: const BorderSide(color: AppTheme.primaryGreen),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Trip saved! 🌱'),
                  backgroundColor: AppTheme.primaryGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            icon: const Icon(Icons.save_rounded, size: 15),
            label: const Text('Save Trip'),
          ),
        ),
      ],
    );
  }
}

class _DecisionFactor {
  final String label;
  final double value;
  final Color color;
  _DecisionFactor(this.label, this.value, this.color);
}
