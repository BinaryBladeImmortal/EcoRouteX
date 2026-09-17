// lib/models/mobility_model.dart
// EcoRouteX – AI Mobility Recommendation Engine (Phase 1 Simulation)

class TripInput {
  final String origin;
  final String destination;
  final double distanceKm;
  final String timeOfDay; // Morning / Afternoon / Evening
  final String weather; // Sunny / Rainy / Cloudy
  final String preference; // Fastest / Cheapest / Eco Friendly

  TripInput({
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.timeOfDay,
    required this.weather,
    required this.preference,
  });
}

class TransportOption {
  final String mode;
  final String emoji;
  final int travelMinutes;
  final int ecoScore; // 0–100
  final String costRange;
  final String reason;
  final bool isRecommended;

  TransportOption({
    required this.mode,
    required this.emoji,
    required this.travelMinutes,
    required this.ecoScore,
    required this.costRange,
    required this.reason,
    this.isRecommended = false,
  });
}

class TripRecommendation {
  final TransportOption best;
  final List<TransportOption> alternatives;
  final String aiExplanation;
  final int mobilityScore;
  final String tripLabel;

  TripRecommendation({
    required this.best,
    required this.alternatives,
    required this.aiExplanation,
    required this.mobilityScore,
    required this.tripLabel,
  });
}

// ── AI Recommendation Engine ───────────────────────────────
class MobilityAdvisor {
  static TripRecommendation analyze(TripInput input) {
    final d = input.distanceKm;
    final isRainy = input.weather == 'Rainy';
    final isMorning = input.timeOfDay == 'Morning';
    final isEco = input.preference == 'Eco Friendly';
    final isFast = input.preference == 'Fastest';

    // Generate all options based on distance + conditions
    final allOptions = _generateOptions(d, isRainy, isMorning, isEco, isFast);

    // Sort by preference
    List<TransportOption> sorted = List.from(allOptions);
    if (isEco) {
      sorted.sort((a, b) => b.ecoScore.compareTo(a.ecoScore));
    } else if (isFast) {
      sorted.sort((a, b) => a.travelMinutes.compareTo(b.travelMinutes));
    } else {
      // Cheapest
      sorted.sort((a, b) => a.costRange.compareTo(b.costRange));
    }

    final best = TransportOption(
      mode: sorted[0].mode,
      emoji: sorted[0].emoji,
      travelMinutes: sorted[0].travelMinutes,
      ecoScore: sorted[0].ecoScore,
      costRange: sorted[0].costRange,
      reason: sorted[0].reason,
      isRecommended: true,
    );

    final alternatives = sorted.skip(1).take(3).toList();

    final explanation = _generateExplanation(best, input);
    final score = _calculateMobilityScore(best, input);

    return TripRecommendation(
      best: best,
      alternatives: alternatives,
      aiExplanation: explanation,
      mobilityScore: score,
      tripLabel: '${input.origin} → ${input.destination}',
    );
  }

  static List<TransportOption> _generateOptions(
      double d, bool isRainy, bool isMorning, bool isEco, bool isFast) {
    final options = <TransportOption>[];

    // Walking — only under 2 km
    if (d <= 2.5) {
      options.add(TransportOption(
        mode: 'Walking',
        emoji: '🚶',
        travelMinutes: (d * 12).round(),
        ecoScore: 100,
        costRange: 'Free',
        reason: 'Zero emissions, healthy and free for short distances.',
      ));
    }

    // Bike — under 10 km, not rainy
    if (d <= 10 && !isRainy) {
      options.add(TransportOption(
        mode: 'Bike',
        emoji: '🚲',
        travelMinutes: (d * 3.5).round(),
        ecoScore: 98,
        costRange: 'Free – ₹50',
        reason: 'Most eco-friendly option, great for medium distances.',
      ));
    }

    // Metro — 3 km and above
    if (d >= 3) {
      options.add(TransportOption(
        mode: 'Metro',
        emoji: '🚆',
        travelMinutes: (d * 2.2 + (isMorning ? 5 : 0)).round(),
        ecoScore: 88,
        costRange: '₹20 – ₹60',
        reason: 'Fast, reliable and low emissions. Best for city travel.',
      ));
    }

    // Bus — always available
    options.add(TransportOption(
      mode: 'Bus',
      emoji: '🚌',
      travelMinutes: (d * 3.8 + (isMorning ? 10 : 0)).round(),
      ecoScore: 72,
      costRange: '₹10 – ₹40',
      reason: 'Affordable shared transport with moderate emissions.',
    ));

    // Car — always available
    options.add(TransportOption(
      mode: 'Car',
      emoji: '🚗',
      travelMinutes: (d * 2.0 + (isMorning ? 8 : 0)).round(),
      ecoScore: 28,
      costRange: '₹80 – ₹200',
      reason: 'Convenient but highest emissions and cost.',
    ));

    // Auto Rickshaw
    if (d <= 15) {
      options.add(TransportOption(
        mode: 'Auto',
        emoji: '🛺',
        travelMinutes: (d * 2.5).round(),
        ecoScore: 45,
        costRange: '₹50 – ₹150',
        reason: 'Flexible door-to-door option for moderate distances.',
      ));
    }

    return options;
  }

