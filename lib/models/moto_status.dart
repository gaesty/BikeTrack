/// Modèle de données représentant l'état d'une moto connectée
/// Contient les informations de localisation, batterie et capteurs de sécurité
class MotoStatus {
  // Coordonnées GPS de la moto
  final double latitude;   // Latitude en degrés décimaux
  final double longitude;  // Longitude en degrés décimaux
  
  // Informations sur la batterie (en pourcentage, 0.0 à 100.0)
  final double batteryLevel;
  
  // Capteurs de sécurité
  final bool shockDetected;  // Détection de chocs ou vibrations anormales
  final bool tiltDetected;   // Détection d'inclinaison excessive (chute potentielle)
  
  // Horodatage de la dernière mise à jour des données
  final DateTime timestamp;

  /// Constructeur de la classe MotoStatus
  /// [latitude] et [longitude] : Position GPS (obligatoires)
  /// [batteryLevel] : Niveau de batterie en pourcentage (obligatoire)
  /// [shockDetected] : État du capteur de choc (par défaut false)
  /// [tiltDetected] : État du capteur d'inclinaison (par défaut false)
  /// [timestamp] : Moment de la mesure (obligatoire)
  MotoStatus({
    required this.latitude,
    required this.longitude,
    required this.batteryLevel,
    this.shockDetected = false,
    this.tiltDetected = false,
    required this.timestamp,
  });

  /// Factory pour créer une instance MotoStatus depuis un objet JSON
  /// Utilisé pour désérialiser les données reçues depuis l'API ou la base de données
  /// [json] : Map contenant les données au format JSON
  /// Returns : Instance de MotoStatus avec les données parsées
  factory MotoStatus.fromJson(Map<String, dynamic> json) {
    return MotoStatus(
      latitude: json['latitude'],
      longitude: json['longitude'],
      batteryLevel: json['batteryLevel'].toDouble(),
      shockDetected: json['shockDetected'] ?? false,
      tiltDetected: json['tiltDetected'] ?? false,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  /// Convertit l'instance MotoStatus en objet JSON
  /// Utilisé pour sérialiser les données avant envoi à l'API ou stockage en base
  /// Returns : Map<String, dynamic> représentant les données au format JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'batteryLevel': batteryLevel,
      'shockDetected': shockDetected,
      'tiltDetected': tiltDetected,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
