const KNOWN_HANDLES = new Set([
  'okicici', 'okhdfcbank', 'oksbi', 'okaxis',
  'ybl', 'ibl', 'axl',
  'paytm',
  'upi',
  'fbl',
  'kotak', 'kotak811',
  'apl',
  'hdfcbank', 'icici', 'sbi', 'axisbank',
  'federal',
  'rbl',
  'yesbank',
  'idfc', 'idfcbank',
  'indus',
  'dbs',
]);

const UPI_REGEX = /^[a-zA-Z0-9.\-_]{2,}@[a-zA-Z]{2,}$/;

function validateUpi(upi) {
  if (!upi || typeof upi !== 'string') {
    return { valid: false, error: 'UPI ID is required' };
  }
  const trimmed = upi.trim().toLowerCase();
  if (!UPI_REGEX.test(trimmed)) {
    return {
      valid: false,
      error: 'Invalid UPI format — expected e.g. yourname@okicici',
    };
  }
  const [id, handle] = trimmed.split('@');
  if (id.length < 2 || id.length > 256) {
    return { valid: false, error: 'UPI handle must be 2-256 characters' };
  }
  const known = KNOWN_HANDLES.has(handle);
  return {
    valid: true,
    upi: trimmed,
    handle,
    known,
    provider: handle,
    note: known ? `Verified handle @${handle}` : `Unknown handle @${handle} — may not clear`,
  };
}

function generateTransactionId() {
  const ts = Date.now().toString(36).toUpperCase();
  const rand = Math.random().toString(36).slice(2, 8).toUpperCase();
  return `UPI${ts}${rand}`;
}

function generateInvoice({ workerId, workerName, upi, amount, triggerType, triggerZone, timeWindow, breakdown, payoutId, triggerId, upiTxnId }) {
  const now = new Date();
  return {
    invoiceId: `INV-${now.getTime().toString(36).toUpperCase()}`,
    issuedAt: now.toISOString(),
    payer: {
      name: 'Delisure Parametric Insurance Pvt Ltd',
      gstin: '33AAACD1234F1Z5',
      address: 'Chennai, Tamil Nadu, India',
    },
    payee: {
      workerId,
      name: workerName,
      upi,
    },
    transaction: {
      upiTransactionId: upiTxnId,
      payoutId,
      triggerId,
      amountINR: amount,
      method: 'UPI instant credit',
      status: 'credited',
      settlementTime: now.toISOString(),
    },
    claim: {
      type: triggerType,
      zone: triggerZone,
      timeWindow,
      breakdown,
    },
    regulatory: {
      productType: 'Parametric Income Protection',
      regulator: 'IRDAI',
      irdaiRegNo: 'IRDAI-REG-DMO-2026-0142',
      taxExempt: true,
      exemptionClause: 'Section 10(10D) — Parametric disaster relief',
    },
  };
}

module.exports = { validateUpi, generateTransactionId, generateInvoice };
