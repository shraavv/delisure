const axios = require('axios');
const https = require('https');

// Force IPv4 — some Docker networks have broken IPv6 routing to the outside
const ipv4Agent = new https.Agent({ family: 4, keepAlive: true });
const { v4: uuidv4 } = require('uuid');
const { query } = require('../db');

const THRESHOLDS = {
  rainfall:  { value: 14, unit: 'mm/hr', minDuration: 1.5, label: 'Heavy Rainfall' },
  heat:      { value: 44, unit: '°C',    minDuration: 3,   label: 'Extreme Heat' },
  aqi:       { value: 300, unit: 'AQI',  minDuration: 4,   label: 'Severe Air Pollution' },
  bandh:     { value: null, unit: null,   minDuration: null, label: 'Civic Disruption' },
  outage:    { value: 2, unit: 'hours',  minDuration: 2,   label: 'Platform Outage' },
};

const TIME_WINDOWS = [
  { label: 'Morning',   start: 7,    end: 11,   multiplier: 0.8, payoutRate: 0.40 },
  { label: 'Lunch',     start: 11,   end: 15,   multiplier: 1.2, payoutRate: 0.60 },
  { label: 'Afternoon', start: 15,   end: 19,   multiplier: 0.7, payoutRate: 0.40 },
  { label: 'Dinner',    start: 19,   end: 22.5, multiplier: 1.5, payoutRate: 0.70 },
];

const ZONE_COORDS = {
  'Velachery':      { lat: 12.9815, lon: 80.2180 },
  'Madipakkam':     { lat: 12.9623, lon: 80.1986 },
  'Tambaram':       { lat: 12.9249, lon: 80.1000 },
  'Adyar':          { lat: 13.0067, lon: 80.2565 },
  'Mylapore':       { lat: 13.0368, lon: 80.2676 },
  'T Nagar':        { lat: 13.0418, lon: 80.2341 },
  'Guindy':         { lat: 13.0067, lon: 80.2206 },
  'Nungambakkam':   { lat: 13.0569, lon: 80.2425 },
  'Anna Nagar':     { lat: 13.0850, lon: 80.2101 },
  'Egmore':         { lat: 13.0732, lon: 80.2609 },
  'Kodambakkam':    { lat: 13.0500, lon: 80.2240 },
  'Porur':          { lat: 13.0356, lon: 80.1569 },
  'Chromepet':      { lat: 12.9516, lon: 80.1413 },
  'Sholinganallur': { lat: 12.9010, lon: 80.2279 },
  'Perungudi':      { lat: 12.9640, lon: 80.2430 },
  'Thiruvanmiyur':  { lat: 12.9830, lon: 80.2640 },
};

async function fetchWeather(zoneName) {
  const coords = ZONE_COORDS[zoneName];
  if (!coords) return null;

  const apiKey = process.env.OPENWEATHER_API_KEY;
  if (!apiKey) return null;

  try {
    const res = await axios.get('https://api.openweathermap.org/data/2.5/weather', {
      params: { lat: coords.lat, lon: coords.lon, appid: apiKey, units: 'metric' },
      timeout: 8000,
      httpsAgent: ipv4Agent,
    });
    const data = res.data;

    return {
      zone: zoneName,
      temp: data.main.temp,
      feelsLike: data.main.feels_like,
      humidity: data.main.humidity,
      weatherMain: data.weather?.[0]?.main,
      weatherDesc: data.weather?.[0]?.description,
      rainMmPerHour: data.rain?.['1h'] || 0,
      windSpeed: data.wind?.speed || 0,
    };
  } catch (err) {
    console.error(`[Monitor] Weather fetch failed for ${zoneName}:`, err.message);
    return null;
  }
}

async function fetchAQI(zoneName) {
  const coords = ZONE_COORDS[zoneName];
  if (!coords) return null;

  const apiKey = process.env.OPENWEATHER_API_KEY;
  if (!apiKey) return null;

  try {
    const res = await axios.get('https://api.openweathermap.org/data/2.5/air_pollution', {
      params: { lat: coords.lat, lon: coords.lon, appid: apiKey },
      timeout: 8000,
      httpsAgent: ipv4Agent,
    });
    const data = res.data.list?.[0];
    if (!data) return null;

    const aqiMap = { 1: 30, 2: 75, 3: 150, 4: 250, 5: 400 };
    const approximateAqi = aqiMap[data.main.aqi] || 50;

    return {
      zone: zoneName,
      aqi: approximateAqi,
      owmLevel: data.main.aqi,
      pm25: data.components?.pm2_5 || 0,
      pm10: data.components?.pm10 || 0,
    };
  } catch (err) {
    console.error(`[Monitor] AQI fetch failed for ${zoneName}:`, err.message);
    return null;
  }
}

