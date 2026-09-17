import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  // Use localhost for desktop/web, Android emulator host for Android devices.
  static String get baseUrl {
    // Flutter Web deployed with Flask on the same Render service.
    if (kIsWeb) {
      return '';
    }

    // Android emulator → host machine.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }

    // Windows/Desktop local development.
    return 'http://127.0.0.1:5000';
  }

  static Future<Map<String, dynamic>> fetchHomeData() async {
    final response = await http.get(Uri.parse('$baseUrl/home'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load home data');
    }
  }

  static Future<Map<String, dynamic>> fetchInsightsData() async {
    final response = await http.get(Uri.parse('$baseUrl/insights'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load insights data');
    }
  }

  static Future<Map<String, dynamic>> fetchProfileData() async {
    final response = await http.get(Uri.parse('$baseUrl/profile'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load profile data');
    }
  }

  static Future<Map<String, dynamic>> planTrip({
    required double distance,
    required int duration,
    required int weather,
    required int timeOfDay,
    required int preference,
    required String origin,
    required String destination,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/plan'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "start": origin,
        "destination": destination,
        "distance": distance,
        "duration": duration,
        "weather": weather,
        "time_of_day": timeOfDay,
        "preference": preference,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to plan trip');
    }
  }

  static Future<Map<String, dynamic>> askAdvisor({
    required String message,
    Map<String, String>? lastRoute,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/advisor'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "message": message,
        if (lastRoute != null) "last_route": lastRoute,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get advisor response');
  }
}
