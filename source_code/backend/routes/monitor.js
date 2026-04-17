const express = require('express');
const router = express.Router();
const { runMonitorCycle, fetchWeather, fetchAQI, ZONE_COORDS } = require('../services/trigger-monitor');

function mockWeather(zone) {
  const hour = new Date().getHours();
  const isRushHour = (hour >= 11 && hour <= 14) || (hour >= 19 && hour <= 22);
  const base = Math.random();
  return {
    zone,
    temp: 28 + Math.round(Math.random() * 12),
    feelsLike: 30 + Math.round(Math.random() * 14),
    humidity: 60 + Math.round(Math.random() * 30),
    weatherMain: base > 0.7 ? 'Rain' : base > 0.4 ? 'Clouds' : 'Clear',
    weatherDesc: base > 0.7 ? 'heavy intensity rain' : base > 0.4 ? 'scattered clouds' : 'clear sky',
    rainMmPerHour: base > 0.7 ? Math.round(10 + Math.random() * 15) : 0,
    windSpeed: Math.round(3 + Math.random() * 10),
    source: 'mock',
  };
}

function mockAQI(zone) {
  const base = 80 + Math.round(Math.random() * 250);
  return { zone, aqi: base, level: base > 300 ? 'Hazardous' : base > 200 ? 'Very Unhealthy' : base > 100 ? 'Unhealthy' : 'Moderate', source: 'mock' };
}

router.post('/run', async (req, res) => {
  try {
    const result = await runMonitorCycle();
    res.json({
      message: `Monitor cycle complete`,
      triggersDetected: result.triggers.length,
      payoutsCreated: result.payouts.length,
      triggers: result.triggers,
      payouts: result.payouts,
    });
  } catch (err) {
    console.error('Monitor run error:', err);
    res.status(500).json({ error: 'Monitor cycle failed' });
  }
});

router.get('/weather/:zone', async (req, res) => {
  try {
    const zone = req.params.zone;
    if (!ZONE_COORDS[zone]) {
      return res.status(404).json({ error: `Unknown zone. Valid: ${Object.keys(ZONE_COORDS).join(', ')}` });
    }
    let weather = await fetchWeather(zone);
    if (!weather) weather = mockWeather(zone);
    res.json(weather);
  } catch (err) {
    console.error('Weather check error:', err);
    res.status(500).json({ error: 'Failed to fetch weather' });
  }
});

router.get('/aqi/:zone', async (req, res) => {
  try {
    const zone = req.params.zone;
    if (!ZONE_COORDS[zone]) {
      return res.status(404).json({ error: `Unknown zone. Valid: ${Object.keys(ZONE_COORDS).join(', ')}` });
    }
    let aqi = await fetchAQI(zone);
    if (!aqi) aqi = mockAQI(zone);
    res.json(aqi);
  } catch (err) {
    console.error('AQI check error:', err);
    res.status(500).json({ error: 'Failed to fetch AQI' });
  }
});

router.get('/zones', (req, res) => {
  res.json({ zones: Object.keys(ZONE_COORDS), count: Object.keys(ZONE_COORDS).length });
});

module.exports = router;
