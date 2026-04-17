# Delisure — Phase 3 Report

**Scale & Optimise (Apr 5 – Apr 17)**
*DEVTrails 2026 Submission · AI-Powered Parametric Income Insurance for India's Gig Economy*

---

## Executive Summary

Phase 3 takes the foundation built in Phase 2 (worker onboarding, weekly
premiums, basic triggers) and turns it into a **production-shape platform**
with advanced fraud defense, an instant payout system, and dashboards for
both workers and insurers.

**Every Phase 3 code deliverable is shipped and running locally on a single
`docker compose up --build` command.** The only missing items are the
5-minute demo video and the pitch deck, both of which are authored separately.

Total new additions in Phase 3:
- **New ML service capabilities** — SHAP explainability, honest held-out metrics
- **Two new fraud layers** — zone density anomaly + device signal fusion
- **Razorpay-compatible payment gateway** — with real order IDs, UTRs, webhooks
- **Admin console with 6 tabs** — analytics, predictive stats, compliance audit PDF
- **5 additional trigger types** — cyclone, traffic, order_collapse, platform_outage, election
- **Worker appeal flow** — plain-language XAI
- **Compliance PDF audit export** — IRDAI-grade
- **Device sensor integration** — accelerometer, gyroscope, battery, WiFi
- **Live OpenWeatherMap monitor** — 15-minute cron polling 16 Chennai zones

---

## Phase 3 Deliverable Coverage

| PDF Requirement | Status | Where it lives |
|---|---|---|
| Advanced Fraud Detection — GPS spoofing | SHIPPED | `backend/routes/triggers.js` + `ml_service/main.py` — 5 spoof scenarios catchable via `/api/triggers/simulate-spoof` |
| Advanced Fraud Detection — fake weather claims using historical data | SHIPPED | Structural defense — workers can't file claims. OWM cron (`backend/services/trigger-monitor.js`) creates them. Historical zone baselines in `zone_risk_profiles` table |
| Instant Payout System (Simulated) | SHIPPED | `backend/services/razorpay-mock.js` — mirrors Razorpay API shape with orders, RazorpayX payouts, UTRs, HMAC-SHA256 webhooks |
| Worker Dashboard — earnings protected, active coverage | SHIPPED | 9 Flutter screens in `mini_prototype/lib/screens/` |
| Insurer Dashboard — loss ratios, predictive analytics | SHIPPED | `admin_dashboard_screen.dart` — 6 tabs including weekly stacked chart, trigger-type pie, ML precision panel |
| 5-minute demo video | NOT IN CODE | Recorded separately |
| Final pitch deck | NOT IN CODE | Authored separately as `pitch_deck.pdf` |

---

## Section 1 — Advanced Fraud Detection

Delisure ships a **five-layer fraud stack** with two novel layers added in
Phase 3 (L5a and L5b). The layers operate in parallel; each one catches a
failure mode the others miss.

### L1 — Identity Lock (DB-enforced)

Defined in `database/schema.sql`:

```sql
phone         VARCHAR(15) UNIQUE NOT NULL,
partner_id    VARCHAR(30) UNIQUE NOT NULL,
aadhaar_hash  VARCHAR(64) UNIQUE
```

One Aadhaar = one account. Aadhaar is validated using the **Verhoeff
checksum** (same algorithm UIDAI uses), then hashed with SHA-256. The raw
number is never stored.

### L2 — Concurrent Claim Block

In `backend/routes/triggers.js`: no duplicate `(worker, type, zone)` claim
within 5 minutes. First claim proceeds; second is silently blocked. Worker
is not penalized.

### L3 — Weekly Earnings Cap

Aggregate payouts for a worker in the trailing 7 days cannot exceed their
`avg_weekly_earnings`. Payout is auto-trimmed if breach detected.

### L4 — ML Behavioral Scoring (Isolation Forest + rules)

In `ml_service/main.py`:

- **Isolation Forest** (100 estimators, 3% contamination) trained on 3000
  normal behavior samples.
- **4 input features**: `gps_distance_km`, `deliveries_during_trigger`,
  `claim_frequency_zscore`, `hours_since_last_claim`.
