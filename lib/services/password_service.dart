import 'password_service_impl.dart';

class PasswordService {
  // Générer un hash de mot de passe
  static Future<String> hashPassword(String password) {
    return PasswordServiceImpl.hashPassword(password);
  }

  // Vérifier un mot de passe
  static Future<bool> verifyPassword(String password, String hashedPassword) {
    return PasswordServiceImpl.verifyPassword(password, hashedPassword);
  }
}