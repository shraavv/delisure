const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { query } = require('../db');
const { calculatePremium, calculatePremiumAuto } = require('../services/ml-client');

function getNextMonday() {
  const d = new Date();
  const day = d.getDay();
  const diff = day === 0 ? 1 : 8 - day;
  d.setDate(d.getDate() + diff);
  return d.toISOString().split('T')[0];
}

router.post('/activate', async (req, res) => {
  try {
    const { workerId } = req.body;
    if (!workerId) return res.status(400).json({ error: 'workerId is required' });

    const wResult = await query('SELECT * FROM workers WHERE id = $1', [workerId]);
    if (wResult.rows.length === 0) return res.status(404).json({ error: 'Worker not found' });
    const worker = wResult.rows[0];

    const existingResult = await query(
      "SELECT * FROM policies WHERE worker_id = $1 AND status = 'active'",
      [workerId]
    );
    if (existingResult.rows.length > 0) {
      return res.status(200).json({ message: 'Policy already active', policy: existingResult.rows[0] });
    }

    let premium;
    let premiumBreakdown = null;
    let riskTier = worker.risk_tier;

    console.log(`[Policy] Activating for worker ${workerId} (${worker.name}) — zones: ${worker.zones}`);
    const mlResult = await calculatePremiumAuto(workerId);

    if (mlResult) {
      premium = mlResult.premium_amount_inr;
      riskTier = mlResult.risk_tier;
      premiumBreakdown = mlResult.breakdown;
      console.log(`[Policy] ML premium: ₹${premium} (${riskTier}) — XGBoost model`);
    } else {
      const premiumMap = { low: 29, standard: 49, high: 69 };
      premium = premiumMap[worker.risk_tier] || 49;
      console.log(`[Policy] ML unavailable — fallback premium: ₹${premium} (${worker.risk_tier})`);
    }

    const id = `pol-${uuidv4().slice(0, 6)}`;
    const result = await query(
      `INSERT INTO policies (id, worker_id, status, weekly_premium, risk_tier, start_date, zones, next_debit_date, total_premiums_paid, weeks_active)
       VALUES ($1, $2, 'active', $3, $4, CURRENT_DATE, $5, $6, 0, 0)
       RETURNING *`,
      [id, workerId, premium, riskTier, worker.zones, getNextMonday()]
    );

    res.status(201).json({
      message: 'Policy activated',
      policy: result.rows[0],
      premiumCalculation: premiumBreakdown ? {
        model: mlResult.model_version,
        breakdown: premiumBreakdown,
      } : { model: 'fallback-static', note: 'ML service unavailable, used static pricing' },
    });
  } catch (err) {
    console.error('Activate policy error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:workerId', async (req, res) => {
  try {
    const allResult = await query(
      'SELECT * FROM policies WHERE worker_id = $1 ORDER BY created_at DESC',
      [req.params.workerId]
    );
    const active = allResult.rows.find(p => p.status === 'active') || null;
    res.json({ active, history: allResult.rows });
  } catch (err) {
    console.error('Get policies error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.put('/:id/pause', async (req, res) => {
  try {
    const result = await query(
      "UPDATE policies SET status = 'paused' WHERE id = $1 AND status = 'active' RETURNING *",
      [req.params.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Active policy not found' });
    }
    res.json({ message: 'Policy paused — takes effect after 24 hours', policy: result.rows[0] });
  } catch (err) {
    console.error('Pause policy error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.put('/:id/resume', async (req, res) => {
  try {
    const result = await query(
      `UPDATE policies SET status = 'active', next_debit_date = $1 WHERE id = $2 AND status = 'paused' RETURNING *`,
      [getNextMonday(), req.params.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Paused policy not found' });
    }
    res.json({ message: 'Policy resumed — coverage active from next Monday', policy: result.rows[0] });
  } catch (err) {
    console.error('Resume policy error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.put('/:id/renew', async (req, res) => {
  try {
    const pResult = await query('SELECT * FROM policies WHERE id = $1', [req.params.id]);
    if (pResult.rows.length === 0) return res.status(404).json({ error: 'Policy not found' });
    const policy = pResult.rows[0];

    let newPremium = parseFloat(policy.weekly_premium);
    let premiumBreakdown = null;

    const mlResult = await calculatePremiumAuto(policy.worker_id);

    if (mlResult) {
      newPremium = mlResult.premium_amount_inr;
      premiumBreakdown = mlResult.breakdown;
    }

    const newPremiumsPaid = parseFloat(policy.total_premiums_paid) + newPremium;
    const newWeeks = policy.weeks_active + 1;

    const result = await query(
      `UPDATE policies SET weekly_premium = $1, total_premiums_paid = $2, weeks_active = $3, next_debit_date = $4 WHERE id = $5 RETURNING *`,
      [newPremium, newPremiumsPaid, newWeeks, getNextMonday(), policy.id]
    );

    await query(
      `INSERT INTO premium_history (worker_id, policy_id, amount, debit_date, status)
       VALUES ($1, $2, $3, CURRENT_DATE, 'success')`,
      [policy.worker_id, policy.id, newPremium]
    );

    res.json({
      message: 'Policy renewed for one week',
      policy: result.rows[0],
      premiumRecalculated: !!premiumBreakdown,
      premiumCalculation: premiumBreakdown ? {
        model: mlResult.model_version,
        breakdown: premiumBreakdown,
      } : null,
    });
  } catch (err) {
    console.error('Renew policy error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:workerId/premium-history', async (req, res) => {
  try {
    const result = await query(
      'SELECT * FROM premium_history WHERE worker_id = $1 ORDER BY debit_date DESC LIMIT 20',
      [req.params.workerId]
    );
    res.json({ workerId: req.params.workerId, history: result.rows, count: result.rows.length });
  } catch (err) {
    console.error('Premium history error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
