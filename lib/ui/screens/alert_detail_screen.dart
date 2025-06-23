import 'package:flutter/material.dart';

class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Alerte")),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Mouvement détecté",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Nous avons détecté un mouvement de votre moto. Vérifiez que tout va bien.",
            ),
            SizedBox(height: 20),
            ElevatedButton(onPressed: null, child: Text("Voir l'alerte")),
            TextButton(onPressed: null, child: Text("Désactiver les alertes")),
          ],
        ),
      ),
    );
  }
}
