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

      // Récupération du device_id
      final userRow = await supabase
          .from('users')
          .select('device_id')
          .eq('id', user.id)
          .maybeSingle();
      final deviceId =
          (userRow as Map<String, dynamic>?)?['device_id'] as String?;
      if (deviceId == null || deviceId.isEmpty) {
        throw 'Aucun appareil associé';
      }

      // Lecture des données pour ce device_id
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

      // Filtre ≥2 points GPS valides
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

      // Construction de la liste
      List<TrajetInfo> infos = [];
      for (final trajet in valid.reversed) {
        final pts = trajet
            .map((r) => LatLng(
                  double.tryParse(r['latitude'].toString()) ?? 0,
                  double.tryParse(r['longitude'].toString()) ?? 0,
                ))
            .where((p) => p.latitude != 0 && p.longitude != 0)
            .toList();
        if (pts.length < 2) continue;

        // Distance
        final calc = const Distance();
        double dist = 0;
        for (var i = 0; i < pts.length - 1; i++) {
          dist += calc(pts[i], pts[i + 1]);
        }

        // Horaires
        final startT = DateTime.tryParse(trajet.first['timestamp']);
        final endT = DateTime.tryParse(trajet.last['timestamp']);
        if (selectedDateTime != null &&
            (startT == null || startT.isBefore(selectedDateTime!))) {
          continue;
        }

        // Vitesses & inclinaisons
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

  Future<void> _selectDateTime(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: selectedDateTime ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: selectedDateTime != null
          ? TimeOfDay.fromDateTime(selectedDateTime!)
          : TimeOfDay.now(),
    );
    if (t == null) return;
    setState(() {
      selectedDateTime = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
    fetchTrajets();
  }

  void _clearFilter() {
    selectedDateTime = null;
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
            padding: const EdgeInsets.only(bottom: 70),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: trajetsInfos.length,
              itemBuilder: (ctx, i) {
                final t = trajetsInfos[i];
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
                    // rend les divider de l'ExpansionTile transparents
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('📅 Début : ${t.dateStart}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                Text('📅 Fin   : ${t.dateEnd}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Text('📏 ${t.distanceKm.toStringAsFixed(2)} km',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                      children: [
                        // carte avec markers
                        Container(
                          height: 150,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: FlutterMap(
                              options: MapOptions(
                                center: pts.first,
                                zoom: 15,
                                interactiveFlags: InteractiveFlag.none,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.example.app',
                                ),
                                if (pts.length > 1)
                                  PolylineLayer(polylines: [
                                    Polyline(points: pts, strokeWidth: 4.0),
                                  ]),
                                MarkerLayer(markers: [
                                  Marker(
                                    point: pts.first,
                                    width: 30,
                                    height: 30,
                                    child: const Icon(Icons.place, color: Colors.green),
                                  ),
                                  Marker(
                                    point: pts.last,
                                    width: 30,
                                    height: 30,
                                    child: const Icon(Icons.place, color: Colors.red),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        ),

                        // stats alignées à gauche
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
              },
            ),
          ),

          // boutons filtre
          Positioned(
            bottom: 10,
            right: 10,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _selectDateTime(context),
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('Filtrer date'),
                ),
                if (selectedDateTime != null) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _clearFilter,
                    icon: const Icon(Icons.clear),
                    label: const Text('Effacer filtre'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  ),
                ],
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
