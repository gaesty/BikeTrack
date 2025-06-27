|Pin MPU9250 | Pin LilyGO A7670E |	Description |
|------------|-------------------|--------------|
|VCC         |	3.3V             |	Alimentation stable |
|GND         |	GND	             |Masse commune |
|SDA         |	GPIO 21	         |Ligne de données I2C |
|SCL         |	GPIO 22          |	Ligne d'horloge I2C |
|AD0         |	GND	             |Configuration adresse 0x68 |


/**
 * @file      A7670E_MPU9250_SMS_GPS_Supabase.ino
 * @description Code complet pour LilyGO A7670E-FASE : SMS, GPS, MPU9250, Supabase via 4G (HTTPS natif AT)
 * @note      Nécessite : TinyGSM, TinyGPSPlus, MPU9250_asukiaaa, ArduinoJson
 * @version   3.4 - Utilisation des commandes AT natives HTTPS pour Supabase
 */

#include "utilities.h"
#include <TinyGsmClient.h>
#include <TinyGPSPlus.h>
#include <Wire.h>
#include <MPU9250_asukiaaa.h>
#include <ArduinoJson.h>

// Inclusion du fichier de secrets en début de code
#include "arduino_secrets.h"

#define TINY_GSM_RX_BUFFER 1024
#define SerialAT Serial1

// --- Paramètres Supabase ---
#define SUPABASE_URL SECRET_SUPABASE_URL
#define SUPABASE_ANON_KEY SECRET_SUPABASE_ANON_KEY
#define DEVICE_ID SECRET_DEVICE_ID

// --- Paramètres opérateur mobile ---
const char apn[] = SECRET_APN;
const char gprsUser[] = SECRET_GPRS_USER;
const char gprsPass[] = SECRET_GPRS_PASS;

#define SMS_TARGET SECRET_SMS_TARGET

// --- Paramètres I2C MPU9250 ---
#define SDA_PIN 21
#define SCL_PIN 22
#define MPU9250_ADDRESS 0x68
#define I2C_CLOCK_SPEED 100000
#define I2C_MAX_RETRIES 5

// --- Temporisations ---
#define MPU_INIT_DELAY 50
#define GPS_INIT_DELAY 300000
#define SMS_INTERVAL 120000
#define SENSOR_INTERVAL 30000
#define SUPABASE_INTERVAL 60000

TinyGsm modem(SerialAT);
TinyGPSPlus gps;
MPU9250_asukiaaa mySensor;

uint32_t check_interval = 0;
uint32_t lastSensorRead = 0;
uint32_t lastSupabaseSend = 0;
bool firstSMSSent = false;
bool gpsEnabled = false;
bool gpsInitialized = false;
bool mpuInitialized = false;
bool accelValid = false;
bool gyroValid = false;
bool magValid = false;
bool tempValid = false;
bool gprsConnected = false;

struct SensorData {
  float ax, ay, az;
  float gx, gy, gz;
  float mx, my, mz;
  float temperature;
} sensorData;

void setup() {
  Serial.begin(115200);
  initializeHardware();
  String moduleModel = identifyModule();
  if (!moduleModel.startsWith("A7670E-FASE")) {
    Serial.println("⚠️ ATTENTION : Ce code est optimisé pour A7670E-FASE");
    Serial.println("   Votre module : " + moduleModel);
    Serial.println("   Les fonctions SMS peuvent ne pas fonctionner.");
  }
  initializeSIM();
  registerNetwork();
  initializeGPRS();
  testSMSCapability();
  initializeGPS();
  initializeMPU9250();
  Serial.println("✅ Module A7670E-FASE prêt !");
  readMPU9250Data();
  delay(5000);
  sendLocationAndSensorSMS();
  firstSMSSent = true;
  sendDataToSupabase();
  check_interval = millis() + SMS_INTERVAL;
  lastSensorRead = millis();
  lastSupabaseSend = millis();
}

