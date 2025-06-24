import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool isMonitoringEnabled = true;
  List<ChuteInfo> chuteAlerts = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchChutes();
  }

  Future<void> fetchChutes() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      chuteAlerts = [];
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
          .limit(500); // charge les 500 dernières données

      final rows = List<Map<String, dynamic>>.from(raw as List);
      final List<ChuteInfo> foundChutes = [];

      for (final r in rows) {
        final ax = double.tryParse(r['accel_x']?.toString() ?? '0')!;
        final ay = double.tryParse(r['accel_y']?.toString() ?? '0')!;
        final az = double.tryParse(r['accel_z']?.toString() ?? '0')!;
        final speed = double.tryParse(r['gps_speed']?.toString() ?? '0')!;
        final timestamp = DateTime.tryParse(r['timestamp'])?.toLocal();

        final pitch = math.atan2(ax, math.sqrt(ay * ay + az * az));
        final roll = math.atan2(ay, math.sqrt(ax * ax + az * az));
        final inclination = math.sqrt(pitch * pitch + roll * roll) * 180 / math.pi;

        // Détection chute selon mode
        final isChute = isMonitoringEnabled
            ? (inclination > 60 && speed < 1) // Mode parking
            : (inclination > 60 && speed > 1); // Mode roulage

        if (isChute && timestamp != null) {
          foundChutes.add(ChuteInfo(
            timestamp: timestamp,
            inclination: inclination,
            gpsSpeed: speed,
          ));
        }
      }

      setState(() {
        chuteAlerts = foundChutes;
        isLoading = false;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerte Chutes'),
        centerTitle: true,
        actions: [
          Row(
            children: [
              const Text('🏍️'),
              Switch(
                value: isMonitoringEnabled,
                onChanged: (val) {
                  setState(() {
                    isMonitoringEnabled = val;
                  });
                  fetchChutes();
                },
              ),
              const Text('🅿️'),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text('Erreur : $errorMessage'))
              : chuteAlerts.isEmpty
                  ? const Center(child: Text('Aucune chute détectée'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: chuteAlerts.length,
                      itemBuilder: (context, index) {
                        final chute = chuteAlerts[index];
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                            title: Text(
                              'Chute détectée à ${DateFormat('dd/MM/yyyy – HH:mm:ss').format(chute.timestamp)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Inclinaison : ${chute.inclination.toStringAsFixed(1)}°\n'
                              'Vitesse GPS : ${chute.gpsSpeed.toStringAsFixed(1)} km/h',
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class ChuteInfo {
  final DateTime timestamp;
  final double inclination;
  final double gpsSpeed;

  ChuteInfo({
    required this.timestamp,
    required this.inclination,
    required this.gpsSpeed,
  });
}
