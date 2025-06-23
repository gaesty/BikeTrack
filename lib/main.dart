import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:biketrack/ui/screens/home_screen.dart';
import 'package:biketrack/ui/screens/history_screen.dart';
import 'package:biketrack/ui/screens/alerts_screen.dart';
import 'package:biketrack/ui/screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://oynnjhnjyeogltujthcy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95bm5qaG5qeWVvZ2x0dWp0aGN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAzMzIwNTgsImV4cCI6MjA2NTkwODA1OH0.eP28KmebtF0AmUdkUcnzLuRhl4uMnkYJfIaHZ4nHFl4',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BikeTrack',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
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

  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    HistoryScreen(),
    AlertsScreen(),
    SettingsScreen(),
  ];

  static const List<String> _titles = [
    'Accueil',
    'Historique',
    'Détection de Choc',
    'Paramètres',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
            label: 'Détection de Choc',
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
