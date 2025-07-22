/// Écran d'accueil de BikeTrack - Vue principale avec carte et données en temps réel
/// 
/// Cet écran constitue le point central de l'application BikeTrack. Il affiche:
/// - Une carte interactive montrant la position actuelle et les trajectoires
/// - Les statistiques du dernier trajet (distance, points GPS)
/// - Les informations de connexion et d'état de l'appareil
/// 
/// Fonctionnalités principales:
/// - Chargement et affichage des données GPS depuis Supabase
/// - Calcul automatique des trajectoires et distances
/// - Gestion des sessions de trajet (détection des redémarrages)
/// - Interface utilisateur réactive avec gestion d'erreurs

// Imports Flutter et packages externes
import 'package:flutter/material.dart';           // Framework UI Flutter
import 'package:flutter_map/flutter_map.dart';   // Widget de carte interactive
import 'package:latlong2/latlong.dart';          // Types pour coordonnées GPS
import 'package:supabase_flutter/supabase_flutter.dart'; // Client base de données
import 'package:intl/intl.dart';                 // Formatage des dates/nombres
import 'package:timezone/data/latest.dart' as tz;  // Données de fuseaux horaires
import 'package:timezone/timezone.dart' as tz;     // Gestion des fuseaux horaires

/// Widget principal de l'écran d'accueil
/// 
/// StatefulWidget permettant de gérer l'état de la carte, des données GPS
/// et des interactions utilisateur de manière réactive.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// État de l'écran d'accueil - Gestion des données et de l'interface
/// 
/// Cette classe gère:
/// - Le contrôleur de carte pour la navigation
/// - Les données de trajectoire et statistiques
/// - Les états de chargement et d'erreur
/// - Les interactions avec la base de données Supabase
class _HomeScreenState extends State<HomeScreen> {
  // Contrôleur pour manipuler la carte (zoom, centre, etc.)
  final MapController _mapController = MapController();
  
  // Données de trajectoire et navigation
  List<LatLng> path = [];           // Points formant la trajectoire à afficher
  LatLng? startPoint;               // Point de départ du trajet
  LatLng? endPoint;                 // Point d'arrivée du trajet
  String date = '';                 // Date du trajet formatée
  double totalDistance = 0.0;       // Distance totale parcourue en kilomètres
  
  // États de l'interface utilisateur
  bool isLoading = true;            // Indicateur de chargement des données
  String? errorMessage;             // Message d'erreur éventuel

  @override
  void initState() {
    super.initState();
    // Initialisation des fuseaux horaires pour le formatage des dates
    tz.initializeTimeZones();
    // Chargement initial des données de trajectoire
    fetchTrajectory();
  }

  /// Récupère et traite les données de trajectoire depuis Supabase
  /// 
  /// Cette méthode complexe:
  /// 1. Récupère l'ID de l'appareil associé à l'utilisateur connecté
  /// 2. Charge tous les points GPS valides de cet appareil
  /// 3. Découpe les données en sessions (gestion des redémarrages)
  /// 4. Sélectionne la session la plus récente avec suffisamment de points
  /// 5. Calcule les statistiques (distance, points de départ/arrivée)
  /// 6. Met à jour l'état de l'interface utilisateur
  Future<void> fetchTrajectory() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Récupération du client Supabase et vérification de l'authentification
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw 'Utilisateur non connecté';

      // 1) Récupération de l'ID de l'appareil associé à l'utilisateur
      final userRow = await supabase
          .from('users')
          .select('device_id')
          .eq('id', user.id)
          .maybeSingle();
      final deviceId =
          (userRow)?['device_id'] as String?;
      if (deviceId == null || deviceId.isEmpty) {
        throw 'Aucun device associé à l’utilisateur';
      }

      // 2) Récupère points valides
      final raw = await supabase
          .from('sensor_data')
          .select()
          .eq('device_id', deviceId)
          .eq('gps_valid', true)
          .order('timestamp', ascending: true);
      final rows = List<Map<String, dynamic>>.from(raw as List);
      if (rows.isEmpty) throw 'Pas de données GPS valides';

      // 3) Découpe en sessions
      List<List<Map<String, dynamic>>> sessions = [];
      List<Map<String, dynamic>> current = [];
      int? lastUptime;
      for (final row in rows) {
        final uptime = row['uptime_seconds'] as int?;
        if (uptime == null || (lastUptime != null && uptime < lastUptime)) {
          if (current.isNotEmpty) {
            sessions.add(current);
            current = [];
          }
        }
        current.add(row);
        lastUptime = uptime;
      }
      if (current.isNotEmpty) sessions.add(current);

      // 4) Filtre sessions ≥2 points
      final valid = sessions.where((sess) {
        final pts = sess
            .map((r) => LatLng(
                  double.tryParse(r['latitude'].toString()) ?? 0,
                  double.tryParse(r['longitude'].toString()) ?? 0,
                ))
            .where((p) => p.latitude != 0 && p.longitude != 0)
            .toList();
        return pts.length >= 2;
      }).toList();
      if (valid.isEmpty) throw 'Aucune session valide';

      // 5) Prend dernière session
      final lastSession = valid.last;
      final points = lastSession
          .map((r) => LatLng(
                double.tryParse(r['latitude'].toString()) ?? 0,
                double.tryParse(r['longitude'].toString()) ?? 0,
              ))
          .toList();

      // 6) Calcule distance
      double distKm = 0;
      const calc = Distance();
      for (int i = 0; i < points.length - 1; i++) {
        distKm += calc(points[i], points[i + 1]) / 1000;
      }

      // 7) Convertit timestamp
      final paris = tz.getLocation('Europe/Paris');
      final utc = DateTime.parse(lastSession.last['timestamp'].toString())
          .toUtc();
      final tzTime = tz.TZDateTime.from(utc, paris);

      // 8) Mise à jour UI
      setState(() {
        path = points;
        startPoint = points.first;
        endPoint = points.last;
        date = DateFormat('dd/MM/yyyy HH:mm').format(tzTime);
        totalDistance = distKm;
        isLoading = false;
      });

      // 9) FitBounds dès que possible
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (path.isNotEmpty) {
          _mapController.fitBounds(
            LatLngBounds.fromPoints(path),
            options: const FitBoundsOptions(padding: EdgeInsets.all(40)),
          );
        }
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (errorMessage != null) return Center(child: Text('Erreur : $errorMessage'));

    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height / 2.2,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: path.isNotEmpty
                  ? path.first
                  : const LatLng(48.8566, 2.3522),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
                retinaMode: true,
              ),
              if (path.length > 1)
                PolylineLayer(polylines: [
                  Polyline(points: path, strokeWidth: 4, color: Colors.blue),
                ]),
              MarkerLayer(markers: [
                if (startPoint != null)
                  Marker(
                    point: startPoint!,
                    width: 30,
                    height: 30,
                    child: const Icon(Icons.flag, color: Colors.green, size: 30),
                  ),
                if (endPoint != null)
                  Marker(
                    point: endPoint!,
                    width: 30,
                    height: 30,
                    child: const Icon(Icons.flag, color: Colors.red, size: 30),
                  ),
              ]),
            ],
          ),
        ),

        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Dernier trajet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        if (startPoint != null && endPoint != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📅 Date : $date',
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      '🚩 Départ : ${startPoint!.latitude.toStringAsFixed(5)}, '
                      '${startPoint!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      '🏁 Arrivée : ${endPoint!.latitude.toStringAsFixed(5)}, '
                      '${endPoint!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '📏 Distance totale : ${totalDistance.toStringAsFixed(2)} km',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Aucun trajet à afficher.'),
          ),
      ],
    );
  }
}
