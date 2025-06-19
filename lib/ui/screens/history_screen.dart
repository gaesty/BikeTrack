import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder - à connecter au backend plus tard
    return Scaffold(
      appBar: AppBar(title: const Text("Historique des trajets")),
      body: const Center(
        child: Text("Aucun trajet enregistré."),
      ),
    );
  }
}
