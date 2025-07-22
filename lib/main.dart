// Importation des packages Flutter et Supabase nécessaires
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

// Importation des écrans de l'application BikeTrack
import 'package:biketrack/ui/screens/home_screen.dart';
import 'package:biketrack/ui/screens/history_screen.dart';
import 'package:biketrack/ui/screens/alerts_screen.dart';
import 'package:biketrack/ui/screens/settings_screen.dart';
import 'package:biketrack/ui/screens/safety_screen.dart';
import 'package:biketrack/ui/screens/login_screen.dart';

/// Point d'entrée principal de l'application BikeTrack
/// Initialise la base de données Supabase et les paramètres de localisation
Future<void> main() async {
  // Assure que Flutter est initialisé avant d'utiliser les services
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialise les données de formatage des dates pour la localisation française
  await initializeDateFormatting('fr_FR', null);

  // Configuration et initialisation de Supabase avec l'URL et la clé API
  await Supabase.initialize(
    url: 'https://oynnjhnjyeogltujthcy.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95bm5qaG5qeWVvZ2x0dWp0aGN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAzMzIwNTgsImV4cCI6MjA2NTkwODA1OH0.eP28KmebtF0AmUdkUcnzLuRhl4uMnkYJfIaHZ4nHFl4',
  );

  // Lance l'application Flutter
  runApp(const MyApp());
}

/// Classe principale de l'application BikeTrack
/// Gère l'état d'authentification et navigue entre login et écran principal
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// État de l'application principale
/// Gère l'authentification utilisateur et l'affichage conditionnel des écrans
class _MyAppState extends State<MyApp> {
  // Indique si l'application est en cours de chargement
  bool _loading = true;
  // Indique si l'utilisateur est connecté
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    // Vérifie l'état de la session au démarrage
    _checkSession();
  }

  /// Vérifie l'état de la session utilisateur et configure l'écoute des changements d'authentification
  Future<void> _checkSession() async {
    // Récupère la session actuelle depuis Supabase
    final session = Supabase.instance.client.auth.currentSession;
    setState(() {
      _loggedIn = session != null;
      _loading = false;
    });

    // Écoute les changements d'état d'authentification
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      final current = Supabase.instance.client.auth.currentSession;
      setState(() {
        _loggedIn = current != null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Affichage de l'écran de chargement pendant l'initialisation
    if (_loading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Configuration de l'application avec thèmes et navigation conditionnelle
    return MaterialApp(
      title: 'BikeTrack',
      theme: ThemeData(primarySwatch: Colors.blue),
      darkTheme: ThemeData.light(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      // Navigation conditionnelle basée sur l'état de connexion
      home: _loggedIn ? const MainScreen() : const LoginPage(),
    );
  }
}

/// Écran principal avec navigation par onglets
/// Contient tous les écrans principaux de l'application BikeTrack
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

/// État de l'écran principal
/// Gère la navigation entre les différents onglets de l'application
class _MainScreenState extends State<MainScreen> {
  // Index de l'onglet actuellement sélectionné
  int _selectedIndex = 0;

  // Liste des écrans disponibles dans l'application
  late final List<Widget> _pages = [
    const HomeScreen(),        // 0 - Écran d'accueil avec carte et statut
    const HistoryScreen(),     // 1 - Historique des trajets et événements
    const AlertsScreen(),      // 2 - Gestion des alertes et notifications
    const SafetyScreen(),      // 3 - Fonctionnalités d'urgence et sécurité
    const SettingsScreen(),    // 4 - Paramètres et configuration
  ];

  /// Gère le changement d'onglet lors de la sélection
  /// [index] : Index de l'onglet sélectionné
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Affiche l'écran correspondant à l'onglet sélectionné
      body: _pages[_selectedIndex],
      // Barre de navigation inférieure avec 5 onglets
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Affiche tous les onglets même avec plus de 3 items
        items: const [
          // Onglet Accueil - Carte et informations principales
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Accueil',
          ),
          // Onglet Historique - Trajets et événements passés
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historique',
          ),
          // Onglet Alertes - Notifications et alertes de sécurité
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bike),
            label: 'Alertes',
          ),
          // Onglet Urgence - Fonctionnalités de sécurité d'urgence
          BottomNavigationBarItem(
            icon: Icon(Icons.emergency),
            label: 'Urgence',
          ),
          // Onglet Paramètres - Configuration de l'application
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}
