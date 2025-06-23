import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/gps_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng _currentPosition = const LatLng(48.8566, 2.3522); // Paris par défaut

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
  }

  Future<void> _setInitialLocation() async {
    final location = await GpsService.getCurrentLocation();
    if (location != null) {
      setState(() {
        _currentPosition = LatLng(location.latitude, location.longitude);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Localisation en temps réel")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentPosition,
          zoom: 15,
        ),
        markers: {
          Marker(markerId: const MarkerId('moto'), position: _currentPosition),
        },
      ),
    );
  }
}
