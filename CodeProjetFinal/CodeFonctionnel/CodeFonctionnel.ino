/**
 * @file CodeFonctionnelsansGPS_Maj.ino
 * @brief Version mise à jour : envoi toutes les 15 s uniquement si GPS valide
 */

#include "utilities.h"
#include "arduino_secrets.h"
#include <TinyGsmClient.h>
#include <TinyGPSPlus.h>
#include <Wire.h>
#include <MPU9250_asukiaaa.h>
#include <ArduinoJson.h>

// --- Modem et client TCP ---
#define TINY_GSM_RX_BUFFER 1024
#define SerialAT Serial1
TinyGsm modem(SerialAT);
TinyGsmClient client(modem);

// --- Définitions I2C pour le MPU9250 ---
#define SDA_PIN 21
#define SCL_PIN 22
#define I2C_CLOCK_SPEED 100000
#define MPU9250_ADDRESS 0x68

// --- Structure données capteur ---
struct SensorData {
  float ax, ay, az;
  float gx, gy, gz;
  float temperature;
} sensorData;

// Modules globaux GPS et MPU
TinyGPSPlus gps;
MPU9250_asukiaaa mySensor;

// --- Paramètres réseau et proxy ---
const char* PROXY_HOST = "35.193.109.50";
const uint16_t PROXY_PORT = 3000;
const char apn[]      = SECRET_APN;
const char gprsUser[] = SECRET_GPRS_USER;
const char gprsPass[] = SECRET_GPRS_PASS;

// --- Intervalles (ms) ---
#define SENSOR_INTERVAL 30000
#define SEND_INTERVAL    15000  // envoi toutes les 15 secondes

// États
bool mpuInitialized   = false;
bool gpsInitialized   = false;
bool accelValid       = false;
bool gyroValid        = false;
bool tempValid        = false;
bool gprsConnected    = false;
uint32_t lastSensorRead = 0, lastSend = 0;

//-----------------------------------------------------------------------------
// Initialisation hardware (alim, modem, I2C MPU)
//-----------------------------------------------------------------------------
void initializeHardware() {
#ifdef BOARD_POWERON_PIN
  pinMode(BOARD_POWERON_PIN, OUTPUT);
  digitalWrite(BOARD_POWERON_PIN, HIGH);
#endif
#ifdef MODEM_RESET_PIN
  pinMode(MODEM_RESET_PIN, OUTPUT);
  digitalWrite(MODEM_RESET_PIN, !MODEM_RESET_LEVEL);
  delay(50);
  digitalWrite(MODEM_RESET_PIN, MODEM_RESET_LEVEL);
  delay(1000);
  digitalWrite(MODEM_RESET_PIN, !MODEM_RESET_LEVEL);
#endif
  pinMode(BOARD_PWRKEY_PIN, OUTPUT);
  digitalWrite(BOARD_PWRKEY_PIN, LOW);  delay(50);
  digitalWrite(BOARD_PWRKEY_PIN, HIGH); delay(500);
  digitalWrite(BOARD_PWRKEY_PIN, LOW);

  SerialAT.begin(MODEM_BAUDRATE, SERIAL_8N1, MODEM_RX_PIN, MODEM_TX_PIN);
  delay(100);
  Wire.begin(SDA_PIN, SCL_PIN, I2C_CLOCK_SPEED);
  delay(100);
}

//-----------------------------------------------------------------------------
// Connexion au réseau GPRS
//-----------------------------------------------------------------------------
bool connectGPRS() {
  Serial.println("🔍 Attente réseau...");
  if (!modem.waitForNetwork(60000L)) {
    Serial.println("❌ Pas d'enregistrement réseau");
    return false;
  }
  Serial.println("✅ Réseau OK, ouverture PDP (APN=" + String(apn) + ")...");
  if (!modem.gprsConnect(apn, gprsUser, gprsPass)) {
    Serial.println("❌ Échec GPRS connect");
    return false;
  }
  Serial.print("📍 IP attribuée : ");
  Serial.println(modem.getLocalIP());
  return true;
}

//-----------------------------------------------------------------------------
// Lecture MPU9250
//-----------------------------------------------------------------------------
void readMPU9250() {
  if (!mpuInitialized) return;
  if (mySensor.accelUpdate() == 0) {
    sensorData.ax = mySensor.accelX();
    sensorData.ay = mySensor.accelY();
    sensorData.az = mySensor.accelZ();
    accelValid = true;
  } else accelValid = false;

  if (mySensor.gyroUpdate() == 0) {
    sensorData.gx = mySensor.gyroX();
    sensorData.gy = mySensor.gyroY();
    sensorData.gz = mySensor.gyroZ();
    gyroValid = true;
  } else gyroValid = false;

  uint8_t raw[2];
  Wire.beginTransmission(MPU9250_ADDRESS);
  Wire.write(0x41);
  Wire.endTransmission(false);
  if (Wire.requestFrom(MPU9250_ADDRESS, 2) == 2) {
    raw[0] = Wire.read();
    raw[1] = Wire.read();
    int16_t t = (raw[0] << 8) | raw[1];
    sensorData.temperature = (t / 340.0f) + 36.53f;
    tempValid = true;
  } else tempValid = false;
}

