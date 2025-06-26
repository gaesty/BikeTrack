import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../ui/screens/alerts_screen.dart';
import 'package:intl/intl.dart';

class AlertDetailScreen extends StatelessWidget {
  final ChuteInfo alert;

  const AlertDetailScreen({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de l\'alerte'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 200,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(alert.latitude, alert.longitude),
                    initialZoom: 16,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.biketrack',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(alert.latitude, alert.longitude),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📅 Date : ${DateFormat('dd/MM/yyyy – HH:mm:ss').format(alert.timestamp)}'),
                  const SizedBox(height: 8),
                  Text('🛰️ Type : ${alert.type}'),
                  const SizedBox(height: 16),
                  Text('🚀 Vitesse moy.  : ${alert.avgSpeed.toStringAsFixed(1)} km/h'),
                  Text('🏎️ Vitesse max   : ${alert.maxSpeed.toStringAsFixed(1)} km/h'),
                  Text('🧭 Inclinaison moy. : ${alert.avgInclination.toStringAsFixed(1)}°'),
                  Text('📐 Inclinaison max  : ${alert.maxInclination.toStringAsFixed(1)}°'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
