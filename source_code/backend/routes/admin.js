const express = require('express');
const router = express.Router();
const PDFDocument = require('pdfkit');
const { query } = require('../db');
const { getMLMetrics } = require('../services/ml-client');
const rzp = require('../services/razorpay-mock');
const {
  generateAdminToken,
  verifyAdminToken,
  revokeAdminToken,
  verifyAdminCredentials,
  requireAdmin,
  ADMIN_USERNAME,
} = require('../middleware/auth');

router.post('/login', (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) {
    return res.status(400).json({ error: 'username and password are required' });
  }
  if (!verifyAdminCredentials(username, password)) {
    console.log(`[Admin] Failed login attempt for username: ${username}`);
    return res.status(401).json({ error: 'Invalid admin credentials' });
  }
  const token = generateAdminToken(username);
  console.log(`[Admin] Login successful for ${username}`);
  res.json({
    message: 'Admin login successful',
    adminToken: token,
    username,
    role: 'admin',
  });
});

router.post('/logout', (req, res) => {
  const token = req.headers['x-admin-token'];
  if (token) revokeAdminToken(token);
  res.json({ message: 'Logged out' });
});

router.get('/verify', (req, res) => {
  const token = req.headers['x-admin-token'];
  if (!token || !verifyAdminToken(token)) {
    return res.status(403).json({ valid: false, error: 'Invalid or expired admin token' });
  }
  res.json({ valid: true, username: ADMIN_USERNAME, role: 'admin' });
});

router.use(requireAdmin);