void loop() {
  while (SerialAT.available() > 0) gps.encode(SerialAT.read());
  if (millis() - lastSensorRead >= SENSOR_INTERVAL) {
    lastSensorRead = millis();
    readMPU9250Data();
    if (gps.location.isUpdated() || gps.location.isValid()) {
      displayGPSInfo();
      gpsInitialized = true;
    }
  }
  if (millis() - lastSupabaseSend >= SUPABASE_INTERVAL) {
    lastSupabaseSend = millis();
    sendDataToSupabase();
  }
  if (firstSMSSent && millis() > check_interval) {
    readMPU9250Data();
    sendLocationAndSensorSMS();
    check_interval = millis() + SMS_INTERVAL;
  }
  delay(100);
}

// --- Fonctions principales ---

void initializeHardware() {
  Serial.println("🔧 Initialisation matérielle...");
  #ifdef BOARD_POWERON_PIN
    pinMode(BOARD_POWERON_PIN, OUTPUT);
    digitalWrite(BOARD_POWERON_PIN, HIGH);
  #endif
  #ifdef MODEM_RESET_PIN
    pinMode(MODEM_RESET_PIN, OUTPUT);
    digitalWrite(MODEM_RESET_PIN, !MODEM_RESET_LEVEL); delay(50);
    digitalWrite(MODEM_RESET_PIN, MODEM_RESET_LEVEL); delay(1000);
    digitalWrite(MODEM_RESET_PIN, !MODEM_RESET_LEVEL);
  #endif
  pinMode(BOARD_PWRKEY_PIN, OUTPUT);
  digitalWrite(BOARD_PWRKEY_PIN, LOW); delay(50);
  digitalWrite(BOARD_PWRKEY_PIN, HIGH); delay(500);
  digitalWrite(BOARD_PWRKEY_PIN, LOW);
  SerialAT.begin(115200, SERIAL_8N1, MODEM_RX_PIN, MODEM_TX_PIN);
  delay(1000);
  Wire.begin(SDA_PIN, SCL_PIN, I2C_CLOCK_SPEED);
  delay(100);
}

String identifyModule() {
  Serial.println("🔍 Identification du module...");
  int retry = 0;
  while (!modem.testAT(1000) && retry < 10) {
    Serial.print(".");
    if (retry++ > 3) {
      digitalWrite(BOARD_PWRKEY_PIN, LOW); delay(50);
      digitalWrite(BOARD_PWRKEY_PIN, HIGH); delay(500);
      digitalWrite(BOARD_PWRKEY_PIN, LOW);
      retry = 0;
    }
  }
  String moduleName = modem.getModemName();
  if (moduleName.length() < 2 || moduleName == "UNKOWN") {
    modem.sendAT("+CGMM");
    if (modem.waitResponse(1000, moduleName) == 1) moduleName.trim();
    if (moduleName.length() < 2 || moduleName == "UNKOWN") {
      modem.sendAT("I");
      String response = "";
      if (modem.waitResponse(1000, response) == 1) {
        int modelIndex = response.indexOf("Model:");
        if (modelIndex >= 0) {
          int endIdx = response.indexOf("\r", modelIndex);
          if (endIdx > modelIndex) {
            moduleName = response.substring(modelIndex + 7, endIdx);
            moduleName.trim();
          }
        }
      }
    }
  }
  if (moduleName.length() < 2) moduleName = "A7670E-FASE";
  Serial.println("\n📋 Module détecté : " + moduleName);
  return moduleName;
}

void initializeSIM() {
  Serial.println("📶 Initialisation SIM...");
  SimStatus sim = SIM_ERROR;
  while (sim != SIM_READY) {
    sim = modem.getSimStatus();
    switch (sim) {
      case SIM_READY: Serial.println("✅ Carte SIM prête"); break;
      case SIM_LOCKED: {
        static const char *SIMCARD_PIN_CODE = SECRET_SIM_PIN_CODE;
        Serial.println("🔒 Déverrouillage SIM...");
        modem.simUnlock(SIMCARD_PIN_CODE);
        break;
      }
      default: break;
    }
    delay(1000);
  }
}

