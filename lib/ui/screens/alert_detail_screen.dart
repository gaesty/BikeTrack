import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alerts_screen.dart'; // ChuteInfo est ici

class AlertDetailScreen extends StatefulWidget {
  final ChuteInfo alert;

  const AlertDetailScreen({super.key, required this.alert});

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  Map<String, dynamic>? sensorData;

  @override
  void initState() {
    super.initState();
    _fetchSensorData();
  }

  Future<void> _fetchSensorData() async {
    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('sensor_data')
        .select()
        .lte('timestamp', widget.alert.timestamp.toUtc().toIso8601String())
        .order('timestamp', ascending: false)
        .limit(1)
        .maybeSingle();

    setState(() {
      sensorData = response;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (sensorData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final lat = double.tryParse(sensorData!['gps_latitude']?.toString() ?? '') ?? 0.0;
    final lon = double.tryParse(sensorData!['gps_longitude']?.toString() ?? '') ?? 0.0;
    final latLng = LatLng(lat, lon);

    return Scaffold(
      appBar: AppBar(title: const Text("Détail de l'alerte")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Chute détectée",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "Heure : ${widget.alert.timestamp}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text("Inclinaison : ${widget.alert.inclination.toStringAsFixed(1)}°"),
            Text("Vitesse GPS : ${widget.alert.gpsSpeed.toStringAsFixed(1)} km/h"),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: FlutterMap(
                options: MapOptions(
                  center: latLng,
                  zoom: 16,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 40,
                        height: 40,
                        point: latLng,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Retour"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
