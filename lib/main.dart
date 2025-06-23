import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
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
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final MapController _mapController;
  List<LatLng> path = [];
  String? date;
  LatLng? startPoint;
  LatLng? endPoint;
  double totalDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    fetchTrajectory();
  }

  Future<void> fetchTrajectory() async {
    final response = await Supabase.instance.client
        .from('sensor_data')
        .select()
        .order('timestamp', ascending: true)
        .limit(100); // adapter selon le nombre de points utiles

    final points = response.map<LatLng>((row) {
      return LatLng(
        double.tryParse(row['latitude'].toString()) ?? 0.0,
        double.tryParse(row['longitude'].toString()) ?? 0.0,
      );
    }).where((p) => p.latitude != 0 && p.longitude != 0).toList();

    if (points.isNotEmpty) {
      double distanceKm = 0.0;
      final Distance calc = const Distance();

      for (int i = 0; i < points.length - 1; i++) {
        distanceKm += calc(points[i], points[i + 1]) / 1000;
      }

      setState(() {
        path = points;
        startPoint = points.first;
        endPoint = points.last;
        date = response.last['timestamp'].toString();
        totalDistance = distanceKm;
      });

      // Auto-centre la carte
      Future.delayed(const Duration(milliseconds: 100), () {
        _mapController.fitBounds(
          LatLngBounds.fromPoints(points),
          options: const FitBoundsOptions(padding: EdgeInsets.all(40)),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height / 2.2,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(48.8566, 2.3522),
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: 'com.example.app',
                ),
                if (path.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: path,
                        strokeWidth: 4.0,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
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
                  ],
                ),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📅 Date : $date',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '🚩 Départ : ${startPoint!.latitude.toStringAsFixed(5)}, ${startPoint!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text(
                        '🏁 Arrivée : ${endPoint!.latitude.toStringAsFixed(5)}, ${endPoint!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '📏 Distance totale : ${totalDistance.toStringAsFixed(2)} km',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Chargement du trajet...'),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Paramètres'),
        ],
      ),
    );
  }
}