void registerNetwork() {
  Serial.println("🌐 Enregistrement réseau...");
  RegStatus status = REG_NO_RESULT;
  while (status != REG_OK_HOME && status != REG_OK_ROAMING) {
    status = modem.getRegistrationStatus();
    switch (status) {
      case REG_OK_HOME: Serial.println("✅ Enregistrement réseau réussi"); break;
      case REG_OK_ROAMING: Serial.println("✅ Enregistrement réseau réussi (itinérance)"); break;
      case REG_DENIED: Serial.println("❌ Enregistrement refusé"); return;
      default: Serial.print("📡 Signal : "); Serial.println(modem.getSignalQuality()); break;
    }
    delay(2000);
  }
}

void initializeGPRS() {
  Serial.println("🌐 Connexion GPRS pour Supabase...");
  modem.sendAT("+CGDCONT=1,\"IP\",\"" + String(apn) + "\"");
  modem.waitResponse();
  if (modem.gprsConnect(apn, gprsUser, gprsPass)) {
    gprsConnected = true;
    Serial.println("✅ Connexion GPRS établie");
    Serial.println("📍 Adresse IP : " + modem.getLocalIP());
  } else {
    Serial.println("❌ Échec connexion GPRS");
    gprsConnected = false;
  }
}

void testSMSCapability() {
  Serial.println("📱 Test capacité SMS...");
  modem.sendAT("+CMGF=1");
  if (modem.waitResponse() == 1) Serial.println("✅ SMS supporté par ce module");
  else Serial.println("❌ SMS non supporté par ce module");
}

void initializeGPS() {
  Serial.println("🛰️ Activation GPS...");
  if (modem.enableGPS(MODEM_GPS_ENABLE_GPIO, MODEM_GPS_ENABLE_LEVEL)) {
    modem.setGPSBaud(115200);
    modem.setGPSMode(3);
    modem.configNMEASentence(1, 1, 1, 1, 1, 1);
    modem.setGPSOutputRate(1);
    modem.enableNMEA();
    gpsEnabled = true;
    Serial.println("✅ GPS activé et configuré");
  } else {
    Serial.println("❌ Échec activation GPS");
  }
}

void initializeMPU9250() {
  Serial.println("📊 Initialisation MPU9250...");
  mySensor.setWire(&Wire);
  int retries = 0;
  bool accelInit = false, gyroInit = false, magInit = false;
  while (!accelInit && retries < I2C_MAX_RETRIES) {
    mySensor.beginAccel(); delay(MPU_INIT_DELAY);
    mySensor.accelUpdate();
    if (abs(mySensor.accelX()) > 0.001 || abs(mySensor.accelY()) > 0.001 || abs(mySensor.accelZ()) > 0.001) {
      accelInit = true; accelValid = true;
    } else { retries++; delay(MPU_INIT_DELAY * retries); }
  }
  retries = 0;
  while (!gyroInit && retries < I2C_MAX_RETRIES) {
    mySensor.beginGyro(); delay(MPU_INIT_DELAY);
    mySensor.gyroUpdate();
    if (abs(mySensor.gyroX()) > 0.001 || abs(mySensor.gyroY()) > 0.001 || abs(mySensor.gyroZ()) > 0.001) {
      gyroInit = true; gyroValid = true;
    } else { retries++; delay(MPU_INIT_DELAY * retries); }
  }
  retries = 0;
  Wire.beginTransmission(MPU9250_ADDRESS); Wire.write(0x37); Wire.write(0x02); Wire.endTransmission(); delay(100);
  Wire.beginTransmission(MPU9250_ADDRESS); Wire.write(0x6A); Wire.write(0x00); Wire.endTransmission(); delay(100);
  while (!magInit && retries < I2C_MAX_RETRIES) {
    mySensor.beginMag(); delay(MPU_INIT_DELAY * 2);
    mySensor.magUpdate();
    if (abs(mySensor.magX()) > 0.001 || abs(mySensor.magY()) > 0.001 || abs(mySensor.magZ()) > 0.001) {
      magInit = true; magValid = true;
    } else { retries++; delay(MPU_INIT_DELAY * retries); }
  }
  if (accelInit || gyroInit || magInit) {
    mpuInitialized = true; tempValid = true;
    Serial.println("✅ MPU9250 initialisé avec succès");
    Serial.println("   Accéléromètre: " + String(accelValid ? "OK" : "Erreur"));
    Serial.println("   Gyroscope: " + String(gyroValid ? "OK" : "Erreur"));
    Serial.println("   Magnétomètre: " + String(magValid ? "OK" : "Erreur"));
  } else {
    Serial.println("⚠️ Initialisation MPU9250 partielle");
  }
}

