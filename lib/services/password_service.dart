/// Service de gestion des mots de passe pour BikeTrack
/// 
/// Cette classe fournit une interface unifiée pour le hachage et la vérification
/// des mots de passe dans l'application BikeTrack. Elle utilise une implémentation
/// spécifique à la plateforme pour optimiser la sécurité et les performances.
/// 
/// Fonctionnalités:
/// - Hachage sécurisé des mots de passe avec salt
/// - Vérification des mots de passe hashés
/// - Compatibilité multiplateforme (mobile, web, desktop)
import 'password_service_impl.dart';

/// Classe principale du service de gestion des mots de passe
/// 
/// Cette classe utilise le pattern Facade pour simplifier l'accès aux
/// fonctionnalités de chiffrement de mots de passe tout en déléguant
/// l'implémentation réelle à une classe spécifique à la plateforme.
class PasswordService {
  
  /// Génère un hash sécurisé d'un mot de passe en clair
  /// 
  /// Utilise un algorithme de hachage robuste (bcrypt, scrypt ou argon2)
  /// avec un salt généré aléatoirement pour chaque mot de passe.
  /// Le résultat peut être stocké en sécurité en base de données.
  /// 
  /// @param password Le mot de passe en clair à hacher
  /// @returns Un Future contenant le hash du mot de passe
  /// @throws Exception si le hachage échoue
  static Future<String> hashPassword(String password) {
    return PasswordServiceImpl.hashPassword(password);
  }

  /// Vérifie qu'un mot de passe en clair correspond au hash stocké
  /// 
  /// Compare le mot de passe fourni avec le hash stocké en utilisant
  /// l'algorithme de hachage approprié. Cette méthode est résistante
  /// aux attaques par timing grâce à une comparaison constante.
  /// 
  /// @param password Le mot de passe en clair à vérifier
  /// @param hashedPassword Le hash stocké pour comparaison
  /// @returns Un Future<bool> - true si le mot de passe correspond
  /// @throws Exception si la vérification échoue
  static Future<bool> verifyPassword(String password, String hashedPassword) {
    return PasswordServiceImpl.verifyPassword(password, hashedPassword);
  }
}