//-----------------------------------------------------------------------------
// Construction JSON compact pour envoi
//-----------------------------------------------------------------------------
String buildJson() {
  StaticJsonDocument<512> doc;
  doc["device_id"]     = SECRET_DEVICE_ID;
  doc["signal_quality"]= modem.getSignalQuality();
  doc["data_source"]   = "4G";
  doc["uptime_seconds"]= millis() / 1000;

  doc["gps_valid"] = gps.location.isValid();
  if (gps.location.isValid()) {
    doc["latitude"]   = gps.location.lat();
    doc["longitude"]  = gps.location.lng();
    doc["altitude"]   = gps.altitude.meters();
    doc["satellites"] = gps.satellites.value();
    doc["hdop"]       = gps.hdop.value();
    doc["gps_speed"]  = gps.speed.kmph();
  }

  doc["accel_valid"] = accelValid;
  if (accelValid) {
    doc["accel_x"] = sensorData.ax;
    doc["accel_y"] = sensorData.ay;
    doc["accel_z"] = sensorData.az;
  }

  doc["gyro_valid"] = gyroValid;
  if (gyroValid) {
    doc["gyro_x"] = sensorData.gx;
    doc["gyro_y"] = sensorData.gy;
    doc["gyro_z"] = sensorData.gz;
  }

  doc["temp_valid"] = tempValid;
  if (tempValid) {
    doc["temperature"] = sensorData.temperature;
  }

  String out;
  serializeJson(doc, out);
  return out;
}

//-----------------------------------------------------------------------------
// Envoi des données JSON via TCP vers proxy
//-----------------------------------------------------------------------------
bool sendDataToProxy(const String &body) {
  Serial.println("🔄 Envoi TCP vers proxy...");
  if (!client.connect(PROXY_HOST, PROXY_PORT)) {
    Serial.println("❌ Échec connexion TCP");
    return false;
  }
  Serial.println("✅ TCP établi");
  String req =
    String("POST /proxy HTTP/1.1\r\n") +
    "Host: " + PROXY_HOST + ":" + PROXY_PORT + "\r\n" +
    "Content-Type: application/json\r\n" +
    "Content-Length: " + body.length() + "\r\n" +
    "Connection: close\r\n\r\n" +
    body;
  client.print(req);

  uint32_t deadline = millis() + 10000;
  while (client.connected() && millis() < deadline) {
    while (client.available()) {
      Serial.write(client.read());
    }
  }
  client.stop();
  Serial.println("✅ TCP fermé");
  return true;
}

//-----------------------------------------------------------------------------
// Setup
//-----------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("🔧 Initialisation hardware...");
  initializeHardware();

  Serial.println("🔍 Test AT...");
  while (!modem.testAT()) { delay(500); }
  Serial.println("✅ Modem prêt");

  Serial.println("📶 SIM...");
  while (modem.getSimStatus() != SIM_READY) {
    modem.simUnlock(SECRET_SIM_PIN_CODE);
    delay(1000);
  }
  Serial.println("✅ SIM prête");

  if (!connectGPRS()) {
    Serial.println("⚠️ GPRS non fonctionnel, vérifier APN et couverture");
  } else {
    gprsConnected = true;
  }

  Serial.println("🛰️ Activation GPS...");
  if (modem.enableGPS(MODEM_GPS_ENABLE_GPIO, MODEM_GPS_ENABLE_LEVEL)) {
    modem.setGPSBaud(115200);
    modem.setGPSMode(3);
    modem.configNMEASentence(1,1,1,1,1,1);
    modem.setGPSOutputRate(1);
    modem.enableNMEA();
    gpsInitialized = true;
    Serial.println("✅ GPS activé et configuré");
  } else {
    Serial.println("❌ Échec activation GPS");
  }

  Serial.println("📊 Initialisation MPU9250...");
  mySensor.setWire(&Wire);
  mySensor.beginAccel();
  mySensor.beginGyro();
  mpuInitialized = true;

  lastSensorRead = millis();
  lastSend       = millis();
}

//-----------------------------------------------------------------------------
// Loop principal
//-----------------------------------------------------------------------------
void loop() {
  // Lecture NMEA
  while (SerialAT.available()) {
    gps.encode(SerialAT.read());
  }
  uint32_t now = millis();

  // Lecture capteurs périodique
  if (now - lastSensorRead >= SENSOR_INTERVAL) {
    lastSensorRead = now;
    readMPU9250();
  }

  // Envoi périodique (toutes les 15 s) si GPS valide
  if (now - lastSend >= SEND_INTERVAL) {
    lastSend = now;
    Serial.println("🌐 Préparation envoi...");
    if (gps.location.isValid()) {
      String json = buildJson();
      Serial.print("📤 JSON: "); Serial.println(json);
      if (sendDataToProxy(json)) {
        Serial.println("✅ Envoi OK");
      } else {
        Serial.println("❌ Envoi échoué");
      }
    } else {
      Serial.println("⚠️ Pas de données GPS valides, envoi interrompu");
    }
  }

  delay(100);
}