void readMPU9250Data() {
  if (!mpuInitialized) return;
  if (accelValid) {
    if (mySensor.accelUpdate() == 0) {
      sensorData.ax = mySensor.accelX();
      sensorData.ay = mySensor.accelY();
      sensorData.az = mySensor.accelZ();
    } else accelValid = false;
  }
  if (gyroValid) {
    if (mySensor.gyroUpdate() == 0) {
      sensorData.gx = mySensor.gyroX();
      sensorData.gy = mySensor.gyroY();
      sensorData.gz = mySensor.gyroZ();
    } else gyroValid = false;
  }
  if (magValid) {
    if (mySensor.magUpdate() == 0) {
      sensorData.mx = mySensor.magX();
      sensorData.my = mySensor.magY();
      sensorData.mz = mySensor.magZ();
    } else magValid = false;
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
    } else tempValid = false;
  }
  Serial.println("📊 Données MPU9250 :");
  if (accelValid) Serial.println("   Accél X: " + String(sensorData.ax, 2) + " g");
  if (gyroValid) Serial.println("   Gyro X: " + String(sensorData.gx, 1) + " °/s");
  if (tempValid) Serial.println("   Température: " + String(sensorData.temperature, 1) + " °C");
}

void displayGPSInfo() {
  Serial.println("📍 Position GPS mise à jour :");
  Serial.print("   Latitude  : "); Serial.println(gps.location.lat(), 8);
  Serial.print("   Longitude : "); Serial.println(gps.location.lng(), 8);
  Serial.print("   Satellites: "); Serial.println(gps.satellites.value());
  Serial.print("   Précision : "); Serial.println(gps.hdop.value());
  Serial.println();
}

