import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TrajetInfo> trajetsInfos = [];
  DateTime? selectedDateTime;

  @override
  void initState() {
    super.initState();
    fetchTrajets();
  }

  Future<void> fetchTrajets() async {
    final response = await Supabase.instance.client
        .from('sensor_data')
        .select()
        .order('timestamp', ascending: true);

    Map<String, List<Map<String, dynamic>>> groupedByDevice = {};
    for (var row in response) {
      final deviceId = row['device_id'] ?? 'unknown';
      groupedByDevice.putIfAbsent(deviceId, () => []);
      groupedByDevice[deviceId]!.add(row);
    }

    List<Map<String, dynamic>>? selectedDeviceData = groupedByDevice['A7670E_002'];
    if (selectedDeviceData == null || selectedDeviceData.isEmpty) return;

    List<List<Map<String, dynamic>>> trajets = [];
    List<Map<String, dynamic>> currentTrajet = [];
    int? lastUptime;

    for (var row in selectedDeviceData) {
      int? uptime = row['uptime_seconds'];
      if (uptime == null || (lastUptime != null && uptime < lastUptime)) {
        if (currentTrajet.isNotEmpty) {
          trajets.add(currentTrajet);
          currentTrajet = [];
        }
      }
      currentTrajet.add(row);
      lastUptime = uptime;
    }
    if (currentTrajet.isNotEmpty) {
      trajets.add(currentTrajet);
    }

    List<TrajetInfo> infos = [];

    for (var trajet in trajets.reversed) {
      final points = trajet
          .map((row) => LatLng(
              double.tryParse(row['latitude'].toString()) ?? 0.0,
              double.tryParse(row['longitude'].toString()) ?? 0.0))
          .where((p) => p.latitude != 0 && p.longitude != 0)
          .toList();
      if (points.length < 2) continue;

      final Distance calc = const Distance();
      double totalDistance = 0.0;
      for (int i = 0; i < points.length - 1; i++) {
        totalDistance += calc(points[i], points[i + 1]);
      }

      final startTime = DateTime.tryParse(trajet.first['timestamp']);
      final endTime = DateTime.tryParse(trajet.last['timestamp']);

      if (selectedDateTime != null) {
        if (startTime == null || startTime.isBefore(selectedDateTime!)) {
          continue;
        }
      }

      double maxSpeed = 0;
      double sumSpeed = 0;
      int countSpeed = 0;

      double maxInclination = 0;
      double sumInclination = 0;
      int countIncl = 0;

      for (var row in trajet) {
        final speed = double.tryParse(row['gps_speed']?.toString() ?? '0') ?? 0;
        if (speed > 0) {
          sumSpeed += speed;
          countSpeed++;
          if (speed > maxSpeed) maxSpeed = speed;
        }

        final ax = double.tryParse(row['accel_x']?.toString() ?? '0') ?? 0;
        final ay = double.tryParse(row['accel_y']?.toString() ?? '0') ?? 0;
        final az = double.tryParse(row['accel_z']?.toString() ?? '0') ?? 0;

        final pitch = math.atan2(ax, math.sqrt(ay * ay + az * az));
        final roll = math.atan2(ay, math.sqrt(ax * ax + az * az));
        final incl = math.sqrt(pitch * pitch + roll * roll) * 180 / math.pi;

        sumInclination += incl;
        countIncl++;
        if (incl > maxInclination) maxInclination = incl;
      }

      final avgSpeed = countSpeed > 0 ? sumSpeed / countSpeed : 0;
      final avgInclination = countIncl > 0 ? sumInclination / countIncl : 0;

      infos.add(TrajetInfo(
        dateStart: startTime != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(startTime.toLocal())
            : 'N/A',
        dateEnd: endTime != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(endTime.toLocal())
            : 'N/A',
        distanceKm: totalDistance / 1000,
        avgSpeed: avgSpeed.toDouble(),
        maxSpeed: maxSpeed,
        maxInclination: maxInclination,
        avgInclination: avgInclination.toDouble(),
        data: trajet,
      ));
    }

    setState(() => trajetsInfos = infos);
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDateTime ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: selectedDateTime != null
            ? TimeOfDay.fromDateTime(selectedDateTime!)
            : TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final DateTime combined = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          selectedDateTime = combined;
        });

        fetchTrajets();
      }
    }
  }

  void _clearFilter() {
    setState(() {
      selectedDateTime = null;
    });
    fetchTrajets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des trajets'), centerTitle: true),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 70.0),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: trajetsInfos.length,
              itemBuilder: (context, index) {
                final trajet = trajetsInfos[index];
                final points = trajet.data
                    .map((row) => LatLng(
                          double.tryParse(row['latitude'].toString()) ?? 0.0,
                          double.tryParse(row['longitude'].toString()) ?? 0.0,
                        ))
                    .where((p) => p.latitude != 0 && p.longitude != 0)
                    .toList();

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('📅 Début : ${trajet.dateStart}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              Text('📅 Fin : ${trajet.dateEnd}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Text(
                              '📏 ${trajet.distanceKm.toStringAsFixed(2)} km',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Container(
                        height: 150,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FlutterMap(
                            options: MapOptions(
                              center: points.isNotEmpty ? points.first : LatLng(0, 0),
                              zoom: 15,
                              interactiveFlags: InteractiveFlag.none,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.app',
                              ),
                              if (points.length > 1)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(points: points, strokeWidth: 4.0),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text('🚀 Vitesse moyenne : ${trajet.avgSpeed.toStringAsFixed(1)} km/h'),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text('🏎️ Vitesse max : ${trajet.maxSpeed.toStringAsFixed(1)} km/h'),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text('🧭 Inclinaison moyenne : ${trajet.avgInclination.toStringAsFixed(1)}°'),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text('🧭 Inclinaison max : ${trajet.maxInclination.toStringAsFixed(1)}°'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: ElevatedButton.icon(
                onPressed: () => _selectDateTime(context),
                icon: const Icon(Icons.filter_list),
                label: const Text('Filtrer date/heure'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
          if (selectedDateTime != null)
            Positioned(
              top: 12,
              right: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime!),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  IconButton(
                    onPressed: _clearFilter,
                    icon: const Icon(Icons.clear),
                    tooltip: 'Réinitialiser le filtre',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class TrajetInfo {
  final String dateStart;
  final String dateEnd;
  final double distanceKm;
  final double avgSpeed;
  final double maxSpeed;
  final double maxInclination;
  final double avgInclination;
  final List<Map<String, dynamic>> data;

  TrajetInfo({
    required this.dateStart,
    required this.dateEnd,
    required this.distanceKm,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.maxInclination,
    required this.avgInclination,
    required this.data,
  });
}