- **Rule-based scoring** running in parallel (GPS >5km, activity paradox,
  frequency outlier, rapid-fire).
- **Combined score**: `0.6 × rule_score + 0.4 × iforest_risk`.
- **SHAP KernelExplainer** generates per-feature contribution for every
  decision.

Thresholds: `<0.3 approve`, `0.3–0.7 review`, `≥0.7 block`.

### L5a — Zone Density Anomaly (NOVEL, Phase 3)

Defeats coordinated burst attacks (e.g. Telegram-organized spoofing rings)
without requiring a graph database.

```sql
SELECT COUNT(DISTINCT worker_id) FROM payouts
WHERE zone = $1 AND created_at > NOW() - INTERVAL '10 minutes'
```

Compared against the 30-day daily baseline for that zone. If concurrent
claimants exceed 3× baseline AND ≥5 claimants, every claim in the window
gets +0.25 fraud score and a `zone_density_spike` flag.

### L5b — Device Signal Fusion (NOVEL, Phase 3)

The biggest anti-spoofing innovation. A GPS-spoofing app can fake
coordinates; it cannot simultaneously fake accelerometer variance, battery
drain pattern, or connection-type metadata.

**Signals captured on the phone** (Flutter):

- **Accelerometer** (`sensors_plus`) — 5-second sampling, computes mean +
  std magnitude. Classifies motion as `stationary`, `walking`, or `vehicle`
  based on std dev thresholds.
- **Gyroscope** (`sensors_plus`) — rotational magnitude.
- **Battery** (`battery_plus`) — level 0-1 and charging state.
- **Connectivity** (`connectivity_plus` + `network_info_plus`) —
  wifi/mobile/ethernet/none plus WiFi SSID.

Signals are posted to `/api/workers/:id/device-signals` before every
trigger simulation (and on dashboard load). The backend fraud scorer fuses
them into Layer 5b:

| Signal state | Fraud score change | Flag |
|---|---|---|
| motion = stationary (recent) | +0.20 | `device_stationary` |
| charging + battery > 80% | +0.10 | `charging_at_claim` |
| on WiFi during claim | +0.08 | `wifi_during_claim` |
| motion = vehicle | **−0.15** | rewards honest workers |
| no signals in last hour | 0 | `no_device_signals` |

**Proven behavior** (same worker, same zone):

- Stationary + WiFi + charging → fraud score 0.82 → **BLOCKED**
- Vehicle motion + mobile data + low battery → fraud score 0.29 → **APPROVED**

### Fake Weather Claims Defense (structural)

The Phase 3 brief specifically calls out "fake weather claims using
historical data" as a threat. Delisure defeats this structurally, not
through detection:

**Workers do not submit claims.** The cron monitor
(`backend/services/trigger-monitor.js`) polls OpenWeatherMap every 15
minutes for all 16 Chennai zones, creates `trigger_events` when thresholds
are breached, then auto-creates payouts for workers in affected zones.
There is no claim form for a worker to falsify. A worker cannot file for
rain that did not happen.

Historical baselines for zone risk scoring are in the `zone_risk_profiles`
table (seeded from real Chennai data: 6 high-risk, 6 standard, 4 low-risk
zones with annual event counts and flood flags).

---

## Section 2 — Instant Payout System (Simulated)

### Razorpay-compatible mock gateway

Per the Phase 3 brief:
> "Integrate mock payment gateways (Razorpay test mode, Stripe sandbox, or
> UPI simulators) to demonstrate how the worker receives their lost wages
> instantly."

Delisure ships a **UPI simulator that mirrors Razorpay's API shape exactly**
in `backend/services/razorpay-mock.js`. Every approved claim runs through
this gateway; migrating to live Razorpay is a one-file credential swap
because the API surface is identical.

### Gateway flow (per approved claim)

1. **Create order** — `POST /v1/orders` equivalent returns
   `order_02a26c0a85a2978d` with amount in paise, currency INR.
2. **Queue UPI payout** — RazorpayX payouts API returns
   `pout_ab68ef687ca4f9ed`, status `queued`, mode UPI, fund account ID.
3. **State transition** — `queued → processing → processed` (or `reversed`
   on failure).
