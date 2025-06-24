
/**
 * @file      code_mpu9250_corrige_v2.ino
 * @description Code corrigé pour LilyGO A7670E-FASE : 
 *             - Initialisation appropriée du modem avec séquence complète
 *             - Attente des données GPS valides avant envoi
 *             - Ordre d'initialisation optimisé
 * @version   CORRIGÉ - Résout les problèmes d'initialisation du modem
 */

#include "utilities.h"
#include <WiFi.h>
#include <TinyGsmClient.h>
#include <TinyGPSPlus.h>
#include <Wire.h>
#include <MPU9250_asukiaaa.h>
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include "arduino_secrets.h"

#define SDA_PIN 21
#define SCL_PIN 22
#define MPU9250_ADDRESS 0x68
#define I2C_CLOCK_SPEED 100000
#define SENSOR_INTERVAL 15000
#define SUPABASE_INTERVAL 15000

// Serial pour GPS et modem
#define SerialAT Serial1

TinyGPSPlus gps;
TinyGsm modem(SerialAT);
MPU9250_asukiaaa mySensor;

uint32_t lastSensorRead = 0;
uint32_t lastSupabaseSend = 0;
bool gpsInitialized = false;
bool gpsDataReceived = false;  // NOUVEAU: Flag pour vérifier si des données GPS ont été reçues
bool mpuInitialized = false;
bool accelValid = false;
bool gyroValid = false;
bool magValid = false;
bool tempValid = false;

struct SensorData {
  float ax, ay, az;
  float gx, gy, gz;
  float mx, my, mz;
  float temperature;
} sensorData;

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("🔧 Initialisation...");

  // ÉTAPE 1: Initialisation du matériel du modem (CRITICIAL - DOIT ÊTRE EN PREMIER)
  initializeModemHardware();

  // ÉTAPE 2: Identification et test du modem
  if (!testModemConnection()) {
    Serial.println("❌ Impossible de communiquer avec le modem");
    Serial.println("   Vérifiez les connexions et redémarrez");
    while(1) delay(1000);
  }

  // ÉTAPE 3: Initialisation GPS
  initializeGPS();

  // ÉTAPE 4: Initialisation I2C pour MPU9250 (APRÈS le modem)
  Wire.begin(SDA_PIN, SCL_PIN, I2C_CLOCK_SPEED);
  delay(100);
  initializeMPU9250();

  // ÉTAPE 5: Connexion Wi-Fi (EN DERNIER pour éviter les conflits)
  initializeWiFi();

  Serial.println("✅ Initialisation terminée !");
  Serial.println("➡️ En attente des données GPS valides...");

  lastSensorRead = millis();
  lastSupabaseSend = millis();
}

void loop() {
  // Lecture des trames NMEA
  while (SerialAT.available()) {
    if (gps.encode(SerialAT.read())) {
      if (gps.location.isValid() && !gpsDataReceived) {
        gpsDataReceived = true;
        Serial.println("🎯 Premières données GPS valides reçues !");
        displayGPSInfo();
      }
    }
  }

  uint32_t now = millis();

  // Lecture périodique des capteurs
  if (now - lastSensorRead >= SENSOR_INTERVAL) {
    lastSensorRead = now;
    readMPU9250Data();

    if (gps.location.isUpdated()) {
      gpsInitialized = true;
      displayGPSInfo();
    }
  }

  // Envoi vers Supabase SEULEMENT si GPS valide (NOUVEAU)
  if (now - lastSupabaseSend >= SUPABASE_INTERVAL) {
    if (gpsDataReceived && gps.location.isValid()) {
      lastSupabaseSend = now;
      sendDataToSupabase();
    } else {
      Serial.println("⏳ En attente de données GPS valides pour envoi Supabase...");
      if (gps.satellites.isValid()) {
        Serial.println("   Satellites détectés: " + String(gps.satellites.value()));
      }
    }
  }

  delay(100);
}

