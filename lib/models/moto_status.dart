class MotoStatus {
  final double latitude;
  final double longitude;
  final double batteryLevel;
  final bool shockDetected;
  final bool tiltDetected;
  final DateTime timestamp;

  MotoStatus({
    required this.latitude,
    required this.longitude,
    required this.batteryLevel,
    this.shockDetected = false,
    this.tiltDetected = false,
    required this.timestamp,
  });

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
