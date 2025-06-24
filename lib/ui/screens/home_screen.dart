import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  List<LatLng> path = [];
  LatLng? startPoint;
  LatLng? endPoint;
  String date = '';
  double totalDistance = 0.0;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    fetchTrajectory();
  }

  Future<void> fetchTrajectory() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw 'Utilisateur non connecté';

      // 1) Récupère device_id
      final userRow = await supabase
          .from('users')
          .select('device_id')
          .eq('id', user.id)
          .maybeSingle();
      final deviceId =
          (userRow as Map<String, dynamic>?)?['device_id'] as String?;
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
