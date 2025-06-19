# biketrack

lib/
  ├── main.dart                    # Point d'entrée de l'application
  ├── app.dart                     # Configuration de l'application
  ├── config/                      # Configuration globale
  │   ├── app_config.dart          # Configuration de l'application
  │   ├── theme.dart               # Thème de l'application
  │   └── routes.dart              # Routes de l'application
  ├── core/                        # Logique centrale
  │   ├── api/                     # API pour communication avec le backend
  │   │   ├── dio_client.dart      # Client HTTP
  │   │   ├── mqtt_client.dart     # Client MQTT pour données en temps réel
  │   │   └── sensor_api.dart      # API pour les capteurs
  │   ├── models/                  # Modèles de données
  │   │   ├── sensor_data.dart     # Modèle pour les données de capteur
  │   │   └── device.dart          # Modèle pour les appareils
  │   ├── repositories/            # Repositories pour la gestion des données
  │   │   ├── sensor_repository.dart   # Repository pour les données capteur
  │   │   └── device_repository.dart   # Repository pour les appareils
  │   └── utils/                   # Utilitaires divers
  │       ├── date_formatter.dart  # Formatage des dates
  │       └── constants.dart       # Constantes de l'application
  ├── presentation/                # Couche de présentation
  │   ├── controllers/             # Contrôleurs (GetX)
  │   │   ├── home_controller.dart   # Contrôleur de la page d'accueil
  │   │   ├── sensor_controller.dart # Contrôleur pour les capteurs
  │   │   └── device_controller.dart # Contrôleur pour les appareils
  │   ├── screens/                 # Écrans de l'application
  │   │   ├── home/                  # Page d'accueil
  │   │   │   ├── home_screen.dart     # Écran principal
  │   │   │   └── widgets/             # Widgets spécifiques à l'écran
  │   │   ├── sensor_detail/         # Détails d'un capteur
  │   │   │   ├── sensor_detail_screen.dart
  │   │   │   └── widgets/
  │   │   └── settings/              # Paramètres
  │   │       ├── settings_screen.dart
  │   │       └── widgets/
  │   └── widgets/                 # Widgets globaux réutilisables
  │       ├── sensor_chart.dart      # Graphique pour les données de capteur
  │       ├── loading_indicator.dart # Indicateur de chargement
  │       └── error_view.dart        # Vue d'erreur
  └── data/                        # Couche de données
      ├── local/                   # Stockage local
      │   ├── database.dart          # Base de données locale
      │   └── preferences.dart       # Préférences de l'application
      └── remote/                  # Sources de données distantes
          ├── api_service.dart       # Service API REST
          └── mqtt_service.dart      # Service MQTT

