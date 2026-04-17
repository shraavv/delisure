const express = require('express');
const cors = require('cors');
const cron = require('node-cron');
require('dotenv').config();

const { authMiddleware } = require('./middleware/auth');
const { query } = require('./db');
const log = require('./utils/logger');
const workersRouter = require('./routes/workers');
const policiesRouter = require('./routes/policies');
const triggersRouter = require('./routes/triggers');
const payoutsRouter = require('./routes/payouts');
const monitorRouter = require('./routes/monitor');
const adminRouter = require('./routes/admin');
const paymentsRouter = require('./routes/payments');
const { runMonitorCycle } = require('./services/trigger-monitor');
const { isMLHealthy } = require('./services/ml-client');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.use((req, res, next) => {
  const start = Date.now();
  const { method, url } = req;
  res.on('finish', () => {
    const duration = Date.now() - start;
    const status = res.statusCode;
    const statusColor = status >= 500 ? log.c.red : status >= 400 ? log.c.yellow : log.c.green;
    const methodColor = method === 'GET' ? log.c.cyan : method === 'POST' ? log.c.blue : method === 'PUT' ? log.c.magenta : log.c.gray;
    const dur = duration > 500 ? log.c.red : duration > 150 ? log.c.yellow : log.c.gray;
    console.log(`${log.c.gray}${log.ts()}${log.c.reset}  ${methodColor}${method.padEnd(5)}${log.c.reset} ${log.c.reset}${url}  ${statusColor}${log.c.bold}${status}${log.c.reset}  ${dur}${duration}ms${log.c.reset}`);
  });
  next();
});

app.get('/api/health', async (req, res) => {
  const mlHealthy = await isMLHealthy();
  res.json({
    service: 'Delisure Backend',
    status: 'running',
    version: '2.0.0',
    mlService: mlHealthy ? 'connected' : 'unavailable (fallback pricing active)',
    monitorEnabled: !!process.env.OPENWEATHER_API_KEY,
    timestamp: new Date().toISOString(),
  });
});

app.use('/api', authMiddleware);

app.use('/api/workers', workersRouter);
app.use('/api/policies', policiesRouter);
app.use('/api/triggers', triggersRouter);
app.use('/api/payouts', payoutsRouter);
app.use('/api/monitor', monitorRouter);
app.use('/api/admin', adminRouter);
app.use('/api/payments', paymentsRouter);

app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

async function ensureMigrations() {
  try {
    await query(`
      CREATE TABLE IF NOT EXISTS payout_appeals (
        id              SERIAL PRIMARY KEY,
        payout_id       VARCHAR(20) NOT NULL,
        worker_id       VARCHAR(20) REFERENCES workers(id),
        reason          TEXT NOT NULL,
        status          VARCHAR(20) CHECK (status IN ('open', 'resolved_approved', 'resolved_rejected')) DEFAULT 'open',
        admin_notes     TEXT,
        created_at      TIMESTAMP DEFAULT NOW(),
        resolved_at     TIMESTAMP
      )
    `);
    await query('CREATE INDEX IF NOT EXISTS idx_appeals_worker ON payout_appeals(worker_id)');
    await query('CREATE INDEX IF NOT EXISTS idx_appeals_status ON payout_appeals(status)');

    await query(`
      CREATE TABLE IF NOT EXISTS device_signals (
        id                    SERIAL PRIMARY KEY,
        worker_id             VARCHAR(20) REFERENCES workers(id),
        collected_at          TIMESTAMP DEFAULT NOW(),
        accel_mean_magnitude  DECIMAL(8,3),
        accel_std_magnitude   DECIMAL(8,3),
        gyro_mean_magnitude   DECIMAL(8,3),
        motion_classification VARCHAR(20),
        battery_level         DECIMAL(4,3),
        battery_is_charging   BOOLEAN,
        connection_type       VARCHAR(20),
        network_name          VARCHAR(100),
        gps_lat               DECIMAL(10,6),
        gps_lng               DECIMAL(10,6),
        gps_accuracy_m        DECIMAL(8,2),
        platform_os           VARCHAR(20)
      )
    `);
    await query('CREATE INDEX IF NOT EXISTS idx_device_signals_worker ON device_signals(worker_id)');
    await query('CREATE INDEX IF NOT EXISTS idx_device_signals_time ON device_signals(collected_at)');

    // Add razorpay tracking columns to payouts
    await query(`
      ALTER TABLE payouts
        ADD COLUMN IF NOT EXISTS razorpay_order_id  VARCHAR(40),
        ADD COLUMN IF NOT EXISTS razorpay_payout_id VARCHAR(40),
        ADD COLUMN IF NOT EXISTS razorpay_status    VARCHAR(20)
    `);

    // Ensure trigger_events CHECK constraint accepts 'cyclone'
    await query(`DO $$
      BEGIN
        IF EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'trigger_events_type_check'
            AND conrelid = 'trigger_events'::regclass
        ) THEN
          ALTER TABLE trigger_events DROP CONSTRAINT trigger_events_type_check;
        END IF;
        ALTER TABLE trigger_events ADD CONSTRAINT trigger_events_type_check
          CHECK (type IN ('rainfall','heat','aqi','bandh','outage','flood','cyclone','traffic','order_collapse','platform_outage','election'));
      EXCEPTION WHEN others THEN NULL;
      END$$;`);
  } catch (err) {
    console.error('[Migration] Failed:', err.message);
  }
}

app.listen(PORT, async () => {
  await ensureMigrations();
  log.section('DELISURE BACKEND STARTED', log.c.magenta);
  log.kv([
    ['Listening',   `http://0.0.0.0:${PORT}`],
    ['Health',      `http://localhost:${PORT}/api/health`],
    ['Database',    (process.env.DATABASE_URL || 'postgresql://postgres@localhost:5432/delisure').replace(/:[^:@]+@/, ':***@')],
    ['ML service',  process.env.ML_SERVICE_URL || 'http://localhost:8000'],
    ['Log level',   (process.env.LOG_LEVEL || 'debug').toUpperCase()],
    ['Admin user',  process.env.ADMIN_USERNAME || 'admin'],
  ]);
  log.endSection(log.c.magenta);

  if (process.env.OPENWEATHER_API_KEY) {
    cron.schedule('*/15 * * * *', async () => {
      try {
        await runMonitorCycle();
      } catch (err) {
        log.error('Cron', `Monitor cycle error: ${err.message}`);
      }
    });
    log.ok('Monitor', 'Active — OpenWeatherMap polling every 15 min');
  } else {
    log.warn('Monitor', 'Inactive — set OPENWEATHER_API_KEY to enable live monitoring');
  }
});
