
CREATE TABLE IF NOT EXISTS workers (
    id              VARCHAR(20) PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    age             INTEGER,
    phone           VARCHAR(15) UNIQUE NOT NULL,
    partner_id      VARCHAR(30) UNIQUE NOT NULL,
    platform        VARCHAR(30) NOT NULL DEFAULT 'swiggy',
    zones           TEXT[] NOT NULL,
    avg_weekly_earnings DECIMAL(10,2) DEFAULT 0,
    avg_active_hours_per_week DECIMAL(5,1) DEFAULT 0,
    risk_tier       VARCHAR(10) CHECK (risk_tier IN ('low', 'standard', 'high')),
    upi_id          VARCHAR(50),
    aadhaar_hash    VARCHAR(64) UNIQUE,
    joined_date     DATE DEFAULT CURRENT_DATE,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS policies (
    id              VARCHAR(20) PRIMARY KEY,
    worker_id       VARCHAR(20) REFERENCES workers(id),
    status          VARCHAR(10) CHECK (status IN ('active', 'paused', 'expired')) DEFAULT 'active',
    weekly_premium  DECIMAL(6,2) NOT NULL,
    risk_tier       VARCHAR(10),
    start_date      DATE NOT NULL,
    zones           TEXT[] NOT NULL,
    next_debit_date DATE,
    total_premiums_paid DECIMAL(10,2) DEFAULT 0,
    weeks_active    INTEGER DEFAULT 0,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trigger_events (
    id              VARCHAR(20) PRIMARY KEY,
    type            VARCHAR(20) CHECK (type IN ('rainfall', 'heat', 'aqi', 'bandh', 'outage', 'flood', 'cyclone', 'traffic', 'order_collapse', 'platform_outage', 'election')),
    zone            VARCHAR(50) NOT NULL,
    city            VARCHAR(50) NOT NULL DEFAULT 'Chennai',
    start_time      TIMESTAMPTZ NOT NULL,
    end_time        TIMESTAMPTZ,
    duration_hours  DECIMAL(5,1),
    intensity       DECIMAL(8,2),
    unit            VARCHAR(20),
    description     TEXT,
    is_active       BOOLEAN DEFAULT TRUE,
    source          VARCHAR(100),
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payouts (
    id              VARCHAR(20) PRIMARY KEY,
    worker_id       VARCHAR(20) REFERENCES workers(id),
    trigger_event_id VARCHAR(20) REFERENCES trigger_events(id),
    amount          DECIMAL(10,2) NOT NULL,
    status          VARCHAR(20) CHECK (status IN ('pending', 'processing', 'credited', 'failed', 'pending_review')) DEFAULT 'pending',
    breakdown       TEXT,
    trigger_type    VARCHAR(20),
    zone            VARCHAR(50),
    time_window     VARCHAR(50),
    payout_rate     VARCHAR(100),
    upi_transaction_id VARCHAR(50),
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS premium_history (
    id              SERIAL PRIMARY KEY,
    worker_id       VARCHAR(20) REFERENCES workers(id),
    policy_id       VARCHAR(20) REFERENCES policies(id),
    amount          DECIMAL(6,2) NOT NULL,
    debit_date      DATE NOT NULL,
    upi_transaction_id VARCHAR(50),
    status          VARCHAR(10) CHECK (status IN ('success', 'failed', 'pending')) DEFAULT 'success',
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS zone_risk_profiles (
    zone_name       VARCHAR(50) PRIMARY KEY,
    risk_tier       VARCHAR(10) CHECK (risk_tier IN ('low', 'standard', 'high')),
    historical_events_per_year INTEGER DEFAULT 0,
    flood_prone     BOOLEAN DEFAULT FALSE,
    avg_annual_rainfall_mm INTEGER DEFAULT 0,
    center_lat      DECIMAL(10,6),
    center_lng      DECIMAL(10,6)
);

CREATE TABLE IF NOT EXISTS fraud_checks (
    id              SERIAL PRIMARY KEY,
    worker_id       VARCHAR(20) REFERENCES workers(id),
    trigger_event_id VARCHAR(20) REFERENCES trigger_events(id),
    payout_id       VARCHAR(20),
    risk_score      DECIMAL(4,3),
    is_flagged      BOOLEAN DEFAULT FALSE,
    flags           TEXT[],
    recommendation  VARCHAR(10) CHECK (recommendation IN ('approve', 'review', 'block')),
    shap_signals    JSONB DEFAULT NULL,
    checked_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS device_signals (
    id                        SERIAL PRIMARY KEY,
    worker_id                 VARCHAR(20) REFERENCES workers(id),
    collected_at              TIMESTAMP DEFAULT NOW(),
    accel_mean_magnitude      DECIMAL(8,3),
    accel_std_magnitude       DECIMAL(8,3),
    gyro_mean_magnitude       DECIMAL(8,3),
    motion_classification     VARCHAR(20) CHECK (motion_classification IN ('stationary', 'walking', 'vehicle', 'unknown')),
    battery_level             DECIMAL(4,3),
    battery_is_charging       BOOLEAN,
    connection_type           VARCHAR(20),
    network_name              VARCHAR(100),
    gps_lat                   DECIMAL(10,6),
    gps_lng                   DECIMAL(10,6),
    gps_accuracy_m            DECIMAL(8,2),
    platform_os               VARCHAR(20)
);
CREATE INDEX IF NOT EXISTS idx_device_signals_worker ON device_signals(worker_id);
CREATE INDEX IF NOT EXISTS idx_device_signals_time   ON device_signals(collected_at);

CREATE TABLE IF NOT EXISTS payout_appeals (
    id              SERIAL PRIMARY KEY,
    payout_id       VARCHAR(20) NOT NULL,
    worker_id       VARCHAR(20) REFERENCES workers(id),
    reason          TEXT NOT NULL,
    status          VARCHAR(20) CHECK (status IN ('open', 'resolved_approved', 'resolved_rejected')) DEFAULT 'open',
    admin_notes     TEXT,
    created_at      TIMESTAMP DEFAULT NOW(),
    resolved_at     TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_appeals_worker ON payout_appeals(worker_id);
CREATE INDEX IF NOT EXISTS idx_appeals_status ON payout_appeals(status);

CREATE INDEX IF NOT EXISTS idx_policies_worker ON policies(worker_id);
CREATE INDEX IF NOT EXISTS idx_policies_status ON policies(status);
CREATE INDEX IF NOT EXISTS idx_payouts_worker ON payouts(worker_id);
CREATE INDEX IF NOT EXISTS idx_payouts_status ON payouts(status);
CREATE INDEX IF NOT EXISTS idx_triggers_zone ON trigger_events(zone);
CREATE INDEX IF NOT EXISTS idx_triggers_active ON trigger_events(is_active);
CREATE INDEX IF NOT EXISTS idx_premium_history_worker ON premium_history(worker_id);
CREATE INDEX IF NOT EXISTS idx_fraud_checks_worker ON fraud_checks(worker_id);
