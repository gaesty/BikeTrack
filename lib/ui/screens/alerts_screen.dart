import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alert_detail_screen.dart';
import 'settings_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool isMonitoringEnabled = true;
  String selectedFilter = 'Toutes';
  List<ChuteInfo> alerts = [];
  bool isLoading = true;
  String? errorMessage;

  double parkingInclinationThreshold = 50;
  double parkingSpeedThreshold = 1;
  double drivingInclinationThreshold = 50;
  double drivingSpeedThreshold = 5;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final Set<String> _sentNotifications = {};

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadSensitivitySettings().then((_) => fetchAlerts());
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  Future<void> _loadSensitivitySettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      parkingInclinationThreshold = prefs.getDouble('parkingInclination') ?? 50;
      parkingSpeedThreshold = prefs.getDouble('parkingSpeed') ?? 1;
      drivingInclinationThreshold = prefs.getDouble('drivingInclination') ?? 50;
      drivingSpeedThreshold = prefs.getDouble('drivingSpeed') ?? 5;
    });
  }

  Future<void> _sendNotification(String title, String body, String id) async {
    if (_sentNotifications.contains(id)) return;
    _sentNotifications.add(id);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'alerts_channel',
      'Alertes',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      id.hashCode,
      title,
      body,
      platformDetails,
    );
  }

  void updateSensitivity({
    required double parkingInclination,
    required double parkingSpeed,
    required double drivingInclination,
    required double drivingSpeed,
  }) {
    setState(() {
      parkingInclinationThreshold = parkingInclination;
      parkingSpeedThreshold = parkingSpeed;
      drivingInclinationThreshold = drivingInclination;
      drivingSpeedThreshold = drivingSpeed;
    });
    fetchAlerts();
  }

  Future<void> fetchAlerts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      alerts.clear();
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
          .order('timestamp', ascending: false)
          .limit(500);

      final rows = List<Map<String, dynamic>>.from(raw as List);
      final List<ChuteInfo> foundAlerts = [];

      for (final r in rows) {
        final ax = double.tryParse(r['accel_x']?.toString() ?? '') ?? 0;
        final ay = double.tryParse(r['accel_y']?.toString() ?? '') ?? 0;
        final az = double.tryParse(r['accel_z']?.toString() ?? '') ?? 0;
        final speed = double.tryParse(r['gps_speed']?.toString() ?? '') ?? 0;
        final timestamp = DateTime.tryParse(r['timestamp'] ?? '')?.toLocal();
        final latitude = double.tryParse(r['latitude']?.toString() ?? '') ?? 0;
        final longitude = double.tryParse(r['longitude']?.toString() ?? '') ?? 0;

        if (timestamp == null) continue;

        final pitch = math.atan2(ax, math.sqrt(ay * ay + az * az));
        final roll = math.atan2(ay, math.sqrt(ax * ax + az * az));
        final inclination = math.sqrt(pitch * pitch + roll * roll) * 180 / math.pi;
        final accelMagnitude = math.sqrt(ax * ax + ay * ay + az * az);

        final isChute = isMonitoringEnabled
            ? (inclination > parkingInclinationThreshold && speed < parkingSpeedThreshold)
            : (inclination > drivingInclinationThreshold && speed > drivingSpeedThreshold);

        final isVol = isMonitoringEnabled && speed > parkingSpeedThreshold;
        final isVolAvecChute = isVol && inclination > parkingInclinationThreshold;
        final isChoc = accelMagnitude > 3.0;

        String? type;
        if (isVolAvecChute) {
          type = 'Vol avec chute';
        } else if (isChute) {
          type = 'Chute';
        } else if (isVol) {
          type = 'Vol';
        } else if (isChoc) {
          type = 'Choc';
        }

        if (type != null) {
          final id = '${type}_${timestamp.toIso8601String()}';

          final chuteInfo = ChuteInfo(
            timestamp: timestamp,
            inclination: inclination,
            gpsSpeed: speed,
            type: type,
            latitude: latitude,
            longitude: longitude,
            avgSpeed: speed,
            maxSpeed: speed,
            avgInclination: inclination,
            maxInclination: inclination,
          );

          foundAlerts.add(chuteInfo);

          _sendNotification(
            'Alerte : $type détecté',
            'À ${DateFormat('HH:mm:ss').format(timestamp)} – Vitesse : ${speed.toStringAsFixed(1)} km/h',
            id,
          );
        }
      }

      setState(() {
        alerts = foundAlerts;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _removeAlert(int index) {
    setState(() {
      alerts.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredAlerts = selectedFilter == 'Toutes'
        ? alerts
        : alerts.where((a) => a.type == selectedFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertes'),
        centerTitle: true,
        actions: [
          Row(
            children: [
              const Text('🏍️'),
              Switch(
                value: isMonitoringEnabled,
                onChanged: (val) {
                  setState(() => isMonitoringEnabled = val);
                  fetchAlerts();
                },
              ),
              const Text('🅿️'),
              const SizedBox(width: 8),
            ],
          ),
          // Suppression du bouton paramètres ici
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchAlerts,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text('Erreur : $errorMessage'))
              : filteredAlerts.isEmpty
                  ? const Center(child: Text('Aucune alerte détectée'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredAlerts.length,
                      itemBuilder: (context, index) {
                        final alert = filteredAlerts[index];
                        return Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Icon(
                              alert.type == 'Chute'
                                  ? Icons.warning_amber
                                  : alert.type == 'Vol avec chute'
                                      ? Icons.warning_rounded
                                      : alert.type == 'Vol'
                                          ? Icons.lock_open
                                          : Icons.bolt,
                              color: alert.type.contains('Chute')
                                  ? Colors.red
                                  : Colors.orange,
                            ),
                            title: Text(
                              '${alert.type} détectée à ${DateFormat('dd/MM/yyyy – HH:mm:ss').format(alert.timestamp)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Inclinaison : ${alert.inclination.toStringAsFixed(1)}°\n'
                              'Vitesse : ${alert.gpsSpeed.toStringAsFixed(1)} km/h',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.grey),
                              onPressed: () => _removeAlert(index),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AlertDetailScreen(alert: alert),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.filter_list),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (_) => FilterBottomSheet(
              selectedFilter: selectedFilter,
              onFilterSelected: (filter) {
                setState(() {
                  selectedFilter = filter;
                });
                Navigator.pop(context);
              },
            ),
          );
        },
      ),
    );
  }
}

class FilterBottomSheet extends StatelessWidget {
  final String selectedFilter;
  final void Function(String) onFilterSelected;

  const FilterBottomSheet({
    Key? key,
    required this.selectedFilter,
    required this.onFilterSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final filters = ['Toutes', 'Chute', 'Vol', 'Vol avec chute', 'Choc'];
    return ListView(
      shrinkWrap: true,
      children: filters.map((filter) {
        return RadioListTile<String>(
          title: Text(filter),
          value: filter,
          groupValue: selectedFilter,
          onChanged: (value) {
            if (value != null) onFilterSelected(value);
          },
        );
      }).toList(),
    );
  }
}

class ChuteInfo {
  final DateTime timestamp;
  final double inclination;
  final double gpsSpeed;
  final String type;
  final double latitude;
  final double longitude;
  final double avgSpeed;
  final double maxSpeed;
  final double avgInclination;
  final double maxInclination;

  ChuteInfo({
    required this.timestamp,
    required this.inclination,
    required this.gpsSpeed,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.avgInclination,
    required this.maxInclination,
  });
}
