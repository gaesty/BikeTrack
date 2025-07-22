/// Fichier de sélection d'implémentation conditionnelle pour le service de mots de passe
/// 
/// Ce fichier utilise les imports conditionnels de Dart pour sélectionner
/// automatiquement l'implémentation appropriée du service de mots de passe
/// selon la plateforme cible :
/// 
/// - Sur le web : utilise password_service_impl_web.dart (crypto-js ou WebCrypto API)
/// - Sur mobile/desktop : utilise password_service_impl_mobile.dart (pointycastle, ffi)
/// 
/// Cette approche permet d'optimiser les performances et la sécurité pour chaque
/// plateforme tout en maintenant une interface unifiée.

// Import conditionnel basé sur la disponibilité des bibliothèques Dart
// dart.library.io est disponible sur mobile/desktop mais pas sur le web
// ignore: uri_does_not_exist

// Re-export de l'implémentation sélectionnée selon la plateforme
// Si dart.library.io est disponible -> mobile/desktop, sinon -> web
export 'password_service_impl_web.dart'
    if (dart.library.io) 'password_service_impl_mobile.dart';