  static String _generateExplanation(TransportOption best, TripInput input) {
    final timeNote =
        input.timeOfDay == 'Morning' ? 'During morning peak hours, ' : '';
    final weatherNote =
        input.weather == 'Rainy' ? 'Given the rainy weather, ' : '';
    final prefNote = input.preference == 'Eco Friendly'
        ? 'prioritizing eco-friendliness'
        : input.preference == 'Fastest'
            ? 'prioritizing travel speed'
            : 'prioritizing cost efficiency';

    return '$weatherNote$timeNote${best.emoji} ${best.mode} is your best option for this ${input.distanceKm.toStringAsFixed(1)} km trip while $prefNote. ${best.reason}';
  }

  static int _calculateMobilityScore(TransportOption best, TripInput input) {
    int score = best.ecoScore;
    if (input.preference == 'Eco Friendly' && best.ecoScore > 80)
      score = (score * 1.1).round();
    if (input.weather == 'Rainy' && best.mode != 'Car')
      score = (score * 0.9).round();
    return score.clamp(0, 100);
  }
}

// ── Chat Message Model ─────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({required this.text, required this.isUser, required this.time});
}

// ── AI Chat Response Engine ────────────────────────────────
class AIChatAdvisor {
  static String respond(String userMessage) {
    final msg = userMessage.toLowerCase().trim();

    if (msg == 'time' ||
        msg == 'what is time' ||
        msg == 'what is the time' ||
        msg == 'what time is it' ||
        _containsAny(msg, ['current time', 'local time'])) {
      return '🕒 The current local time is ${_currentTime()}. For trip duration or the best time to travel, ask about travel time or rush hour.';
    }

    if (_containsAny(msg, ['hello', 'hi', 'hey'])) {
      return "👋 Hello! I'm your EcoRouteX AI Mobility Advisor. Ask me anything about travel options, best routes, eco-friendly choices, or how to save money on your commute!";
    }

    if (_containsAny(msg, [
      'fun things to do',
      'things to do',
      'fun places',
      'place to visit',
      'places to visit',
      'tourist places',
      'weekend plans',
      'weekend trip',
      'what can i do'
    ])) {
      return "🎉 For a fun Mumbai outing, consider a walk along Marine Drive, visiting Gateway of India and Colaba, exploring Bandra's waterfront, or spending time at Juhu Beach. Use Plan Trip to compare the most convenient and eco-friendly way to get there.";
    }

    if (_containsAny(msg, ['car vs metro', 'car or metro', 'metro vs car']) ||
        (_containsAny(msg, ['car']) &&
            _containsAny(msg, ['metro', 'train']) &&
            _containsAny(msg, ['better', 'compare', 'versus', 'vs']))) {
      return "⚖️ For a longer Mumbai commute, Metro or suburban rail is usually faster, cheaper, and cleaner than Car. Car is more convenient for short trips, heavy luggage, or places without good transit. The Plan Trip screen can compare your exact route.";
    }

    if (_containsAny(msg, ['safe', 'safety', 'dangerous', 'secure']) &&
        _containsAny(msg,
            ['bike', 'bicycle', 'cycle', 'walk', 'walking', 'night', 'dark'])) {
      return "🛡️ For night travel, use well-lit roads, wear visible clothing, use a helmet when cycling, and share your route. Prefer a trusted public-transit option if the road feels isolated or unsafe.";
    }

    if (_containsAny(
        msg, ['rain', 'rainy', 'weather', 'monsoon', 'storm', 'hot', 'heat'])) {
      return "🌧️ Weather affects travel: Metro or Bus is usually more comfortable in rain, while cycling and walking are better on clear days. Leave extra time during heavy rain and check local conditions before starting.";
    }

    if (_containsAny(msg, [
      'cost',
      'price',
      'fare',
      'cheap',
      'cheapest',
      'money',
      'budget',
      'expensive',
      'how much'
    ])) {
      return "💰 For low-cost travel, Walk and Bike are cheapest for short trips, followed by Bus and Metro. Auto and Car usually cost more. Fares vary by route, so enter your trip in Plan Trip for a route-specific recommendation.";
    }

    if (_containsAny(msg, [
      'rush hour',
      'peak hour',
      'peak hours',
      'morning commute',
      'evening commute',
      'at night',
      'night travel',
      'late night',
      'morning',
      'evening'
    ])) {
      return "🕒 During Mumbai rush hours, Metro or suburban rail avoids much road congestion. At night, choose a well-lit route and a reliable mode, and allow extra time for reduced service frequency.";
    }

    if (_containsAny(msg, [
      'virar',
      'churchgate',
      'andheri',
      'bandra',
      'thane',
      'dadar',
      'borivali',
      'dahisar',
      'powai',
      'colaba',
      'nalasopara',
      'vasai',
      'ghatkopar',
      'lower parel',
      'worli',
      'juhu',
      'vile parle'
    ])) {
      return "📍 I can help compare travel options between Mumbai locations. For places such as Virar, Churchgate, Andheri, Bandra, Thane, or Powai, enter the exact origin and destination in Plan Trip so the route distance and recommendation are calculated.";
    }

    if (_containsAny(msg, [
      'eco',
      'environment',
      'green',
      'carbon',
      'co2',
      'emission',
      'sustainable',
      'pollution'
    ])) {
      return "🌱 Walking and cycling have the lowest emissions, followed by Metro and Bus. Replacing regular Car trips with public transport can reduce both CO₂ and congestion. Plan Trip estimates the CO₂ impact for your selected route.";
    }

    if (_containsAny(msg, [
      'fastest',
      'fast',
      'quick',
      'quickest',
      'speed',
      'traffic',
      'travel time',
      'how long'
    ])) {
      return "⚡ For longer urban trips, Metro or suburban rail often beats Car because it avoids traffic. Car can be faster for short trips when roads are clear. Enter your route in Plan Trip for a personalized result.";
    }

    if (_containsAny(
        msg, ['college', 'university', 'school', 'office', 'commute'])) {
      return "🎓 For a regular commute, Metro or Bus is often practical during peak hours. For trips under about 5 km, cycling can be economical and healthy. Enter the route in Plan Trip for a more specific recommendation.";
    }

    if (_containsAny(msg, ['bike', 'bicycle', 'cycling', 'cycle'])) {
      return "🚲 Cycling works well for short trips, especially on clear days. Use a helmet, choose safer roads, and avoid cycling in heavy rain or unsafe traffic conditions.";
    }

    if (_containsAny(msg, ['metro', 'train', 'subway', 'rail'])) {
      return "🚆 Metro or suburban rail is usually a strong choice for medium and long urban trips: it avoids road traffic, has predictable travel time, and produces less CO₂ than Car.";
    }

    if (_containsAny(msg, ['car', 'drive', 'driving'])) {
      return "🚗 Car is convenient for short trips, heavy luggage, or areas with limited transit, but it usually costs and pollutes more. Consider Metro or Bus for regular urban commutes.";
    }

    if (_containsAny(msg, ['walk', 'walking', 'on foot'])) {
      return "🚶 Walking is ideal for short trips under about 2 km. It is free, healthy, and emission-free. For longer distances, consider cycling or public transport.";
    }

    if (_containsAny(msg,
        ['best', 'recommend', 'suggest', 'which mode', 'what should i take'])) {
      return "🤖 To give you the best recommendation, head to the Plan Trip screen and enter your route details. I'll analyze distance, time, weather and your preference to find the smartest option for you!";
    }

    return "🤔 I can only help with travel-related questions. Ask me about transport costs, weather and route choices, safety, travel time, or eco-friendly modes.";
  }

