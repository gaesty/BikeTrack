/**
 * @file proxy.js
 * @description Serveur proxy Node.js pour BikeTrack
 * @author BikeTrack Team
 * @version 1.0
 * 
 * Ce serveur proxy fait le pont entre les appareils IoT (module LilyGO A7670E)
 * et la base de données Supabase. Il reçoit les données de télémétrie compactes
 * des appareils et les reformate pour insertion dans Supabase.
 * 
 * Fonctionnalités:
 * - Réception des données JSON via HTTP POST
 * - Mapping/expansion des champs compacts vers le schéma Supabase
 * - Transmission sécurisée vers l'API REST Supabase
 * - Gestion des erreurs et logging
 */

// Import des modules Node.js requis
const express = require('express') // Framework web pour créer l'API REST
const axios   = require('axios')   // Client HTTP pour appels vers Supabase
const app     = express()          // Instance de l'application Express

// Middleware pour parser automatiquement les requêtes JSON
app.use(express.json())

// Configuration Supabase - Paramètres de connexion à la base de données
const SUPABASE_URL     = {SUPABASE_URL}
// Clé API anonyme Supabase (permet l'insertion avec les politiques RLS)
const SUPABASE_API_KEY = {SUPABASE_API_KEY}

/**
 * Route POST /proxy
 * Point d'entrée principal pour recevoir les données des appareils IoT
 * 
 * Fonctionnement:
 * 1. Reçoit les données JSON compactes depuis les modules IoT
 * 2. Effectue le mapping vers le schéma complet Supabase
 * 3. Transmet les données formatées à Supabase
 * 4. Retourne une réponse de succès/erreur
 * 
 * @param {Object} req.body - Données de télémétrie au format compact
 * @returns {Object} - Réponse JSON avec statut de l'opération
 */
app.post('/proxy', async (req, res) => {
  try {
    // Récupération des données envoyées par l'appareil IoT
    const p = req.body

    // Mapping/expansion des champs compacts vers le schéma Supabase complet
    // Cette approche permet d'économiser la bande passante mobile
    const payload = {
      // Identification et métadonnées de l'appareil
      device_id     : p.id      || p.device_id,      // ID unique de l'appareil
      signal_quality: p.sig     || p.signal_quality, // Qualité du signal cellulaire (0-31)
      data_source   : p.src     || p.data_source,    // Source des données ("4G", "WiFi", etc.)
      uptime_seconds: p.up      || p.uptime_seconds, // Temps de fonctionnement en secondes

      // Données GPS/GNSS - Position et navigation
      gps_valid     : p.gps     || p.gps_valid,     // Validité du fix GPS
      latitude      : p.lat     || p.latitude,      // Latitude en degrés décimaux
      longitude     : p.lng     || p.longitude,     // Longitude en degrés décimaux
      altitude      : p.alt     || p.altitude,      // Altitude en mètres
      satellites    : p.sat     || p.satellites,    // Nombre de satellites visibles
      hdop          : p.hdop    || p.hdop,          // Dilution de précision horizontale

      // Données accéléromètre - Détection de mouvement et vibrations
      accel_valid   : p.acc     || p.accel_valid,   // Validité des données accéléromètre
      accel_x       : p.ax      || p.accel_x,       // Accélération axe X (g)
      accel_y       : p.ay      || p.accel_y,       // Accélération axe Y (g)
      accel_z       : p.az      || p.accel_z,       // Accélération axe Z (g)

      // Données gyroscope - Détection de rotation et basculement
      gyro_valid    : p.gyr     || p.gyro_valid,    // Validité des données gyroscope
      gyro_x        : p.gx      || p.gyro_x,        // Vitesse angulaire axe X (°/s)
      gyro_y        : p.gy      || p.gyro_y,        // Vitesse angulaire axe Y (°/s)
      gyro_z        : p.gz      || p.gyro_z,        // Vitesse angulaire axe Z (°/s)

      // Données magnétomètre - Boussole numérique (optionnel)
      mag_valid     : p.mag     || p.mag_valid,     // Validité des données magnétomètre
      mag_x         : p.mx      || p.mag_x,         // Champ magnétique axe X (µT)
      mag_y         : p.my      || p.mag_y,         // Champ magnétique axe Y (µT)
      mag_z         : p.mz      || p.mag_z,         // Champ magnétique axe Z (µT)

      // Données environnementales
      temp_valid    : (p.tmp    !== undefined) || p.temp_valid, // Validité température
      temperature   : p.tmp     || p.temperature  // Température interne (°C)
    }

    // Envoi des données formatées vers Supabase via API REST
    const response = await axios.post(SUPABASE_URL, payload, {
      headers: {
        // En-têtes d'authentification Supabase
        apikey       : SUPABASE_API_KEY,
        Authorization: `Bearer ${SUPABASE_API_KEY}`,
        'Content-Type': 'application/json',
        Prefer        : 'return=minimal' // Réponse minimaliste pour économiser la bande passante
      }
    })

    // Réponse de succès à l'appareil IoT
    res.status(200).json({ success: true })
  } catch (error) {
    // Gestion des erreurs avec logging détaillé
    console.error('Erreur proxy:', error.response?.data || error.message)
    // Retour de l'erreur à l'appareil IoT
    res.status(error.response?.status || 500).json({ error: error.message })
  }
})

// Configuration du serveur - Écoute sur le port 3000
const PORT = 3000
app.listen(PORT, () => {
  console.log(`🚀 Proxy Supabase BikeTrack démarré sur le port ${PORT}`)
  console.log(`📡 Prêt à recevoir les données des appareils IoT`)
  console.log(`🔗 Endpoint: http://localhost:${PORT}/proxy`)
})
