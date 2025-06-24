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
  DateTimeRange? selectedRange;
  String? errorMessage;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTrajets();
  }

  Future<void> fetchTrajets() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      trajetsInfos = [];
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw 'Utilisateur non connecté';

      final userRow = await supabase
          .from('users')
          .select('device_id')
          .eq('id', user.id)
          .maybeSingle();
      final deviceId = (userRow as Map<String, dynamic>?)?['device_id'] as String?;
      if (deviceId == null || deviceId.isEmpty) throw 'Aucun appareil associé';

      final raw = await supabase
          .from('sensor_data')
          .select()
          .eq('device_id', deviceId)
          .order('timestamp', ascending: true);
      final rows = List<Map<String, dynamic>>.from(raw as List);
      if (rows.isEmpty) throw 'Pas de données GPS';

      // Découpage en sessions
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

      // Filtrer selon range (date + heure)
      final List<TrajetInfo> infos = [];
      for (final trajet in sessions.reversed) {
        final startT = DateTime.tryParse(trajet.first['timestamp']);
        if (selectedRange != null &&
            (startT == null ||
             startT.isBefore(selectedRange!.start) ||
             startT.isAfter(selectedRange!.end))) {
          continue;
        }

        final pts = trajet
            .map((r) => LatLng(
                  double.tryParse(r['latitude'].toString()) ?? 0,
                  double.tryParse(r['longitude'].toString()) ?? 0,
                ))
            .where((p) => p.latitude != 0 && p.longitude != 0)
            .toList();
        if (pts.length < 2) continue;

        final calc = const Distance();
        double dist = 0;
        for (var i = 0; i < pts.length - 1; i++) {
          dist += calc(pts[i], pts[i + 1]);
        }

        final endT = DateTime.tryParse(trajet.last['timestamp']);

        double sumV = 0, maxV = 0;
        int countV = 0;
        double sumI = 0, maxI = 0;
        int countI = 0;
        for (final r in trajet) {
          final v = double.tryParse(r['gps_speed']?.toString() ?? '0')!;
          if (v > 0) {
            sumV += v;
            countV++;
            if (v > maxV) maxV = v;
          }
          final ax = double.tryParse(r['accel_x']?.toString() ?? '0')!;
          final ay = double.tryParse(r['accel_y']?.toString() ?? '0')!;
          final az = double.tryParse(r['accel_z']?.toString() ?? '0')!;
          final pitch = math.atan2(ax, math.sqrt(ay * ay + az * az));
          final roll = math.atan2(ay, math.sqrt(ax * ax + az * az));
          final incl = math.sqrt(pitch * pitch + roll * roll) * 180 / math.pi;
          sumI += incl;
          countI++;
          if (incl > maxI) maxI = incl;
        }

        infos.add(TrajetInfo(
          dateStart: startT != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(startT.toLocal())
              : 'N/A',
          dateEnd: endT != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(endT.toLocal())
              : 'N/A',
          distanceKm: dist / 1000,
          avgSpeed: countV > 0 ? sumV / countV : 0,
          maxSpeed: maxV,
          avgInclination: countI > 0 ? sumI / countI : 0,
          maxInclination: maxI,
          data: trajet,
        ));
      }

      setState(() {
        trajetsInfos = infos;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _pickRange(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: selectedRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Colors.black, // body text color
            ),
          ),
          child: child!,
        );
      },
    );
    if (range == null) return;

    // Pour filtrer heure, on garde la date range + ajoute l'heure max/min pour inclure toute la journée sélectionnée
    final newRange = DateTimeRange(
      start: DateTime(range.start.year, range.start.month, range.start.day, 0, 0, 0),
      end: DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
    );

    setState(() => selectedRange = newRange);
    fetchTrajets();
  }

  void _clearFilter() {
    setState(() {
      selectedRange = null;
    });
    fetchTrajets();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (errorMessage != null) return Center(child: Text('Erreur : $errorMessage'));

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des trajets'), centerTitle: true),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (selectedRange != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Filtre : ${DateFormat('dd/MM/yyyy HH:mm').format(selectedRange!.start)} ↔ ${DateFormat('dd/MM/yyyy HH:mm').format(selectedRange!.end)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearFilter,
                        ),
                      ],
                    ),
                  ),
                ...trajetsInfos.map((t) {
                  final pts = t.data
                      .map((r) => LatLng(
                            double.tryParse(r['latitude'].toString()) ?? 0,
                            double.tryParse(r['longitude'].toString()) ?? 0,
                          ))
                      .where((p) => p.latitude != 0 && p.longitude != 0)
                      .toList();
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        collapsedShape:
                            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        childrenPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('📅 Début : ${t.dateStart}'),
                                  Text('📅 Fin   : ${t.dateEnd}'),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Text('📏 ${t.distanceKm.toStringAsFixed(2)} km'),
                              ),
                            ),
                          ],
                        ),
                        children: [
                          Container(
                            height: 150,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: FlutterMap(
                                options: MapOptions(
                                    center: pts.first, zoom: 15, interactiveFlags: InteractiveFlag.none),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'app',
                                  ),
                                  if (pts.length > 1)
                                    PolylineLayer(
                                        polylines: [Polyline(points: pts, strokeWidth: 4)]),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                          point: pts.first,
                                          width: 30,
                                          height: 30,
                                          child:
                                              const Icon(Icons.place, color: Colors.green)),
                                      Marker(
                                          point: pts.last,
                                          width: 30,
                                          height: 30,
                                          child: const Icon(Icons.place, color: Colors.red)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🚀 Vitesse moy.  : ${t.avgSpeed.toStringAsFixed(1)} km/h'),
                                Text('🏎️ Vitesse max  : ${t.maxSpeed.toStringAsFixed(1)} km/h'),
                                Text('🧭 Inclinaison moy. : ${t.avgInclination.toStringAsFixed(1)}°'),
                                Text('📐 Inclinaison max : ${t.maxInclination.toStringAsFixed(1)}°'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () => _pickRange(context),
                icon: const Icon(Icons.calendar_today),
                label: const Text('Période'),
              ),
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
  final double avgInclination;
  final double maxInclination;
  final List<Map<String, dynamic>> data;

  TrajetInfo({
    required this.dateStart,
    required this.dateEnd,
    required this.distanceKm,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.avgInclination,
    required this.maxInclination,
    required this.data,
  });
}
