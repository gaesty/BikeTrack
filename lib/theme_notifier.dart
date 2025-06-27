import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier(super.value);

  static Future<ThemeNotifier> create() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    return ThemeNotifier(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
    value = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
