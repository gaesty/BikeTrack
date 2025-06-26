// confirmation_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

class ConfirmationScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final int timeoutSeconds;

  // On ajoute latitude et longitude au constructeur, et on les rend obligatoires
  ConfirmationScreen({
    required this.latitude,
    required this.longitude,
    this.timeoutSeconds = 30,
    Key? key,
  }) : super(key: key);

  @override
  _ConfirmationScreenState createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  late int secondsLeft;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    secondsLeft = widget.timeoutSeconds;
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (secondsLeft == 0) {
        timer.cancel();
        Navigator.of(context).pop(false); // Pas de réponse = "Non"
      } else {
        setState(() {
          secondsLeft--;
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Alerte chute détectée")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Tout va bien ?", style: TextStyle(fontSize: 24)),
            SizedBox(height: 20),
            Text("Répondez dans $secondsLeft secondes"),
            SizedBox(height: 20),
            // Affichage facultatif des coordonnées
            Text(
              "Position : "
              "${widget.latitude.toStringAsFixed(5)}, "
              "${widget.longitude.toStringAsFixed(5)}",
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text("Oui"),
                ),
                SizedBox(width: 40),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text("Non"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
