import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui/screens/home_screen.dart' show DashboardScreen;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://oynnjhnjyeogltujthcy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95bm5qaG5qeWVvZ2x0dWp0aGN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAzMzIwNTgsImV4cCI6MjA2NTkwODA1OH0.eP28KmebtF0AmUdkUcnzLuRhl4uMnkYJfIaHZ4nHFl4',
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
