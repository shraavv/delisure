const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { query } = require('../db');
const { validateAadhaar, hashAadhaar, maskAadhaar } = require('../utils/aadhaar');
const { validateUpi } = require('../utils/upi');
const { getWorkerRiskProfile } = require('../services/ml-client');

router.post('/verify-upi', (req, res) => {
  const { upi } = req.body;
  const result = validateUpi(upi);
  if (!result.valid) return res.status(422).json(result);
  res.json(result);
});

router.post('/verify-aadhaar', (req, res) => {
  const { aadhaar } = req.body;
  if (!aadhaar) return res.status(400).json({ error: 'aadhaar number is required' });

  const result = validateAadhaar(aadhaar);
  if (!result.valid) {
    return res.status(422).json({ valid: false, error: result.error });
  }

  res.json({
    valid: true,
    masked: maskAadhaar(aadhaar),
    message: 'Aadhaar number is valid (Verhoeff checksum passed)',
  });
});

router.post('/register', async (req, res) => {
  try {
    const { partnerId, platform, name, phone, zones, age, upiId, aadhaar, avgWeeklyEarnings, avgActiveHoursPerWeek } = req.body;

    if (!partnerId || !zones || !zones.length || !phone) {
      return res.status(400).json({ error: 'partnerId, phone, and zones are required' });
    }

    if (!aadhaar) {
      return res.status(400).json({ error: 'Aadhaar number is required for KYC verification' });
    }

    const aadhaarValidation = validateAadhaar(aadhaar);
    if (!aadhaarValidation.valid) {
      return res.status(422).json({ error: `Aadhaar KYC failed: ${aadhaarValidation.error}` });
    }

    if (upiId) {
      const upiValidation = validateUpi(upiId);
      if (!upiValidation.valid) {
        return res.status(422).json({ error: `UPI validation failed: ${upiValidation.error}` });
      }
    }

    const aadhaarHash = hashAadhaar(aadhaar);

    const aadhaarExists = await query('SELECT id FROM workers WHERE aadhaar_hash = $1', [aadhaarHash]);
    if (aadhaarExists.rows.length > 0) {
      return res.status(409).json({ error: 'This Aadhaar is already linked to an existing account', workerId: aadhaarExists.rows[0].id });
    }

    const existing = await query('SELECT id FROM workers WHERE partner_id = $1', [partnerId]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Worker already registered', workerId: existing.rows[0].id });
    }

    const zoneResult = await query(
      'SELECT risk_tier FROM zone_risk_profiles WHERE zone_name = ANY($1)',
      [zones]
    );
    const tierPriority = { high: 3, standard: 2, low: 1 };
    let worstTier = 'standard';
    for (const row of zoneResult.rows) {
      if ((tierPriority[row.risk_tier] || 0) > (tierPriority[worstTier] || 0)) {
        worstTier = row.risk_tier;
      }
    }

    const tierBase = { high: 5600, standard: 5000, low: 4400 };
    const baseEarnings = tierBase[worstTier] || 5000;
    const zoneBonus = 1 + Math.min(Math.max(zones.length - 1, 0) * 0.04, 0.15);
    const variance = 1 + (Math.random() - 0.5) * 0.1;
    const estimatedEarnings = avgWeeklyEarnings && avgWeeklyEarnings > 0
      ? Number(avgWeeklyEarnings)
      : Math.round(baseEarnings * zoneBonus * variance);
    const estimatedHours = avgActiveHoursPerWeek && avgActiveHoursPerWeek > 0
      ? Number(avgActiveHoursPerWeek)
      : Math.round(46 + Math.random() * 10);

    const id = `w-${uuidv4().slice(0, 6)}`;
    const result = await query(
      `INSERT INTO workers (id, name, age, phone, partner_id, platform, zones, avg_weekly_earnings, avg_active_hours_per_week, risk_tier, upi_id, aadhaar_hash)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
       RETURNING id, name, age, phone, partner_id, platform, zones, avg_weekly_earnings, avg_active_hours_per_week, risk_tier, upi_id, joined_date, created_at`,
      [id, name || 'New Worker', age || null, phone, partnerId, platform || 'swiggy', zones, estimatedEarnings, estimatedHours, worstTier, upiId || null, aadhaarHash]
    );

    res.status(201).json({
      message: 'Worker registered — Aadhaar KYC verified',
      worker: result.rows[0],
      aadhaar: { verified: true, masked: maskAadhaar(aadhaar) },
    });
  } catch (err) {
    if (err.code === '23505') {
      if (err.constraint?.includes('aadhaar')) {
        return res.status(409).json({ error: 'This Aadhaar is already linked to an existing account' });
      }
      return res.status(409).json({ error: 'Duplicate phone or partner ID' });
    }
    console.error('Register error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { partnerId, phone } = req.body;
    if (!partnerId || !phone) {
      return res.status(400).json({ error: 'partnerId and phone are required' });
    }

    const phoneDigits = phone.replace(/\D/g, '').slice(-10);

    const result = await query(
      `SELECT id, name, phone, partner_id, platform, zones, risk_tier, upi_id FROM workers
       WHERE partner_id = $1
         AND RIGHT(REGEXP_REPLACE(phone, '[^0-9]', '', 'g'), 10) = $2`,
      [partnerId, phoneDigits]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'No account found with this Partner ID and phone number' });
    }

    res.json({ message: 'Login successful', worker: result.rows[0] });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const result = await query('SELECT * FROM workers WHERE id = $1', [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Worker not found' });

    const worker = result.rows[0];

    const zoneResult = await query(
      'SELECT * FROM zone_risk_profiles WHERE zone_name = ANY($1)',
      [worker.zones]
    );

    res.json({ ...worker, zoneDetails: zoneResult.rows });
  } catch (err) {
    console.error('Get worker error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:id/dashboard', async (req, res) => {
  try {
    const wResult = await query('SELECT * FROM workers WHERE id = $1', [req.params.id]);
    if (wResult.rows.length === 0) return res.status(404).json({ error: 'Worker not found' });
    const worker = wResult.rows[0];

    const policyResult = await query(
      "SELECT * FROM policies WHERE worker_id = $1 AND status = 'active' LIMIT 1",
      [worker.id]
    );
    const policy = policyResult.rows[0] || null;

    const payoutsResult = await query(
      'SELECT * FROM payouts WHERE worker_id = $1 ORDER BY created_at DESC LIMIT 10',
      [worker.id]
    );
    const workerPayouts = payoutsResult.rows;
    const totalPayouts = workerPayouts.reduce((sum, p) => sum + parseFloat(p.amount), 0);

    const monthStart = new Date();
    monthStart.setDate(1);
    monthStart.setHours(0, 0, 0, 0);
    const thisMonthPayouts = workerPayouts
      .filter(p => new Date(p.created_at) >= monthStart)
      .reduce((sum, p) => sum + parseFloat(p.amount), 0);

    res.json({
      worker: { name: worker.name, id: worker.id, riskTier: worker.risk_tier, zones: worker.zones, avgWeeklyEarnings: parseFloat(worker.avg_weekly_earnings) },
      coverage: policy
        ? { status: 'active', weeklyPremium: parseFloat(policy.weekly_premium), nextDebitDate: policy.next_debit_date, tier: policy.risk_tier }
        : { status: 'inactive' },
      stats: {
        totalPayoutsReceived: totalPayouts,
        thisMonthPayouts,
        activeZones: worker.zones.length,
        totalPremiumsPaid: policy ? parseFloat(policy.total_premiums_paid) : 0,
        netBenefit: totalPayouts - (policy ? parseFloat(policy.total_premiums_paid) : 0),
      },
      recentPayouts: workerPayouts.slice(0, 5),
    });
  } catch (err) {
    console.error('Dashboard error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const { avgWeeklyEarnings, avgActiveHoursPerWeek, upiId, zones } = req.body;
    const result = await query(
      `UPDATE workers SET
        avg_weekly_earnings = COALESCE($1, avg_weekly_earnings),
        avg_active_hours_per_week = COALESCE($2, avg_active_hours_per_week),
        upi_id = COALESCE($3, upi_id),
        zones = COALESCE($4, zones)
       WHERE id = $5 RETURNING *`,
      [avgWeeklyEarnings, avgActiveHoursPerWeek, upiId, zones, req.params.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Worker not found' });
    res.json({ message: 'Profile updated', worker: result.rows[0] });
  } catch (err) {
    console.error('Update worker error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/:id/device-signals', async (req, res) => {
  try {
    const {
      accelMeanMagnitude, accelStdMagnitude, gyroMeanMagnitude,
      motionClassification,
      batteryLevel, batteryIsCharging,
      connectionType, networkName,
      gpsLat, gpsLng, gpsAccuracyM,
      platformOs,
    } = req.body;

    const result = await query(
      `INSERT INTO device_signals
        (worker_id, accel_mean_magnitude, accel_std_magnitude, gyro_mean_magnitude,
         motion_classification, battery_level, battery_is_charging, connection_type,
         network_name, gps_lat, gps_lng, gps_accuracy_m, platform_os)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
       RETURNING *`,
      [req.params.id, accelMeanMagnitude ?? null, accelStdMagnitude ?? null, gyroMeanMagnitude ?? null,
       motionClassification ?? 'unknown', batteryLevel ?? null, batteryIsCharging ?? null,
       connectionType ?? null, networkName ?? null, gpsLat ?? null, gpsLng ?? null,
       gpsAccuracyM ?? null, platformOs ?? null]
    );
    res.status(201).json({ message: 'Device signals recorded', signal: result.rows[0] });
  } catch (err) {
    console.error('Device signals error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:id/risk-profile', async (req, res) => {
  try {
    const profile = await getWorkerRiskProfile(req.params.id);
    if (!profile) {
      return res.status(503).json({ error: 'ML service unavailable' });
    }
    res.json(profile);
  } catch (err) {
    console.error('Risk profile error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/', async (req, res) => {
  try {
    const result = await query('SELECT * FROM workers ORDER BY created_at DESC');
    res.json({ workers: result.rows, count: result.rows.length });
  } catch (err) {
    console.error('List workers error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
