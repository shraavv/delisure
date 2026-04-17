const express = require('express');
const router = express.Router();
const { query } = require('../db');
const rzp = require('../services/razorpay-mock');
const log = require('../utils/logger');

// ── Status / config ──────────────────────────────────────
router.get('/status', (req, res) => {
  res.json({
    provider: 'Razorpay (test mode)',
    keyId: rzp.KEY_ID,
    mode: 'test',
    supports: ['UPI', 'orders', 'payouts', 'webhooks'],
    docs: 'https://razorpay.com/docs (mock — not real API)',
  });
});

// ── Create order ─────────────────────────────────────────
router.post('/orders', (req, res) => {
  const { amountInr, receipt, notes } = req.body;
  if (!amountInr || amountInr <= 0) {
    return res.status(400).json({ error: 'amountInr required' });
  }
  const order = rzp.createOrder({ amountInr, receipt, notes });
  log.info('Razorpay', `Order ${order.id} created — ₹${amountInr}`);
  res.status(201).json(order);
});

router.get('/orders/:id', (req, res) => {
  const o = rzp.getOrder(req.params.id);
  if (!o) return res.status(404).json({ error: 'Order not found' });
  res.json(o);
});

// ── Process UPI payout for a claim ───────────────────────
router.post('/process-payout', async (req, res) => {
  try {
    const { payoutId } = req.body;
    if (!payoutId) return res.status(400).json({ error: 'payoutId required' });

    const dbPayout = await query(
      `SELECT p.*, w.upi_id AS worker_upi, w.name AS worker_name
       FROM payouts p JOIN workers w ON w.id = p.worker_id
       WHERE p.id = $1`, [payoutId]
    );
    if (dbPayout.rows.length === 0) {
      return res.status(404).json({ error: 'Payout not found' });
    }
    const p = dbPayout.rows[0];
    if (!p.worker_upi) {
      return res.status(422).json({ error: 'Worker has no UPI ID on file' });
    }
    if (p.status !== 'credited') {
      return res.status(409).json({ error: `Payout already ${p.status}` });
    }

    // 1. Create order
    const order = rzp.createOrder({
      amountInr: p.amount,
      receipt: `claim_${p.id}`,
      notes: {
        worker_id: p.worker_id,
        trigger_type: p.trigger_type,
        zone: p.zone,
        claim_id: p.id,
      },
    });

    // 2. Queue UPI payout
    const { payout, payment } = rzp.createUpiPayout({
      orderId: order.id,
      upiId: p.worker_upi,
      amountInr: p.amount,
      workerId: p.worker_id,
      purpose: 'claim_payout',
    });

    // 3. Simulate async settlement (in production: wait for webhook)
    const { payout: settled, webhook } = rzp.settlePayout(payout.id);

    // 4. Update DB payout with real UTR from NPCI
    await query(
      `UPDATE payouts SET upi_transaction_id = $2 WHERE id = $1`,
      [p.id, settled.utr]
    );

    log.ok('Razorpay', `Payout ${payout.id} SETTLED — UTR ${settled.utr} → ${p.worker_upi}`);

    res.json({
      order,
      payment,
      payout: settled,
      webhook: {
        event: 'payout.processed',
        signature: webhook.signature,
        verify_url: '/api/payments/webhook',
      },
      utr: settled.utr,
    });
  } catch (err) {
    log.error('Razorpay', `Payout processing failed: ${err.message}`);
    res.status(500).json({ error: err.message });
  }
});

// ── Webhook receiver (inbound from Razorpay in real life) ─
router.post('/webhook', (req, res) => {
  const signature = req.headers['x-razorpay-signature'];
  const body = req.body;

  const expected = rzp.signWebhook(body);
  if (signature !== expected) {
    log.warn('Razorpay', 'Webhook signature verification FAILED');
    return res.status(400).json({ error: 'Invalid signature' });
  }

  log.ok('Razorpay', `Webhook received: ${body.event}`);
  res.json({ received: true, event: body.event });
});

// ── Verify payment signature (client calls this post-checkout) ─
router.post('/verify', (req, res) => {
  const { orderId, paymentId, signature } = req.body;
  if (!orderId || !paymentId || !signature) {
    return res.status(400).json({ error: 'orderId, paymentId, signature required' });
  }
  const valid = rzp.verifyPaymentSignature({ orderId, paymentId, signature });
  res.json({ valid });
});

// ── Lookup ───────────────────────────────────────────────
router.get('/payout/:id', (req, res) => {
  const p = rzp.getPayout(req.params.id);
  if (!p) return res.status(404).json({ error: 'Payout not found' });
  res.json(p);
});

module.exports = router;
