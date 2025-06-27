import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:biketrack/ui/screens/home_screen.dart';
import 'package:biketrack/ui/screens/history_screen.dart';
import 'package:biketrack/ui/screens/alerts_screen.dart';
import 'package:biketrack/ui/screens/settings_screen.dart';
import 'package:biketrack/ui/screens/safety_screen.dart';
import 'package:biketrack/ui/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  await Supabase.initialize(
    url: 'https://oynnjhnjyeogltujthcy.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95bm5qaG5qeWVvZ2x0dWp0aGN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAzMzIwNTgsImV4cCI6MjA2NTkwODA1OH0.eP28KmebtF0AmUdkUcnzLuRhl4uMnkYJfIaHZ4nHFl4',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _loading = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    setState(() {
      _loggedIn = session != null;
      _loading = false;
    });

    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      final current = Supabase.instance.client.auth.currentSession;
      setState(() {
        _loggedIn = current != null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      title: 'BikeTrack',
      theme: ThemeData(primarySwatch: Colors.blue),
      darkTheme: ThemeData.light(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: _loggedIn ? const MainScreen() : const LoginPage(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    const HomeScreen(),
    const HistoryScreen(),
    const AlertsScreen(),
    const SafetyScreen(),
    const SettingsScreen(),
  ];


  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historique',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bike),
            label: 'Alertes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emergency),
            label: 'Urgence',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}
