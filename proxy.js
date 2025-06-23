const express = require('express');
const axios = require('axios');
const app = express();

app.use(express.json());

const SUPABASE_URL = 'https://oynnjhnjyeogltujthcy.supabase.co/rest/v1/sensor_data';
const SUPABASE_API_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95bm5qaG5qeWVvZ2x0dWp0aGN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAzMzIwNTgsImV4cCI6MjA2NTkwODA1OH0.eP28KmebtF0AmUdkUcnzLuRhl4uMnkYJfIaHZ4nHFl4'; // ta clé anonyme

app.post('/proxy', async (req, res) => {
  try {
    const response = await axios.post(SUPABASE_URL, req.body, {
      headers: {
        'apikey': SUPABASE_API_KEY,
        'Authorization': `Bearer ${SUPABASE_API_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation'
      }
    });
    res.status(response.status).json(response.data);
  } catch (error) {
    console.error('Erreur proxy :', error.message);
    if (error.response) {
      res.status(error.response.status).json(error.response.data);
    } else {
      res.status(500).send('Erreur proxy interne');
    }
  }
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Proxy HTTP vers Supabase démarré sur le port ${PORT}`);
});