// NOUVELLE FONCTION: Initialisation complète du matériel du modem
void initializeModemHardware() {
  Serial.println("🔧 Initialisation du matériel du modem...");

  // CRITICIAL: Alimentation du modem (souvent oublié dans le code principal)
  #ifdef BOARD_POWERON_PIN
    pinMode(BOARD_POWERON_PIN, OUTPUT);
    digitalWrite(BOARD_POWERON_PIN, HIGH);
    Serial.println("✅ Alimentation modem activée (BOARD_POWERON_PIN)");
    delay(100);
  #endif

  // CRITICIAL: Séquence de reset du modem (manquait dans le code principal)
  #ifdef MODEM_RESET_PIN
    pinMode(MODEM_RESET_PIN, OUTPUT);
    digitalWrite(MODEM_RESET_PIN, !MODEM_RESET_LEVEL); 
    delay(50);
    digitalWrite(MODEM_RESET_PIN, MODEM_RESET_LEVEL); 
    delay(1000);  // Délai plus long pour reset complet
    digitalWrite(MODEM_RESET_PIN, !MODEM_RESET_LEVEL);
    Serial.println("✅ Reset du modem effectué");
    delay(100);
  #endif

  // Séquence PWRKEY appropriée
  pinMode(BOARD_PWRKEY_PIN, OUTPUT);
  digitalWrite(BOARD_PWRKEY_PIN, LOW);
  delay(50);
  digitalWrite(BOARD_PWRKEY_PIN, HIGH);
  delay(500);  // Délai plus long pour démarrage stable
  digitalWrite(BOARD_PWRKEY_PIN, LOW);
  Serial.println("✅ Séquence PWRKEY terminée");

  // Initialisation de la communication série
  SerialAT.begin(115200, SERIAL_8N1, MODEM_RX_PIN, MODEM_TX_PIN);
  delay(1000);  // Laisser le temps au modem de démarrer
}

// NOUVELLE FONCTION: Test de la connexion modem avec retry
bool testModemConnection() {
  Serial.println("🔍 Test de la connexion modem...");

  int retry = 0;
  int maxRetries = 10;

  while (!modem.testAT(1000) && retry < maxRetries) {
    Serial.print(".");
    retry++;

    // Retry PWRKEY si nécessaire
    if (retry % 3 == 0) {
      Serial.println("\n🔄 Nouvelle tentative PWRKEY...");
      digitalWrite(BOARD_PWRKEY_PIN, LOW);
      delay(50);
      digitalWrite(BOARD_PWRKEY_PIN, HIGH);
      delay(500);
      digitalWrite(BOARD_PWRKEY_PIN, LOW);
      delay(1000);
    }

    delay(1000);
  }

  if (retry >= maxRetries) {
    return false;
  }

  Serial.println("\n✅ Modem répond aux commandes AT");

  // Identification du modem
  String modemName = modem.getModemName();
  Serial.println("📋 Modem détecté : " + modemName);

  return true;
}

void initializeGPS() {
  Serial.println("🛰️ Activation GPS...");

  int retry = 10;
  while (!modem.enableGPS(MODEM_GPS_ENABLE_GPIO, MODEM_GPS_ENABLE_LEVEL)) {
    Serial.print(".");
    if (retry-- <= 0) {
      Serial.println("❌ Échec démarrage GPS. Vérifiez la carte.");
      break;
    }
    delay(200);
  }

  if (retry > 0) {
    Serial.println("\n✅ GPS activé");
    // Configuration NMEA
    modem.setGPSBaud(115200);
    modem.setGPSMode(3); // GPS + GLONASS + Beidou
    modem.configNMEASentence(1, 1, 1, 1, 1, 1);
    modem.setGPSOutputRate(1);
    modem.enableNMEA();
    Serial.println("➡️ Configuration GPS terminée, attente des données...");
  }
}

void initializeMPU9250() {
  Serial.println("📊 Initialisation MPU9250...");
  mySensor.setWire(&Wire);

  // Test accéléromètre
  mySensor.beginAccel(); 
  delay(50);
  mySensor.accelUpdate();
  if (abs(mySensor.accelX()) > 0.001) accelValid = true;

  // Test gyroscope
  mySensor.beginGyro(); 
  delay(50);
  mySensor.gyroUpdate();
  if (abs(mySensor.gyroX()) > 0.001) gyroValid = true;

  // Configuration magnétomètre
  Wire.beginTransmission(MPU9250_ADDRESS);
  Wire.write(0x37); Wire.write(0x02); 
  Wire.endTransmission(); 
  delay(100);

  Wire.beginTransmission(MPU9250_ADDRESS);
  Wire.write(0x6A); Wire.write(0x00); 
  Wire.endTransmission(); 
  delay(100);

  // Test magnétomètre
  mySensor.beginMag(); 
  delay(100);
  mySensor.magUpdate();
  if (abs(mySensor.magX()) > 0.001) magValid = true;

  mpuInitialized = accelValid || gyroValid || magValid;
  tempValid = mpuInitialized;

  if (mpuInitialized) {
    Serial.println("✅ MPU9250 initialisé");
  } else {
    Serial.println("⚠️ Initialisation partielle MPU9250");
  }
}

