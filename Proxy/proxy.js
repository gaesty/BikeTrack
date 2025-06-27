const express = require('express')
const axios   = require('axios')
const app     = express()

app.use(express.json())

// URL Supabase REST
const SUPABASE_URL     = 'https://oynnjhnjyeogltujthcy.supabase.co/rest/v1/sensor_data'
// Clé anonyme (rôle anon)
const SUPABASE_API_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95bm5qaG5qeWVvZ2x0dWp0aGN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAzMzIwNTgsImV4cCI6MjA2NTkwODA1OH0.eP28KmebtF0AmUdkUcnzLuRhl4uMnkYJfIaHZ4nHFl4'

/**
 * POST /proxy
 * Extrait les champs compacts (id, sig, src, acc, ax, …)
 * puis les renomme conformément au schéma sensor_data avant d'appeler Supabase
 */
app.post('/proxy', async (req, res) => {
  try {
    const p = req.body

    // Expansion / mapping des champs
    const payload = {
      device_id     : p.id      || p.device_id,
      signal_quality: p.sig     || p.signal_quality,
      data_source   : p.src     || p.data_source,
      uptime_seconds: p.up      || p.uptime_seconds,

      // GPS
      gps_valid     : p.gps     || p.gps_valid,
      latitude      : p.lat     || p.latitude,
      longitude     : p.lng     || p.longitude,
      altitude      : p.alt     || p.altitude,
      satellites    : p.sat     || p.satellites,
      hdop          : p.hdop    || p.hdop,

      // Accéléromètre
      accel_valid   : p.acc     || p.accel_valid,
      accel_x       : p.ax      || p.accel_x,
      accel_y       : p.ay      || p.accel_y,
      accel_z       : p.az      || p.accel_z,

      // Gyroscope
      gyro_valid    : p.gyr     || p.gyro_valid,
      gyro_x        : p.gx      || p.gyro_x,
      gyro_y        : p.gy      || p.gyro_y,
      gyro_z        : p.gz      || p.gyro_z,

      // Magnétomètre (si pertinent)
      mag_valid     : p.mag     || p.mag_valid,
      mag_x         : p.mx      || p.mag_x,
      mag_y         : p.my      || p.mag_y,
      mag_z         : p.mz      || p.mag_z,

      // Température
      temp_valid    : (p.tmp    !== undefined) || p.temp_valid,
      temperature   : p.tmp     || p.temperature
    }

    // Envoi à Supabase
    const response = await axios.post(SUPABASE_URL, payload, {
      headers: {
        apikey       : SUPABASE_API_KEY,
        Authorization: `Bearer ${SUPABASE_API_KEY}`,
        'Content-Type': 'application/json',
        Prefer        : 'return=minimal'
      }
    })

    res.status(200).json({ success: true })
  } catch (error) {
    console.error('Erreur proxy:', error.response?.data || error.message)
    res.status(error.response?.status || 500).json({ error: error.message })
  }
})

const PORT = 3000
app.listen(PORT, () => {
  console.log(`Proxy Supabase démarré sur le port ${PORT}`)
})
