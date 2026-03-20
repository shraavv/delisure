# delisure
### AI-Powered Parametric Income Insurance for Gig Delivery Workers

> Arjun rides through Chennai's monsoons so your biryani arrives hot.
> When the floods stop him from working, nothing stops his bills.
> delisure changes that — automatically.

---

## Table of Contents
1. [The Problem](#the-problem)
2. [Persona & Scenarios](#persona--scenarios)
3. [Application Workflow](#application-workflow)
4. [Weekly Premium Model](#weekly-premium-model)
5. [Parametric Triggers](#parametric-triggers)
6. [AI/ML Integration](#aiml-integration)
7. [Adversarial Defense & Anti-Spoofing Strategy](#adversarial-defense--anti-spoofing-strategy)
8. [Why Mobile, Not Web](#why-mobile-not-web)
9. [Tech Stack](#tech-stack)
10. [Development Plan](#development-plan)

---

## The Problem

India has 12 million platform-based delivery workers (Zomato, Swiggy,
Zepto, Amazon, Dunzo). They earn per delivery — no deliveries means no
income, zero recourse. External disruptions they cannot control routinely
destroy their weekly earnings overnight.

A Swiggy delivery partner in Chennai earns approximately ₹700–850/day.
During the northeast monsoon season (October–December), riders lose an
average of 2–4 working days per month to heavy rainfall alone — a monthly
income loss of ₹1,400–3,400. No existing insurance product covers this.

**delisure** is a parametric income insurance platform that pays delivery
workers automatically when a measurable disruption event halts their ability
to work — no claim filing, no waiting, no proof required.

**Coverage scope:**
- ✅ Income lost due to external environmental and civic disruptions
- ❌ Vehicle damage or repair — excluded
- ❌ Health, injury, or accident costs — excluded
- ❌ Any worker-side or personal disruption — excluded

---

## Persona & Scenarios

### Arjun, 27 — Swiggy Delivery Partner, Chennai

| Attribute | Detail |
|-----------|--------|
| Delivery zones | Adyar, Velachery, Thiruvanmallur (South Chennai) |
| Daily earnings | ₹700–850 across 8–12 deliveries |
| Weekly earnings | ~₹5,000–5,500 |
| Peak hours | 12–2pm (lunch), 7–9:30pm (dinner) |
| Device | Mid-range Android, uses GPay daily |
| Insurance today | None. No product exists for his situation. |

Arjun's financial reality: daily earnings cover daily expenses. A 2-day
disruption is not an inconvenience — it means skipping meals or
defaulting on rent.

---

### Scenario 1 — Cyclone Michaung (real event, November 2023)

Extreme rainfall across Chennai for 3 consecutive days. Swiggy partner
GPS activity in affected zones dropped over 80%. Arjun lost approximately
₹2,100 in income with zero compensation.

**With delisure:** Rainfall threshold breached at 7:18pm on Day 1.
System detects active policy for Arjun's zone. Fraud check passes — no
delivery activity detected during trigger window. ₹1,260 (60% income
replacement, dinner-hour weighted) credited to his GPay account by
9:30pm. He did nothing.

---

### Scenario 2 — Bandh / Civic Strike

An unannounced transport bandh declared across Tamil Nadu. Section 144
prohibitory orders issued across Chennai. Arjun cannot reach pickup
locations.

**With delisure:** Civic trigger fires after confirmation from 2
verified sources (state government notification + major news outlet).
Full-day income replacement at 60% rate credited automatically. Duration
matches the official declared period.

---

### Scenario 3 — Extreme Heat (April–June)

Feels-like temperature in Chennai crosses 44°C during the 11am–4pm
window. Outdoor physical labour becomes medically inadvisable and order
volumes drop sharply.

**With delisure:** Heat trigger fires for the affected window only.
Arjun receives 50% income replacement for the afternoon hours. Evening
coverage continues normally once temperature drops.

---

### Scenario 4 — Grid Power Outage

A 5-hour unscheduled TANGEDCO outage hits Velachery. Restaurants in the
zone cannot operate — kitchens down, cold storage failing, order
placements collapse. Arjun is physically available but there is nothing
to deliver.

**With delisure:** TANGEDCO outage API logs the event. Order volume
collapse in the zone cross-confirms. Trigger fires at the 4-hour mark.
50% income replacement credited for the outage duration. No weather
event needed — the supply side of Arjun's work collapsed and delisure
caught it.

---

## Application Workflow

### Onboarding (one-time, ~5 minutes)
```
Download delisure app
  → Enter Swiggy Partner ID (auto-fetches earnings history, active zones)
  → KYC via Aadhaar OTP
  → Select up to 3 primary delivery zones
  → AI risk profile generated → weekly premium quoted instantly
  → Set up UPI mandate for Monday auto-debit
  → Coverage active immediately
```

The Swiggy Partner ID integration pulls average weekly earnings, active
hours, and primary zones automatically. Workers enter almost nothing
manually.

---

### Weekly Coverage Cycle

Every Monday, the weekly premium is auto-debited via UPI mandate. The
worker receives a push notification confirming coverage is active. The
backend begins monitoring all parametric triggers for their registered
zones in real time, evaluated every 30 minutes.

---

### Trigger → Payout Flow
```
API detects threshold breach in registered zone
  → All active policies for that zone identified
  → Fraud validation layer runs (GPS cross-check + activity paradox
     check + accelerometer validation + cell tower triangulation)
  → Eligible workers receive push notification:
     "Disruption detected. Payout processing."
  → Payout amount calculated (time-of-day income weighting applied)
  → UPI transfer initiated via Razorpay
  → ₹ credited within 2 hours
  → In-app confirmation with full breakdown
```

**The worker does nothing at any point in this flow.**

---

### Worker Dashboard

The app home screen shows:
- Active coverage status and current week's premium
- Registered zones and their live trigger status
- Payout history with event breakdowns
- Upcoming premium debit date
- 7-day disruption forecast for registered zones
- Proactive alerts when elevated risk is forecast for the coming week

---

## Weekly Premium Model

### Why Weekly?

Swiggy delivery partners are paid weekly by the platform. Their
financial planning horizon is one week — they cannot reliably commit
to monthly outflows. A weekly model matches their earnings cycle exactly
and allows them to pause coverage between weeks if needed.

---

### Base Premium Tiers

| Risk tier | Weekly premium | Qualification |
|-----------|---------------|---------------|
| Low | ₹29 | Zone has <4 trigger-level events/year historically |
| Standard | ₹49 | Zone has 4–10 events/year |
| High | ₹69 | Zone has >10 events/year or is flood-prone |
| Monsoon surge | ₹89 | Active monsoon season + elevated IMD forecast |

---

### Dynamic Premium Calculation Pipeline

The base tier is a starting point. Every Monday before the auto-debit
runs, the XGBoost model recalculates the final premium using the
following inputs:
```
INPUTS                          ENGINE                    OUTPUT
─────────────────────           ──────────────────        ──────────────
Zone disruption history    →
IMD 7-day forecast         →
Current season / monsoon   →    Base Tier Lookup          Final weekly
Delivery route risk score  →  + XGBoost Adjustment    →  premium in ₹
Earnings volatility index  →    Layer                     ──────────────
Claim history vs peers     →  × Seasonality (1.3×         Monday push
Platform diversification   →    if monsoon active)        notification
Coverage streak (loyalty)  →                              + UPI debit
```

**What each input does:**

| Input | Effect on premium |
|-------|-------------------|
| Hyper-local zone flood history | Velachery priced 3× higher than Nungambakkam 8km away |
| Delivery route GPS history | Worker crossing flood-prone underpasses priced higher than elevated-road riders in same zone |
| Time-of-day exposure | Dinner-rush-only workers pay slightly more — higher income variance per trigger |
| Multi-platform registration | Small discount — Swiggy + Zomato workers have natural income hedge |
| 8+ week streak, zero claims | ₹5–8 weekly loyalty discount |
| Monsoon season active | 1.3× multiplier applied across all tiers |
| Earnings volatility ±40% | Slight premium increase — higher average loss per event |
| Sunday surge opt-in | Worker can top up ₹15–20 before a high-risk week |

---

### Payout Calculation

Payouts replace 40–70% of estimated income for disrupted hours — not
a flat amount. Losing the 7–9pm dinner rush is a materially greater
income loss than losing the same hours at 2pm.

| Time window | Earning weight | Payout rate |
|-------------|---------------|-------------|
| 7am–11am | 0.8× | 40% of hourly baseline |
| 11am–3pm (lunch peak) | 1.2× | 60% of hourly baseline |
| 3pm–7pm | 0.7× | 40% of hourly baseline |
| 7pm–10:30pm (dinner peak) | 1.5× | 70% of hourly baseline |

**Hourly baseline** = worker's average weekly earnings ÷ average active
hours/week (from Swiggy Partner data).


<img width="1823" height="777" alt="image" src="https://github.com/user-attachments/assets/2abca2ed-d608-4cc5-9d96-0cc461b0dc93" />

---

## Parametric Triggers

All triggers evaluated every 30 minutes per registered zone. One trigger
firing in a worker's zone during active coverage hours qualifies them
for a payout.

---

### Trigger 1 — Weather, Climate & Air Quality Disruption

This trigger consolidates five distinct environmental disruption signals
into a single unified trigger group. Each sub-trigger has its own data
source, threshold, and payout logic — but all share the same fraud
validation pipeline and cooldown window.

| Sub-trigger | Source | Threshold | Window | Payout |
|-------------|--------|-----------|--------|--------|
| Heavy Rainfall | OpenWeatherMap + IMD | ≥14mm/hr for ≥90 mins | Any active hours | Time-weighted replacement |
| Local Flood Gauge Breach | Chennai Corporation gauge API (Adyar river, Buckingham Canal) | Gauge crosses ward-critical level for ≥30 mins | Any active hours | Time-weighted replacement |
| Cyclone Watch (Pre-Emptive) | IMD cyclone warning API | Cyclone warning issued ≥48hrs before landfall | Pre-landfall window | 40% pre-emptive; full rates post-landfall |
| Extreme Heat | OpenWeatherMap feels-like field | Feels-like ≥44°C for ≥3 consecutive hours | 11am–4pm only | 50% afternoon window |
| Severe Air Pollution | CPCB open API | AQI ≥300 (Hazardous) for ≥4 continuous hours | Any active hours | 40% income replacement |

**Why five signals instead of one:**
Each sub-trigger catches a different failure mode of the same underlying
problem — that outdoor delivery has become impossible due to environmental
conditions. Rainfall APIs fire late. Flood gauges measure actual ground
inundation. Cyclone warnings fire 48 hours early. Heat triggers fire only
in the afternoon window where they cause real income loss. AQI catches
days where the air itself is a health hazard regardless of weather.
Together they eliminate the gaps that any single environmental API
would leave.

**Priority logic when multiple sub-triggers fire simultaneously:**
The highest applicable payout rate is used — never stacked. A cyclone
landfall that breaches both the rainfall threshold and flood gauge
threshold pays out once at the higher time-weighted rate, not twice.

---

### Trigger 2 — Civic & Political Disruption

This trigger consolidates two government-action disruption signals —
unplanned civic events and predictable electoral blackouts — into a
single group. Both result in the same outcome for Arjun: he cannot
move freely, restaurants reduce hours, and orders collapse.

| Sub-trigger | Source | Threshold | Validation | Payout |
|-------------|--------|-----------|------------|--------|
| Bandh / Curfew / Section 144 | State government notification API + NLP classifier on verified news sources | Declared bandh, Section 144, or transport strike in worker's city | Minimum 2 independent verified sources required | 60% for official declared duration |
| Election / Voting Day | Election Commission of India open data | Official voting day declared in worker's city | EC published schedule — single verified source sufficient | 50% for official voting hours |

**Why these belong together:**
Both are government-action events that cause the same downstream effect
— movement restrictions, reduced restaurant operations, and order volume
collapse. The key distinction in their handling is verification: bandhs
require 2 independent sources because they can be rumoured or
exaggerated, while election days are published months in advance on EC
open data and require no real-time verification at all.

**NLP confidence scoring for bandh sub-trigger:**
Rather than binary verified/unverified, the NLP classifier outputs a
confidence score (0.0–1.0) based on source authority, number of
independent confirmations, and geographic specificity.
- Confidence ≥0.85 → trigger fires immediately
- Confidence 0.60–0.84 → payout held 2 hours pending confirmation
- Confidence <0.60 → trigger withheld, manual review

---

### Trigger 3 — Platform Outage
- **Source:** Swiggy Partner API status endpoint (mocked in Phase 1)
- **Threshold:** App-level errors for active partner pings in zone for
  ≥2 continuous hours during active hours
- **Payout:** 50% income replacement for outage duration

---

### Trigger 4 — Traffic Paralysis
- **Source:** Google Maps Directions API / HERE Traffic API
- **Threshold:** Average travel speed across worker's primary zone
  drops below 8 km/h for ≥90 continuous minutes during active hours
- **Rationale:** Roads flood before IMD officially logs heavy rain.
  Traffic collapse fires 45–90 minutes earlier than a rainfall trigger
  for the same event — every minute of earlier detection is income
  protected.
- **Payout:** Time-weighted replacement for paralysis duration

---

### Trigger 5 — Grid Power Outage
- **Source:** TANGEDCO outage API (Tamil Nadu DISCOM)
- **Threshold:** ≥4 continuous hours of outage in worker's zone during
  active hours
- **Rationale:** Extended power cuts collapse restaurant order capacity
  — kitchens down, cold storage failing, orders stop. Worker is
  available but the supply side of their work has collapsed.
- **Cross-validation:** Swiggy order volume drop in the zone used to
  confirm. If orders remain normal despite the outage, restaurants
  have adequate backup power and the trigger is held.
- **Payout:** 50% income replacement for outage duration

---

### Trigger 6 — Swiggy Order Volume Collapse
- **Source:** Swiggy Partner API order density endpoint
- **Threshold:** Order placements in worker's zone drop >65% vs the
  same time slot on the previous 3 equivalent days, sustained ≥60 mins
- **Rationale:** Instead of measuring environmental conditions and
  inferring disruption, this measures the work itself. If orders aren't
  flowing, Arjun isn't earning — regardless of the cause. This is the
  most honest trigger in the system and requires platform data access
  that no external competitor can replicate.
- **Payout:** Time-weighted replacement for collapse duration

---

## AI/ML Integration

### Module 1 — Dynamic Premium Engine

**Model:** XGBoost (Gradient Boosted Trees)

**Inputs:** Zone-level historical disruption frequency, worker's weekly
earnings baseline, IMD 7-day forecast, current season, worker's claim
history vs zone peers, delivery route risk score, earnings volatility
index.

**Output:** Weekly premium in ₹, recalculated every Monday before
auto-debit runs. Full input-output pipeline detailed in the Weekly
Premium Model section above.

---

### Module 2 — Fraud Detection Engine

**Model:** Isolation Forest (anomaly detection) + rule-based pre-filter

**Rule-based pre-filter (4-layer stack):**

- **Layer 1 — Identity Lock (at registration):** One phone number + one
  Aadhaar hash = one account, ever. Enforced at database level with
  `unique=True` constraints. SHA-256 hash of Aadhaar stored — raw
  Aadhaar never persisted.

- **Layer 2 — Concurrent Claim Block (at trigger time):** 4-hour
  cooldown window. First claim proceeds, second silently blocked.
  Worker is not penalised.

- **Layer 3 — Weekly Cap (at trigger time):** Total payouts cannot
  exceed declared weekly earnings. Second payout automatically trimmed
  to fit remaining cap headroom.

- **Layer 4 — ML Behavioral Scoring (ongoing):** `concurrent_attempts`
  and `blocked_claims_week` fed as features into the fraud model.
  Repeated probing raises fraud probability score over time.

**Isolation Forest signals:**
- Delivery pattern anomaly — GPS trace inconsistent with historical
  workday pattern
- Activity paradox check — deliveries completed during claimed
  disruption window
- Cross-worker correlation — graph clustering of suspiciously similar
  claim histories
- Trigger timing manipulation — LSTM detecting strategic pre-trigger
  work cessation
- Frequency outlier — claims >2 standard deviations above zone peers

---

### Module 3 — Earnings Imputation Model

**Purpose:** Independently estimate a worker's likely earnings for any
given time window based on zone, time of day, day of week, and weather
conditions — without relying on declared figures. Used to cross-check
declared baselines and as a fallback when Swiggy Partner API is
unavailable.

**Model:** XGBoost regression on historical peer earnings data.

---

### Module 4 — Bandh / Civic Trigger NLP Classifier

**Purpose:** Output a confidence score (0.0–1.0) for civic disruption
claims rather than binary verified/unverified. Confidence thresholds
and routing logic detailed under Trigger 2 above.

**Model:** Fine-tuned BERT classifier on Indian civic disruption news
corpus.

---

### Module 5 — Weather API Disagreement Resolver

**Purpose:** When OpenWeatherMap and IMD disagree on ground conditions,
determine which source to trust for that specific zone, season, and
weather type — based on historical divergence cases cross-referenced
against actual Swiggy GPS activity drops as ground truth.

**Model:** Lightweight XGBoost trained on historical API divergence vs.
observed delivery activity drops.

---

### Module 6 — Predictive Risk Calendar

**Purpose:** 30-day zone-level disruption probability forecast used for
in-app worker alerts, pre-adjusting Monday premiums, and insurer admin
dashboard predictions.

**Model:** Prophet / SARIMA time-series on historical IMD + CPCB data.

---

### Module 7 — Churn Prediction + Proactive Retention

**Purpose:** Predict which workers are likely to cancel their weekly
mandate in the next 2 weeks and trigger a proactive in-app message
before they do.

*Example: "Chennai's northeast monsoon starts in 3 weeks — this is
exactly when your coverage matters most. Stay covered."*

**Model:** Logistic regression on weekly engagement, premium delta, and
claim history features.

---

### Module 8 — Hyperlocal Micro-Zone Learning

**Purpose:** As claims data accumulates, learn sub-ward micro-zones —
specific street clusters that flood first, intersections that jam
hardest — and re-price workers operating in high-risk micro-zones
within generally moderate wards. A genuine long-term competitive moat
— no insurer has this resolution of ground-truth data today.

**Model:** DBSCAN spatial clustering on GPS + claims data feeding back
into the premium engine.

---

### Module 9 — Cold Start Fraud Baseline for New Workers

**Purpose:** Bootstrap a new worker's initial fraud risk score using
peer similarity — find the 20 most similar existing workers and inherit
a weighted average of their fraud profile. Prevents treating every new
worker as zero-risk by default.

**Model:** KNN similarity on worker metadata features.

---

### Module 10 — Explainable AI (XAI) Layer

**Purpose:** Every fraud score is accompanied by a human-readable
explanation of the specific signals that drove it — for regulatory
compliance, admin reviewer efficiency, and worker appeal fairness.

**Model:** SHAP (SHapley Additive exPlanations) on top of all fraud
model outputs.

**Example admin dashboard output for a flagged claim:**

| Signal | Contribution | Direction |
|--------|-------------|-----------|
| Worker stationary 6hrs before trigger | +31% | Toward fraud |
| Cell tower mismatch detected | +24% | Toward fraud |
| Concurrent claim attempt | +18% | Toward fraud |
| 4-week clean claim history | -12% | Away from fraud |
| Zone density normal for event | -8% | Away from fraud |
| **Final fraud score** | **73%** | **Hard flag** |

**Three places XAI surfaces:**

1. **Admin dashboard:** Full SHAP breakdown per flagged claim alongside
   one-tap approve or escalate.

2. **Worker appeal flow:** Plain language explanation when a claim is
   held — never showing a raw score, never using the word fraud:
   > *"Our system flagged an unusual signal during your claim window.
   > This may be due to network conditions in your area. Your case is
   > under review and you will not lose your claim."*

3. **Compliance export:** Weekly PDF audit trail of all automated claim
   decisions with full SHAP breakdowns — exportable for IRDAI
   regulatory submission.

**Why this matters beyond the product:**
IRDAI and international insurance regulators increasingly require that
automated claim decisions be explainable and auditable. A black-box
fraud score is not an auditable decision. Showing SHAP explainability
at Phase 1 signals that delisure is built for real-world deployment,
not just a hackathon demo.

<img width="963" height="875" alt="image" src="https://github.com/user-attachments/assets/6c4d6d6d-a70c-4edf-ab2a-4774f0746602" />

---

## Adversarial Defense & Anti-Spoofing Strategy

> A syndicate of 500 workers organizing via Telegram, running GPS-spoofing
> apps while sitting at home, drained a competitor's liquidity pool in
> hours. Simple GPS verification is obsolete. Here is how delisure is
> built differently.

---

### The Threat Model

The attack is coordinated — workers spoof their GPS into a red-alert
zone and submit simultaneous claims. The system sees 500 stranded
workers. They are all at home. delisure's defense does not rely on
GPS alone. It builds a multi-signal truth layer that a spoofing app
cannot replicate.

---

### 1. Differentiating a Genuine Worker from a Spoofer

| Signal | What it checks | Why it can't be faked |
|--------|---------------|----------------------|
| Accelerometer & Gyroscope | Is the device moving like a two-wheeler in a flood? | A person sitting at home produces flat stationary motion data |
| Cell Tower Triangulation | Does the connected cell tower match the GPS-claimed location? | A worker spoofing to Velachery while in Ambattur connects to Ambattur towers |
| Historical Mobility Pattern | Has this worker ever been in this zone at this time on equivalent days? | Sudden appearance in a new zone at trigger time is a strong anomaly |
| Battery & Charging State | Is battery draining like active riding or stable like plugged in at home? | Spoofing apps don't simulate battery drain |
| App Interaction Pattern | Is device behavior human (scrolling, dwell time) or automated (no noise)? | Scripts produce inhuman interaction patterns |
| Swiggy Activity Cross-Check | Did any deliveries complete during the trigger window? | Active delivery pings directly contradict the claim |

---

### 2. Detecting a Coordinated Fraud Ring

| Data Point | What it reveals |
|------------|----------------|
| Claim simultaneity spike | Genuine events produce rolling claim waves. Rings fire simultaneously the moment a threshold is crossed |
| Social graph clustering | Workers in the same fraud ring share registration cohort, device fingerprint, cell tower at registration, and UPI contact overlap — dense subgraphs surface in Neo4j |
| Device fingerprint uniformity | Spoofing apps distributed through Telegram produce identical GPS update intervals across many devices |
| Zone density anomaly | A zone that normally has 12 active workers suddenly showing 87 at trigger time is itself the fraud signal |
| Pre-trigger registration surge | New registrations or zone-change requests spiking hours before a trigger fires signal coordinated pre-positioning |

---

### 3. The UX Balance — Flagged Claims Without Punishing Honest Workers

A genuine worker in a flood zone may have poor GPS signal, patchy cell
coverage, inconsistent accelerometer data, and a dead battery from
riding in the rain all day. They look like a spoofer on several
individual signals. The system must not punish them.

**Tier 1 — Clean Pass:** All signals consistent. Payout releases within
2 hours. Worker experiences nothing unusual.

**Tier 2 — Soft Hold:** One or two signals inconsistent but overall
score below hard threshold. Payout held maximum 4 hours while system
passively collects additional signal. If signals remain ambiguous,
claim auto-approves at 50% with notification:
> *"We detected some signal issues — possibly due to network conditions
> in your area. Your payout has been partially processed. Tap here to
> request a full review."*

**Tier 3 — Hard Flag:** Multiple high-confidence signals — cell tower
mismatch, mock location app detected, ring membership confirmed. Payout
withheld, manual review triggered. Worker notified without accusation:
> *"We need to verify a few details before processing your payout.
> This usually takes under 24 hours. You won't lose your claim."*

**The core principle:** A genuine worker who triggers a false positive
experiences a delay, not a denial.

---

### Why This Architecture Is Spoofing-Resistant

GPS spoofing apps can fake coordinates. They cannot simultaneously fake
accelerometer data consistent with outdoor riding, match cell towers to
a spoofed location, replicate a years-long mobility history, produce
human app interaction patterns, or suppress the zone density anomaly
that 500 simultaneous claims creates. Each layer is individually
defeatable. Defeating all simultaneously at fraud-ring scale is not
practically achievable.

---

## Why Mobile, Not Web

**1. The user lives on his phone.**
Arjun's entire financial life — GPay, Swiggy Partner app, WhatsApp,
banking — runs on a mid-range Android. A native app meets him where
he already is.

**2. Push notifications are the core product moment.**
The most important UX in delisure is Arjun receiving a notification
that money is on its way before he even realises a trigger fired.
Firebase push via Flutter is significantly more reliable than web
notifications.

**3. Sensor access for fraud detection.**
Background GPS, accelerometer, gyroscope, and cell tower data are all
required for the anti-spoofing architecture. Flutter's `geolocator` and
`sensors_plus` packages provide clean, permission-compliant access to
all of these. Mobile browsers cannot.

Single Dart codebase compiling natively for Android and iOS. Optimised
for 2GB RAM, Android 9+.

---

## Tech Stack

<img width="1639" height="665" alt="image" src="https://github.com/user-attachments/assets/3f7b5f7e-7c17-4f5a-b6d2-4f647eaf3f2b" />

---

## Development Plan

### Phase 1 — Ideation & Foundation (Mar 4–20) ← current
- [x] Problem definition and persona research
- [x] Premium model and trigger threshold design
- [x] Tech stack and architecture decisions
- [x] AI/ML module planning across all 10 modules
- [x] Adversarial defense and anti-spoofing architecture
- [x] Flutter app skeleton — 4 screens (onboarding, home, trigger
      alert, payout confirmation)
- [x] GitHub repository setup
- [x] 2-minute strategy and prototype video

### Phase 2 — Automation & Protection (Mar 21 – Apr 4)
- [ ] Full worker onboarding and KYC flow (Flutter)
- [ ] Insurance policy management screens
- [ ] XGBoost premium model v1 integrated
- [ ] Weather & climate trigger group live (rainfall, heat, AQI, gauge)
- [ ] Civic & political trigger group live (bandh + election)
- [ ] 4-layer fraud defense stack integrated
- [ ] Anti-spoofing sensor fusion layer v1
- [ ] End-to-end claims flow: trigger → fraud check → payout
- [ ] Tiered claim response (clean pass / soft hold / hard flag)
- [ ] SHAP explainability on admin dashboard v1
- [ ] Razorpay test mode UPI simulation

### Phase 3 — Scale & Optimise (Apr 5–17)
- [ ] Isolation Forest fraud engine integrated
- [ ] Graph ring detection (Neo4j + PyTorch Geometric)
- [ ] LSTM trigger timing manipulation detector
- [ ] BERT civic disruption classifier with confidence scoring
- [ ] Traffic paralysis + outage + order volume collapse triggers live
- [ ] Cyclone pre-emptive trigger
- [ ] Churn prediction + proactive retention
- [ ] Micro-zone learning pipeline v1
- [ ] Worker appeal flow with plain-language XAI
- [ ] Compliance PDF export (SHAP audit trail)
- [ ] Worker dashboard + insurer admin dashboard
- [ ] Full end-to-end demo: simulated cyclone → trigger fires →
      anti-spoofing passes → UPI payout credited
- [ ] Final pitch deck + 5-minute walkthrough video

## Demo

https://github.com/user-attachments/assets/e02938c0-46de-4b23-93ef-82212c60d1ab

https://github.com/user-attachments/assets/adec701e-c71f-45d0-8752-53d10c84eb85

---

*Guidewire DEVTrails 2026 — Unicorn Chase*
*Demo video: [link]*
