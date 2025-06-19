import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui/screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://<TON-PROJET>.supabase.co',
    anonKey: '<TA-CLE-ANONYME>',
  );

  runApp(const BikeTrackApp());
}

class BikeTrackApp extends StatelessWidget {
  const BikeTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BikeTrack',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.white,
      ),
      debugShowCheckedModeBanner: false,
      home: const DashboardScreen(), 
    );
  }
}