4. **NPCI settlement** — returns UTR (Unique Transaction Reference) in
   standard UPI format: `UPI1776430940399E5YLWP`.
5. **Webhook callback** — signed with HMAC-SHA256 using the webhook secret.
6. **DB update** — payout row gets `razorpay_order_id`,
   `razorpay_payout_id`, `razorpay_status`, `upi_transaction_id` (UTR).

### Configuration (docker-compose.yml)

```yaml
RAZORPAY_KEY_ID:         rzp_test_delisure2026
RAZORPAY_KEY_SECRET:     rzp_secret_delisure_demo_9f3a4c2b
RAZORPAY_WEBHOOK_SECRET: whsec_delisure_demo_2026
```

### Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/payments/status` | Gateway info, key ID, supported methods |
| POST | `/api/payments/orders` | Create Razorpay-style order |
| GET | `/api/payments/orders/:id` | Fetch order |
| POST | `/api/payments/process-payout` | Queue + settle UPI payout for a claim |
| POST | `/api/payments/verify` | Verify checkout signature (HMAC-SHA256) |
| POST | `/api/payments/webhook` | Inbound webhook (validates signature) |
| GET | `/api/payments/payout/:id` | Fetch payout state |

### Benchmark (live)

Trigger fired at T+0s → fraud scored at T+0.7s → Razorpay order at T+0.8s →
UPI payout queued at T+0.9s → UTR returned at T+1.0s. End-to-end,
sub-second.

### Invoice PDF

Every credited payout surfaces an "Invoice" badge in the Flutter app.
Tapping it downloads a branded PDF (via `backend/routes/payouts.js`
endpoint `/api/payouts/:id/invoice/pdf`) containing:

- Delisure header (dark + gold branding)
- Section 1: Parties (Insurer card + Beneficiary card)
- Section 2: Parametric Event details
- Section 3: Payout calculation breakdown
- Section 4: Payment Record with UTR in gold
- **Section 5: Razorpay gateway trail** — order ID, payout ID, gateway status
- Section 6: IRDAI regulatory and tax status

---

## Section 3 — Intelligent Dashboard

### Worker Dashboard (9 screens)

| Screen | Purpose |
|---|---|
| Splash | Animated launch, auth check |
| Login | Partner ID + phone |
| Onboarding | 5-step wizard (details, Aadhaar KYC, zones, UPI, premium review) |
| Dashboard | Zone-estimated earnings, active coverage, recent payouts, active trigger alerts, risk calendar |
| Coverage | Policy details, ML premium breakdown, trigger thresholds, pause toggle |
| Payouts | Total paid, net benefit, filter by trigger type, Appeal chip on held/failed payouts, Invoice chip on credited |
| Profile | Worker info, premium payment history, notification toggles |
| Risk Calendar | 30-day forward-looking risk scores per zone |
| Claim Detail | SHAP signal breakdown for fraud-flagged claims |

**Predictive analytics on the worker side**: the Risk Calendar is a
30-day forecast generated by the ML service from zone baselines,
monsoon boost (Jun–Aug, Oct–Dec), and weekend bumps.

### Admin Console (6 tabs)

Authentication: separate HMAC-SHA256 signed tokens (not just the API key).
Credentials: `admin` / `delisure@admin2026`. Middleware: `requireAdmin` in
`backend/middleware/auth.js`.

**Top row — 4 key stats** (directly from the Phase 3 brief):

1. Total workers
2. Active policies
3. **Loss Ratio** — color-coded green/orange/red
4. **Predicted Claims (next week)** — trend-weighted rolling average of
   last 4 weeks

**Tab 1 — Analytics**

- **Weekly stacked bar chart** (last 8 weeks): credited (green), pending
  (orange), blocked (red)
- **Pie chart** for trigger type distribution over last 30 days
- **Zone activity** list with triggers + payouts per zone
- **Fraud summary** strip (flagged count, flag rate, avg risk score)
- **ML Model Precision panel** — see Section 4 for the actual numbers
- **Razorpay payment gateway card** showing test-mode key ID + feature
  checkmarks

**Tab 2 — Pending** — held payouts with confirmation-dialog approve/reject
that triggers the full Razorpay settlement flow and returns order ID +
payout ID + UTR in a result dialog.

