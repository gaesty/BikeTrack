import 'package:flutter/material.dart';
import '../../models/moto_status.dart';

class MotoCard extends StatelessWidget {
  final MotoStatus status;

  const MotoCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Dernière position :",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text("Latitude : ${status.latitude.toStringAsFixed(5)}"),
            Text("Longitude : ${status.longitude.toStringAsFixed(5)}"),
            const SizedBox(height: 8),
            Text("Batterie : ${status.batteryLevel.toStringAsFixed(0)}%"),
            if (status.shockDetected)
              const Text(
                "⚠️ Choc détecté !",
                style: TextStyle(color: Colors.red),
              ),
            if (status.tiltDetected)
              const Text(
                "⚠️ Inclinaison anormale !",
                style: TextStyle(color: Colors.orange),
              ),
            Text("Mis à jour : ${status.timestamp.toLocal()}"),
          ],
        ),
      ),
    );
  }
}