router.get('/audit-report', async (req, res) => {
  try {
    const result = await query(`
      SELECT fc.*, w.name as worker_name, w.partner_id,
             p.amount, p.trigger_type, p.zone, p.status as payout_status, p.upi_transaction_id,
             te.start_time, te.intensity, te.unit
      FROM fraud_checks fc
      JOIN workers w ON w.id = fc.worker_id
      LEFT JOIN payouts p ON p.id = fc.payout_id
      LEFT JOIN trigger_events te ON te.id = fc.trigger_event_id
      ORDER BY fc.checked_at DESC
      LIMIT 100
    `);

    const stats = await query(`
      SELECT
        COUNT(*) as total_checks,
        COUNT(*) FILTER (WHERE recommendation = 'approve') as approved,
        COUNT(*) FILTER (WHERE recommendation = 'review') as reviewed,
        COUNT(*) FILTER (WHERE recommendation = 'block') as blocked
      FROM fraud_checks
    `);
    const s = stats.rows[0];

    const doc = new PDFDocument({
      size: 'A4',
      margins: { top: 120, bottom: 70, left: 48, right: 48 },
      bufferPages: true,
    });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="delisure-compliance-audit-${Date.now()}.pdf"`);
    doc.pipe(res);

    // ── Theme palette (matches app dark-luxe theme) ─────
    const C = {
      brand:     '#0F0F14',  // near-black (app bgLight)
      brandSoft: '#18181B',  // softer dark (app bgSecondary)
      accent:    '#D4A843',  // gold (app primaryBlue)
      accentDark:'#B8912F',  // darker gold
      text:      '#09090B',
      muted:     '#71717A',
      mutedSec:  '#A1A1AA',
      light:     '#FAFAF9',  // warm off-white
      softGold:  '#FEF7E0',  // soft amber tint
      border:    '#E4E4E7',
      approve:   '#22C55E',  // app successGreen
      review:    '#F59E0B',  // app warningOrange
      block:     '#EF4444',  // app alertRed
    };
    const W = doc.page.width;
    const H = doc.page.height;
    const L = 48, R = W - 48;

    // ── Header (every page) ────────────────────────────
    const drawHeader = (pageTitle) => {
      doc.rect(0, 0, W, 72).fillColor(C.brand).fill();
      doc.rect(0, 72, W, 4).fillColor(C.accent).fill();

      // Gold logo mark with shield
      doc.circle(L + 16, 36, 16).fillColor(C.accent).fill();
      doc.fillColor(C.brand).font('Helvetica-Bold').fontSize(18).text('D', L + 10, 27);

      doc.fillColor(C.accent).font('Helvetica-Bold').fontSize(19).text('Delisure', L + 42, 20);
      doc.fillColor(C.mutedSec).font('Helvetica').fontSize(9)
         .text('Parametric Income Insurance · Chennai · IRDAI Reg #IRDAI-REG-DMO-2026-0142', L + 42, 44);

      doc.fillColor(C.accent).font('Helvetica-Bold').fontSize(10)
         .text(pageTitle, R - 200, 26, { width: 200, align: 'right' });
      doc.fillColor(C.mutedSec).font('Helvetica').fontSize(8)
         .text(new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }) + ' IST',
               R - 200, 46, { width: 200, align: 'right' });
    };

    // ── Footer (every page) ────────────────────────────
    const drawFooter = (pageNum, totalPages) => {
      const fy = H - 50;
      doc.moveTo(L, fy).lineTo(R, fy).strokeColor(C.border).lineWidth(0.5).stroke();
      doc.fillColor(C.muted).font('Helvetica').fontSize(8)
         .text('Delisure Parametric Insurance Pvt Ltd · GSTIN 33AAACD1234F1Z5 · support@delisure.in',
               L, fy + 8, { width: R - L, align: 'left' })
         .text(`Page ${pageNum} of ${totalPages}`,
               L, fy + 8, { width: R - L, align: 'right' });
      doc.fillColor(C.muted).fontSize(7)
         .text('Confidential · Automated compliance audit — generated under IRDAI (Automated Decision Disclosure) Guidelines 2024',
               L, fy + 22, { width: R - L, align: 'center' });
    };

    // ── Section title helper ──────────────────────────
    const drawSectionTitle = (num, title, y) => {
      doc.rect(L, y, 4, 20).fillColor(C.accent).fill();
      doc.fillColor(C.brand).font('Helvetica-Bold').fontSize(13)
         .text(title.toUpperCase(), L + 14, y + 2);
      doc.fillColor(C.muted).font('Helvetica').fontSize(9)
         .text(`Section ${num}`, L + 14, y + 18);
      return y + 32;
    };

    drawHeader('Compliance Audit Report');

    let y = 90;

    // ── Section 1: Summary ─────────────────────────────
    y = drawSectionTitle('1', 'Executive Summary', y);

    doc.rect(L, y, R - L, 74).fillColor(C.brand).fill();
    doc.rect(L, y, R - L, 74).fillOpacity(0.03).fillColor(C.accent).fill().fillOpacity(1);
    doc.rect(L, y, R - L, 74).fillColor(C.softGold).fill();
    doc.rect(L, y, 4, 74).fillColor(C.accent).fill();

    doc.fillColor(C.text).font('Helvetica').fontSize(9);
    const summaryCols = [
      { label: 'Total decisions',  value: s.total_checks,  color: C.brand },
      { label: 'Auto-approved',    value: s.approved,      color: C.approve },
      { label: 'Held for review',  value: s.reviewed,      color: C.review },
      { label: 'Auto-blocked',     value: s.blocked,       color: C.block },
    ];
    const colW = (R - L - 24) / 4;
    summaryCols.forEach((col, i) => {
      const cx = L + 16 + i * colW;
      doc.fillColor(C.muted).font('Helvetica').fontSize(9).text(col.label, cx, y + 14);
      doc.fillColor(col.color).font('Helvetica-Bold').fontSize(22).text(String(col.value), cx, y + 28);
    });

    y += 90;

    doc.fillColor(C.text).font('Helvetica').fontSize(9.5)
       .text('This report enumerates every AI-assisted claim decision taken by Delisure\'s parametric insurance engine. Each entry includes the fraud risk score, the model\'s recommendation, and SHAP feature-contribution signals that explain how the decision was reached — as required by IRDAI Automated Decision Disclosure guidelines.',
             L, y, { width: R - L, align: 'justify', lineGap: 2 });
    y += 48;

    // ── Section 2: Audit log ──────────────────────────
    y = drawSectionTitle('2', 'Claim-by-Claim Audit Log', y);

    if (result.rows.length === 0) {
      doc.fillColor(C.muted).font('Helvetica-Oblique').fontSize(10)
         .text('No fraud-check records available. Run at least one trigger simulation to populate the audit log.',
               L, y, { width: R - L });
    }

    for (let idx = 0; idx < result.rows.length; idx++) {
      const row = result.rows[idx];

      // Page-break check — reserve ~130px per claim
      if (y > H - 180) {
        drawFooter(doc._pageBuffer?.length ?? 1, 1); // placeholder, we finalize at end
        doc.addPage();
        drawHeader('Compliance Audit Report (cont.)');
        y = 90;
        y = drawSectionTitle('2', 'Claim-by-Claim Audit Log (cont.)', y);
      }

      const recColor = row.recommendation === 'block' ? C.block
                     : row.recommendation === 'review' ? C.review : C.approve;

      // Claim card
      const cardTop = y;
      doc.rect(L, y, R - L, 28).fillColor(C.brand).fill();
      doc.rect(L, y, 3, 28).fillColor(C.accent).fill();
      doc.fillColor(C.accent).font('Helvetica-Bold').fontSize(10)
         .text(`Claim #${idx + 1}`, L + 14, y + 6);
      doc.fillColor(C.mutedSec).font('Helvetica').fontSize(9)
         .text(`Payout ${row.payout_id || '—'}`, L + 14, y + 18);

      doc.roundedRect(R - 96, y + 8, 84, 14, 3).fillColor(recColor).fill();
      doc.fillColor('#FFFFFF').font('Helvetica-Bold').fontSize(8)
         .text((row.recommendation || 'APPROVE').toUpperCase(), R - 96, y + 11, { width: 84, align: 'center' });
      y += 28;

      // Body fields (two-column key-value)
      const fields = [
        ['Worker',      `${row.worker_name} (${row.worker_id})`],
        ['Partner ID',  row.partner_id || '—'],
        ['Trigger',     `${(row.trigger_type || '').toUpperCase()} · ${row.zone || '—'}`],
        ['Amount',      `INR ${Number(row.amount || 0).toFixed(2)}`],
        ['Risk Score',  `${(parseFloat(row.risk_score || 0) * 100).toFixed(1)} / 100`],
        ['UPI Txn ID',  row.upi_transaction_id || '—'],
        ['Payout Status', (row.payout_status || '—').toUpperCase()],
        ['Checked At',  new Date(row.checked_at).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' })],
      ];
      doc.rect(L, y, R - L, 8 + fields.length / 2 * 13).fillColor('#FAFAFA').fill();
      doc.fillColor(C.text).font('Helvetica').fontSize(9);
      for (let fi = 0; fi < fields.length; fi += 2) {
        const rowY = y + 6 + (fi / 2) * 13;
        doc.fillColor(C.muted).font('Helvetica').fontSize(8.5).text(fields[fi][0],     L + 12, rowY);
        doc.fillColor(C.text).font('Helvetica-Bold').fontSize(9)      .text(fields[fi][1], L + 80, rowY);
        if (fields[fi + 1]) {
          doc.fillColor(C.muted).font('Helvetica').fontSize(8.5).text(fields[fi + 1][0],     L + 280, rowY);
          doc.fillColor(C.text).font('Helvetica-Bold').fontSize(9)      .text(fields[fi + 1][1], L + 360, rowY, { width: 140, ellipsis: true });
        }
      }
      y += 8 + Math.ceil(fields.length / 2) * 13 + 4;

      // SHAP
      let signals = [];
      try {
        signals = typeof row.shap_signals === 'string' ? JSON.parse(row.shap_signals) : (row.shap_signals || []);
      } catch {}

      if (signals && signals.length > 0) {
        doc.fillColor(C.accentDark).font('Helvetica-Bold').fontSize(9)
           .text('SHAP FEATURE CONTRIBUTIONS', L + 8, y);
        y += 14;
        for (const sig of signals.slice(0, 5)) {
          const pct = Math.abs(parseFloat(sig.contribution || 0));
          const isFraud = sig.direction === 'toward_fraud';
          const clr = isFraud ? C.block : C.approve;
          const arrow = isFraud ? '▲' : '▼';

          doc.fillColor(C.text).font('Helvetica').fontSize(8.5)
             .text(sig.signal || '—', L + 16, y, { width: 200 });
          // bar
          const barX = L + 230, barW = 180;
          doc.rect(barX, y + 2, barW, 7).fillColor(C.light).fill();
          doc.rect(barX, y + 2, Math.min(barW * pct, barW), 7).fillColor(clr).fill();
          doc.fillColor(clr).font('Helvetica-Bold').fontSize(8)
             .text(`${arrow} ${(pct * 100).toFixed(0)}%`, barX + barW + 6, y, { width: 50 });
          y += 12;
        }
      }

      if (row.flags && row.flags.length > 0) {
        doc.fillColor(C.muted).font('Helvetica-Oblique').fontSize(8)
           .text(`Flags raised: ${row.flags.join(' · ')}`, L + 8, y + 2, { width: R - L - 16 });
        y += 12;
      }

      // Card border
      doc.moveTo(L, cardTop + 26).lineTo(L, y + 4).strokeColor(C.border).lineWidth(0.5).stroke();
      doc.moveTo(R, cardTop + 26).lineTo(R, y + 4).stroke();
      doc.moveTo(L, y + 4).lineTo(R, y + 4).stroke();

      y += 14;
    }

    // ── Finalize: page numbers ────────────────────────
    const range = doc.bufferedPageRange();
    for (let i = range.start; i < range.start + range.count; i++) {
      doc.switchToPage(i);
      drawFooter(i + 1, range.count);
    }

    doc.end();
    console.log(`[Admin] Audit PDF generated — ${result.rows.length} decisions exported`);
  } catch (err) {
    console.error('Audit report error:', err);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

router.get('/ml-metrics', async (req, res) => {
  const m = await getMLMetrics();
  if (!m) return res.status(503).json({ error: 'ML service unavailable' });
  res.json(m);
});

router.get('/analytics', async (req, res) => {
  try {
    const weeklyTrendResult = await query(`
      SELECT
        TO_CHAR(DATE_TRUNC('week', created_at), 'YYYY-MM-DD') as week,
        COALESCE(SUM(amount) FILTER (WHERE status = 'credited'), 0) as payouts_credited,
        COUNT(*) FILTER (WHERE status = 'credited') as claims_count,
        COUNT(*) FILTER (WHERE status = 'pending_review') as pending_count,
        COUNT(*) FILTER (WHERE status = 'failed') as blocked_count
      FROM payouts
      WHERE created_at >= CURRENT_DATE - INTERVAL '8 weeks'
      GROUP BY DATE_TRUNC('week', created_at)
      ORDER BY week ASC
    `);

    const premiumPoolResult = await query(
      "SELECT COALESCE(SUM(weekly_premium), 0) as weekly_pool FROM policies WHERE status = 'active'"
    );
    const weeklyPremiumPool = parseFloat(premiumPoolResult.rows[0].weekly_pool);

    const totalPayoutsResult = await query(
      "SELECT COALESCE(SUM(amount), 0) as total FROM payouts WHERE status = 'credited'"
    );
    const totalPremiumsResult = await query(
      "SELECT COALESCE(SUM(total_premiums_paid), 0) as total FROM policies"
    );
    const totalCredited = parseFloat(totalPayoutsResult.rows[0].total);
    const totalPremiums = parseFloat(totalPremiumsResult.rows[0].total);
    const lossRatio = totalPremiums > 0 ? (totalCredited / totalPremiums) : 0;

    const zoneRiskResult = await query(`
      SELECT te.zone, COUNT(*) as trigger_count,
             COALESCE(SUM(p.amount) FILTER (WHERE p.status = 'credited'), 0) as payouts
      FROM trigger_events te
      LEFT JOIN payouts p ON p.trigger_event_id = te.id
      WHERE te.start_time >= CURRENT_DATE - INTERVAL '30 days'
      GROUP BY te.zone
      ORDER BY trigger_count DESC
      LIMIT 10
    `);

    const typeBreakdownResult = await query(`
      SELECT trigger_type, COUNT(*) as count,
             COALESCE(SUM(amount), 0) as total_amount
      FROM payouts
      WHERE created_at >= CURRENT_DATE - INTERVAL '30 days' AND trigger_type IS NOT NULL
      GROUP BY trigger_type
      ORDER BY total_amount DESC
    `);

    const last4wResult = await query(`
      SELECT
        COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '7 days') as w1,
        COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '14 days' AND created_at < CURRENT_DATE - INTERVAL '7 days') as w2,
        COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '21 days' AND created_at < CURRENT_DATE - INTERVAL '14 days') as w3,
        COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '28 days' AND created_at < CURRENT_DATE - INTERVAL '21 days') as w4
      FROM payouts
    `);
    const w = last4wResult.rows[0];
    const counts = [parseInt(w.w4), parseInt(w.w3), parseInt(w.w2), parseInt(w.w1)];
    const avg = counts.reduce((a, b) => a + b, 0) / 4;
    const trend = counts[3] - counts[0];
    const predictedNextWeekClaims = Math.max(0, Math.round(avg + (trend * 0.3)));

    const fraudRateResult = await query(`
      SELECT
        COUNT(*) FILTER (WHERE is_flagged = TRUE) as flagged,
        COUNT(*) as total,
        AVG(risk_score) FILTER (WHERE risk_score IS NOT NULL) as avg_score
      FROM fraud_checks
      WHERE checked_at >= CURRENT_DATE - INTERVAL '30 days'
    `);
    const fr = fraudRateResult.rows[0];
    const fraudStats = {
      flaggedCount: parseInt(fr.flagged) || 0,
      totalChecks: parseInt(fr.total) || 0,
      flagRate: fr.total > 0 ? ((fr.flagged / fr.total) * 100).toFixed(1) : '0.0',
      avgRiskScore: fr.avg_score ? parseFloat(fr.avg_score).toFixed(3) : '0.000',
    };

    res.json({
      lossRatio: parseFloat(lossRatio.toFixed(3)),
      lossRatioPct: parseFloat((lossRatio * 100).toFixed(1)),
      totalCredited,
      totalPremiums,
      weeklyPremiumPool,
      weeklyTrend: weeklyTrendResult.rows.map(r => ({
        week: r.week,
        credited: parseFloat(r.payouts_credited),
        claims: parseInt(r.claims_count),
        pending: parseInt(r.pending_count),
        blocked: parseInt(r.blocked_count),
      })),
      zoneBreakdown: zoneRiskResult.rows.map(r => ({
        zone: r.zone,
        triggers: parseInt(r.trigger_count),
        payouts: parseFloat(r.payouts),
      })),
      triggerTypeBreakdown: typeBreakdownResult.rows.map(r => ({
        type: r.trigger_type,
        count: parseInt(r.count),
        total: parseFloat(r.total_amount),
      })),
      predictedNextWeekClaims,
      last4Weeks: counts,
      fraudStats,
    });
  } catch (err) {
    console.error('Analytics error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/stats', async (req, res) => {
  try {
    const workersResult = await query('SELECT COUNT(*) as total FROM workers');
    const policiesResult = await query("SELECT COUNT(*) as total FROM policies WHERE status = 'active'");
    const payoutsTodayResult = await query(
      "SELECT COALESCE(SUM(amount), 0) as total, COUNT(*) as count FROM payouts WHERE created_at >= CURRENT_DATE"
    );
    const activeTriggersResult = await query('SELECT COUNT(*) as total FROM trigger_events WHERE is_active = TRUE');
    const fraudResult = await query(
      "SELECT COUNT(*) FILTER (WHERE is_flagged = TRUE) as flagged, COUNT(*) as total FROM fraud_checks"
    );
    const claimsWeekResult = await query(
      "SELECT COUNT(*) as total FROM payouts WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'"
    );
    const premiumPoolResult = await query(
      "SELECT COALESCE(SUM(weekly_premium), 0) as total FROM policies WHERE status = 'active'"
    );
    const pendingResult = await query(
      "SELECT COUNT(*) as total FROM payouts WHERE status = 'pending_review'"
    );

    const totalFraud = parseInt(fraudResult.rows[0].total) || 1;
    const flaggedCount = parseInt(fraudResult.rows[0].flagged) || 0;
    const flagRate = ((flaggedCount / totalFraud) * 100).toFixed(1);

    res.json({
      totalWorkers: parseInt(workersResult.rows[0].total),
      activePolicies: parseInt(policiesResult.rows[0].total),
      totalPayoutsToday: parseFloat(payoutsTodayResult.rows[0].total),
      payoutCountToday: parseInt(payoutsTodayResult.rows[0].count),
      triggersActiveNow: parseInt(activeTriggersResult.rows[0].total),
      fraudFlagRate: parseFloat(flagRate),
      claimsThisWeek: parseInt(claimsWeekResult.rows[0].total),
      weeklyPremiumPool: parseFloat(premiumPoolResult.rows[0].total),
      pendingReview: parseInt(pendingResult.rows[0].total),
    });
  } catch (err) {
    console.error('Admin stats error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/fraud-checks', async (req, res) => {
  try {
    const result = await query(
      `SELECT fc.*, fc.shap_signals, w.name as worker_name, w.partner_id, p.amount as payout_amount, p.trigger_type, p.zone, p.status as payout_status
       FROM fraud_checks fc
       JOIN workers w ON w.id = fc.worker_id
       JOIN payouts p ON p.id = fc.payout_id
       ORDER BY fc.checked_at DESC
       LIMIT 50`
    );
    res.json({ fraudChecks: result.rows, count: result.rows.length });
  } catch (err) {
    console.error('Fraud checks error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/workers', async (req, res) => {
  try {
    const result = await query(
      `SELECT w.id, w.name, w.phone, w.partner_id, w.platform, w.zones, w.avg_weekly_earnings, w.risk_tier, w.upi_id, w.created_at,
        (SELECT COUNT(*) FROM policies WHERE worker_id = w.id AND status = 'active') as active_policies,
        (SELECT status FROM policies WHERE worker_id = w.id ORDER BY created_at DESC LIMIT 1) as policy_status,
        (SELECT COUNT(*) FROM payouts WHERE worker_id = w.id) as total_claims,
        (SELECT COALESCE(SUM(amount), 0) FROM payouts WHERE worker_id = w.id AND status = 'credited') as total_payouts,
        (SELECT COALESCE(SUM(amount), 0) FROM payouts WHERE worker_id = w.id AND status = 'pending_review') as pending_amount,
        (SELECT risk_score FROM fraud_checks WHERE worker_id = w.id ORDER BY checked_at DESC LIMIT 1) as latest_fraud_score,
        (SELECT recommendation FROM fraud_checks WHERE worker_id = w.id ORDER BY checked_at DESC LIMIT 1) as latest_fraud_recommendation,
        (SELECT weekly_premium FROM policies WHERE worker_id = w.id ORDER BY created_at DESC LIMIT 1) as weekly_premium
       FROM workers w
       ORDER BY w.created_at DESC`
    );
    res.json({ workers: result.rows, count: result.rows.length });
  } catch (err) {
    console.error('Admin workers error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/pending-payouts', async (req, res) => {
  try {
    const result = await query(
      `SELECT p.*, w.name as worker_name, w.partner_id, w.upi_id,
        fc.risk_score as fraud_score, fc.is_flagged, fc.flags, fc.recommendation as fraud_recommendation
       FROM payouts p
       JOIN workers w ON w.id = p.worker_id
       LEFT JOIN fraud_checks fc ON fc.payout_id = p.id
       WHERE p.status = 'pending_review'
       ORDER BY p.created_at DESC`
    );
    res.json({ pendingPayouts: result.rows, count: result.rows.length });
  } catch (err) {
    console.error('Pending payouts error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.put('/payouts/:id/approve', async (req, res) => {
  try {
    const lookup = await query(
      `SELECT p.*, w.upi_id, w.name FROM payouts p JOIN workers w ON w.id = p.worker_id
       WHERE p.id = $1 AND p.status = 'pending_review'`, [req.params.id]);
    if (lookup.rows.length === 0) {
      return res.status(404).json({ error: 'Pending payout not found' });
    }
    const p = lookup.rows[0];

    let utrId, rzpOrderId = null, rzpPayoutId = null, rzpStatus = null;
    let razorpayPayout = null;
    if (p.upi_id) {
      const order = rzp.createOrder({
        amountInr: p.amount,
        receipt: `admin_approve_${p.id}`,
        notes: { worker_id: p.worker_id, approved_by: 'admin', trigger_type: p.trigger_type },
      });
      const { payout: rzpPayout } = rzp.createUpiPayout({
        orderId: order.id, upiId: p.upi_id, amountInr: p.amount,
        workerId: p.worker_id, purpose: 'claim_payout',
      });
      const { payout: settled } = rzp.settlePayout(rzpPayout.id);
      utrId = settled.utr;
      rzpOrderId = order.id;
      rzpPayoutId = rzpPayout.id;
      rzpStatus = settled.status;
      razorpayPayout = { orderId: order.id, payoutId: rzpPayout.id, status: settled.status, utr: utrId };
    } else {
      utrId = `UPI${Date.now()}${Math.random().toString(36).slice(2, 8).toUpperCase()}`;
    }

    const result = await query(
      `UPDATE payouts SET status = 'credited', upi_transaction_id = $2,
         razorpay_order_id = $3, razorpay_payout_id = $4, razorpay_status = $5
       WHERE id = $1 RETURNING *`,
      [req.params.id, utrId, rzpOrderId, rzpPayoutId, rzpStatus]
    );
    console.log(`[Admin] Payout ${req.params.id} APPROVED by admin → ₹${result.rows[0].amount} via UTR ${utrId}`);
    res.json({
      message: 'Payout approved and credited',
      payout: { ...result.rows[0], worker_upi: p.upi_id },
      upiTransactionId: utrId,
      razorpay: razorpayPayout,
    });
  } catch (err) {
    console.error('Approve payout error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/appeals', async (req, res) => {
  try {
    const result = await query(
      `SELECT a.*, w.name as worker_name, w.partner_id, w.upi_id,
              p.amount, p.trigger_type, p.zone, p.status as payout_status, p.breakdown,
              fc.risk_score, fc.recommendation as fraud_recommendation, fc.flags
       FROM payout_appeals a
       JOIN workers w ON w.id = a.worker_id
       LEFT JOIN payouts p ON p.id = a.payout_id
       LEFT JOIN fraud_checks fc ON fc.payout_id = a.payout_id
       ORDER BY
         CASE a.status WHEN 'open' THEN 1 ELSE 2 END,
         a.created_at DESC`
    );
    res.json({ appeals: result.rows, count: result.rows.length });
  } catch (err) {
    console.error('Admin appeals error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.put('/appeals/:id/approve', async (req, res) => {
  try {
    const { adminNotes } = req.body || {};
    const appeal = await query('SELECT * FROM payout_appeals WHERE id = $1', [req.params.id]);
    if (appeal.rows.length === 0) return res.status(404).json({ error: 'Appeal not found' });
    if (appeal.rows[0].status !== 'open') {
      return res.status(400).json({ error: 'Appeal already resolved' });
    }

    const a = appeal.rows[0];
    const upiTxnId = `UPI${Date.now()}${Math.random().toString(36).slice(2, 8).toUpperCase()}`;
    await query(
      "UPDATE payouts SET status = 'credited', upi_transaction_id = $2 WHERE id = $1",
      [a.payout_id, upiTxnId]
    );
    const updated = await query(
      `UPDATE payout_appeals
       SET status = 'resolved_approved', admin_notes = $2, resolved_at = NOW()
       WHERE id = $1 RETURNING *`,
      [req.params.id, adminNotes || 'Approved on appeal']
    );
    console.log(`[Admin] Appeal ${req.params.id} APPROVED — payout ${a.payout_id} credited via UPI (${upiTxnId})`);
    res.json({ message: 'Appeal approved, payout credited', appeal: updated.rows[0], upiTransactionId: upiTxnId });
  } catch (err) {
    console.error('Appeal approve error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.put('/appeals/:id/reject', async (req, res) => {
  try {
    const { adminNotes } = req.body || {};
    const appeal = await query('SELECT * FROM payout_appeals WHERE id = $1', [req.params.id]);
    if (appeal.rows.length === 0) return res.status(404).json({ error: 'Appeal not found' });
    if (appeal.rows[0].status !== 'open') {
      return res.status(400).json({ error: 'Appeal already resolved' });
    }

    const updated = await query(
      `UPDATE payout_appeals
       SET status = 'resolved_rejected', admin_notes = $2, resolved_at = NOW()
       WHERE id = $1 RETURNING *`,
      [req.params.id, adminNotes || 'Rejected after review']
    );
    console.log(`[Admin] Appeal ${req.params.id} REJECTED`);
    res.json({ message: 'Appeal rejected', appeal: updated.rows[0] });
  } catch (err) {
    console.error('Appeal reject error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.put('/payouts/:id/reject', async (req, res) => {
  try {
    const result = await query(
      "UPDATE payouts SET status = 'failed' WHERE id = $1 AND status = 'pending_review' RETURNING *",
      [req.params.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Pending payout not found' });
    }
    console.log(`[Admin] Payout ${req.params.id} REJECTED by admin`);
    res.json({ message: 'Payout rejected', payout: result.rows[0] });
  } catch (err) {
    console.error('Reject payout error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