**Tab 3 — Appeals** — worker-submitted appeals with reasons. Admin can
approve-and-credit or reject.

**Tab 4 — Fraud Checks** — last 50 ML decisions with icon-coded flag
chips (stationary device, charging, WiFi, zone-density, ML anomaly,
rapid-fire, GPS anomaly, activity paradox, frequency outlier).

**Tab 5 — Workers** — all registered workers with aggregated stats.

**Tab 6 — Triggers** — historical trigger events.

### Admin header actions

- **Logout** (revokes HMAC token)
- **Export Compliance PDF** — see Section 5
- **Simulate GPS Spoof** — dialog picker for 5 attack scenarios → result
  dialog showing the model's fraud score and verdict
- **Simulate Held Claim** — creates a pending_review payout on demand for
  demo purposes
- **Refresh** — re-loads all tabs in parallel

---

## Section 4 — Honest ML Metrics

Metrics exposed at `GET /api/ml/metrics` and rendered in the admin
Analytics tab. All numbers from held-out 20% test splits. **Zero
overfitting tricks.**

### Premium Pricing Model — XGBoost

Training deliberately injects realistic noise so the model cannot just
reverse-engineer the pricing formula:

| Noise source | Distribution |
|---|---|
| Earnings misreporting | N(0, 8%) on earnings ratio |
| Zone assignment error | 2% flipped by one tier |
| Quote variance | ×(1 + N(0, 5%)) multiplicative |
| Admin overrides | ±Rs.5 or ±Rs.8 on 3% of quotes |
| Additive measurement | N(0, Rs.1.5) |

Regularization: `subsample=0.8`, `colsample_bytree=0.8`, `reg_alpha=0.1`,
`reg_lambda=1.0`.

| Metric | Train | Test | Interpretation |
|---|---|---|---|
| MAE | Rs.2.41 | Rs.3.27 | Mean absolute error per premium quote |
| RMSE | Rs.3.37 | Rs.4.71 | Penalizes outliers |
| R² | 0.978 | **0.954** | Variance explained |
| Overfit gap | — | **0.024** | Small gap = healthy generalization |

### Fraud Model — Isolation Forest

Evaluated against a deliberately realistic 300-sample adversarial set:

- **40% obvious fraud** (all 4 signals elevated)
- **35% moderate** (1–2 signals elevated)
- **25% subtle** (single signal barely above normal — hardest to detect)

| Metric | Value |
|---|---|
| Precision | 0.66 |
| Recall | 0.59 |
| F1 score | 0.63 |
| Accuracy | 0.936 |
| False positive rate | 0.03 |
| True positives | 178 |
| False negatives | 122 |

The 122 missed cases are mostly the "subtle" tier — indistinguishable from
legitimate claims on the 4-feature vector alone. That's exactly why
Delisure ships additional fraud layers (rules + zone density + device
fusion) on top of the Isolation Forest — each layer catches a failure
mode the others miss.

**Why not 99% recall?** A 100%-recall model on a trivial test set is the
classic ML demo lie. We chose honesty.

### Every decision explainable (SHAP)

Per-feature contribution signals computed with `shap.KernelExplainer`
(50-sample background set) for every fraud check. Stored as JSONB in the
`fraud_checks.shap_signals` column. Rendered as:

- Visual bars in the Compliance PDF
- Icon-coded chips in the admin Fraud Checks tab
- Plain-language signals in the Claim Detail screen (for worker appeals,
  never uses the word "fraud")

---

## Section 5 — Compliance PDF Audit Trail

IRDAI requires automated claim decisions to be explainable and auditable.
Delisure exports a full audit PDF on demand.

**Endpoint**: `GET /api/admin/audit-report` (requires admin token).

**Contents**:

- Branded header (every page): logo mark, IRDAI reg number, timestamp
- **Section 1 — Executive Summary**: 4-column stat block (total decisions,
  auto-approved, held for review, blocked)
- **Section 2 — Claim-by-Claim Audit Log**: each claim rendered as a
  card with:
  - Claim number + payout ID in a dark title bar
  - Color-coded recommendation pill (approve/review/block)
  - 8-field key-value grid (worker, partner ID, trigger, amount, risk
    score, UPI txn, status, timestamp)
  - **SHAP Contribution bars** — visual horizontal bars with
    arrow direction per feature
  - Flags raised list
