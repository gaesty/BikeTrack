import 'package:biketrack/ui/screens/confirmation_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'alert_detail_screen.dart';

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

  Future<void> fetchAlerts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      alerts.clear();
      _sentNotifications.clear();
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

      final deviceId = (userRow)?['device_id'] as String?;
      if (deviceId == null || deviceId.isEmpty) throw 'Aucun appareil associé';

      // Récupérer le dernier enregistrement sensor_data pour ce device
      final lastSensor = await supabase
          .from('sensor_data')
          .select('battery_is_charging')
          .eq('device_id', deviceId)
          .order('timestamp', ascending: false)
          .limit(1)
          .maybeSingle();
      if (lastSensor != null && lastSensor['battery_is_charging'] != null) {
        setState(() {
          isMonitoringEnabled = lastSensor['battery_is_charging'] == false;
        });
      }

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
        final isChoc = false; // Désactivé

        String? type;
        if (isVolAvecChute) {
          type = 'Vol avec chute';
        } else if (isChute) {
          type = 'Chute';
        } else if (isVol) {
          type = 'Vol';
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

          await _sendNotification(
            'Alerte : $type détecté',
            'À ${DateFormat('HH:mm:ss').format(timestamp)} – Vitesse : ${speed.toStringAsFixed(1)} km/h',
            id,
          );

          // Appel à la fonction de confirmation et envoi mail si chute à grande vitesse (exemple vitesse > 50 km/h)
          if (type == 'Chute' && speed > 50) {
            onCrashDetected(context, latitude, longitude);
          }
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
        title: const Text(
          'Alertes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(14),
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.shade300,
                              child: Text(
                                alert.type.substring(0, 1),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(alert.type,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Text(
                              'Inclinaison: ${alert.inclination.toStringAsFixed(1)}° - '
                              'Vitesse: ${alert.gpsSpeed.toStringAsFixed(1)} km/h\n'
                              '${DateFormat('dd/MM/yyyy HH:mm:ss').format(alert.timestamp)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                final originalIndex = alerts.indexOf(alert);
                                _removeAlert(originalIndex);
                              },
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AlertDetailScreen(alert: alert),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showFilterDialog,
        label: const Text('Filtrer'),
        icon: const Icon(Icons.filter_list),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final filters = ['Toutes', 'Chute', 'Vol', 'Vol avec chute'];
        return AlertDialog(
          title: const Text('Filtrer les alertes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: filters
                .map((filter) => RadioListTile<String>(
                      title: Text(filter),
                      value: filter,
                      groupValue: selectedFilter,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedFilter = value);
                          Navigator.pop(context);
                        }
                      },
                    ))
                .toList(),
          ),
        );
      },
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

/// Classe pour stocker un contact d'urgence
class EmergencyContact {
  final String name;
  final String phone;

  EmergencyContact({required this.name, required this.phone});

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone};

  factory EmergencyContact.fromMap(Map<String, dynamic> map) =>
      EmergencyContact(name: map['name'], phone: map['phone']);
}

/// Charge la liste des contacts depuis SharedPreferences
Future<List<EmergencyContact>> loadContacts() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = prefs.getString('emergency_contacts');
  if (jsonString == null) return [];
  final List<dynamic> jsonList = json.decode(jsonString);
  return jsonList
      .map((e) => EmergencyContact.fromMap(e as Map<String, dynamic>))
      .toList();
}

/// Fonction appelée lors d'une chute détectée (avec confirmation)
void onCrashDetected(BuildContext context, double latitude, double longitude) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ConfirmationScreen(
        latitude: latitude,
        longitude: longitude,
      ),
    ),
  );
}
