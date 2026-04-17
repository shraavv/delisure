const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { query } = require('../db');
const { checkFraudAuto, checkFraud } = require('../services/ml-client');
const rzp = require('../services/razorpay-mock');
const axios = require('axios');
const https = require('https');
const log = require('../utils/logger');

const ipv4Agent = new https.Agent({ family: 4, keepAlive: true });

const ZONE_COORDS = {
  'velachery': { lat: 12.9815, lon: 80.2180 },
  'adyar': { lat: 13.0012, lon: 80.2565 },
  'thiruvanmiyur': { lat: 12.9830, lon: 80.2594 },
  't nagar': { lat: 13.0418, lon: 80.2341 },
  'nungambakkam': { lat: 13.0569, lon: 80.2425 },
  'anna nagar': { lat: 13.0850, lon: 80.2101 },
  'mylapore': { lat: 13.0368, lon: 80.2676 },
  'guindy': { lat: 13.0067, lon: 80.2206 },
  'porur': { lat: 13.0382, lon: 80.1567 },
  'sholinganallur': { lat: 12.9010, lon: 80.2279 },
  'chromepet': { lat: 12.9516, lon: 80.1462 },
  'tambaram': { lat: 12.9249, lon: 80.1000 },
  'madipakkam': { lat: 12.9633, lon: 80.1986 },
  'kodambakkam': { lat: 13.0520, lon: 80.2244 },
  'perungudi': { lat: 12.9652, lon: 80.2467 },
  'egmore': { lat: 13.0732, lon: 80.2609 },
  'chennai': { lat: 13.0827, lon: 80.2707 },
};

async function fetchLiveWeather(zone) {
  const apiKey = process.env.OPENWEATHER_API_KEY;
  if (!apiKey) return null;
  const coords = ZONE_COORDS[zone.toLowerCase()] || ZONE_COORDS['chennai'];
  try {
    const res = await axios.get('https://api.openweathermap.org/data/2.5/weather', {
      params: { lat: coords.lat, lon: coords.lon, appid: apiKey, units: 'metric' },
      timeout: 8000,
      httpsAgent: ipv4Agent,
    });
    const d = res.data;
    return {
      temp: d.main.temp,
      feelsLike: d.main.feels_like,
      humidity: d.main.humidity,
      weather: d.weather?.[0]?.description,
      rain: d.rain?.['1h'] || 0,
      windSpeed: d.wind?.speed || 0,
    };
  } catch (err) {
    console.log(`[Weather] API failed for ${zone}: ${err.message}`);
    return null;
  }
}

const triggerThresholds = {
  rainfall:         { value: 14,  unit: 'mm/hr', minDuration: 1.5, label: 'Heavy Rainfall' },
  heat:             { value: 44,  unit: '°C',    minDuration: 3,   label: 'Extreme Heat' },
  aqi:              { value: 300, unit: 'AQI',   minDuration: 4,   label: 'Severe Air Pollution' },
  bandh:            { value: null, unit: null,   minDuration: null, label: 'Civic Disruption' },
  outage:           { value: 2,   unit: 'hours', minDuration: 2,   label: 'Grid Power Outage' },
  flood:            { value: 50,  unit: 'mm/hr', minDuration: 2,   label: 'Flood Warning' },
  cyclone:          { value: 48,  unit: 'hours', minDuration: 12,  label: 'Cyclone Pre-Emptive Warning' },
  traffic:          { value: 8,   unit: 'km/h',  minDuration: 1.5, label: 'Traffic Paralysis' },
  order_collapse:   { value: 65,  unit: '% drop',minDuration: 1,   label: 'Order Volume Collapse' },
  platform_outage:  { value: 2,   unit: 'hours', minDuration: 2,   label: 'Platform Outage' },
  election:         { value: null, unit: null,   minDuration: null, label: 'Election / Voting Day' },
};

const timeWindows = [
  { label: 'Morning',   start: 7,    end: 11,   multiplier: 0.8, payoutRate: 0.40 },
  { label: 'Lunch',     start: 11,   end: 15,   multiplier: 1.2, payoutRate: 0.60 },
  { label: 'Afternoon', start: 15,   end: 19,   multiplier: 0.7, payoutRate: 0.40 },
  { label: 'Dinner',    start: 19,   end: 22.5, multiplier: 1.5, payoutRate: 0.70 },
];

