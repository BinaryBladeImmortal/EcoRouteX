import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/mobility_widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About EcoRouteX'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlowCard(
                glowColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppTheme.greenGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.eco_rounded,
                              color: AppTheme.primaryDark, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text('EcoRouteX',
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Smart, eco-friendly travel planning for your city',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'EcoRouteX helps you plan trips, compare travel modes, and choose practical routes for your city. It combines route recommendations with CO2 tracking so you can understand the impact of everyday travel.',
                      style: TextStyle(
                          color: AppTheme.textSoft, height: 1.5, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlowCard(
                glowColor: AppTheme.accentBlue,
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withOpacity(0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.accentBlue.withOpacity(0.45),
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppTheme.accentBlue,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Created by',
                            style: TextStyle(
                              color: AppTheme.textSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Jolls Dmello',
                            style: TextStyle(
                              color: AppTheme.textWhite,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Original concept, design, and development',
                            style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SectionHeader(title: 'Powered by Machine Learning'),
              const SizedBox(height: 12),
              GlowCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _AboutDetail(
                      icon: Icons.route_rounded,
                      title: 'Route Recommendation',
                      text:
                          'A Random Forest model suggests the best travel mode using distance, weather, time of day, and your preferences. Rule-based logic handles real-world edge cases.',
                    ),
                    SizedBox(height: 18),
                    _AboutDetail(
                      icon: Icons.co2_rounded,
                      title: 'CO2 Estimation',
                      text:
                          'A separate Random Forest model estimates carbon emissions for each trip.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SectionHeader(title: 'Project Details'),
              const SizedBox(height: 12),
              GlowCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: const [
                    _AboutRow(label: 'Created by', value: 'Jolls Dmello'),
                    _AboutRow(
                        label: 'Project type',
                        value: 'College Project Team original work'),
                    _AboutRow(label: 'Version', value: 'v1.0'),
                    _AboutRow(label: 'Built', value: '2026'),
                    _AboutRow(
                      label: 'Built with',
                      value: 'Flutter · Flask · scikit-learn',
                    ),
                    _AboutRow(
                      label: 'Note',
                      value: 'Student project and learning prototype',
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SectionHeader(title: 'Attribution'),
              const SizedBox(height: 12),
              GlowCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _AttributionRow('Map data © OpenStreetMap contributors'),
                    _AttributionRow('Routing via OSRM'),
                    _AttributionRow('Geocoding via Photon'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'All rights reserved by Jolls Dmello',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Created in 2026',
                      style: TextStyle(
                        color: AppTheme.textFaint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutDetail extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _AboutDetail(
      {required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const SizedBox(height: 5),
              Text(text,
                  style: const TextStyle(
                      color: AppTheme.textSoft, height: 1.45, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _AboutRow(
      {required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12, top: 2),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                  bottom:
                      BorderSide(color: AppTheme.textFaint.withOpacity(0.2)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 98,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppTheme.textWhite, fontSize: 12, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _AttributionRow extends StatelessWidget {
  final String text;

  const _AttributionRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              color: AppTheme.accentBlue, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: AppTheme.textSoft, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
