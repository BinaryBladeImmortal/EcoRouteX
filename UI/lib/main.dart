// lib/main.dart
// EcoRouteX – AI Powered Smart Mobility Advisor
// Phase 1 UI Prototype

import 'package:flutter/material.dart';
import 'utils/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/plan_trip_screen.dart';
import 'screens/ai_advisor_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/about_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // SystemChrome.setSystemUIOverlayStyle(
  //   const SystemUiOverlayStyle(
  //     statusBarColor: Colors.transparent,
  //     statusBarIconBrightness: Brightness.light,
  //     systemNavigationBarColor: Color(0xFF1A2D3E),
  //   ),
  // );
  runApp(const EcoRouteXApp());
}

class EcoRouteXApp extends StatelessWidget {
  const EcoRouteXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoRouteX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const MainShell(),
    );
  }
}

// ── Main Shell with Bottom Navigation ─────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _navigateTo(int index) => setState(() => _currentIndex = index);

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(
        onNavigate: _navigateTo,
        onAboutTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AboutScreen()),
        ),
      ),
      const PlanTripScreen(),
      const AiAdvisorScreen(),
      const InsightsScreen(),
      const DashboardScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          border: Border(
              top: BorderSide(color: AppTheme.textFaint.withOpacity(0.2))),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -4))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppTheme.primaryGreen,
          unselectedItemColor: AppTheme.textFaint,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w400, fontSize: 10),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.navigation_outlined),
                activeIcon: Icon(Icons.navigation_rounded),
                label: 'Plan Trip'),
            BottomNavigationBarItem(
                icon: Icon(Icons.auto_awesome_outlined),
                activeIcon: Icon(Icons.auto_awesome_rounded),
                label: 'AI Advisor'),
            BottomNavigationBarItem(
                icon: Icon(Icons.insights_outlined),
                activeIcon: Icon(Icons.insights_rounded),
                label: 'Insights'),
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard_rounded),
                label: 'Dashboard'),
          ],
        ),
      ),
    );
  }
}
