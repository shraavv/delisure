const crypto = require('crypto');

const KEY_ID     = process.env.RAZORPAY_KEY_ID     || 'rzp_test_delisure2026';
const KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || 'rzp_secret_delisure_demo_9f3a4c2b';
const WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET || 'whsec_delisure_demo_2026';

const orders   = new Map();
const payments = new Map();
const payouts  = new Map();

function genId(prefix) {
  return prefix + '_' + crypto.randomBytes(8).toString('hex');
}

// ── Razorpay-style signature helpers ─────────────────────
function signPayload(orderId, paymentId) {
  return crypto.createHmac('sha256', KEY_SECRET)
    .update(`${orderId}|${paymentId}`)
    .digest('hex');
}

function signWebhook(body) {
  return crypto.createHmac('sha256', WEBHOOK_SECRET)
    .update(typeof body === 'string' ? body : JSON.stringify(body))
    .digest('hex');
}

function verifyPaymentSignature({ orderId, paymentId, signature }) {
  const expected = signPayload(orderId, paymentId);
  return crypto.timingSafeEqual(
    Buffer.from(expected, 'hex'),
    Buffer.from(signature || '', 'hex')
  );
}

// ── Order creation (mirrors POST /v1/orders) ────────────
function createOrder({ amountInr, receipt, notes = {} }) {
  const orderId = genId('order');
  const amount = Math.round(parseFloat(amountInr) * 100); // paise
  const order = {
    id: orderId,
    entity: 'order',
    amount,
    amount_paid: 0,
    amount_due: amount,
    currency: 'INR',
    receipt: receipt || null,
    status: 'created',
    notes,
    created_at: Math.floor(Date.now() / 1000),
  };
  orders.set(orderId, order);
  return order;
}

// ── UPI payout (mirrors POST /v1/payouts for RazorpayX) ─
function createUpiPayout({ orderId, upiId, amountInr, workerId, purpose = 'claim_payout' }) {
  const order = orders.get(orderId);
  if (!order) throw new Error('Order not found');

  const payoutId = genId('pout');
  const paymentId = genId('pay');
  const amount = Math.round(parseFloat(amountInr) * 100);

  // Simulate Razorpay state transitions:
  // queued -> processing -> processed (success) | reversed (failure)
  const payout = {
    id: payoutId,
    entity: 'payout',
    fund_account_id: genId('fa'),
    amount,
    currency: 'INR',
    notes: { worker_id: workerId, order_id: orderId, purpose },
    fees: 0,
    tax: 0,
    status: 'queued',
    utr: null,
    mode: 'UPI',
    purpose,
    reference_id: receiptRef(workerId),
    narration: `Delisure parametric claim payout`,
    batch_id: null,
    status_details: { description: 'Payout queued for processing', source: 'delisure' },
    created_at: Math.floor(Date.now() / 1000),
    payment_id: paymentId,
    upi_id: upiId,
  };
  payouts.set(payoutId, payout);

  // Payment record
  const payment = {
    id: paymentId,
    entity: 'payment',
    amount,
    currency: 'INR',
    status: 'captured',
    order_id: orderId,
    method: 'upi',
    vpa: upiId,
    captured: true,
    created_at: Math.floor(Date.now() / 1000),
  };
  payments.set(paymentId, payment);

  // Order state update
  order.amount_paid = amount;
  order.amount_due = 0;
  order.status = 'paid';

  return { payout, payment, order };
}

function receiptRef(workerId) {
  const ts = Date.now().toString(36).toUpperCase();
  return `DLSR-${workerId}-${ts}`.slice(0, 30);
}

// ── Simulate async settlement (in real life: webhook) ───
function settlePayout(payoutId) {
  const payout = payouts.get(payoutId);
  if (!payout) return null;

  // Generate UTR (Unique Transaction Reference) — matches UPI standard
  const utr = 'UPI' + Date.now() + Math.random().toString(36).slice(2, 8).toUpperCase();

  payout.status = 'processed';
  payout.utr = utr;
  payout.status_details = { description: 'Payout processed successfully', source: 'npci' };
  payout.processed_at = Math.floor(Date.now() / 1000);

  // Webhook body
  const webhookBody = {
    entity: 'event',
    account_id: 'acc_delisure_test',
    event: 'payout.processed',
    contains: ['payout'],
    payload: { payout: { entity: payout } },
    created_at: Math.floor(Date.now() / 1000),
  };

  return {
    payout,
    webhook: {
      body: webhookBody,
      signature: signWebhook(webhookBody),
      headers: {
        'X-Razorpay-Event-Id': genId('evt'),
        'X-Razorpay-Signature': signWebhook(webhookBody),
      },
    },
  };
}

function getOrder(id)   { return orders.get(id)   || null; }
function getPayment(id) { return payments.get(id) || null; }
function getPayout(id)  { return payouts.get(id)  || null; }

module.exports = {
  KEY_ID,
  createOrder,
  createUpiPayout,
  settlePayout,
  signPayload,
  signWebhook,
  verifyPaymentSignature,
  getOrder,
  getPayment,
  getPayout,
};
