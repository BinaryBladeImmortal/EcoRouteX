// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoroutex/main.dart';
import 'package:ecoroutex/models/mobility_model.dart';

void main() {
  testWidgets('EcoRouteX app builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const EcoRouteXApp());

    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });

  test('AI advisor keeps travel scope and avoids false positives', () {
    final outOfScope = AIChatAdvisor.respond('explain quantum physics');
    final ambiguous = AIChatAdvisor.respond('what is time');
    final metroCost = AIChatAdvisor.respond('how much does metro cost');
    final nightBike = AIChatAdvisor.respond('is it safe to bike at night');
    final comparison = AIChatAdvisor.respond('car vs metro which is better');
    final weather = AIChatAdvisor.respond("what's the weather like");
    final currentTime = AIChatAdvisor.respond('what is time');
    final funThings = AIChatAdvisor.respond('fun things to do');

    expect(outOfScope, contains('only help with travel-related questions'));
    expect(ambiguous, contains('current local time'));
    expect(metroCost, contains('low-cost travel'));
    expect(nightBike, contains('helmet'));
    expect(comparison, contains('longer Mumbai commute'));
    expect(weather, contains('Weather affects travel'));
    expect(currentTime, contains('current local time'));
    expect(funThings, contains('Mumbai outing'));
  });
}
