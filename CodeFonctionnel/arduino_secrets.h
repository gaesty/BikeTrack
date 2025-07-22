
#ifndef ARDUINO_SECRETS_H
#define ARDUINO_SECRETS_H

// ============================================================================
// CONFIGURATION CARTE SIM - Paramètres opérateur mobile
// ============================================================================

// Code PIN de votre carte SIM (4 chiffres généralement)
// IMPORTANT: Changez cette valeur selon votre carte SIM réelle
#define SECRET_SIM_PIN_CODE "2305"

// ============================================================================
// CONFIGURATION RÉSEAU MOBILE - Paramètres APN
// ============================================================================

// Point d'accès réseau (APN) de votre opérateur mobile
// Bouygues Telecom: "mmsbouygtel.com"
// Orange: "orange.fr" 
// SFR: "websfr"
// Free: "free"
#define SECRET_APN "mmsbouygtel.com"

// Identifiants GPRS (généralement vides pour les opérateurs français)
#define SECRET_GPRS_USER ""  // Nom d'utilisateur (laissez vide si non requis)
#define SECRET_GPRS_PASS ""  // Mot de passe (laissez vide si non requis)

// ============================================================================
// IDENTIFICATION DISPOSITIF - ID unique pour ce tracker
// ============================================================================

// Identifiant unique de ce dispositif BikeTrack
// Format recommandé: [MODÈLE]_[NUMÉRO] (ex: A7670E_001, A7670E_002...)
// Cet ID permet de différencier plusieurs trackers dans la base de données
#define SECRET_DEVICE_ID "A7670E_003"

// ============================================================================
// CONFIGURATION SERVEUR - Paramètres de connexion au proxy BikeTrack
// ============================================================================

// URL complète du serveur proxy BikeTrack
// Ce serveur fait le pont entre le dispositif et la base de données Supabase
#define SECRET_PROXY_URL "http://35.193.109.50:3000/proxy"

// Paramètres de connexion décomposés (utilisés par le client TCP)
#define PROXY_HOST "35.193.109.50"  // Adresse IP ou nom d'hôte du serveur
#define PROXY_PORT 3000             // Port TCP du serveur (généralement 3000)

#endif // ARDUINO_SECRETS_H