- Footer (every page): company info, GSTIN, page number, IRDAI disclosure
  notice

Theme matches the Flutter app — near-black header with gold accents, warm
off-white body for print-friendliness.

---

## Section 6 — 11 Parametric Trigger Types

Phase 3 expanded the trigger system from 6 to **11 types** covering
environmental, civic, platform, and traffic disruptions:

| # | Type | Threshold | Min Duration | Source |
|---|---|---|---|---|
| 1 | rainfall | ≥ 14 mm/hr | 1.5h | OpenWeatherMap (live) |
| 2 | heat | ≥ 44°C feels-like | 3h | OpenWeatherMap (live) |
| 3 | aqi | ≥ 300 AQI | 4h | OpenWeatherMap AQI (live) |
| 4 | bandh | Civic disruption | — | Gov notification (manual) |
| 5 | outage | Grid power outage | 2h | TANGEDCO API (manual) |
| 6 | flood | ≥ 50 mm/hr | 2h | IMD / OpenWeatherMap |
| 7 | **cyclone** (new) | IMD ≥ 48h pre-landfall | 12h | IMD (manual/API) |
| 8 | **traffic** (new) | Avg speed ≤ 8 km/h | 1.5h | Traffic API (manual) |
| 9 | **order_collapse** (new) | Order drop ≥ 65% | 1h | Swiggy API (simulated) |
| 10 | **platform_outage** (new) | Swiggy app errors | 2h | Swiggy status (simulated) |
| 11 | **election** (new) | EC-declared voting day | — | Election Commission |

---

## How to Run

### Prerequisites

- Docker 20+ and Docker Compose
- Flutter SDK 3.3+ (for the mobile app)
- Android device or emulator (optional, for the app)

### Start the stack

```bash
cd source_code
docker compose up --build
```

That's it. On first run:

- PostgreSQL 16 auto-initializes from `database/schema.sql` and
  `database/seed.sql`
- ML service trains both models on startup (takes about 15 seconds)
- Backend runs migrations (appeals table, device signals table, cyclone
  trigger CHECK constraint)

Services available at:

- Backend API — `http://localhost:3000`
- ML service — `http://localhost:8000`
- PostgreSQL — `localhost:5433` (internal port 5432)

### Verify

```bash
curl http://localhost:3000/api/health
# { "service": "Delisure Backend", "status": "running",
#   "mlService": "connected", "monitorEnabled": true, ... }

curl http://localhost:8000/api/ml/metrics | jq
# Full metrics including overfit_gap_r2, adversarial tier breakdown, ...

curl http://localhost:3000/api/payments/status \
  -H "x-api-key: delisure-demo-key-2026"
# Razorpay test-mode confirmation
```

### Run the Flutter app

```bash
cd mini_prototype
flutter pub get
flutter run
```

Edit `lib/services/api_service.dart` line 7 to set `_host` to your
machine's LAN IP (for physical Android device) or `10.0.2.2` (for Android
emulator).

### Test credentials

**Worker login** (seeded):
- Partner ID: `SWG-CHN-28491`
- Phone: `9876543210`

**Admin login**:
- Username: `admin`
- Password: `delisure@admin2026`

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Flutter Mobile App (Android + iOS)                 │
│  10 screens · sensors_plus + battery_plus +         │
│  connectivity_plus + network_info_plus              │
└───────────────┬─────────────────────┬───────────────┘
                │ REST/JSON           │ REST/JSON
        ┌───────▼──────────┐   ┌─────▼──────────────┐
        │  Node.js Backend │   │  Python ML Service │
        │  Express :3000   │◀──│  FastAPI :8000     │
        │  6 routes + cron │   │  XGBoost + IForest │
        │  PDF generation  │   │  + SHAP explainer  │
        │  Razorpay mock   │   │                    │
        └────────┬─────────┘   └────────┬───────────┘
                 │ SQL (pg pool)        │ SQL (psycopg2)
                 │                      │
         ┌───────▼──────────────────────▼────────────┐
         │      PostgreSQL 16 (Alpine)               │
         │  8 tables · 10 indexes · runtime migrations│
         └───────────────────────────────────────────┘
                           ▲
                           │
                  OpenWeatherMap API
               (live weather + AQI for 16 zones)
