import 'package:flutter/material.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Safety Center")),
      body: ListView(
        children: const [
          SwitchListTile(
            title: Text("Automatic alerts"),
            value: true,
            onChanged: null,
          ),
          ListTile(title: Text("Add emergency contact")),
          ListTile(title: Text("Edit emergency contacts")),
          Divider(),
          ListTile(title: Text("Alert status")),
          ListTile(title: Text("Send a test alert")),
        ],
      ),
    );
  }
}
