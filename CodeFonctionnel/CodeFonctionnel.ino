/**
 * @file CodeCompletAvecBatterie.ino
 * @description Code complet LilyGO A7670E avec monitoring de batterie intégré
 * @version 4.0 - Monitoring de batterie complet
 */

#include "utilities.h"
#include "arduino_secrets.h"
#include <TinyGsmClient.h>
#include <TinyGPSPlus.h>
#include <Wire.h>
#include <MPU9250_asukiaaa.h>
#include <ArduinoJson.h>

// --- Configuration modem ---
#define TINY_GSM_RX_BUFFER 1024
#define SerialAT Serial1
TinyGsm modem(SerialAT);
TinyGsmClient client(modem);

// --- Configuration I2C MPU9250 ---
#define SDA_PIN 21
#define SCL_PIN 22
#define I2C_CLOCK_SPEED 100000
#define MPU9250_ADDRESS 0x68

// --- Configuration batterie ---
#ifndef BOARD_BAT_ADC_PIN
#error "Cette carte ne supporte pas le monitoring de batterie"
#endif

// Table de correspondance tension/pourcentage pour batterie LiPo 18650
const int BATTERY_VOLTAGE_TABLE[][2] = {
    {4200, 100}, {4180, 99}, {4160, 98}, {4140, 97}, {4120, 96},
    {4100, 95}, {4080, 94}, {4060, 93}, {4040, 92}, {4020, 91},
    {4000, 90}, {3980, 88}, {3960, 86}, {3940, 84}, {3920, 82},
    {3900, 80}, {3880, 78}, {3860, 76}, {3840, 74}, {3820, 72},
    {3800, 70}, {3780, 68}, {3760, 66}, {3740, 64}, {3720, 62},
    {3700, 60}, {3680, 58}, {3660, 56}, {3640, 54}, {3620, 52},
    {3600, 50}, {3580, 48}, {3560, 46}, {3540, 44}, {3520, 42},
    {3500, 40}, {3480, 38}, {3460, 36}, {3440, 34}, {3420, 32},
    {3400, 30}, {3380, 28}, {3360, 26}, {3340, 24}, {3320, 22},
    {3300, 20}, {3280, 18}, {3260, 16}, {3240, 14}, {3220, 12},
    {3200, 10}, {3180, 8}, {3160, 6}, {3140, 4}, {3120, 2}, {3100, 0}
};

// --- Paramètres réseau et proxy ---
const char* PROXY_HOST 
const uint16_t PROXY_PORT
const char apn[] = SECRET_APN;
const char gprsUser[] = SECRET_GPRS_USER;
const char gprsPass[] = SECRET_GPRS_PASS;

// --- Intervalles (ms) ---
#define SENSOR_INTERVAL 30000
#define BATTERY_INTERVAL 10000  // Lecture batterie toutes les 10s
#define SEND_INTERVAL 15000

// --- Structures de données ---
struct SensorData {
    float ax, ay, az;
    float gx, gy, gz;
    float mx, my, mz;
    float temperature;
} sensorData;

struct BatteryData {
    uint32_t voltage_mv;
    int percentage;
    bool is_charging;
    bool valid;
    uint32_t solar_voltage_mv;
    String status;
} batteryData;

// --- Variables globales ---
TinyGPSPlus gps;
MPU9250_asukiaaa mySensor;

bool mpuInitialized = false;
bool gpsInitialized = false;
bool accelValid = false;
bool gyroValid = false;
bool magValid = false;
bool tempValid = false;
bool gprsConnected = false;

uint32_t lastSensorRead = 0;
uint32_t lastBatteryRead = 0;
uint32_t lastSend = 0;

//-----------------------------------------------------------------------------
// Initialisation hardware
//-----------------------------------------------------------------------------
void initializeHardware() {
    Serial.println("🔧 Initialisation hardware...");
    
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
    digitalWrite(BOARD_PWRKEY_PIN, LOW); delay(50);
    digitalWrite(BOARD_PWRKEY_PIN, HIGH); delay(500);
    digitalWrite(BOARD_PWRKEY_PIN, LOW);

    SerialAT.begin(MODEM_BAUDRATE, SERIAL_8N1, MODEM_RX_PIN, MODEM_TX_PIN);
    delay(100);

    Wire.begin(SDA_PIN, SCL_PIN, I2C_CLOCK_SPEED);
    delay(100);

    // Configuration ADC pour la batterie[11][14][27]
    analogSetAttenuation(ADC_11db);  // 150mV ~ 2450mV
    analogReadResolution(12);        // 12-bit (0-4095)
    #if CONFIG_IDF_TARGET_ESP32
    analogSetWidth(12);
    #endif
}

