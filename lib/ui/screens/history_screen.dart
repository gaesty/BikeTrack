import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ride History")),
      body: Column(
        children: [
          CalendarDatePicker(
            firstDate: DateTime(2023),
            lastDate: DateTime.now(),
            initialDate: DateTime.now(),
            onDateChanged: (value) {
              // handle date change
            },
          ),
          const ListTile(
            title: Text("25 juillet 2024"),
            subtitle: Text("5:29 PM - 5:48 PM"),
            trailing: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
