import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Réglages")),
      body: ListView(
        children: const [
          ListTile(title: Text("Notifications"), trailing: Icon(Icons.chevron_right)),
          ListTile(title: Text("Alertes de choc"), trailing: Icon(Icons.chevron_right)),
          ListTile(title: Text("Zones de sécurité"), trailing: Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}
