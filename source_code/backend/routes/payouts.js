const express = require('express');
const router = express.Router();
const PDFDocument = require('pdfkit');
const { query } = require('../db');
const { generateInvoice } = require('../utils/upi');

router.get('/stats/summary', async (req, res) => {
  try {
    const totalResult = await query("SELECT COALESCE(SUM(amount), 0) as total, COUNT(*) as count FROM payouts WHERE status = 'credited'");
    const pendingResult = await query("SELECT COALESCE(SUM(amount), 0) as total, COUNT(*) as count FROM payouts WHERE status = 'processing'");
    const byTypeResult = await query(
      "SELECT trigger_type, COUNT(*) as count, COALESCE(SUM(amount), 0) as total FROM payouts GROUP BY trigger_type"
    );

    res.json({
      credited: { total: parseFloat(totalResult.rows[0].total), count: parseInt(totalResult.rows[0].count) },
      processing: { total: parseFloat(pendingResult.rows[0].total), count: parseInt(pendingResult.rows[0].count) },
      byTriggerType: byTypeResult.rows,
    });
  } catch (err) {
    console.error('Payout stats error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:workerId', async (req, res) => {
  try {
    const result = await query(
      'SELECT * FROM payouts WHERE worker_id = $1 ORDER BY created_at DESC',
      [req.params.workerId]
    );
    const total = result.rows.reduce((sum, p) => sum + parseFloat(p.amount), 0);

    res.json({
      workerId: req.params.workerId,
      totalPaidOut: total,
      count: result.rows.length,
      payouts: result.rows,
    });
  } catch (err) {
    console.error('Get payouts error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:workerId/breakdown/:payoutId', async (req, res) => {
  try {
    const payoutResult = await query(
      'SELECT * FROM payouts WHERE id = $1 AND worker_id = $2',
      [req.params.payoutId, req.params.workerId]
    );
    if (payoutResult.rows.length === 0) return res.status(404).json({ error: 'Payout not found' });
    const payout = payoutResult.rows[0];

    const triggerResult = await query(
      'SELECT * FROM trigger_events WHERE id = $1',
      [payout.trigger_event_id]
    );

    const fraudResult = await query(
      'SELECT * FROM fraud_checks WHERE payout_id = $1',
      [payout.id]
    );

    res.json({
      payout,
      trigger: triggerResult.rows[0] || null,
      fraudCheck: fraudResult.rows[0] || null,
      explanation: payout.breakdown,
    });
  } catch (err) {
    console.error('Payout breakdown error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:payoutId/invoice', async (req, res) => {
  try {
    const payoutResult = await query(
      `SELECT p.*, w.name as worker_name, w.upi_id as worker_upi, te.id as trigger_id
       FROM payouts p
       JOIN workers w ON w.id = p.worker_id
       LEFT JOIN trigger_events te ON te.id = p.trigger_event_id
       WHERE p.id = $1`,
      [req.params.payoutId]
    );
    if (payoutResult.rows.length === 0) return res.status(404).json({ error: 'Payout not found' });
    const p = payoutResult.rows[0];
    if (p.status !== 'credited') {
      return res.status(400).json({ error: `No invoice for ${p.status} payout — only credited payouts have invoices` });
    }

    const invoice = generateInvoice({
      workerId: p.worker_id,
      workerName: p.worker_name,
      upi: p.worker_upi,
      amount: parseFloat(p.amount),
      triggerType: p.trigger_type,
      triggerZone: p.zone,
      timeWindow: p.time_window,
      breakdown: p.breakdown,
      payoutId: p.id,
      triggerId: p.trigger_id,
      upiTxnId: p.upi_transaction_id,
    });

    res.json(invoice);
  } catch (err) {
    console.error('Invoice error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:payoutId/invoice/pdf', async (req, res) => {
  try {
    const payoutResult = await query(
      `SELECT p.*, w.name as worker_name, w.upi_id as worker_upi, w.partner_id
       FROM payouts p
       JOIN workers w ON w.id = p.worker_id
       WHERE p.id = $1`,
      [req.params.payoutId]
    );
    if (payoutResult.rows.length === 0) return res.status(404).json({ error: 'Payout not found' });
    const p = payoutResult.rows[0];
    if (p.status !== 'credited') {
      return res.status(400).json({ error: 'Invoice only available for credited payouts' });
    }

    const doc = new PDFDocument({
      size: 'A4',
      margins: { top: 120, bottom: 70, left: 48, right: 48 },
      bufferPages: true,
    });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="delisure-invoice-${p.id}.pdf"`);
    doc.pipe(res);

    const C = {
      brand:     '#0F0F14',   // near-black (matches app bgLight)
      brandSoft: '#18181B',
      accent:    '#D4A843',   // gold (app primaryBlue)
      accentDark:'#B8912F',
      text:      '#09090B',
      muted:     '#71717A',
      mutedSec:  '#A1A1AA',
      light:     '#FAFAF9',
      softGold:  '#FEF7E0',
      goldBorder:'#FBBF24',
      border:    '#E4E4E7',
      green:     '#22C55E',   // matches app successGreen
      greenDark: '#15803D',
      greenLight:'#DCFCE7',
    };
    const W = doc.page.width, H = doc.page.height;
    const L = 48, R = W - 48;

    // ── Header ─────────────────────────────────────────
    doc.rect(0, 0, W, 82).fillColor(C.brand).fill();
    doc.rect(0, 82, W, 4).fillColor(C.accent).fill();

    doc.circle(L + 18, 40, 18).fillColor(C.accent).fill();
    doc.fillColor(C.brand).font('Helvetica-Bold').fontSize(20).text('D', L + 11, 28);

    doc.fillColor(C.accent).font('Helvetica-Bold').fontSize(22).text('Delisure', L + 46, 20);
    doc.fillColor(C.mutedSec).font('Helvetica').fontSize(8.5)
       .text('Parametric Income Insurance · Chennai, Tamil Nadu', L + 46, 46)
       .text('IRDAI Reg #IRDAI-REG-DMO-2026-0142 · GSTIN 33AAACD1234F1Z5', L + 46, 58);

    doc.fillColor(C.accent).font('Helvetica-Bold').fontSize(13)
       .text('PAYOUT INVOICE', R - 180, 24, { width: 180, align: 'right' });
    doc.fillColor(C.mutedSec).font('Helvetica').fontSize(9)
       .text(`#${p.id.toUpperCase()}`, R - 180, 46, { width: 180, align: 'right' })
       .text(new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }) + ' IST',
             R - 180, 60, { width: 180, align: 'right' });

    // ── Section title helper ──────────────────────────
    const sectionTitle = (num, title, y) => {
      doc.rect(L, y, 4, 20).fillColor(C.accent).fill();
      doc.fillColor(C.brand).font('Helvetica-Bold').fontSize(12)
         .text(title.toUpperCase(), L + 14, y + 2);
      doc.fillColor(C.muted).font('Helvetica').fontSize(8.5)
         .text(`Section ${num}`, L + 14, y + 18);
      return y + 32;
    };

    const kvRow = (label, value, y, opts = {}) => {
      doc.fillColor(C.muted).font('Helvetica').fontSize(9).text(label, L + 12, y);
      doc.fillColor(opts.valueColor || C.text).font(opts.bold ? 'Helvetica-Bold' : 'Helvetica').fontSize(10)
         .text(value, L + 130, y, { width: R - L - 140, align: 'left' });
      return y + 16;
    };

    let y = 110;

    // ── Section 1: Parties ────────────────────────────
    y = sectionTitle('1', 'Parties', y);

    // Two-column: Insurer | Beneficiary
    const colW = (R - L - 12) / 2;

    doc.roundedRect(L, y, colW, 100, 4).fillColor(C.softGold).fill();
    doc.rect(L, y, 3, 100).fillColor(C.accent).fill();
    doc.fillColor(C.accentDark).font('Helvetica-Bold').fontSize(8).text('INSURER', L + 12, y + 10);
    doc.fillColor(C.text).font('Helvetica-Bold').fontSize(11)
       .text('Delisure Parametric Insurance Pvt Ltd', L + 12, y + 24, { width: colW - 20 });
    doc.fillColor(C.muted).font('Helvetica').fontSize(8.5)
       .text('Chennai, Tamil Nadu, India', L + 12, y + 44)
       .text('GSTIN: 33AAACD1234F1Z5', L + 12, y + 58)
       .text('Reg: IRDAI-REG-DMO-2026-0142', L + 12, y + 72)
       .text('support@delisure.in', L + 12, y + 86);

    const RC = L + colW + 12;
    doc.roundedRect(RC, y, colW, 100, 4).fillColor(C.light).fill();
    doc.rect(RC, y, 3, 100).fillColor(C.brand).fill();
    doc.fillColor(C.muted).font('Helvetica-Bold').fontSize(8).text('BENEFICIARY', RC + 12, y + 10);
    doc.fillColor(C.text).font('Helvetica-Bold').fontSize(11)
       .text(p.worker_name, RC + 12, y + 24, { width: colW - 20 });
    doc.fillColor(C.muted).font('Helvetica').fontSize(8.5)
       .text(`Worker ID: ${p.worker_id}`, RC + 12, y + 44)
       .text(`Partner ID: ${p.partner_id || '—'}`, RC + 12, y + 58)
       .text(`UPI: ${p.worker_upi || '—'}`, RC + 12, y + 72)
       .text('Platform: Swiggy', RC + 12, y + 86);

    y += 120;

    // ── Section 2: Claim trigger ──────────────────────
    y = sectionTitle('2', 'Parametric Trigger Event', y);

    doc.roundedRect(L, y, R - L, 90, 4).fillColor(C.softGold).fill();
    doc.roundedRect(L, y, R - L, 90, 4).strokeColor(C.goldBorder).lineWidth(0.5).stroke();
    doc.rect(L, y, 4, 90).fillColor(C.accent).fill();
    doc.fillColor(C.accentDark).font('Helvetica-Bold').fontSize(8)
       .text('PARAMETRIC EVENT', L + 16, y + 12);
    doc.fillColor(C.text).font('Helvetica-Bold').fontSize(15)
       .text((p.trigger_type || '').toUpperCase(), L + 16, y + 24);
    doc.fillColor(C.muted).font('Helvetica').fontSize(9)
       .text(`Affected zone: ${p.zone || '—'}`, L + 16, y + 48)
       .text(`Time window: ${p.time_window || '—'}`, L + 16, y + 62)
       .text(`Payout rate applied: ${p.payout_rate || '—'}`, L + 16, y + 76);

    y += 104;

    // ── Section 3: Calculation breakdown ─────────────
    y = sectionTitle('3', 'Payout Calculation', y);

    doc.fillColor(C.text).font('Helvetica').fontSize(9.5)
       .text(p.breakdown || '—', L + 12, y, { width: R - L - 24, align: 'justify', lineGap: 3 });
    y += doc.heightOfString(p.breakdown || '—', { width: R - L - 24, lineGap: 3 }) + 20;

    // ── Section 4: Amount + Transaction ──────────────
    y = sectionTitle('4', 'Payment Record', y);

    doc.roundedRect(L, y, R - L, 100, 6).fillColor(C.brand).fill();
    doc.roundedRect(L, y, 6, 100, 3).fillColor(C.accent).fill();

    doc.fillColor(C.mutedSec).font('Helvetica').fontSize(9)
       .text('TOTAL AMOUNT CREDITED', L + 20, y + 16);
    doc.fillColor(C.accent).font('Helvetica-Bold').fontSize(32)
       .text(`INR ${parseFloat(p.amount).toFixed(2)}`, L + 20, y + 32);

    // Credited status pill in the amount box
    doc.roundedRect(L + 20, y + 72, 88, 18, 9).fillColor(C.green).fill();
    doc.fillColor('#FFFFFF').font('Helvetica-Bold').fontSize(9)
       .text('✓ CREDITED', L + 20, y + 77, { width: 88, align: 'center' });

    doc.fillColor(C.mutedSec).font('Helvetica').fontSize(8.5)
       .text('UPI Transaction ID', R - 220, y + 16, { width: 200, align: 'right' });
    doc.fillColor(C.accent).font('Courier-Bold').fontSize(11)
       .text(p.upi_transaction_id || '—', R - 220, y + 30, { width: 200, align: 'right' });
    doc.fillColor(C.mutedSec).font('Helvetica').fontSize(8.5)
       .text(`Method: UPI via Razorpay (test mode)`, R - 220, y + 56, { width: 200, align: 'right' })
       .text(`Settled: ${new Date().toLocaleDateString('en-IN')}`, R - 220, y + 70, { width: 200, align: 'right' });

    y += 118;

    // ── Section 5: Razorpay gateway trail ─────────────
    if (p.razorpay_order_id) {
      y = sectionTitle('5', 'Payment Gateway Trail (Razorpay)', y);
      y = kvRow('Razorpay Order ID',  p.razorpay_order_id, y);
      y = kvRow('Razorpay Payout ID', p.razorpay_payout_id || '—', y);
      y = kvRow('Gateway Status',     (p.razorpay_status || 'processed').toUpperCase(), y, { valueColor: C.green, bold: true });
      y = kvRow('Environment',        'Test mode — key rzp_test_delisure2026', y);
      y += 6;
    }

    // ── Section 6: Regulatory ─────────────────────────
    y = sectionTitle(p.razorpay_order_id ? '6' : '5', 'Regulatory & Tax', y);

    y = kvRow('Product type', 'Parametric Income Protection', y);
    y = kvRow('Regulator', 'IRDAI (Insurance Regulatory and Development Authority of India)', y);
    y = kvRow('Registration', 'IRDAI-REG-DMO-2026-0142', y);
    y = kvRow('Tax status', 'Exempt under Section 10(10D) — Parametric disaster relief', y);
    y = kvRow('Jurisdiction', 'India', y);

    // ── Footer ─────────────────────────────────────────
    const fy = H - 50;
    doc.moveTo(L, fy).lineTo(R, fy).strokeColor(C.border).lineWidth(0.5).stroke();
    doc.fillColor(C.muted).font('Helvetica').fontSize(8)
       .text('Delisure Parametric Insurance Pvt Ltd · www.delisure.in · support@delisure.in',
             L, fy + 8, { width: R - L, align: 'center' });
    doc.fillColor(C.muted).font('Helvetica-Oblique').fontSize(7)
       .text('System-generated invoice — no signature required. For dispute resolution, contact support within 30 days.',
             L, fy + 22, { width: R - L, align: 'center' });

    doc.end();
  } catch (err) {
    console.error('Invoice PDF error:', err);
    if (!res.headersSent) res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/:payoutId/appeal', async (req, res) => {
  try {
    const { payoutId } = req.params;
    const { workerId, reason } = req.body;
    if (!workerId || !reason || reason.trim().length < 10) {
      return res.status(400).json({ error: 'workerId and reason (min 10 chars) are required' });
    }

    const payout = await query(
      "SELECT * FROM payouts WHERE id = $1 AND worker_id = $2",
      [payoutId, workerId]
    );
    if (payout.rows.length === 0) {
      return res.status(404).json({ error: 'Payout not found for this worker' });
    }
    if (!['pending_review', 'failed'].includes(payout.rows[0].status)) {
      return res.status(400).json({
        error: 'Only held or rejected payouts can be appealed',
        currentStatus: payout.rows[0].status
      });
    }

    const existing = await query(
      "SELECT id FROM payout_appeals WHERE payout_id = $1 AND status = 'open'",
      [payoutId]
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Appeal already open for this payout', appealId: existing.rows[0].id });
    }

    const result = await query(
      `INSERT INTO payout_appeals (payout_id, worker_id, reason, status)
       VALUES ($1, $2, $3, 'open') RETURNING *`,
      [payoutId, workerId, reason.trim()]
    );

    console.log(`[Appeal] Worker ${workerId} appealed payout ${payoutId} — "${reason.slice(0, 60)}..."`);
    res.status(201).json({ message: 'Appeal submitted for admin review', appeal: result.rows[0] });
  } catch (err) {
    console.error('Appeal submit error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:workerId/appeals/list', async (req, res) => {
  try {
    const result = await query(
      `SELECT a.*, p.amount, p.trigger_type, p.zone
       FROM payout_appeals a
       LEFT JOIN payouts p ON p.id = a.payout_id
       WHERE a.worker_id = $1
       ORDER BY a.created_at DESC`,
      [req.params.workerId]
    );
    res.json({ appeals: result.rows, count: result.rows.length });
  } catch (err) {
    console.error('Worker appeals list error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