//-----------------------------------------------------------------------------
// Lecture et calcul du niveau de batterie
//-----------------------------------------------------------------------------
int getBatteryPercentageFromVoltage(uint32_t voltage_mv) {
    // Recherche dans la table de correspondance[14][27]
    int tableSize = sizeof(BATTERY_VOLTAGE_TABLE) / sizeof(BATTERY_VOLTAGE_TABLE[0]);
    
    // Voltage supérieur au maximum
    if (voltage_mv >= BATTERY_VOLTAGE_TABLE[0][0]) {
        return BATTERY_VOLTAGE_TABLE[0][1];
    }
    
    // Voltage inférieur au minimum
    if (voltage_mv <= BATTERY_VOLTAGE_TABLE[tableSize-1][0]) {
        return BATTERY_VOLTAGE_TABLE[tableSize-1][1];
    }
    
    // Interpolation linéaire entre deux points
    for (int i = 0; i < tableSize - 1; i++) {
        if (voltage_mv <= BATTERY_VOLTAGE_TABLE[i][0] && 
            voltage_mv >= BATTERY_VOLTAGE_TABLE[i+1][0]) {
            
            int v1 = BATTERY_VOLTAGE_TABLE[i][0];
            int p1 = BATTERY_VOLTAGE_TABLE[i][1];
            int v2 = BATTERY_VOLTAGE_TABLE[i+1][0];
            int p2 = BATTERY_VOLTAGE_TABLE[i+1][1];
            
            // Interpolation: percentage = p1 + (voltage_mv - v1) * (p2 - p1) / (v2 - v1)
            return p1 + (voltage_mv - v1) * (p2 - p1) / (v2 - v1);
        }
    }
    
    return 0; // Fallback
}

void readBatteryData() {
    // Lecture tension batterie via ADC[11][28]
    uint32_t rawVoltage = analogReadMilliVolts(BOARD_BAT_ADC_PIN);
    
    // Facteur de correction pour diviseur de tension (x2 sur LilyGO A7670E)[8]
    batteryData.voltage_mv = rawVoltage * 2;
    
    // Calcul du pourcentage basé sur la table de correspondance
    batteryData.percentage = getBatteryPercentageFromVoltage(batteryData.voltage_mv);
    
    // Détection de charge (seuil ≥ 4150mV)[24]
    batteryData.is_charging = (batteryData.voltage_mv >= 4150);
    
    // Lecture tension panneau solaire si disponible
    #ifdef BOARD_SOLAR_ADC_PIN
    batteryData.solar_voltage_mv = analogReadMilliVolts(BOARD_SOLAR_ADC_PIN) * 2;
    // Amélioration détection charge avec panneau solaire
    if (batteryData.solar_voltage_mv > 5000) { // >5V = soleil
        batteryData.is_charging = true;
    }
    #else
    batteryData.solar_voltage_mv = 0;
    #endif
    
    // Détermination du statut textuel
    if (batteryData.percentage <= 5) {
        batteryData.status = "critical";
    } else if (batteryData.percentage <= 20) {
        batteryData.status = "low";
    } else if (batteryData.is_charging) {
        batteryData.status = "charging";
    } else if (batteryData.percentage >= 95) {
        batteryData.status = "full";
    } else {
        batteryData.status = "discharging";
    }
    
    batteryData.valid = true;
    
    // Affichage des données de batterie
    Serial.println("🔋 Données batterie:");
    Serial.println("   Tension: " + String(batteryData.voltage_mv) + "mV");
    Serial.println("   Pourcentage: " + String(batteryData.percentage) + "%");
    Serial.println("   État: " + batteryData.status);
    if (batteryData.solar_voltage_mv > 0) {
        Serial.println("   Solaire: " + String(batteryData.solar_voltage_mv) + "mV");
    }
}

