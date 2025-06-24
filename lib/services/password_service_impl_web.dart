import 'package:bcrypt/bcrypt.dart';

class PasswordServiceImpl {
  static Future<String> hashPassword(String password) async {
    // Run synchronously on web since isolates aren't available
    return BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 10)); // Lower rounds for better web performance
  }

  static Future<bool> verifyPassword(String password, String hashedPassword) async {
    return BCrypt.checkpw(password, hashedPassword);
  }
}