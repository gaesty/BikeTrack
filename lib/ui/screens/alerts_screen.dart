import 'package:flutter/material.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Alertes")),
      body: ListView(
        children: const [
          ListTile(
            title: Text("Choc détecté"),
            subtitle: Text("10:35"),
            leading: Icon(Icons.warning),
          ),
          ListTile(
            title: Text("Mouvement suspect"),
            subtitle: Text("09:11"),
            leading: Icon(Icons.warning_amber),
          ),
        ],
      ),
    );
  }
}
