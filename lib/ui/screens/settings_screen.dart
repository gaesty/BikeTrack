import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Seuils
  double parkingInclination = 50;
  double parkingSpeed = 1;
  double drivingInclination = 50;
  double drivingSpeed = 5;

  // Notifications
  bool notifyFall = true;
  bool notifyTheft = true;

  // Loading
  bool isLoading = true;

  // Champs compte
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserData();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      parkingInclination = prefs.getDouble('parkingInclination') ?? 50;
      parkingSpeed = prefs.getDouble('parkingSpeed') ?? 1;
      drivingInclination = prefs.getDouble('drivingInclination') ?? 50;
      drivingSpeed = prefs.getDouble('drivingSpeed') ?? 5;
      notifyFall = prefs.getBool('notifyFall') ?? true;
      notifyTheft = prefs.getBool('notifyTheft') ?? true;
    });
  }

  Future<void> _loadUserData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final response = await supabase
        .from('users')
        .select('first_name, last_name')
        .eq('id', user.id)
        .single();
    if (response != null) {
      setState(() {
        firstNameController.text = response['first_name'] ?? '';
        lastNameController.text = response['last_name'] ?? '';
        isLoading = false;
      });
    }
  }

  Future<void> _saveUserInfo() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('users').update({
        'first_name': firstNameController.text,
        'last_name': lastNameController.text,
      }).eq('id', user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Infos utilisateur mises à jour avec succès")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la mise à jour des infos utilisateur")),
      );
    }
  }

  Future<void> _changePassword() async {
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Les mots de passe ne correspondent pas")),
      );
      return;
    }

    try {
      await supabase.auth.updateUser(
        UserAttributes(password: passwordController.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mot de passe mis à jour avec succès")),
      );
      passwordController.clear();
      confirmPasswordController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors du changement de mot de passe")),
      );
    }
  }

  Future<void> _logout() async {
    try {
      await supabase.auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Déconnexion réussie")),
      );
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la déconnexion")),
      );
    }
  }

  Future<void> _saveDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    final success = await prefs.setDouble(key, value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? "Paramètre '$key' sauvegardé : ${value.toStringAsFixed(1)}"
              : "Erreur lors de la sauvegarde de '$key'"),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final success = await prefs.setBool(key, value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? "Paramètre '$key' sauvegardé"
              : "Erreur lors de la sauvegarde de '$key'"),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildSliderCard({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$title : ${value.toStringAsFixed(1)} $unit",
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              label: "${value.toStringAsFixed(1)} $unit",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String emoji,
  }) {
    return SwitchListTile(
      title: Text('$emoji $title', style: const TextStyle(fontWeight: FontWeight.w500)),
      value: value,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Paramètres')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Section sensibilité
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('🔧 Sensibilité des alertes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Mode parking', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            _buildSliderCard(
              title: "Inclinaison",
              value: parkingInclination,
              min: 10,
              max: 90,
              divisions: 80,
              unit: "°",
              onChanged: (v) {
                setState(() => parkingInclination = v);
                _saveDouble('parkingInclination', v);
              },
            ),
            _buildSliderCard(
              title: "Vitesse",
              value: parkingSpeed,
              min: 0,
              max: 20,
              divisions: 20,
              unit: "km/h",
              onChanged: (v) {
                setState(() => parkingSpeed = v);
                _saveDouble('parkingSpeed', v);
              },
            ),

            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Mode roulage', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            _buildSliderCard(
              title: "Inclinaison",
              value: drivingInclination,
              min: 10,
              max: 90,
              divisions: 80,
              unit: "°",
              onChanged: (v) {
                setState(() => drivingInclination = v);
                _saveDouble('drivingInclination', v);
              },
            ),
            _buildSliderCard(
              title: "Vitesse",
              value: drivingSpeed,
              min: 0,
              max: 100,
              divisions: 100,
              unit: "km/h",
              onChanged: (v) {
                setState(() => drivingSpeed = v);
                _saveDouble('drivingSpeed', v);
              },
            ),

            const Divider(height: 40),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text('🔔 Notifications push', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildSwitchTile(
              title: "Alerte chute",
              emoji: "⚠️",
              value: notifyFall,
              onChanged: (v) {
                setState(() => notifyFall = v);
                _saveBool('notifyFall', v);
              },
            ),
            _buildSwitchTile(
              title: "Alerte vol",
              emoji: "🔒",
              value: notifyTheft,
              onChanged: (v) {
                setState(() => notifyTheft = v);
                _saveBool('notifyTheft', v);
              },
            ),

            const Divider(height: 40),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text('👤 Compte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: firstNameController,
              decoration: const InputDecoration(
                labelText: 'Prénom',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lastNameController,
              decoration: const InputDecoration(
                labelText: 'Nom',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saveUserInfo,
              icon: const Icon(Icons.save),
              label: const Text("Enregistrer les infos"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('🔐 Changer le mot de passe', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nouveau mot de passe',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmer le mot de passe',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.lock),
              label: const Text("Changer le mot de passe"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 32),
            Center(
              child: TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text("Se déconnecter"),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            )
          ],
        ),
      ),
    );
  }
}
