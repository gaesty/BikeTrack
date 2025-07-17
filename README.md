# 🏍️ BikeTrack

**Système de surveillance et de sécurité intelligent pour motocycles**

BikeTrack est une solution complète qui combine une application mobile Flutter et un dispositif IoT embarqué pour offrir un système de surveillance avancé des motocycles. Le projet intègre la géolocalisation, la détection de mouvements, les alertes de sécurité et un système de suivi en temps réel.

## 📋 Table des matières

- [🎯 Fonctionnalités principales](#-fonctionnalités-principales)
- [🏗️ Architecture du projet](#️-architecture-du-projet)
- [📱 Application mobile](#-application-mobile)
- [🔧 Dispositif IoT](#-dispositif-iot)
- [🌐 Infrastructure cloud](#-infrastructure-cloud)
- [⚙️ Installation](#️-installation)
- [🚀 Utilisation](#-utilisation)
- [🔧 Configuration](#-configuration)
- [📊 Technologies utilisées](#-technologies-utilisées)
- [🤝 Contribution](#-contribution)

## 🎯 Fonctionnalités principales

### 🔒 Sécurité et surveillance
- **Détection de vol** : Alertes automatiques en cas de mouvement non autorisé
- **Détection de chute** : Système d'urgence automatique avec confirmation
- **Alertes en temps réel** : Notifications push instantanées
- **Contacts d'urgence** : Envoi automatique d'alertes aux proches

### 📍 Géolocalisation et suivi
- **Suivi GPS en temps réel** : Localisation précise du véhicule
- **Historique des trajets** : Visualisation des parcours effectués
- **Cartes interactives** : Affichage sur OpenStreetMap
- **Calcul de distances** : Statistiques de trajets détaillées

### 📊 Surveillance technique
- **Monitoring de batterie** : Suivi du niveau de charge en temps réel
- **Capteurs d'inclinaison** : MPU9250 pour détecter les mouvements anormaux
- **Données accélérométriques** : Analyse des forces G et détection d'impacts
- **Connectivité 4G** : Transmission de données via réseau cellulaire

## 🏗️ Architecture du projet

Le projet BikeTrack est organisé en plusieurs composants interconnectés :

```
BikeTrack/
├── 📱 Application Flutter/     # Interface utilisateur mobile
├── 🔧 Code Arduino/           # Firmware pour LilyGO A7670E
├── 🌐 Proxy Cloud/           # Serveur intermédiaire
└── 🗄️ Base de données/        # Supabase pour le stockage
```

## 📱 Application mobile

### Écrans principaux

**🏠 Accueil (`home_screen.dart`)**
- Carte interactive avec le dernier trajet effectué
- Affichage des points de départ et d'arrivée
- Statistiques du trajet (distance, durée)
- Visualisation en temps réel de la position

**📊 Historique (`history_screen.dart`)**
- Liste complète des trajets passés
- Filtrage par période personnalisable
- Cartes miniatures pour chaque trajet
- Statistiques détaillées (vitesse, inclinaison)

**🚨 Alertes (`alerts_screen.dart`)**
- Monitoring des événements de sécurité
- Détection automatique de vol et chute
- Notifications push configurables
- Seuils de sensibilité personnalisables

**🆘 Urgence (`safety_screen.dart`)**
- Gestion des contacts d'urgence
- Configuration du délai de confirmation
- Système d'alerte automatique en cas de chute

**⚙️ Paramètres (`settings_screen.dart`)**
- Configuration des seuils de détection
- Paramètres de notification
- Gestion du compte utilisateur
- Réglages de sensibilité (parking/roulage)

### Authentification
- **Connexion sécurisée** (`login_screen.dart`)
- **Inscription** (`signup_screen.dart`) 
- **Gestion des sessions** avec Supabase Auth

## 🔧 Dispositif IoT

### Matériel
- **LilyGO A7670E-FASE** : Module principal avec connectivité 4G
- **MPU9250** : Capteur 9 axes (accéléromètre, gyroscope, magnétomètre)
- **GPS intégré** : Localisation haute précision
- **Batterie LiPo** : Monitoring automatique du niveau de charge

### Fonctionnalités du firmware
```cpp
// Principales fonctions du code Arduino
- Initialisation GPS et capteurs MPU9250
- Connexion réseau 4G automatique
- Envoi de données vers Supabase via HTTPS
- Système de SMS d\'urgence
- Monitoring de batterie en temps réel
- Détection de mouvements anormaux
```

### Configuration matérielle
| Composant | Pin LilyGO | Description |
|-----------|------------|-------------|
| MPU9250 SDA | GPIO 21 | Ligne de données I2C |
| MPU9250 SCL | GPIO 22 | Ligne d'horloge I2C |
| MPU9250 VCC | 3.3V | Alimentation stable |
| MPU9250 GND | GND | Masse commune |

## 🌐 Infrastructure cloud

### Base de données Supabase
- **Table `users`** : Informations utilisateurs et device_id
- **Table `sensor_data`** : Données télémétriques en temps réel
- **Authentification** : Gestion sécurisée des comptes
- **API REST** : Interface standardisée pour les données

### Proxy Cloud (`Proxy/proxy.js`)
- **Serveur Express.js** déployé sur Google Cloud
- **Transformation de données** : Format compact vers schéma Supabase
- **Relais HTTPS** : Interface entre dispositif IoT et base de données
- **Gestion des erreurs** : Robustesse des communications

### Structure des données
```javascript
// Format compact du dispositif IoT
{
  "id": "device_id",
  "sig": 85,                    // Signal quality
  "lat": 48.8566,              // Latitude
  "lng": 2.3522,               // Longitude
  "ax": 0.12,                  // Accélération X
  "speed": 45.5                // Vitesse GPS
}

// Format étendu en base de données
{
  "device_id": "device_id",
  "signal_quality": 85,
  "latitude": 48.8566,
  "longitude": 2.3522,
  "accel_x": 0.12,
  "gps_speed": 45.5,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

## ⚙️ Installation

### Prérequis
- **Flutter SDK** ≥ 3.8.1
- **Android Studio** ou **VS Code** avec extensions Flutter
- **Arduino IDE** avec support ESP32
- **Compte Supabase** pour la base de données
- **Google Cloud Platform** pour le proxy (optionnel)

### Installation de l'application

1. **Cloner le projet**
```bash
git clone https://github.com/Ewnn/BikeTrack.git
cd BikeTrack
```

2. **Installer les dépendances**
```bash
flutter pub get
```

3. **Configuration Supabase**
   - Créer un projet sur [supabase.com](https://supabase.com)
   - Modifier les clés API dans `lib/main.dart`

4. **Lancer l'application**
```bash
flutter run
```

### Installation du firmware Arduino

1. **Préparer l'environnement**
```bash
# Installer les bibliothèques requises
- TinyGSM
- TinyGPSPlus  
- MPU9250_asukiaaa
- ArduinoJson
```

2. **Configuration**
   - Créer `arduino_secrets.h` avec vos paramètres réseau
   - Configurer l'APN de votre opérateur mobile
   - Définir l'URL du proxy cloud

3. **Upload du firmware**
```bash
# Compiler et uploader via Arduino IDE
# Port série : 115200 baud
```

## 🚀 Utilisation

### Première utilisation

1. **Inscription dans l'application**
   - Créer un compte avec email/mot de passe
   - Associer votre device_id unique

2. **Installation du dispositif**
   - Monter le boîtier LilyGO sur le véhicule
   - Connecter les capteurs selon le schéma
   - Mettre sous tension et vérifier la connexion 4G

3. **Configuration des alertes**
   - Définir les contacts d'urgence
   - Ajuster les seuils de sensibilité
   - Tester les notifications

### Utilisation quotidienne

- **Suivi automatique** : Le dispositif démarre automatiquement avec le véhicule
- **Alertes en temps réel** : Réception des notifications sur l'application
- **Consultation des trajets** : Visualisation dans l'onglet "Historique"
- **Urgence** : Système de confirmation automatique en cas de chute

## 🔧 Configuration

### Paramètres de détection

**Mode Parking**
- Seuil d'inclinaison : 10-90° (défaut: 50°)
- Seuil de vitesse : 0-20 km/h (défaut: 1 km/h)

**Mode Roulage**  
- Seuil d'inclinaison : 10-90° (défaut: 50°)
- Seuil de vitesse : 0-120 km/h (défaut: 5 km/h)

### Fichiers de configuration

**Arduino (`arduino_secrets.h`)**
```cpp
#define SECRET_APN "operator.apn"
#define SECRET_GPRS_USER "username"
#define SECRET_GPRS_PASS "password"
#define SECRET_SIM_PIN_CODE "0000"
#define PROXY_HOST "your-proxy-url.com"
#define PROXY_PORT 3000
```

**Application (variables d'environnement)**
```dart
// Supabase configuration in lib/main.dart
const String supabaseUrl = 'your-supabase-url';
const String supabaseAnonKey = 'your-anon-key';
```

## 📊 Technologies utilisées

### Frontend Mobile
- **Flutter** 3.8.1+ - Framework de développement mobile
- **Dart** - Langage de programmation
- **flutter_map** - Cartographie interactive
- **supabase_flutter** - Client base de données
- **geolocator** - Services de géolocalisation
- **flutter_local_notifications** - Notifications push

### Firmware IoT
- **Arduino/ESP32** - Plateforme de développement
- **TinyGSM** - Communication cellulaire
- **TinyGPSPlus** - Parsing des données GPS
- **MPU9250_asukiaaa** - Interface capteur IMU
- **ArduinoJson** - Sérialisation des données

### Infrastructure Cloud
- **Supabase** - Base de données PostgreSQL + Auth
- **Node.js/Express** - Serveur proxy
- **Google Cloud Platform** - Hébergement
- **OpenStreetMap** - Tuiles cartographiques

### Outils de développement
- **VS Code** - Éditeur de code
- **Android Studio** - IDE Android
- **Arduino IDE** - Développement firmware
- **Git** - Contrôle de version

## 🤝 Contribution

### Comment contribuer

1. **Fork** le projet
2. **Créer** une branche pour votre fonctionnalité
3. **Commiter** vos changements
4. **Pousser** vers la branche
5. **Ouvrir** une Pull Request

### Structure des commits
```
feat: ajout de la détection de freinage brusque
fix: correction du calcul de distance GPS  
docs: mise à jour du README pour l'installation
style: reformatage du code AlertsScreen
```

### Rapporter des bugs
Utilisez les issues GitHub avec le template :
- Description du problème
- Étapes pour reproduire  
- Comportement attendu
- Captures d'écran si pertinent
- Informations sur l'environnement

---

**BikeTrack** - Votre motocycle sous surveillance intelligente 🏍️

Développé avec ❤️ pour la sécurité des motards