```

**4 services, 1 Docker Compose command.**

---

## What is NOT Built (Honest Scope)

Delisure's README describes an ambitious 10-module ML architecture. Not
all of it ships in Phase 3. The following items are architected and
documented but scoped out in favor of feature-complete core flows:

| Feature | Status | Why scoped out |
|---|---|---|
| Neo4j graph ring detection | Deferred | Separate DB + PyTorch Geometric training data. Zone density anomaly covers burst attacks today. |
| LSTM trigger-timing manipulation | Deferred | Separate training pipeline |
| BERT civic NLP classifier | Deferred | Fine-tuning dataset; bandh is binary today |
| Churn prediction | Deferred | No telemetry data yet |
| Micro-zone DBSCAN clustering | Deferred | Needs 6+ months of real claim data |
| Cold-start fraud baseline (KNN) | Deferred | New workers get 0 from IForest; rule layer still fires |
| Firebase push notifications | Deferred | Requires Firebase project setup |
| Razorpay **live** integration | Deferred | Mock UTRs today; Razorpay requires KYB |
| IMD / CPCB direct integration | Deferred | OWM provides both weather + AQI |
| Cell tower triangulation | Deferred | Requires READ_PHONE_STATE (Play Store sensitive) |

**What this means**: every required Phase 3 deliverable from the official
PDF is shipped. The deferred items are upgrades for Phase 4+ that extend
defense against *persistent adversarial campaigns* (slow-burn rings,
weeks-long attacks), not fill gaps in the MVP scope. Delisure's shipped
5-layer fraud stack defeats burst attacks (Telegram swarms) today without
requiring graph-database analytics.

---

## File Map

```
source_code/
├── backend/
│   ├── routes/
│   │   ├── admin.js          (RBAC + analytics + audit PDF + appeals)
│   │   ├── workers.js        (registration, KYC, UPI validation)
│   │   ├── policies.js       (activate/pause/renew)
│   │   ├── triggers.js       (simulate + spoof demo + auto-credit)
│   │   ├── payouts.js        (history, invoice PDF, appeal submit)
│   │   ├── payments.js       (Razorpay-compatible endpoints)
│   │   └── monitor.js        (health + live weather)
│   ├── services/
│   │   ├── ml-client.js      (axios proxy to ML service)
│   │   ├── razorpay-mock.js  (Razorpay API simulator)
│   │   └── trigger-monitor.js (OWM cron, IPv4-forced)
│   ├── middleware/auth.js    (API key + HMAC admin tokens)
│   ├── utils/
│   │   ├── aadhaar.js        (Verhoeff checksum + SHA-256)
│   │   ├── upi.js            (regex + handle whitelist)
│   │   └── logger.js         (structured debug output)
│   └── server.js             (express boot + migrations)
│
├── database/
│   ├── schema.sql            (8 tables, 10 indexes)
│   └── seed.sql              (3 workers, 4 triggers, 5 payouts, 16 zones)
│
├── ml_service/
│   ├── main.py               (XGBoost + IForest + SHAP + honest metrics)
│   ├── Dockerfile
│   └── requirements.txt
│
├── mini_prototype/            (Flutter app)
│   └── lib/
│       ├── screens/           (10 screens)
│       ├── services/
│       │   ├── api_service.dart
│       │   └── device_signals.dart  (accelerometer + battery + wifi)
│       └── ...
│
├── docker-compose.yml         (3 services, health checks, auto-migrations)
├── features.pdf               (complete feature catalogue)
└── PHASE3_REPORT.md           (this file)
```

---

## Credits

Built for DEVTrails 2026 Phase 3. Chennai-first. Parametric-insurance-first.
Gig-worker-first.

**Delisure — Your earnings, protected.**

---

# 

# DEMO VIDEO

# https://drive.google.com/drive/u/2/folders/1prr7_gF3o10BlDwwTqll1J6O0_7dV4F9
