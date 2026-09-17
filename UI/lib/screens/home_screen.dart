// lib/screens/home_screen.dart
// EcoRouteX – Home Dashboard (Enhanced v2)

import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/mobility_widgets.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final VoidCallback onAboutTap;
  const HomeScreen(
      {super.key, required this.onNavigate, required this.onAboutTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Future<Map<String, dynamic>> _homeData;
  late PageController _tipPageController;
  Timer? _tipTimer;
  final ValueNotifier<int> _tipIndexNotifier = ValueNotifier<int>(0);

  void _refreshHome() {
    setState(() {
      _homeData = ApiService.fetchHomeData();
    });
  }

  static const _tips = [
    'Taking the train during peak hours reduces travel time and emissions by up to 60%',
    'Cycling for just 5 km daily saves over 500 kg of CO₂ per year.',
    'Bus ridership of 40 passengers equals removing 35 cars from the road.',
    'Walking under 2 km is always faster than waiting for transport.',
    'Smart travel planning reduces your weekly commute cost by up to 40%.',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _homeData = ApiService.fetchHomeData();
    _tipPageController = PageController(initialPage: 0);
    _startTipTimer();
  }

  void _startTipTimer() {
    _tipTimer?.cancel();
    _tipTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_tipPageController.hasClients) return;
      final currentIndex = _tipIndexNotifier.value;
      final nextIndex = (currentIndex + 1) % _tips.length;
      _tipPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _tipPageController.dispose();
    _tipIndexNotifier.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _homeData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (snapshot.hasData) {
                final data = snapshot.data!;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildLiveMobilityCard(),
                      const SizedBox(height: 12),
                      _buildAlertCard(data),
                      const SizedBox(height: 18),
                      _buildMobilityScoreCard(data),
                      const SizedBox(height: 14),
                      _buildPlanTripButton(),
                      const SizedBox(height: 22),
                      SectionHeader(
                          title: 'Weekly Summary',
                          action: 'Details',
                          onAction: () => widget.onNavigate(3)),
                      const SizedBox(height: 12),
                      _buildWeeklySummaryRow(data),
                      const SizedBox(height: 22),
                      const SectionHeader(title: 'Recent Trips'),
                      const SizedBox(height: 12),
                      _buildRecentTrips(data),
                      const SizedBox(height: 22),
                      const SectionHeader(title: 'Smart Tips'),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<int>(
                        valueListenable: _tipIndexNotifier,
                        builder: (context, tipIndex, child) {
                          return _buildTipSlider(tipIndex);
                        },
                      ),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<int>(
                        valueListenable: _tipIndexNotifier,
                        builder: (context, tipIndex, child) {
                          return _buildTipDots(tipIndex);
                        },
                      ),
                    ],
                  ),
                );
              } else {
                return const Center(child: Text('No data'));
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EcoRouteX',
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium
                      ?.copyWith(color: AppTheme.primaryGreen)),
              const Text('Smart Mobility Advisor',
                  style: TextStyle(color: AppTheme.textSoft, fontSize: 12)),
            ],
          ),
        ),
        GestureDetector(
          onTap: widget.onAboutTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppTheme.primaryGreen.withOpacity(0.4), width: 1.5),
            ),
            child:
                const Center(child: Text('👤', style: TextStyle(fontSize: 18))),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveMobilityCard() {
    return GlowCard(
      glowColor: AppTheme.accentBlue,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.cell_tower_rounded,
                    color: AppTheme.accentBlue, size: 14),
              ),
              const SizedBox(width: 7),
              const Text('CITY MOBILITY STATUS',
                  style: TextStyle(
                      color: AppTheme.accentBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
              const Spacer(),
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('LIVE',
                  style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _mobilityStatus(
                      '🚦', 'Traffic', 'Moderate', AppTheme.warningAmber)),
              const SizedBox(width: 8),
              Expanded(
                  child: _mobilityStatus(
                      '☀️', 'Weather', 'Sunny', AppTheme.accentAmber)),
              const SizedBox(width: 8),
              Expanded(
                  child: _mobilityStatus(
                      '🚆', 'Best Mode', 'Train', AppTheme.primaryGreen)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobilityStatus(
      String emoji, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          Text(label,
              style: const TextStyle(color: AppTheme.textSoft, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> data) {
    final summary = data['weekly_summary'] as Map<String, dynamic>;
    final co2 = summary['co2'] as double;
    final alert = _generateAlert(co2);
    final Color color = alert['color'] == 'green'
        ? AppTheme.primaryGreen
        : alert['color'] == 'blue'
            ? AppTheme.accentBlue
            : AppTheme.warningAmber;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(alert['icon']!, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI ALERT',
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(alert['title']!,
                    style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                Text(alert['body']!,
                    style: const TextStyle(
                        color: AppTheme.textSoft, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _generateAlert(double co2) {
    if (co2 > 10) {
      return {
        'icon': '🚨',
        'title': 'High Emissions This Week',
        'body': 'Try train or bike for your next trips to reduce CO₂.',
        'color': 'amber'
      };
    } else {
      return {
        'icon': '🌱',
        'title': 'You\'re Doing Great!',
        'body': 'Keep up the eco-friendly choices. Planet thanks you!',
        'color': 'green'
      };
    }
  }

  Widget _buildMobilityScoreCard(Map<String, dynamic> data) {
    final score = data['mobility_score'] as int;
    final level = _getMobilityLevel(score);
    return GlowCard(
      glowColor: AppTheme.primaryGreen,
      gradient: const LinearGradient(
        colors: [Color(0xFF0D2818), Color(0xFF142030)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          EcoRing(score: score, radius: 46, lineWidth: 7),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mobility Score',
                    style: TextStyle(
                        color: AppTheme.textSoft,
                        fontSize: 11,
                        letterSpacing: 0.8)),
                const SizedBox(height: 3),
                Text(level, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 5),
                const Text('Top 22% of eco-friendly commuters!',
                    style: TextStyle(
                        color: AppTheme.textSoft, fontSize: 11, height: 1.4)),
                const SizedBox(height: 8),
                const InfoChip(
                    label: '↑ +6 pts this week',
                    color: AppTheme.primaryGreen,
                    icon: Icons.trending_up_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMobilityLevel(int score) {
    if (score >= 90) return 'Eco Champion 🌍';
    if (score >= 80) return 'Smart Traveler 🌱';
    if (score >= 70) return 'Green Commuter 🌿';
    if (score >= 60) return 'Conscious Rider 🚲';
    return 'Getting Started 🌱';
  }

  Widget _buildPlanTripButton() {
    return GestureDetector(
      onTap: () async {
        widget.onNavigate(1);

        // small delay to allow trip save
        await Future.delayed(const Duration(seconds: 1));

        _refreshHome(); // 🔥 REFRESH DATA
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppTheme.greenGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.greenGlow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: AppTheme.primaryDark.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.navigation_rounded,
                  color: AppTheme.primaryDark, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plan a Smart Trip',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: AppTheme.primaryDark)),
                  const Text('AI-powered route analysis',
                      style: TextStyle(color: Color(0xFF005540), fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppTheme.primaryDark, size: 15),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySummaryRow(Map<String, dynamic> data) {
    final summary = data['weekly_summary'] as Map<String, dynamic>;
    return Row(
      children: [
        Expanded(
            child: QuickStat(
                value: '${summary['distance']}',
                label: 'km\nTraveled',
                icon: Icons.route_rounded,
                color: AppTheme.accentBlue)),
        const SizedBox(width: 8),
        Expanded(
            child: QuickStat(
                value: '${summary['trips']}',
                label: 'Trips\nLogged',
                icon: Icons.directions_rounded,
                color: AppTheme.primaryGreen)),
        const SizedBox(width: 8),
        Expanded(
            child: QuickStat(
                value: '₹${summary['cost']}',
                label: 'Cost\nThis Week',
                icon: Icons.currency_rupee_rounded,
                color: AppTheme.accentAmber)),
        const SizedBox(width: 8),
        Expanded(
            child: QuickStat(
                value: '${summary['co2']}',
                label: 'kg CO₂\nEmitted',
                icon: Icons.eco_rounded,
                color: AppTheme.warningAmber)),
      ],
    );
  }

/*************  ✨ Windsurf Command ⭐  *************/
  /// Builds a list of recent trips
  ///
  /// This widget takes a list of trips and renders them into a list
  /// of trip summaries. Each summary includes the start and end
  /// locations, the mode of transportation, the distance traveled,
  /// and the eco score associated with the trip. If the list of trips
  /// is empty, this widget will render a message indicating that
  /// *****  bc86a668-9898-4c3a-9c3c-127897343ea4  ******
  Widget _buildRecentTrips(Map<String, dynamic> data) {
    final trips = data['recent_trips'] as List<dynamic>;
    print("FRONTEND TRIPS: $trips");

    if (trips.isEmpty) {
      return const Text(
        "No trips yet",
        style: TextStyle(color: Colors.white),
      );
    }

    return GlowCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: List.generate(trips.length, (i) {
          final t = trips[i];

          final modeMap = {
            0: "Car 🚗",
            1: "Bus 🚌",
            2: "Train 🚆",
            3: "Bike 🚲",
            4: "Walk 🚶"
          };

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              border: i < trips.length - 1
                  ? Border(
                      bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    )
                  : null,
            ),
            child: Row(
              children: [
                const Icon(Icons.navigation, color: Colors.green, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${t['start']} → ${t['destination']}",
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        "${modeMap[t['mode']] ?? 'Unknown'} • ${t['distance']} km",
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  "${t['eco_score']}/100",
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTipSlider(int currentIndex) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2030), Color(0xFF1A3A50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentBlue.withOpacity(0.25)),
        boxShadow: AppTheme.blueGlow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: PageView.builder(
          controller: _tipPageController,
          onPageChanged: (index) {
            _tipIndexNotifier.value = index;
          },
          itemCount: _tips.length,
          itemBuilder: (context, index) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(11)),
                    child: const Text('💡', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('SMART TIP',
                            style: TextStyle(
                                color: AppTheme.accentBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 3),
                        Text(_tips[index],
                            style: const TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 12,
                                height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTipDots(int currentIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_tips.length, (i) {
        final active = i == currentIndex;
        return GestureDetector(
          onTap: () {
            if (!_tipPageController.hasClients) return;
            _tipPageController.animateToPage(
              i,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
            _tipIndexNotifier.value = i;
            // Restart timer when manually changed
            _startTipTimer();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? AppTheme.primaryGreen : AppTheme.textFaint,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}