async function checkBandh() {
  return null;
}

async function checkPlatformOutage() {
  return null;
}

function evaluateWeatherTrigger(weather) {
  if (!weather) return null;

  if (weather.rainMmPerHour >= THRESHOLDS.rainfall.value) {
    return {
      type: 'rainfall',
      zone: weather.zone,
      intensity: weather.rainMmPerHour,
      unit: 'mm/hr',
      description: `Heavy rainfall in ${weather.zone} — ${weather.rainMmPerHour}mm/hr detected (threshold: ${THRESHOLDS.rainfall.value}mm/hr). ${weather.weatherDesc}.`,
      source: 'OpenWeatherMap (Live)',
    };
  }

  if (weather.feelsLike >= THRESHOLDS.heat.value) {
    return {
      type: 'heat',
      zone: weather.zone,
      intensity: weather.feelsLike,
      unit: '°C',
      description: `Extreme heat in ${weather.zone} — feels like ${weather.feelsLike}°C (threshold: ${THRESHOLDS.heat.value}°C).`,
      source: 'OpenWeatherMap (Live)',
    };
  }

  return null;
}

function evaluateAQITrigger(aqiData) {
  if (!aqiData) return null;

  if (aqiData.aqi >= THRESHOLDS.aqi.value) {
    return {
      type: 'aqi',
      zone: aqiData.zone,
      intensity: aqiData.aqi,
      unit: 'AQI',
      description: `Severe air pollution in ${aqiData.zone} — AQI ${aqiData.aqi} (threshold: ${THRESHOLDS.aqi.value}). PM2.5: ${aqiData.pm25}µg/m³.`,
      source: 'OpenWeatherMap Air Pollution (Live)',
    };
  }

  return null;
}

function formatHour(h) {
  const hr = Math.floor(h);
  const period = hr >= 12 ? 'PM' : 'AM';
  const hr12 = hr > 12 ? hr - 12 : (hr === 0 ? 12 : hr);
  const min = (h % 1) * 60;
  return min > 0 ? `${hr12}:${String(Math.round(min)).padStart(2, '0')} ${period}` : `${hr12}:00 ${period}`;
}

async function createTriggerEvent(trigger) {
  const id = `trg-${uuidv4().slice(0, 6)}`;
  const estDuration = THRESHOLDS[trigger.type]?.minDuration || 2;

  const intervalStr = `${estDuration} hours`;
  const result = await query(
    `INSERT INTO trigger_events (id, type, zone, city, start_time, end_time, duration_hours, intensity, unit, description, is_active, source)
     VALUES ($1, $2, $3, 'Chennai', NOW(), NOW() + $4::INTERVAL, $5, $6, $7, $8, TRUE, $9)
     RETURNING *`,
    [id, trigger.type, trigger.zone, intervalStr, estDuration, trigger.intensity, trigger.unit, trigger.description, trigger.source]
  );
  return result.rows[0];
}

async function hasActiveTrigger(type, zone) {
  const result = await query(
    'SELECT id FROM trigger_events WHERE type = $1 AND zone = $2 AND is_active = TRUE',
    [type, zone]
  );
  return result.rows.length > 0;
}