void sendDataToSupabase() {
  if (!gprsConnected) {
    Serial.println("❌ GPRS non connecté, impossible d'envoyer vers Supabase");
    return;
  }
  Serial.println("🌐 Envoi des données vers Supabase...");

  StaticJsonDocument<1024> doc;
  doc["device_id"] = DEVICE_ID;
  doc["signal_quality"] = modem.getSignalQuality();
  doc["data_source"] = "4G";
  doc["uptime_seconds"] = millis() / 1000;
  if (gpsInitialized && gps.location.isValid()) {
    doc["gps_valid"] = true;
    doc["latitude"] = gps.location.lat();
    doc["longitude"] = gps.location.lng();
    doc["altitude"] = gps.altitude.meters();
    doc["satellites"] = gps.satellites.value();
    doc["hdop"] = gps.hdop.value();
    if (gps.speed.isValid()) doc["gps_speed"] = gps.speed.kmph();
  } else {
    doc["gps_valid"] = false;
  }
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
  String jsonString;
  serializeJson(doc, jsonString);
  Serial.println("JSON envoyé à Supabase :");
  Serial.println(jsonString);

  // --- HTTPS natif via AT ---
  modem.sendAT("+HTTPTERM"); // Toujours terminer avant d'initier
  modem.waitResponse();
  modem.sendAT("+HTTPINIT");
  modem.waitResponse();

  modem.sendAT("+HTTPPARA=\"URL\",\"https://oynnjhnjyeogltujthcy.supabase.co/rest/v1/sensor_data\"");
  modem.waitResponse();

  modem.sendAT("+HTTPPARA=\"CONTENT\",\"application/json\"");
  modem.waitResponse();

  modem.sendAT("+HTTPPARA=\"USERDATA\",\"apikey: " + String(SUPABASE_ANON_KEY) + "\\r\\nAuthorization: Bearer " + String(SUPABASE_ANON_KEY) + "\\r\\nPrefer: return=minimal\"");
  modem.waitResponse();

  modem.sendAT("+HTTPSSL=1");
  modem.waitResponse();

  modem.sendAT("+HTTPDATA=" + String(jsonString.length()) + ",10000");
  if (modem.waitResponse(10000, ">") == 1) {
    modem.stream.print(jsonString);
    if (modem.waitResponse(10000) == 1) {
      modem.sendAT("+HTTPACTION=1");
      if (modem.waitResponse(30000, "+HTTPACTION: 1,") == 1) {
        String httpResp = modem.stream.readStringUntil('\n');
        Serial.println("Réponse HTTP Supabase : " + httpResp);
      }
    }
  }
  modem.sendAT("+HTTPTERM");
  modem.waitResponse();
}

void sendLocationAndSensorSMS() {
  String message = "";
  if (gpsInitialized && gps.location.isValid()) {
    message += "Maps: https://maps.google.com/?q=" +
               String(gps.location.lat(), 8) + "," +
               String(gps.location.lng(), 8) + "\n";
  } else {
    message += "GPS: Position non disponible\n";
  }
  if (mpuInitialized) {
    message += "MPU9250: ";
    if (accelValid) {
      message += "Acc: X" + String(sensorData.ax, 1) + "g ";
      message += "Y" + String(sensorData.ay, 1) + "g ";
      message += "Z" + String(sensorData.az, 1) + "g\n";
    }
    if (gyroValid) {
      message += "Gyr: X" + String(sensorData.gx, 1) + "°/s ";
      message += "Y" + String(sensorData.gy, 1) + "°/s ";
      message += "Z" + String(sensorData.gz, 1) + "°/s\n";
    }
  } else {
    message += "MPU9250: Erreur lecture capteur\n";
  }
  Serial.println("📱 Envoi SMS localisation + capteurs...");
  Serial.println("Message: " + message);
  bool result = modem.sendSMS(SMS_TARGET, message);
  Serial.print("📱 SMS ");
  Serial.println(result ? "envoyé ✅" : "échec ❌");
}

void recoverI2C() {
  Serial.println("⚠️ Tentative de récupération du bus I2C...");
  Wire.end();
  pinMode(SCL_PIN, OUTPUT);
  pinMode(SDA_PIN, OUTPUT);
  digitalWrite(SDA_PIN, HIGH);
  delayMicroseconds(5);
  for (int i = 0; i < 9; i++) {
    digitalWrite(SCL_PIN, LOW);
    delayMicroseconds(5);
    digitalWrite(SCL_PIN, HIGH);
    delayMicroseconds(5);
  }
  digitalWrite(SDA_PIN, LOW);
  delayMicroseconds(5);
  digitalWrite(SCL_PIN, HIGH);
  delayMicroseconds(5);
  digitalWrite(SDA_PIN, HIGH);
  delayMicroseconds(5);
  Wire.begin(SDA_PIN, SCL_PIN, I2C_CLOCK_SPEED);
  delay(100);
  Serial.println("✅ Récupération I2C terminée");
}


