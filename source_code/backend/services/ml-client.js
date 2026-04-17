const axios = require('axios');

const ML_URL = process.env.ML_SERVICE_URL || 'http://localhost:8000';

async function calculatePremiumAuto(workerId) {
  try {
    console.log(`[ML] → GET /api/ml/premium/${workerId}`);
    const res = await axios.get(`${ML_URL}/api/ml/premium/${encodeURIComponent(workerId)}`, { timeout: 5000 });
    console.log(`[ML] ← Premium for ${workerId}: ₹${res.data.premium_amount_inr} (${res.data.risk_tier})`);
    return res.data;
  } catch (err) {
    console.error(`[ML] ✗ Auto premium failed for ${workerId}:`, err.message);
    return null;
  }
}

async function calculatePremium({ workerId, zones, avgWeeklyEarnings, claimHistoryCount = 0, season = null, forecastSeverity = 0, weeksActive = 0 }) {
  try {
    const payload = {
      worker_id: workerId,
      zones,
      avg_weekly_earnings: avgWeeklyEarnings,
      claim_history_count: claimHistoryCount,
      forecast_severity: forecastSeverity,
      weeks_active: weeksActive,
    };
    if (season) payload.season = season;

    const res = await axios.post(`${ML_URL}/api/ml/premium`, payload, { timeout: 5000 });
    return res.data;
  } catch (err) {
    console.error('[ML Client] Premium calculation failed:', err.message);
    return null;
  }
}

async function checkFraudAuto(workerId, triggerZone) {
  try {
    console.log(`[ML] → GET /api/ml/fraud-score/${workerId}/${triggerZone}`);
    const res = await axios.get(
      `${ML_URL}/api/ml/fraud-score/${encodeURIComponent(workerId)}/${encodeURIComponent(triggerZone)}`,
      { timeout: 5000 }
    );
    console.log(`[ML] ← Fraud for ${workerId}: score=${res.data.risk_score} rec=${res.data.recommendation} flags=${res.data.flags?.length || 0}`);
    return res.data;
  } catch (err) {
    console.error(`[ML] ✗ Auto fraud check failed for ${workerId}/${triggerZone}:`, err.message);
    return null;
  }
}

async function checkFraud({ workerId, triggerZone, gpsLat, gpsLng, deliveriesDuringTrigger = 0, claimFreqZscore = 0, hoursSinceLastClaim = 72 }) {
  try {
    const res = await axios.post(`${ML_URL}/api/ml/fraud-check`, {
      worker_id: workerId,
      trigger_zone: triggerZone,
      worker_gps_lat: gpsLat,
      worker_gps_lng: gpsLng,
      deliveries_during_trigger: deliveriesDuringTrigger,
      claim_frequency_zscore: claimFreqZscore,
      hours_since_last_claim: hoursSinceLastClaim,
    }, { timeout: 5000 });
    return res.data;
  } catch (err) {
    console.error('[ML Client] Fraud check failed:', err.message);
    return null;
  }
}

async function getWorkerRiskProfile(workerId) {
  try {
    const res = await axios.get(`${ML_URL}/api/ml/worker-risk-profile/${encodeURIComponent(workerId)}`, { timeout: 10000 });
    return res.data;
  } catch (err) {
    console.error('[ML Client] Risk profile failed:', err.message);
    return null;
  }
}

async function getRiskCalendar(zone) {
  try {
    const res = await axios.get(`${ML_URL}/api/ml/risk-calendar/${encodeURIComponent(zone)}`, { timeout: 5000 });
    return res.data;
  } catch (err) {
    console.error('[ML Client] Risk calendar failed:', err.message);
    return null;
  }
}

async function getMLMetrics() {
  try {
    const res = await axios.get(`${ML_URL}/api/ml/metrics`, { timeout: 5000 });
    return res.data;
  } catch (err) {
    console.error('[ML Client] Metrics fetch failed:', err.message);
    return null;
  }
}

async function isMLHealthy() {
  try {
    const res = await axios.get(`${ML_URL}/api/ml/health`, { timeout: 3000 });
    return res.data.status === 'healthy';
  } catch {
    return false;
  }
}

module.exports = {
  calculatePremium,
  calculatePremiumAuto,
  checkFraud,
  checkFraudAuto,
  getWorkerRiskProfile,
  getRiskCalendar,
  getMLMetrics,
  isMLHealthy,
};
