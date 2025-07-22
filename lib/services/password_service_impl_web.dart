/// Implémentation web du service de mots de passe pour BikeTrack
/// 
/// Cette implémentation utilise BCrypt pour le web avec des optimisations
/// spécifiques à cette plateforme. Contrairement à l'implémentation mobile,
/// les calculs s'exécutent de manière synchrone car les isolates ne sont
/// pas disponibles dans les navigateurs web.
/// 
/// Adaptations pour le web:
/// - Utilise 10 rounds au lieu de 12 pour de meilleures performances
/// - Exécution synchrone (pas d'isolates disponibles)
/// - Compatible avec tous les navigateurs modernes
/// - Optimisé pour la latence réseau et les ressources limitées
import 'package:bcrypt/bcrypt.dart';  // Bibliothèque BCrypt compilée pour le web

/// Implémentation concrète du service de mots de passe pour la plateforme web
/// 
/// Cette classe adapte les opérations de chiffrement pour les contraintes
/// spécifiques aux navigateurs web, notamment l'absence d'isolates et
/// les limitations de performance JavaScript.
class PasswordServiceImpl {
  
  /// Hash un mot de passe en utilisant BCrypt optimisé pour le web
  /// 
  /// Sur le web, BCrypt s'exécute dans le thread principal car les isolates
  /// ne sont pas supportés. Pour maintenir de bonnes performances, nous
  /// utilisons 10 rounds au lieu de 12, ce qui reste très sécurisé tout
  /// en réduisant la latence perçue par l'utilisateur.
  /// 
  /// Le nombre de rounds réduit (10 vs 12) représente environ 4x moins
  /// d'itérations (1024 vs 4096) mais reste largement suffisant pour
  /// résister aux attaques par force brute modernes.
  /// 
  /// @param password Le mot de passe en clair à hacher (String)
  /// @returns Future<String> Le hash BCrypt complet (salt + hash)
  /// @throws Exception si le hachage échoue
  static Future<String> hashPassword(String password) async {
    // Exécution synchrone avec Future.value pour maintenir l'API async
    // 10 rounds = 2^10 = 1024 itérations (optimisé pour les performances web)
    return BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 10));
  }

  /// Vérifie qu'un mot de passe correspond au hash stocké (version web)
  /// 
  /// Cette méthode effectue la vérification de manière synchrone dans
  /// le thread principal, ce qui est acceptable car la vérification
  /// est généralement plus rapide que le hachage initial.
  /// 
  /// La vérification reste résistante aux attaques par timing grâce
  /// à l'implémentation BCrypt qui effectue toujours le même nombre
  /// d'opérations indépendamment du résultat.
  /// 
  /// @param password Le mot de passe en clair à vérifier (String)
  /// @param hashedPassword Le hash BCrypt stocké (String)
  /// @returns Future<bool> true si le mot de passe correspond, false sinon
  /// @throws Exception si la vérification échoue
  static Future<bool> verifyPassword(String password, String hashedPassword) async {
    // Vérification synchrone avec protection contre les attaques par timing
    return BCrypt.checkpw(password, hashedPassword);
  }
}