async function processClaimsForTrigger(triggerEvent) {
  const zone = triggerEvent.zone;
  const duration = parseFloat(triggerEvent.duration_hours);
  const currentHour = new Date().getHours() + new Date().getMinutes() / 60;
  const startHour = currentHour;

  const policiesResult = await query(
    `SELECT p.*, w.avg_weekly_earnings, w.avg_active_hours_per_week, w.name as worker_name, w.upi_id, w.id as wid
     FROM policies p JOIN workers w ON w.id = p.worker_id
     WHERE p.status = 'active' AND $1 = ANY(p.zones)`,
    [zone]
  );

  const payouts = [];

  for (const policy of policiesResult.rows) {
    const hourlyBaseline = parseFloat(policy.avg_weekly_earnings) / parseFloat(policy.avg_active_hours_per_week);

    let totalPayout = 0;
    const affectedWindows = [];

    for (const window of TIME_WINDOWS) {
      const overlapStart = Math.max(startHour, window.start);
      const overlapEnd = Math.min(startHour + duration, window.end);
      const overlapHours = Math.max(0, overlapEnd - overlapStart);

      if (overlapHours > 0) {
        const windowPayout = hourlyBaseline * window.multiplier * window.payoutRate * overlapHours;
        totalPayout += windowPayout;
        affectedWindows.push({
          label: window.label,
          hours: overlapHours,
          amount: Math.round(windowPayout),
          rate: `${window.payoutRate * 100}%`,
        });
      }
    }

    totalPayout = Math.round(totalPayout);
    if (totalPayout <= 0) continue;

    const payoutId = `pay-${uuidv4().slice(0, 6)}`;
    const breakdown = `${triggerEvent.description} Duration: ${duration}hrs (${formatHour(startHour)}–${formatHour(startHour + duration)}). ${affectedWindows.map(w => `${w.label}: ₹${w.amount} @ ${w.rate}`).join(', ')}. Total ₹${totalPayout} via UPI.`;
    const payoutRateStr = affectedWindows.map(w => `${w.label}: ${w.rate}`).join(', ');

    const payoutResult = await query(
      `INSERT INTO payouts (id, worker_id, trigger_event_id, amount, status, breakdown, trigger_type, zone, time_window, payout_rate)
       VALUES ($1, $2, $3, $4, 'processing', $5, $6, $7, $8, $9)
       RETURNING *`,
      [payoutId, policy.wid, triggerEvent.id, totalPayout, breakdown,
       triggerEvent.type, zone,
       `${formatHour(startHour)} – ${formatHour(startHour + duration)}`,
       payoutRateStr]
    );

    await query(
      `INSERT INTO fraud_checks (worker_id, trigger_event_id, payout_id, risk_score, is_flagged, flags, recommendation)
       VALUES ($1, $2, $3, 0, FALSE, '{}', 'approve')`,
      [policy.wid, triggerEvent.id, payoutId]
    );

    payouts.push({
      workerId: policy.wid,
      workerName: policy.worker_name,
      amount: totalPayout,
      payoutId,
    });
  }

  return payouts;
}

async function runMonitorCycle() {
  console.log(`[Monitor] Starting cycle at ${new Date().toISOString()}`);

  const zonesResult = await query(
    "SELECT DISTINCT unnest(zones) as zone FROM policies WHERE status = 'active'"
  );
  const activeZones = zonesResult.rows.map(r => r.zone);

  if (activeZones.length === 0) {
    console.log('[Monitor] No active policies — skipping');
    return { triggers: [], totalPayouts: 0 };
  }

  const allTriggers = [];
  const allPayouts = [];

  for (const zone of activeZones) {
    const weather = await fetchWeather(zone);
    const weatherTrigger = evaluateWeatherTrigger(weather);

    if (weatherTrigger && !(await hasActiveTrigger(weatherTrigger.type, zone))) {
      console.log(`[Monitor] TRIGGER: ${weatherTrigger.type} in ${zone} — ${weatherTrigger.intensity} ${weatherTrigger.unit}`);
      const triggerEvent = await createTriggerEvent(weatherTrigger);
      const payouts = await processClaimsForTrigger(triggerEvent);
      allTriggers.push(triggerEvent);
      allPayouts.push(...payouts);
    }

    const aqi = await fetchAQI(zone);
    const aqiTrigger = evaluateAQITrigger(aqi);

    if (aqiTrigger && !(await hasActiveTrigger('aqi', zone))) {
      console.log(`[Monitor] TRIGGER: AQI ${aqiTrigger.intensity} in ${zone}`);
      const triggerEvent = await createTriggerEvent(aqiTrigger);
      const payouts = await processClaimsForTrigger(triggerEvent);
      allTriggers.push(triggerEvent);
      allPayouts.push(...payouts);
    }
  }

  console.log(`[Monitor] Cycle complete — ${allTriggers.length} triggers, ${allPayouts.length} payouts`);
  return { triggers: allTriggers, payouts: allPayouts };
}

module.exports = {
  runMonitorCycle,
  fetchWeather,
  fetchAQI,
  evaluateWeatherTrigger,
  evaluateAQITrigger,
  processClaimsForTrigger,
  createTriggerEvent,
  THRESHOLDS,
  ZONE_COORDS,
};