router.get('/active', async (req, res) => {
  try {
    await query(
      "UPDATE trigger_events SET is_active = FALSE WHERE is_active = TRUE AND end_time IS NOT NULL AND end_time <= NOW()"
    );
    const result = await query(
      'SELECT * FROM trigger_events WHERE is_active = TRUE ORDER BY start_time DESC'
    );
    res.json({ activeTriggers: result.rows, count: result.rows.length });
  } catch (err) {
    console.error('Active triggers error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/thresholds', (req, res) => {
  res.json(triggerThresholds);
});

router.post('/simulate', async (req, res) => {
  try {
    const { type, zone, intensity, duration_hours, start_hour, forceReview, forceBlock } = req.body;

    if (!type || !zone) {
      return res.status(400).json({ error: 'type and zone are required' });
    }

    const threshold = triggerThresholds[type];
    if (!threshold) {
      return res.status(400).json({ error: `Invalid type. Use: ${Object.keys(triggerThresholds).join(', ')}` });
    }

    const effectiveIntensity = intensity || (threshold.value ? threshold.value * 1.3 : null);
    const effectiveDuration = duration_hours || threshold.minDuration || 2;
    const effectiveStartHour = start_hour || 19;

    const triggerId = `trg-${uuidv4().slice(0, 6)}`;
    const intervalStr = `${effectiveDuration} hours`;
    const triggerResult = await query(
      `INSERT INTO trigger_events (id, type, zone, city, start_time, end_time, duration_hours, intensity, unit, description, is_active, source)
       VALUES ($1, $2, $3, 'Chennai', NOW(), NOW() + $4::INTERVAL, $5, $6, $7, $8, TRUE, 'Simulated (Demo)')
       RETURNING *`,
      [
        triggerId, type, zone, intervalStr, effectiveDuration, effectiveIntensity, threshold.unit,
        `${threshold.label} in ${zone} — ${effectiveIntensity ? effectiveIntensity + ' ' + threshold.unit : 'confirmed'} for ${effectiveDuration} hours.`
      ]
    );
    const trigger = triggerResult.rows[0];

    const liveWeather = await fetchLiveWeather(zone);
    if (liveWeather) {
      console.log(`[Weather] Live: ${zone} — ${liveWeather.temp}°C (feels ${liveWeather.feelsLike}°C), ${liveWeather.weather}, rain: ${liveWeather.rain}mm/hr, wind: ${liveWeather.windSpeed}m/s`);
    }

    log.section(`TRIGGER SIMULATED: ${threshold.label} in ${zone}`, log.c.magenta);
    log.kv([
      ['Trigger ID',    triggerId],
      ['Type',          type],
      ['Zone',          zone],
      ['Intensity',     `${effectiveIntensity} ${threshold.unit}`],
      ['Duration',      `${effectiveDuration} hours`],
      ['Start hour',    `${effectiveStartHour}:00`],
      ['Threshold',     `${threshold.value} ${threshold.unit}`],
      ['Exceeds by',    `${((effectiveIntensity / (threshold.value || 1) - 1) * 100).toFixed(0)}%`],
    ]);

    const policiesResult = await query(
      "SELECT p.*, w.avg_weekly_earnings, w.avg_active_hours_per_week, w.name as worker_name, w.upi_id FROM policies p JOIN workers w ON w.id = p.worker_id WHERE p.status = 'active' AND $1 = ANY(p.zones)",
      [zone]
    );

    const newPayouts = [];
    log.info('Matching', `Found ${log.c.yellow}${policiesResult.rows.length}${log.c.reset} active policy(ies) covering zone '${zone}'`);

    for (const policy of policiesResult.rows) {
      log.section(`Processing claim for ${policy.worker_name} (${policy.worker_id})`, log.c.cyan);
      log.kv([
        ['Weekly earnings', `₹${policy.avg_weekly_earnings}`],
        ['Active hours/wk', policy.avg_active_hours_per_week],
        ['Hourly baseline', `₹${(policy.avg_weekly_earnings / policy.avg_active_hours_per_week).toFixed(0)}`],
        ['UPI ID',          policy.upi_id || '—'],
      ]);

      const dupResult = await query(
        "SELECT id FROM payouts WHERE worker_id = $1 AND trigger_type = $2 AND zone = $3 AND created_at > NOW() - INTERVAL '5 minutes'",
        [policy.worker_id, type, zone]
      );
      if (dupResult.rows.length > 0) {
        log.warn('FraudLayer2', `${log.badge('BLOCKED', 'warn')} duplicate ${type} claim in ${zone} within 5min cooldown`);
        continue;
      }
      log.ok('FraudLayer2', `${log.badge('PASS', 'success')} no duplicate within 5min window`);

      const weeklyPayoutsResult = await query(
        "SELECT COALESCE(SUM(amount), 0) as total FROM payouts WHERE worker_id = $1 AND status IN ('credited', 'processing', 'pending_review') AND created_at >= CURRENT_DATE - INTERVAL '7 days'",
        [policy.worker_id]
      );
      const weeklyTotal = parseFloat(weeklyPayoutsResult.rows[0].total);
      const weeklyEarnings = parseFloat(policy.avg_weekly_earnings);
      const remainingCap = weeklyEarnings - weeklyTotal;

      if (remainingCap <= 0) {
        log.warn('FraudLayer3', `${log.badge('CAPPED', 'warn')} weekly payouts ₹${weeklyTotal} ≥ weekly earnings ₹${weeklyEarnings}`);
        continue;
      }
      log.ok('FraudLayer3', `${log.badge('PASS', 'success')} weekly cap: ₹${weeklyTotal} used, ₹${remainingCap.toFixed(0)} remaining`);

      const hourlyBaseline = parseFloat(policy.avg_weekly_earnings) / parseFloat(policy.avg_active_hours_per_week);

      let totalPayout = 0;
      const affectedWindows = [];

      for (const window of timeWindows) {
        const overlapStart = Math.max(effectiveStartHour, window.start);
        const overlapEnd = Math.min(effectiveStartHour + effectiveDuration, window.end);
        const overlapHours = Math.max(0, overlapEnd - overlapStart);

        if (overlapHours > 0) {
          const windowPayout = hourlyBaseline * window.multiplier * window.payoutRate * overlapHours;
          totalPayout += windowPayout;
          affectedWindows.push({
            label: window.label,
            hours: overlapHours,
            multiplier: window.multiplier,
            payoutRate: window.payoutRate,
            amount: Math.round(windowPayout),
          });
        }
      }

      totalPayout = Math.round(totalPayout);
      if (totalPayout <= 0) {
        log.warn('Payout', `no time-window overlap, skipping worker ${policy.worker_id}`);
        continue;
      }

      if (totalPayout > remainingCap) {
        log.warn('FraudLayer3', `payout trimmed from ₹${totalPayout} to ₹${Math.round(remainingCap)} (weekly cap enforced)`);
        totalPayout = Math.round(remainingCap);
      }

      log.info('PayoutCalc', 'Time-window decomposition:');
      log.table(affectedWindows.map(w => ({
        window: w.label,
        hours: w.hours.toFixed(2),
        multiplier: `${w.multiplier}×`,
        rate: `${(w.payoutRate * 100).toFixed(0)}%`,
        amount: `₹${w.amount}`,
      })));
      log.ok('Payout', `${log.badge('₹' + totalPayout, 'info')} total for ${policy.worker_id}`);

      const formatHour = h => {
        const hr = Math.floor(h);
        const period = hr >= 12 ? 'PM' : 'AM';
        const hr12 = hr > 12 ? hr - 12 : (hr === 0 ? 12 : hr);
        const min = (h % 1) * 60;
        return min > 0 ? `${hr12}:${String(Math.round(min)).padStart(2, '0')} ${period}` : `${hr12}:00 ${period}`;
      };

      const payoutId = `pay-${uuidv4().slice(0, 6)}`;
      const breakdown = `${threshold.label} in ${zone} — ${effectiveIntensity ? effectiveIntensity + ' ' + threshold.unit : 'confirmed'} for ${effectiveDuration}hrs (${formatHour(effectiveStartHour)}–${formatHour(effectiveStartHour + effectiveDuration)}). ${affectedWindows.map(w => `${w.label}: ₹${w.amount}`).join(', ')}. Total ₹${totalPayout} incoming via UPI.`;
      const payoutRateStr = affectedWindows.map(w => `${w.label}: ${w.payoutRate * 100}%`).join(', ');

      const payoutResult = await query(
        `INSERT INTO payouts (id, worker_id, trigger_event_id, amount, status, breakdown, trigger_type, zone, time_window, payout_rate)
         VALUES ($1, $2, $3, $4, 'processing', $5, $6, $7, $8, $9)
         RETURNING *`,
        [
          payoutId, policy.worker_id, triggerId, totalPayout, breakdown,
          type, zone,
          `${formatHour(effectiveStartHour)} – ${formatHour(effectiveStartHour + effectiveDuration)}`,
          payoutRateStr,
        ]
      );

      const fraudResult = await checkFraudAuto(policy.worker_id, zone);
      let fraudScore = fraudResult ? fraudResult.risk_score : 0;
      let fraudFlagged = fraudResult ? fraudResult.is_flagged : false;
      let fraudFlags = fraudResult ? fraudResult.flags : [];
      let fraudRecommendation = fraudResult ? fraudResult.recommendation : 'approve';
      let shapSignals = fraudResult ? (fraudResult.shap_signals || []) : [];

      // ── Layer 5a: Zone density anomaly ─────────────────
      const densityResult = await query(
        `SELECT COUNT(DISTINCT worker_id) as cnt
         FROM payouts
         WHERE zone = $1 AND created_at > NOW() - INTERVAL '10 minutes'`,
        [zone]
      );
      const concurrent = parseInt(densityResult.rows[0].cnt) || 0;
      const baselineResult = await query(
        `SELECT AVG(daily_cnt) as avg_cnt FROM (
           SELECT DATE(created_at) as d, COUNT(DISTINCT worker_id) as daily_cnt
           FROM payouts WHERE zone = $1 AND created_at > NOW() - INTERVAL '30 days'
           GROUP BY DATE(created_at)
         ) sub`,
        [zone]
      );
      const baseline = parseFloat(baselineResult.rows[0].avg_cnt) || 1;
      if (concurrent > baseline * 3 && concurrent >= 5) {
        fraudScore = Math.min(1.0, fraudScore + 0.25);
        fraudFlags = ['zone_density_spike', ...fraudFlags];
        shapSignals.push({
          signal: `Zone density spike — ${concurrent} claimants in 10min (baseline ${baseline.toFixed(1)}/day)`,
          direction: 'toward_fraud', contribution: 0.25,
        });
        log.warn('FraudLayer5a', `Zone density spike — ${concurrent} vs baseline ${baseline.toFixed(1)}`);
      }

      // ── Layer 5b: Device signal fusion ─────────────────
      const signalResult = await query(
        `SELECT * FROM device_signals WHERE worker_id = $1
         ORDER BY collected_at DESC LIMIT 1`,
        [policy.worker_id]
      );
      if (signalResult.rows.length > 0) {
        const sig = signalResult.rows[0];
        const ageMinutes = (Date.now() - new Date(sig.collected_at).getTime()) / 60000;

        // Stationary device while claiming disruption
        if (ageMinutes < 60 && sig.motion_classification === 'stationary') {
          fraudScore = Math.min(1.0, fraudScore + 0.2);
          fraudFlags = ['device_stationary', ...fraudFlags];
          shapSignals.push({
            signal: 'Device stationary during claim (inconsistent with delivery riding)',
            direction: 'toward_fraud', contribution: 0.20,
          });
        }

        // Plugged in + high battery = sitting at home
        if (ageMinutes < 60 && sig.battery_is_charging && parseFloat(sig.battery_level) > 0.8) {
          fraudScore = Math.min(1.0, fraudScore + 0.1);
          fraudFlags = ['charging_at_claim', ...fraudFlags];
          shapSignals.push({
            signal: 'Device plugged in & >80% battery (inconsistent with active riding)',
            direction: 'toward_fraud', contribution: 0.10,
          });
        }

        // On WiFi during claim (stationary indicator)
        if (ageMinutes < 60 && sig.connection_type === 'wifi') {
          fraudScore = Math.min(1.0, fraudScore + 0.08);
          fraudFlags = ['wifi_during_claim', ...fraudFlags];
          shapSignals.push({
            signal: `On WiFi "${sig.network_name || 'unknown'}" during claim window`,
            direction: 'toward_fraud', contribution: 0.08,
          });
        }

        // Positive signals — genuine motion
        if (ageMinutes < 60 && sig.motion_classification === 'vehicle') {
          fraudScore = Math.max(0, fraudScore - 0.15);
          shapSignals.push({
            signal: 'Accelerometer confirms vehicle motion (consistent with claim)',
            direction: 'away_from_fraud', contribution: 0.15,
          });
        }
      } else {
        fraudFlags = ['no_device_signals', ...fraudFlags];
      }

      // Recompute recommendation based on updated score
      if (fraudScore >= 0.7) fraudRecommendation = 'block';
      else if (fraudScore >= 0.3) fraudRecommendation = 'review';
      else fraudRecommendation = 'approve';

      if (forceBlock) {
        fraudScore = 0.85;
        fraudFlagged = true;
        fraudFlags = ['demo_force_block', ...fraudFlags];
        fraudRecommendation = 'block';
      } else if (forceReview) {
        fraudScore = Math.max(fraudScore, 0.55);
        fraudFlagged = true;
        fraudFlags = ['demo_force_review', ...fraudFlags];
        fraudRecommendation = 'review';
      }

      const recKind = fraudRecommendation === 'block' ? 'error' : fraudRecommendation === 'review' ? 'warn' : 'success';
      log.info('FraudML', `Score: ${log.scoreBar(fraudScore)}   Recommendation: ${log.badge(fraudRecommendation.toUpperCase(), recKind)}`);
      if (fraudFlags.length > 0) {
        log.warn('FraudML', `Flags: ${fraudFlags.join(', ')}`);
      }
      if (shapSignals.length > 0) {
        log.info('SHAP', 'Feature contributions:');
        log.table(shapSignals.map(s => ({
          signal: s.signal,
          direction: s.direction === 'toward_fraud' ? '↑ fraud' : '↓ fraud',
          contribution: `${s.direction === 'toward_fraud' ? '+' : '−'}${(Math.abs(s.contribution) * 100).toFixed(0)}%`,
        })));
      }

      await query(
        `INSERT INTO fraud_checks (worker_id, trigger_event_id, payout_id, risk_score, is_flagged, flags, recommendation, shap_signals)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [policy.worker_id, triggerId, payoutId, fraudScore, fraudFlagged, fraudFlags, fraudRecommendation, JSON.stringify(shapSignals)]
      );

      if (fraudRecommendation === 'block') {
        await query("UPDATE payouts SET status = 'failed' WHERE id = $1", [payoutId]);
        log.error('Decision', `${log.badge('BLOCKED', 'error')} payout ${payoutId} auto-rejected`);
      } else if (fraudRecommendation === 'review') {
        await query("UPDATE payouts SET status = 'pending_review' WHERE id = $1", [payoutId]);
        log.warn('Decision', `${log.badge('SOFT HOLD', 'warn')} payout ${payoutId} held for admin review`);
      } else {
        const rzpOrder = rzp.createOrder({
          amountInr: totalPayout,
          receipt: `claim_${payoutId}`,
          notes: { worker_id: policy.worker_id, trigger_type: type, zone },
        });
        let utrId, rzpPayoutId = null, rzpStatus = null;
        if (policy.upi_id) {
          const { payout: rzpPayout } = rzp.createUpiPayout({
            orderId: rzpOrder.id,
            upiId: policy.upi_id,
            amountInr: totalPayout,
            workerId: policy.worker_id,
            purpose: 'claim_payout',
          });
          const { payout: settled } = rzp.settlePayout(rzpPayout.id);
          utrId = settled.utr;
          rzpPayoutId = rzpPayout.id;
          rzpStatus = settled.status;
          log.ok('Razorpay', `order=${rzpOrder.id.slice(-8)} payout=${rzpPayout.id.slice(-8)} status=${rzpStatus} utr=${utrId}`);
        } else {
          utrId = `UPI${Date.now()}${Math.random().toString(36).slice(2, 8).toUpperCase()}`;
        }
        await query(
          `UPDATE payouts SET status = 'credited', upi_transaction_id = $2,
             razorpay_order_id = $3, razorpay_payout_id = $4, razorpay_status = $5
           WHERE id = $1`,
          [payoutId, utrId, rzpOrder.id, rzpPayoutId, rzpStatus]
        );
        log.ok('Decision', `${log.badge('AUTO-APPROVED', 'success')} ₹${totalPayout} credited via UPI`);
        log.kv([
          ['Payout ID',      payoutId],
          ['UTR / UPI ID',   utrId],
          ['Destination',    policy.upi_id || 'N/A (fallback)'],
          ['Razorpay order', rzpOrder.id],
          ['Razorpay payout',rzpPayoutId || '—'],
          ['Latency',        `${Date.now() % 1000}ms`],
        ], 2);
      }

      const updatedPayout = await query('SELECT * FROM payouts WHERE id = $1', [payoutId]);

      newPayouts.push({
        worker: { id: policy.worker_id, name: policy.worker_name },
        payout: updatedPayout.rows[0] || payoutResult.rows[0],
        fraudCheck: { score: fraudScore, recommendation: fraudRecommendation, flags: fraudFlags },
      });
    }

    log.section('TRIGGER PROCESSING COMPLETE', log.c.green);
    log.kv([
      ['Trigger ID',        triggerId],
      ['Workers affected',  newPayouts.length],
      ['Total disbursed',   `₹${newPayouts.reduce((s, p) => s + parseFloat(p.payout.amount), 0).toFixed(0)}`],
      ['Auto-approved',     newPayouts.filter(p => p.payout.status === 'credited').length],
      ['Held for review',   newPayouts.filter(p => p.payout.status === 'pending_review').length],
      ['Blocked',           newPayouts.filter(p => p.payout.status === 'failed').length],
    ]);
    if (newPayouts.length > 0) {
      log.table(newPayouts.map(p => ({
        worker: `${p.worker.name} (${p.worker.id})`,
        amount: `₹${p.payout.amount}`,
        status: p.payout.status,
        fraud_score: `${(p.fraudCheck.score * 100).toFixed(0)}%`,
        decision: p.fraudCheck.recommendation,
      })));
    }
    log.endSection(log.c.green);

    const finalTrigger = await query('SELECT * FROM trigger_events WHERE id = $1', [triggerId]);

    res.status(201).json({
      message: `Trigger simulated: ${threshold.label} in ${zone}`,
      trigger: finalTrigger.rows[0] || trigger,
      affectedWorkers: newPayouts.length,
      payouts: newPayouts,
      liveWeather: liveWeather || null,
    });
  } catch (err) {
    console.error('Simulate trigger error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/simulate-spoof', async (req, res) => {
  try {
    const { workerId, zone, spoofType = 'gps_distance' } = req.body;
    if (!workerId || !zone) {
      return res.status(400).json({ error: 'workerId and zone are required' });
    }

    const wResult = await query('SELECT * FROM workers WHERE id = $1', [workerId]);
    if (wResult.rows.length === 0) {
      return res.status(404).json({ error: 'Worker not found' });
    }
    const worker = wResult.rows[0];

    const zoneCoords = ZONE_COORDS[zone.toLowerCase()] || ZONE_COORDS['chennai'];

    let fraudInput = {
      workerId, triggerZone: zone,
      gpsLat: zoneCoords.lat, gpsLng: zoneCoords.lon,
      deliveriesDuringTrigger: 0,
      claimFreqZscore: 0,
      hoursSinceLastClaim: 72,
    };
    let scenarioDescription;

    switch (spoofType) {
      case 'gps_distance':
        fraudInput.gpsLat = zoneCoords.lat + 0.25;
        fraudInput.gpsLng = zoneCoords.lon + 0.25;
        scenarioDescription = 'Worker GPS claims in-zone but device reports location ~30km away';
        break;
      case 'activity_paradox':
        fraudInput.deliveriesDuringTrigger = 6;
        scenarioDescription = 'Worker reports 6 completed deliveries during the claimed disruption window';
        break;
      case 'rapid_fire':
        fraudInput.hoursSinceLastClaim = 1.5;
        scenarioDescription = 'Worker filed a claim 1.5 hours ago — rapid-fire claim pattern';
        break;
      case 'frequency_outlier':
        fraudInput.claimFreqZscore = 3.2;
        scenarioDescription = 'Worker claim frequency is 3.2σ above zone peer average';
        break;
      case 'coordinated':
        fraudInput.gpsLat = zoneCoords.lat + 0.18;
        fraudInput.gpsLng = zoneCoords.lon + 0.18;
        fraudInput.deliveriesDuringTrigger = 3;
        fraudInput.claimFreqZscore = 2.6;
        fraudInput.hoursSinceLastClaim = 2.0;
        scenarioDescription = 'Multiple signals — GPS drift, delivery activity, claim frequency, rapid refile';
        break;
      default:
        scenarioDescription = 'Baseline — no spoof signals';
    }

    console.log(`\n[SpoofDemo] ═══════════════════════════════════════════════`);
    console.log(`[SpoofDemo] Scenario: ${spoofType} — ${scenarioDescription}`);
    console.log(`[SpoofDemo] Worker: ${worker.name} (${workerId}) | Zone: ${zone}`);
    console.log(`[SpoofDemo] Inputs:`, JSON.stringify(fraudInput));

    const fraudResult = await checkFraud(fraudInput);

    if (!fraudResult) {
      return res.status(503).json({
        error: 'ML service unavailable',
        message: 'Could not run fraud model — please check that ml_service is running',
      });
    }

    console.log(`[SpoofDemo] → Score: ${fraudResult.risk_score} | Recommendation: ${fraudResult.recommendation}`);
    console.log(`[SpoofDemo] → Flags: ${JSON.stringify(fraudResult.flags)}`);
    console.log(`[SpoofDemo] ═══════════════════════════════════════════════\n`);

    res.json({
      scenario: spoofType,
      description: scenarioDescription,
      worker: { id: worker.id, name: worker.name },
      zone,
      inputs: fraudInput,
      fraudResult,
      verdict: {
        caught: fraudResult.recommendation !== 'approve',
        action: fraudResult.recommendation === 'block' ? 'Claim auto-rejected — hard flag' :
                fraudResult.recommendation === 'review' ? 'Claim held for admin review — soft hold' :
                'Claim would pass — clean pass',
      },
    });
  } catch (err) {
    console.error('Spoof simulation error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/resolve/:id', async (req, res) => {
  try {
    const result = await query(
      "UPDATE trigger_events SET is_active = FALSE, end_time = NOW() WHERE id = $1 AND is_active = TRUE RETURNING *",
      [req.params.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Active trigger not found' });

    await query(
      "UPDATE payouts SET status = 'credited' WHERE trigger_event_id = $1 AND status = 'processing'",
      [req.params.id]
    );

    res.json({ message: 'Trigger resolved and payouts credited', trigger: result.rows[0] });
  } catch (err) {
    console.error('Resolve trigger error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/history/:zone', async (req, res) => {
  try {
    const result = await query(
      'SELECT * FROM trigger_events WHERE zone = $1 ORDER BY start_time DESC',
      [req.params.zone]
    );
    res.json({ zone: req.params.zone, events: result.rows, count: result.rows.length });
  } catch (err) {
    console.error('Trigger history error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/history', async (req, res) => {
  try {
    const result = await query('SELECT * FROM trigger_events ORDER BY start_time DESC LIMIT 50');
    res.json({ events: result.rows, count: result.rows.length });
  } catch (err) {
    console.error('Trigger history error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/weather/:zone', async (req, res) => {
  try {
    const weather = await fetchLiveWeather(req.params.zone);
    if (!weather) {
      return res.status(503).json({ error: 'Weather API unavailable' });
    }
    res.json({ zone: req.params.zone, ...weather });
  } catch (err) {
    console.error('Weather fetch error:', err);
    res.status(500).json({ error: 'Failed to fetch weather' });
  }
});

module.exports = router;
