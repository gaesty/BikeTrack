import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  List<Map<String, String>> emergencyContacts = [];
  int emergencyDelay = 10;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getStringList('emergencyContacts') ?? [];
    setState(() {
      emergencyContacts = contactsJson
          .map((c) => Map<String, String>.from(json.decode(c)))
          .toList();
      emergencyDelay = prefs.getInt('emergencyDelay') ?? 10;
    });
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = emergencyContacts.map((c) => json.encode(c)).toList();
    await prefs.setStringList('emergencyContacts', contactsJson);
  }

  Future<void> _saveDelay() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('emergencyDelay', emergencyDelay);
  }

  void _addEmergencyContact() {
    final nameController = TextEditingController();
    final numberController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ajouter un contact"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Prénom"),
              autofocus: true,
            ),
            TextField(
              controller: numberController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Numéro de téléphone"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final number = numberController.text.trim();
              if (name.isNotEmpty && number.isNotEmpty) {
                setState(() {
                  emergencyContacts.add({'name': name, 'number': number});
                });
                _saveContacts();
                Navigator.pop(context);
              }
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }

  void _editEmergencyContact(int index) {
    final nameController =
        TextEditingController(text: emergencyContacts[index]['name']);
    final numberController =
        TextEditingController(text: emergencyContacts[index]['number']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Modifier le contact"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Prénom"),
              autofocus: true,
            ),
            TextField(
              controller: numberController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Numéro de téléphone"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final number = numberController.text.trim();
              if (name.isNotEmpty && number.isNotEmpty) {
                setState(() {
                  emergencyContacts[index] = {'name': name, 'number': number};
                });
                _saveContacts();
                Navigator.pop(context);
              }
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  void _removeEmergencyContact(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer le contact"),
        content: Text(
            "Voulez-vous vraiment supprimer le contact ${emergencyContacts[index]['name']} ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                emergencyContacts.removeAt(index);
              });
              _saveContacts();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📞 Contact d'urgence", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '📋 Liste des contacts d’urgence',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          if (emergencyContacts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: Text(
                "Aucun contact ajouté.\nAjoutez un contact d'urgence ci-dessous.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              )),
            ),
          ...emergencyContacts.asMap().entries.map(
                (entry) => Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(entry.value['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(entry.value['number'] ?? ''),
                    leading: const Icon(Icons.person, color: Colors.blue),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () => _editEmergencyContact(entry.key),
                          tooltip: 'Modifier',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeEmergencyContact(entry.key),
                          tooltip: 'Supprimer',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _addEmergencyContact,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un contact'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const Divider(height: 40),
          const Text(
            '⏱️ Délai de confirmation avant envoi d’alerte automatique',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '$emergencyDelay secondes',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          Slider(
            value: emergencyDelay.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            label: '$emergencyDelay sec',
            onChanged: (value) {
              setState(() => emergencyDelay = value.toInt());
              _saveDelay();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
