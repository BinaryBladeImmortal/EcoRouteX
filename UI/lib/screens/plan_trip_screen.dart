// lib/screens/plan_trip_screen.dart
// EcoRouteX – Plan Trip (Enhanced with Map UI + Trip Timeline)

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/mobility_widgets.dart';
import '../models/mobility_model.dart';
import 'recommendation_screen.dart';
import '../services/api_service.dart';
import '../services/map_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class PlanTripScreen extends StatefulWidget {
  const PlanTripScreen({super.key});

  @override
  State<PlanTripScreen> createState() => _PlanTripScreenState();
}

class _PlanTripScreenState extends State<PlanTripScreen>
    with SingleTickerProviderStateMixin {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _distCtrl = TextEditingController();
  final TextEditingController startController = TextEditingController();
  final TextEditingController destController = TextEditingController();

  String _timeOfDay = 'Morning';
  String _weather = 'Sunny';
  String _preference = 'Eco Friendly';
  bool _routeDrawn = false;
  bool _isAnalyzing = false;

  late AnimationController _mapCtrl;
  late Animation<double> _routeAnim;

  // Photon + OSRM state
  List<dynamic> _originSuggestions = [];
  List<dynamic> _destSuggestions = [];
  Timer? _originDebounce;
  Timer? _destDebounce;
  Timer? _routeTimer;
  double? _originLat;
  double? _originLon;
  double? _destLat;
  double? _destLon;
  bool _showOriginSuggestions = false;
  bool _showDestSuggestions = false;
  bool _isCalculatingDistance = false;

  // Map state
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];

  static const _times = ['Morning', 'Afternoon', 'Evening'];
  static const _weathers = ['Sunny', 'Cloudy', 'Rainy'];
  static const _preferences = ['Eco Friendly', 'Fastest', 'Cheapest'];

  static const Map<String, String> _weatherEmoji = {
    'Sunny': '☀️',
    'Cloudy': '☁️',
    'Rainy': '🌧️'
  };
  static const Map<String, String> _timeEmoji = {
    'Morning': '🌅',
    'Afternoon': '🌤️',
    'Evening': '🌆'
  };
  static const Map<String, String> _prefEmoji = {
    'Eco Friendly': '🌱',
    'Fastest': '⚡',
    'Cheapest': '💰'
  };
  static const Map<String, Color> _prefColors = {
    'Eco Friendly': AppTheme.primaryGreen,
    'Fastest': AppTheme.accentBlue,
    'Cheapest': AppTheme.accentAmber,
  };

  @override
  void initState() {
    super.initState();
    _mapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _routeAnim = CurvedAnimation(parent: _mapCtrl, curve: Curves.easeInOut);
    _routeTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _routeDrawn = true);
      _mapCtrl.forward();
    });
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _distCtrl.dispose();
    _mapCtrl.dispose();
    _mapController.dispose();
    startController.dispose();
    destController.dispose();
    _originDebounce?.cancel();
    _destDebounce?.cancel();
    _routeTimer?.cancel();
    super.dispose();
  }

  // ── Load real route on map ────────────────────────────────
  Future<void> _loadRoute() async {
    if (_originLat == null ||
        _originLon == null ||
        _destLat == null ||
        _destLon == null) {
      return;
    }

    final start = LatLng(_originLat!, _originLon!);
    final end = LatLng(_destLat!, _destLon!);

    final route = await MapService.getRoute(start, end);

    if (mounted) {
      setState(() {
        _routePoints = route;
      });

      // Fit map after UI builds (critical for flutter_map)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitMapToRoute();
      });
    }
  }

  // ── Fit map bounds to show entire route ────────────────────
  void _fitMapToRoute() {
    if (_routePoints.isEmpty) {
      // Fallback: just center on origin if no route
      if (_originLat != null && _originLon != null) {
        _mapController.move(
          LatLng(_originLat!, _originLon!),
          14,
        );
      }
      return;
    }

    // If only one point, just center on it
    if (_routePoints.length < 2) {
      _mapController.move(_routePoints.first, 14);
      return;
    }

    final bounds = LatLngBounds.fromPoints(_routePoints);

    // Use fitCamera for newer flutter_map versions
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
        maxZoom: 16,
      ),
    );
  }

  // ── Photon API: Fetch location suggestions ─────────────────
  Future<List<dynamic>> _fetchPhotonSuggestions(String query) async {
    if (query.length < 2) return [];
    try {
      final res = await http.get(
        Uri.parse('https://photon.komoot.io/api/?q=$query&limit=5'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data['features'] ?? [];
      }
    } catch (e) {
      debugPrint('Photon API error: $e');
    }
    return [];
  }

  // ── OSRM: Calculate distance between coordinates ───────────
  Future<double?> _calculateOSRMDistance(
      double lon1, double lat1, double lon2, double lat2) async {
    try {
      final res = await http.get(
        Uri.parse(
            'https://router.project-osrm.org/route/v1/driving/$lon1,$lat1;$lon2,$lat2?overview=false'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final meters = data['routes'][0]['distance'] as num;
          return meters / 1000; // Convert to km
        }
      }
    } catch (e) {
      debugPrint('OSRM API error: $e');
    }
    return null;
  }

  // ── Calculate and update distance ──────────────────────────
  Future<void> _updateDistance() async {
    if (_originLat == null ||
        _originLon == null ||
        _destLat == null ||
        _destLon == null) {
      return;
    }

    setState(() => _isCalculatingDistance = true);

    final distance = await _calculateOSRMDistance(
        _originLon!, _originLat!, _destLon!, _destLat!);

    if (distance != null && mounted) {
      setState(() {
        _distCtrl.text = distance.toStringAsFixed(1);
        _isCalculatingDistance = false;
      });
    } else {
      setState(() => _isCalculatingDistance = false);
    }
  }

  // ── Select origin from suggestion ───────────────────────────
  void _selectOrigin(dynamic feature) {
    final coords = feature['geometry']['coordinates'] as List;
    final props = feature['properties'] as Map;
    final name = props['name'] ?? props['street'] ?? 'Unknown';

    setState(() {
      _originLon = coords[0] as double;
      _originLat = coords[1] as double;
      _originCtrl.text = name;
      _originSuggestions = [];
      _showOriginSuggestions = false;
    });

    _updateDistance();
  }

  // ── Select destination from suggestion ──────────────────────
  void _selectDestination(dynamic feature) async {
    final coords = feature['geometry']['coordinates'] as List;
    final props = feature['properties'] as Map;
    final name = props['name'] ?? props['street'] ?? 'Unknown';

    setState(() {
      _destLon = coords[0] as double;
      _destLat = coords[1] as double;
      _destCtrl.text = name;
      _destSuggestions = [];
      _showDestSuggestions = false;
    });

    // Update distance and load route on map
    await _updateDistance();
    await _loadRoute();
  }

  void _analyze() async {
    setState(() => _isAnalyzing = true);

    // Load real route on map first
    await _loadRoute();

    try {
      final distance = double.tryParse(_distCtrl.text) ?? 8.0;
      final estimatedDuration = (distance / 50 * 60 + 10).round();

      // ✅ ADD THESE HERE
      final weatherMap = {'Sunny': 0, 'Cloudy': 1, 'Rainy': 2};
      final timeMap = {'Morning': 9, 'Afternoon': 14, 'Evening': 18};
      final prefMap = {'Eco Friendly': 0, 'Fastest': 1, 'Cheapest': 2};

      final input = TripInput(
        origin: _originCtrl.text.isEmpty ? 'Origin' : _originCtrl.text,
        destination: _destCtrl.text.isEmpty ? 'Destination' : _destCtrl.text,
        distanceKm: distance,
        timeOfDay: _timeOfDay,
        weather: _weather,
        preference: _preference,
      );

      final apiResult = await ApiService.planTrip(
        distance: input.distanceKm,
        duration: estimatedDuration,
        weather: weatherMap[input.weather] ?? 0,
        timeOfDay: timeMap[input.timeOfDay] ?? 9,
        preference: prefMap[input.preference] ?? 0,
        origin: input.origin,
        destination: input.destination,
      );

      // Create TripRecommendation from API result
      final bestOption = TransportOption(
        mode: apiResult['best_mode'],
        emoji: _getModeEmoji(apiResult['best_mode']),
        travelMinutes: (apiResult['duration'] as num).round(),
        ecoScore: apiResult['eco_score'],
        costRange: _estimateCostRange(apiResult['best_mode'], distance),
        reason: _estimateModeReason(apiResult['best_mode']),
        isRecommended: true,
      );

      final result = TripRecommendation(
        best: bestOption,
        alternatives: [], // empty for now
        aiExplanation:
            'Based on your ${distance}km trip, ${apiResult['best_mode']} is the optimal choice with ${apiResult['co2']}kg CO₂ emissions.',
        mobilityScore: 85, // hardcoded
        tripLabel: 'Eco Trip',
      );

      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  RecommendationScreen(input: input, result: result)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _getModeEmoji(String mode) {
    const emojis = {
      'Car': '🚗',
      'Bus': '🚌',
      'Metro': '🚇',
      'Bike': '🚲',
      'Walk': '🚶',
    };
    return emojis[mode] ?? '🚗';
  }

  String _estimateCostRange(String mode, double distance) {
    switch (mode) {
      case 'Walk':
        return 'Free';
      case 'Bike':
        final maxCost = (distance * 8).round().clamp(5, 50);
        return 'Free – ₹$maxCost';
      case 'Metro':
        final maxCost = (15 + distance * 2.5).round();
        return '₹20 – ₹$maxCost';
      case 'Bus':
        final maxCost = (10 + distance * 4).round();
        return '₹10 – ₹$maxCost';
      case 'Car':
        final minCost = (distance * 12 + 20).round();
        final maxCost = (distance * 25 + 40).round();
        return '₹$minCost – ₹$maxCost';
      default:
        return '₹50 – ₹150';
    }
  }

  String _estimateModeReason(String mode) {
    switch (mode) {
      case 'Walk':
        return 'Walking is ideal for short trips and produces zero emissions.';
      case 'Bike':
        return 'Cycling is eco-friendly and often faster for short urban distances.';
      case 'Metro':
        return 'Train is fast, dependable, and low-emission for city travel.';
      case 'Bus':
        return 'Bus travel is affordable and widely available for most routes.';
      case 'Car':
        return 'Car is convenient for speed and comfort, but has higher cost and emissions.';
      default:
        return 'AI recommended based on your preference and trip details.';
    }
  }

  void _onRouteChanged() {
    _mapCtrl.reset();
    _mapCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildMapSection()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildTripSummaryCard(),
                  const SizedBox(height: 14),
                  _buildRouteInputCard(),
                  const SizedBox(height: 14),
                  _buildConditionsCard(),
                  const SizedBox(height: 14),
                  _buildPreferenceCard(),
                  const SizedBox(height: 14),
                  _buildTripTimeline(),
                  const SizedBox(height: 24),
                  _buildAnalyzeButton(),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text('Powered by EcoRouteX AI Engine',
                        style:
                            TextStyle(color: AppTheme.textFaint, fontSize: 11)),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Real Map Section with Route ───────────────────────────
  Widget _buildMapSection() {
    final hasRoute = _routePoints.isNotEmpty;
    final hasOrigin = _originLat != null && _originLon != null;
    final hasDest = _destLat != null && _destLon != null;

    return Container(
      height: 240,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(19.3919, 72.8397), // Virar default
            initialZoom: 12,
            minZoom: 5,
            maxZoom: 18,
            interactionOptions: InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            // 🌍 Map tiles (OpenStreetMap)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.ecoroutex',
            ),

            // 🟢 Route polyline
            if (hasRoute)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 4,
                    color: AppTheme.primaryGreen,
                  ),
                ],
              ),

            // 📍 Markers
            MarkerLayer(
              markers: [
                if (hasOrigin)
                  Marker(
                    point: LatLng(_originLat!, _originLon!),
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),
                if (hasDest)
                  Marker(
                    point: LatLng(_destLat!, _destLon!),
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.green,
                      size: 30,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Trip Summary Card ─────────────────────────────────────
  Widget _buildTripSummaryCard() {
    final dist = double.tryParse(_distCtrl.text) ?? 8.0;
    final mins = (dist * 2.5).round();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.25)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.summarize_rounded,
              color: AppTheme.primaryGreen, size: 18),
          const SizedBox(width: 10),
          const Text('TRIP SUMMARY',
              style: TextStyle(
                  color: AppTheme.primaryGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const Spacer(),
          InfoChip(
              label: '${_distCtrl.text} km',
              color: AppTheme.accentBlue,
              icon: Icons.straighten_rounded),
          const SizedBox(width: 8),
          InfoChip(
              label: '~$mins min',
              color: AppTheme.accentAmber,
              icon: Icons.access_time_rounded),
        ],
      ),
    );
  }

  // ── Route Input Card ──────────────────────────────────────
  Widget _buildRouteInputCard() {
    return GlowCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('📍 Your Route', 'Where are you going?'),
          const SizedBox(height: 14),
          _locationFieldWithSuggestions(
            controller: _originCtrl,
            label: 'Start Location',
            hint: 'Type to search...',
            color: AppTheme.accentBlue,
            icon: Icons.my_location_rounded,
            suggestions: _originSuggestions,
            showSuggestions: _showOriginSuggestions,
            onChanged: (value) {
              _originDebounce?.cancel();
              _originDebounce =
                  Timer(const Duration(milliseconds: 400), () async {
                final results = await _fetchPhotonSuggestions(value);
                if (mounted) {
                  setState(() {
                    _originSuggestions = results;
                    _showOriginSuggestions = results.isNotEmpty;
                  });
                }
              });
            },
            onSelect: _selectOrigin,
            onTapOutside: () => setState(() => _showOriginSuggestions = false),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  final tmp = _originCtrl.text;
                  _originCtrl.text = _destCtrl.text;
                  _destCtrl.text = tmp;
                  _onRouteChanged();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppTheme.primaryGreen.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.swap_vert_rounded,
                      color: AppTheme.primaryGreen, size: 16),
                ),
              ),
            ),
          ),
          _locationFieldWithSuggestions(
            controller: _destCtrl,
            label: 'Destination',
            hint: 'Type to search...',
            color: AppTheme.primaryGreen,
            icon: Icons.location_on_rounded,
            suggestions: _destSuggestions,
            showSuggestions: _showDestSuggestions,
            onChanged: (value) {
              _destDebounce?.cancel();
              _destDebounce =
                  Timer(const Duration(milliseconds: 400), () async {
                final results = await _fetchPhotonSuggestions(value);
                if (mounted) {
                  setState(() {
                    _destSuggestions = results;
                    _showDestSuggestions = results.isNotEmpty;
                  });
                }
              });
            },
            onSelect: _selectDestination,
            onTapOutside: () => setState(() => _showDestSuggestions = false),
          ),
          const SizedBox(height: 14),
          _locationField(
            controller: _distCtrl,
            label: 'Distance',
            hint: _isCalculatingDistance ? 'Calculating...' : 'Auto or manual',
            color: AppTheme.accentAmber,
            icon: Icons.straighten_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffix: _isCalculatingDistance ? '...' : 'km',
            onChanged: (_) => setState(() {}),
            readOnly: _isCalculatingDistance,
          ),
        ],
      ),
    );
  }

  Widget _locationField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Color color,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? suffix,
    ValueChanged<String>? onChanged,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
          onChanged: onChanged,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: color.withOpacity(0.7), size: 16),
            suffixText: suffix,
            suffixStyle: const TextStyle(color: AppTheme.textSoft),
          ),
        ),
      ],
    );
  }

  Widget _locationFieldWithSuggestions({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Color color,
    required IconData icon,
    required List<dynamic> suggestions,
    required bool showSuggestions,
    required ValueChanged<String> onChanged,
    required Function(dynamic) onSelect,
    required VoidCallback onTapOutside,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTapOutside,
          child: TextField(
            controller: controller,
            style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: color.withOpacity(0.7), size: 16),
              suffixIcon: showSuggestions
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.accentBlue,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
        if (showSuggestions && suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.textFaint.withOpacity(0.2)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: AppTheme.textFaint.withOpacity(0.2),
              ),
              itemBuilder: (context, index) {
                final feature = suggestions[index];
                final props = feature['properties'] as Map;
                final name = props['name'] ?? props['street'] ?? 'Unknown';
                final city = props['city'] ?? props['state'] ?? '';
                final displayName = city.isNotEmpty ? '$name, $city' : name;

                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Icon(Icons.location_on,
                      color: color.withOpacity(0.7), size: 18),
                  title: Text(
                    displayName,
                    style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onSelect(feature),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Conditions Card ───────────────────────────────────────
  Widget _buildConditionsCard() {
    return GlowCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('🌤️ Travel Conditions', 'When and what\'s the weather?'),
          const SizedBox(height: 14),
          const Text('Time of Day',
              style: TextStyle(
                  color: AppTheme.textSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _times
                .map((t) => _optionChip('${_timeEmoji[t]} $t', t == _timeOfDay,
                    AppTheme.accentAmber, () => setState(() => _timeOfDay = t)))
                .toList(),
          ),
          const SizedBox(height: 14),
          const Text('Weather',
              style: TextStyle(
                  color: AppTheme.textSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _weathers
                .map((w) => _optionChip('${_weatherEmoji[w]} $w', w == _weather,
                    AppTheme.accentBlue, () => setState(() => _weather = w)))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Preference Card ───────────────────────────────────────
  Widget _buildPreferenceCard() {
    return GlowCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('🎯 Travel Preference', 'What matters most to you?'),
          const SizedBox(height: 14),
          ..._preferences.map((pref) {
            final active = pref == _preference;
            final color = _prefColors[pref]!;
            return GestureDetector(
              onTap: () => setState(() => _preference = pref),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 9),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: active ? color.withOpacity(0.1) : AppTheme.mapDark,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                      color:
                          active ? color : AppTheme.textFaint.withOpacity(0.3),
                      width: active ? 1.5 : 1),
                ),
                child: Row(
                  children: [
                    Text(_prefEmoji[pref]!,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(pref,
                            style: TextStyle(
                                color: active ? color : AppTheme.textWhite,
                                fontWeight: FontWeight.w600,
                                fontSize: 13))),
                    Icon(
                        active
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: active ? color : AppTheme.textFaint,
                        size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Trip Timeline ─────────────────────────────────────────
  Widget _buildTripTimeline() {
    final dist = double.tryParse(_distCtrl.text) ?? 8.0;
    final List<_TimelineStep> steps = _buildTimelineSteps(dist);

    return GlowCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded,
                  color: AppTheme.primaryGreen, size: 18),
              const SizedBox(width: 8),
              Text('Trip Timeline',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              InfoChip(
                  label: '${steps.fold(0, (s, e) => s + e.minutes)} min total',
                  color: AppTheme.accentAmber),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (i) {
            final step = steps[i];
            final isLast = i == steps.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: step.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: step.color.withOpacity(0.4),
                                blurRadius: 6)
                          ],
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 44,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [step.color, steps[i + 1].color],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.location,
                            style: const TextStyle(
                                color: AppTheme.textWhite,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        if (!isLast) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(step.modeEmoji,
                                  style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 5),
                              Text('${step.mode} · ${step.minutes} min',
                                  style: TextStyle(
                                      color: step.color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  List<_TimelineStep> _buildTimelineSteps(double dist) {
    if (dist <= 2) {
      return [
        _TimelineStep(_originCtrl.text, '', '', 0, AppTheme.accentBlue),
        _TimelineStep(_destCtrl.text, 'Walk', '🚶', (dist * 12).round(),
            AppTheme.primaryGreen),
      ];
    } else if (dist <= 5) {
      return [
        _TimelineStep(_originCtrl.text, '', '', 0, AppTheme.accentBlue),
        _TimelineStep('Nearby Station', 'Walk', '🚶', 5, AppTheme.accentAmber),
        _TimelineStep(_destCtrl.text, 'Bike / Bus', '🚲', (dist * 3).round(),
            AppTheme.primaryGreen),
      ];
    } else {
      return [
        _TimelineStep(_originCtrl.text, '', '', 0, AppTheme.accentBlue),
        _TimelineStep('Train Station', 'Walk', '🚶', 5, AppTheme.accentAmber),
        _TimelineStep('City Center', 'Train', '🚆', (dist * 1.8).round(),
            AppTheme.accentBlue),
        _TimelineStep(_destCtrl.text, 'Walk', '🚶', 4, AppTheme.primaryGreen),
      ];
    }
  }

  // ── Analyze Button ────────────────────────────────────────
  Widget _buildAnalyzeButton() {
    return GestureDetector(
      onTap: _isAnalyzing ? null : _analyze,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient: _isAnalyzing
              ? LinearGradient(colors: [
                  AppTheme.primaryGreen.withOpacity(0.5),
                  AppTheme.secondaryGreen.withOpacity(0.5)
                ])
              : AppTheme.greenGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _isAnalyzing ? [] : AppTheme.greenGlow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _isAnalyzing
              ? [
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primaryDark)),
                  const SizedBox(width: 12),
                  const Text('Analyzing Route...',
                      style: TextStyle(
                          color: AppTheme.primaryDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ]
              : [
                  const Icon(Icons.auto_awesome_rounded,
                      color: AppTheme.primaryDark, size: 20),
                  const SizedBox(width: 10),
                  const Text('Analyze Smart Route',
                      style: TextStyle(
                          color: AppTheme.primaryDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ],
        ),
      ),
    );
  }

  Widget _optionChip(
      String label, bool active, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : AppTheme.mapDark,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: active ? color : AppTheme.textFaint.withOpacity(0.3),
              width: active ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? color : AppTheme.textSoft,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _label(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(subtitle,
            style: const TextStyle(color: AppTheme.textSoft, fontSize: 11)),
      ],
    );
  }
}

// ── Timeline Step Model ───────────────────────────────────
class _TimelineStep {
  final String location, mode, modeEmoji;
  final int minutes;
  final Color color;
  _TimelineStep(
      this.location, this.mode, this.modeEmoji, this.minutes, this.color);
}

// ── Map Grid Painter ──────────────────────────────────────

// ── Route Painter ─────────────────────────────────────────