void initializeWiFi() {
  Serial.println("🔌 Connexion au WiFi...");
  WiFi.begin(SECRET_WIFI_SSID, SECRET_WIFI_PASSWORD);

  int retry = 0;
  while (WiFi.status() != WL_CONNECTED && retry++ < 20) {
    delay(500);
    Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi connecté à : " + WiFi.SSID());
    Serial.println("📡 Adresse IP : " + WiFi.localIP().toString());
  } else {
    Serial.println("\n❌ Connexion WiFi échouée");
  }
}

void readMPU9250Data() {
  if (!mpuInitialized) return;

  if (accelValid && mySensor.accelUpdate() == 0) {
    sensorData.ax = mySensor.accelX();
    sensorData.ay = mySensor.accelY();
    sensorData.az = mySensor.accelZ();
  }

  if (gyroValid && mySensor.gyroUpdate() == 0) {
    sensorData.gx = mySensor.gyroX();
    sensorData.gy = mySensor.gyroY();
    sensorData.gz = mySensor.gyroZ();
  }

  if (magValid && mySensor.magUpdate() == 0) {
    sensorData.mx = mySensor.magX();
    sensorData.my = mySensor.magY();
    sensorData.mz = mySensor.magZ();
  }

  if (tempValid) {
    uint8_t rawData[2];
    Wire.beginTransmission(MPU9250_ADDRESS);
    Wire.write(0x41);
    Wire.endTransmission(false);
    if (Wire.requestFrom(MPU9250_ADDRESS, 2) == 2) {
      rawData[0] = Wire.read();
      rawData[1] = Wire.read();
      int16_t tempCount = ((int16_t)rawData[0] << 8) | rawData[1];
      sensorData.temperature = ((float)tempCount / 340.0) + 36.53;
    }
  }
}

void displayGPSInfo() {
  Serial.println("📍 GPS:");
  Serial.println(" Lat: " + String(gps.location.lat(), 6));
  Serial.println(" Lng: " + String(gps.location.lng(), 6));
  Serial.println(" Satellites: " + String(gps.satellites.value()));
  Serial.println(" HDOP: " + String(gps.hdop.value()));
}

// FONCTION MODIFIÉE: Envoi seulement si GPS valide
void sendDataToSupabase() {
  // NOUVELLE VÉRIFICATION: Ne pas envoyer si pas de données GPS valides
  if (!gpsDataReceived || !gps.location.isValid()) {
    Serial.println("⏳ Pas de données GPS valides, envoi annulé");
    return;
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("❌ WiFi déconnecté");
    return;
  }

  StaticJsonDocument<1024> doc;
  doc["device_id"] = SECRET_DEVICE_ID;
  doc["signal_quality"] = WiFi.RSSI();
  doc["data_source"] = "WiFi";
  doc["uptime_seconds"] = millis()/1000;

  // GPS toujours valide à ce point
  doc["gps_valid"] = true;
  doc["latitude"] = gps.location.lat();
  doc["longitude"] = gps.location.lng();
  doc["altitude"] = gps.altitude.meters();
  doc["satellites"] = gps.satellites.value();
  doc["hdop"] = gps.hdop.value();
  if (gps.speed.isValid()) doc["gps_speed"] = gps.speed.kmph();

  if (accelValid) {
    doc["accel_valid"] = true;
    doc["accel_x"] = sensorData.ax;
    doc["accel_y"] = sensorData.ay;
    doc["accel_z"] = sensorData.az;
  } else doc["accel_valid"] = false;

  if (gyroValid) {
    doc["gyro_valid"] = true;
    doc["gyro_x"] = sensorData.gx;
    doc["gyro_y"] = sensorData.gy;
    doc["gyro_z"] = sensorData.gz;
  } else doc["gyro_valid"] = false;

  if (magValid) {
    doc["mag_valid"] = true;
    doc["mag_x"] = sensorData.mx;
    doc["mag_y"] = sensorData.my;
    doc["mag_z"] = sensorData.mz;
  } else doc["mag_valid"] = false;

  if (tempValid) {
    doc["temp_valid"] = true;
    doc["temperature"] = sensorData.temperature;
  } else doc["temp_valid"] = false;

  String str;
  serializeJson(doc, str);
  Serial.println("📤 JSON avec GPS valide:");
  Serial.println(str);

  HTTPClient http;
  http.begin(SECRET_PROXY_URL);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SECRET_SUPABASE_ANON_KEY);
  http.addHeader("Authorization", "Bearer " + String(SECRET_SUPABASE_ANON_KEY));
  http.addHeader("Prefer", "return=minimal");

  int code = http.POST(str);
  Serial.println("📬 Code HTTP : " + String(code));
  if (code > 0) {
    Serial.println("📨 Réponse : " + http.getString());
  } else {
    Serial.println("❌ Échec envoi HTTP");
  }
  http.end();
}