  static String _currentTime() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  static bool _containsAny(String message, List<String> phrases) {
    return phrases.any((phrase) {
      final pattern = RegExp(
        r'(?<!\w)' + RegExp.escape(phrase) + r'(?!\w)',
      );
      return pattern.hasMatch(message);
    });
  }
}

// ── Sample Weekly Data ─────────────────────────────────────
class WeeklyTripData {
  final String day;
  final double distanceKm;
  final String mode;
  WeeklyTripData(this.day, this.distanceKm, this.mode);
}

final List<WeeklyTripData> sampleWeeklyTrips = [
  WeeklyTripData('Mon', 12.0, 'Metro'),
  WeeklyTripData('Tue', 8.5, 'Bike'),
  WeeklyTripData('Wed', 15.0, 'Metro'),
  WeeklyTripData('Thu', 6.0, 'Bus'),
  WeeklyTripData('Fri', 12.0, 'Metro'),
  WeeklyTripData('Sat', 4.0, 'Bike'),
  WeeklyTripData('Sun', 2.5, 'Walk'),
];

final Map<String, double> sampleModeUsage = {
  'Metro': 40.0,
  'Bike': 25.0,
  'Bus': 18.0,
  'Walk': 10.0,
  'Car': 7.0,
};

// ── Achievements ───────────────────────────────────────────
class Achievement {
  final String title, description, emoji;
  final bool earned;
  final int progress;
  Achievement(
      {required this.title,
      required this.description,
      required this.emoji,
      required this.earned,
      required this.progress});
}

final List<Achievement> sampleAchievements = [
  Achievement(
      title: 'Green Commuter',
      description: 'Use eco transport 10 times',
      emoji: '🌱',
      earned: true,
      progress: 100),
  Achievement(
      title: 'Eco Traveler',
      description: 'Travel 100 km by transit',
      emoji: '🚆',
      earned: true,
      progress: 100),
  Achievement(
      title: 'Carbon Saver',
      description: 'Avoid car for 7 days',
      emoji: '💚',
      earned: false,
      progress: 71),
  Achievement(
      title: 'City Explorer',
      description: 'Try all 5 transport modes',
      emoji: '🗺️',
      earned: false,
      progress: 60),
  Achievement(
      title: 'Speed Commuter',
      description: 'Complete 20 metro trips',
      emoji: '⚡',
      earned: false,
      progress: 35),
  Achievement(
      title: 'Smart Traveler',
      description: 'Use AI advisor 15 times',
      emoji: '🤖',
      earned: false,
      progress: 20),
];
