import 'package:bcrypt/bcrypt.dart';
import 'dart:isolate';

class PasswordServiceImpl {
  static Future<String> hashPassword(String password) async {
    // Use isolates on mobile platforms
    final response = await Isolate.run(() {
      return BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 12));
    });
    return response;
  }

  static Future<bool> verifyPassword(String password, String hashedPassword) async {
    final response = await Isolate.run(() {
      return BCrypt.checkpw(password, hashedPassword);
    });
    return response;
  }
}