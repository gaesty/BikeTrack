import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: const [
          ListTile(title: Text("Impact Sensitivity"), subtitle: Text("Medium")),
          ListTile(title: Text("Movement Sensitivity"), subtitle: Text("Low")),
          SwitchListTile(
            title: Text("Push Notifications"),
            value: true,
            onChanged: null,
          ),
          Divider(),
          ListTile(title: Text("Edit Profile")),
          ListTile(title: Text("Change Password")),
          ListTile(title: Text("Delete Account")),
          Divider(),
          ListTile(title: Text("Dark Mode")),
          ListTile(title: Text("Help")),
          ListTile(title: Text("Log Out")),
        ],
      ),
    );
  }
}