//-----------------------------------------------------------------------------
// Connexion GPRS
//-----------------------------------------------------------------------------
bool connectGPRS() {
    Serial.println("🔍 Attente réseau...");
    if (!modem.waitForNetwork(60000L)) {
        Serial.println("❌ Pas d'enregistrement réseau");
        return false;
    }

    Serial.println("✅ Réseau OK, ouverture PDP...");
    if (!modem.gprsConnect(apn, gprsUser, gprsPass)) {
        Serial.println("❌ Échec GPRS connect");
        return false;
    }

    Serial.println("📍 IP attribuée : " + modem.getLocalIP());
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

    if (mySensor.magUpdate() == 0) {
        sensorData.mx = mySensor.magX();
        sensorData.my = mySensor.magY();
        sensorData.mz = mySensor.magZ();
        magValid = true;
    } else magValid = false;

    // Lecture température
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
// Construction JSON avec données de batterie
//-----------------------------------------------------------------------------
String buildJsonWithBattery() {
    StaticJsonDocument<768> doc; // Augmenté pour les données de batterie
    
    doc["device_id"] = SECRET_DEVICE_ID;
    doc["signal_quality"] = modem.getSignalQuality();
    doc["data_source"] = "4G";
    doc["uptime_seconds"] = millis() / 1000;

    // Données GPS
    doc["gps_valid"] = gps.location.isValid();
    if (gps.location.isValid()) {
        doc["latitude"] = gps.location.lat();
        doc["longitude"] = gps.location.lng();
        doc["altitude"] = gps.altitude.meters();
        doc["satellites"] = gps.satellites.value();
        doc["hdop"] = gps.hdop.value();
        doc["gps_speed"] = gps.speed.kmph();
    }

    // Données capteurs
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

    doc["mag_valid"] = magValid;
    if (magValid) {
        doc["mag_x"] = sensorData.mx;
        doc["mag_y"] = sensorData.my;
        doc["mag_z"] = sensorData.mz;
    }

    doc["temp_valid"] = tempValid;
    if (tempValid) {
        doc["temperature"] = sensorData.temperature;
    }

    // *** NOUVELLES DONNÉES DE BATTERIE ***
    doc["battery_voltage_mv"] = batteryData.voltage_mv;
    doc["battery_percentage"] = batteryData.percentage;
    doc["battery_is_charging"] = batteryData.is_charging;
    doc["battery_valid"] = batteryData.valid;
    doc["battery_status"] = batteryData.status;
    
    if (batteryData.solar_voltage_mv > 0) {
        doc["solar_voltage_mv"] = batteryData.solar_voltage_mv;
    }

    String output;
    serializeJson(doc, output);
    return output;
}

//-----------------------------------------------------------------------------
// Envoi données vers proxy
//-----------------------------------------------------------------------------
bool sendDataToProxy(const String &body) {
    Serial.println("🔄 Envoi TCP vers proxy...");
    
    if (!client.connect(PROXY_HOST, PROXY_PORT)) {
        Serial.println("❌ Échec connexion TCP");
        return false;
    }

    Serial.println("✅ TCP établi");

    String request = 
        String("POST /proxy HTTP/1.1\r\n") +
        "Host: " + PROXY_HOST + ":" + PROXY_PORT + "\r\n" +
        "Content-Type: application/json\r\n" +
        "Content-Length: " + body.length() + "\r\n" +
        "Connection: close\r\n\r\n" +
        body;

    client.print(request);

    // Lecture réponse
    uint32_t deadline = millis() + 10000;
    while (client.connected() && millis() < deadline) {
        while (client.available()) {
            Serial.write(client.read());
        }
    }

    client.stop();
    Serial.println("\n✅ TCP fermé");
    return true;
}

//-----------------------------------------------------------------------------
// Setup
//-----------------------------------------------------------------------------
void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("🚀 Démarrage LilyGO A7670E avec monitoring batterie");

    initializeHardware();

    // Test modem
    Serial.println("🔍 Test AT...");
    while (!modem.testAT()) { delay(500); }
    Serial.println("✅ Modem prêt");

    // SIM
    Serial.println("📶 SIM...");
    while (modem.getSimStatus() != SIM_READY) {
        modem.simUnlock(SECRET_SIM_PIN_CODE);
        delay(1000);
    }
    Serial.println("✅ SIM prête");

    // GPRS
    if (!connectGPRS()) {
        Serial.println("⚠️ GPRS non fonctionnel");
    } else {
        gprsConnected = true;
    }

    // GPS
    Serial.println("🛰️ Activation GPS...");
    if (modem.enableGPS(MODEM_GPS_ENABLE_GPIO, MODEM_GPS_ENABLE_LEVEL)) {
        modem.setGPSBaud(115200);
        modem.setGPSMode(3);
        modem.configNMEASentence(1,1,1,1,1,1);
        modem.setGPSOutputRate(1);
        modem.enableNMEA();
        gpsInitialized = true;
        Serial.println("✅ GPS activé");
    } else {
        Serial.println("❌ Échec activation GPS");
    }

    // MPU9250
    Serial.println("📊 Initialisation MPU9250...");
    mySensor.setWire(&Wire);
    mySensor.beginAccel();
    mySensor.beginGyro();
    mySensor.beginMag();
    mpuInitialized = true;

    // Lecture initiale de la batterie
    readBatteryData();

    Serial.println("✅ Système prêt !");
    
    lastSensorRead = millis();
    lastBatteryRead = millis();
    lastSend = millis();
}

//-----------------------------------------------------------------------------
// Loop principal
//-----------------------------------------------------------------------------
void loop() {
    uint32_t now = millis();

    // Lecture NMEA GPS
    while (SerialAT.available()) {
        gps.encode(SerialAT.read());
    }

    // Lecture capteurs périodique
    if (now - lastSensorRead >= SENSOR_INTERVAL) {
        lastSensorRead = now;
        readMPU9250();
    }

    // Lecture batterie périodique
    if (now - lastBatteryRead >= BATTERY_INTERVAL) {
        lastBatteryRead = now;
        readBatteryData();
    }

    // Envoi périodique des données
    if (now - lastSend >= SEND_INTERVAL) {
        lastSend = now;
        
        Serial.println("🌐 Préparation envoi...");
        
        if (gps.location.isValid() && gprsConnected) {
            String jsonData = buildJsonWithBattery();
            Serial.println("📤 JSON: " + jsonData);
            
            if (sendDataToProxy(jsonData)) {
                Serial.println("✅ Envoi réussi");
            } else {
                Serial.println("❌ Envoi échoué");
            }
        } else {
            if (!gps.location.isValid()) {
                Serial.println("⚠️ GPS non valide");
            }
            if (!gprsConnected) {
                Serial.println("⚠️ GPRS non connecté");
                // Tentative de reconnexion
                gprsConnected = connectGPRS();
            }
        }
    }

    delay(100);
}
