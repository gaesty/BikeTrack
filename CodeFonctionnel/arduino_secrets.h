/**
 * @file arduino_secrets.h
 * @brief Fichier de configuration des paramètres sensibles
 * @note IMPORTANT : Ce fichier ne doit JAMAIS être commité dans git !
 */

#ifndef ARDUINO_SECRETS_H
#define ARDUINO_SECRETS_H

// --- Configuration SIM ---
#define SECRET_SIM_PIN_CODE "2305"


// --- Configuration réseau (optionnel) ---
#define SECRET_APN "mmsbouygtel.com"
#define SECRET_GPRS_USER ""
#define SECRET_GPRS_PASS ""

// --- Configuration dispositif ---
#define SECRET_DEVICE_ID "A7670E_003"

// --- Proxy URL ---
#define SECRET_PROXY_URL "http://35.193.109.50:3000/proxy"
#define PROXY_HOST "35.193.109.50"
#define PROXY_PORT 3000

#endif // ARDUINO_SECRETS_H