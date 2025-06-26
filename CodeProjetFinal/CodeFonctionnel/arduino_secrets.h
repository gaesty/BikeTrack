/**
 * @file arduino_secrets.h
 * @brief Fichier de configuration des paramètres sensibles
 * @note IMPORTANT : Ce fichier ne doit JAMAIS être commité dans git !
 */

#ifndef ARDUINO_SECRETS_H
#define ARDUINO_SECRETS_H

// --- Configuration Supabase ---
#define SECRET_SUPABASE_URL "https://oynnjhnjyeogltujthcy.supabase.co"
#define SECRET_SUPABASE_ANON_KEY "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95bm5qaG5qeWVvZ2x0dWp0aGN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAzMzIwNTgsImV4cCI6MjA2NTkwODA1OH0.eP28KmebtF0AmUdkUcnzLuRhl4uMnkYJfIaHZ4nHFl4"

// --- Configuration SIM ---
#define SECRET_SIM_PIN_CODE "2305"

// --- Configuration SMS ---
#define SECRET_SMS_TARGET "+33613303386"

// --- Configuration réseau (optionnel) ---
#define SECRET_APN "mmsbouygtel.com"
#define SECRET_GPRS_USER ""
#define SECRET_GPRS_PASS ""

// --- Configuration dispositif ---
#define SECRET_DEVICE_ID "A7670E_003"

// --- Wifi ---
#define SECRET_WIFI_SSID "Pixel_7837"
#define SECRET_WIFI_PASSWORD "fcyjk6urgkt7fek"

// --- Proxy URL ---
#define SECRET_PROXY_URL "http://35.193.109.50:3000/proxy"

#endif // ARDUINO_SECRETS_H