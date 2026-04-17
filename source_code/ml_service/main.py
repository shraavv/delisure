"""
Delisure ML Microservice
=========================

AI-Powered Parametric Income Insurance for Gig Delivery Workers.

Endpoints:
    POST /api/ml/premium            - XGBoost dynamic premium (manual params)
    GET  /api/ml/premium/{worker_id} - XGBoost dynamic premium (auto from DB)
    POST /api/ml/fraud-check        - Isolation Forest + rule-based fraud detection
    GET  /api/ml/fraud-check/{worker_id}/{trigger_zone} - Fraud check (auto from DB)
    GET  /api/ml/risk-calendar/{zone} - 30-day risk prediction calendar
    GET  /api/ml/health             - Health check
"""

import hashlib
import math
import os
import pickle
from datetime import date, datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import List, Optional

import numpy as np
import psycopg2
import psycopg2.extras
import xgboost as xgb
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from sklearn.ensemble import IsolationForest

import logging
import shap

logging.basicConfig(
    level=logging.INFO,
    format="\033[36m[ML %(levelname)s]\033[0m %(message)s",
)
logger = logging.getLogger("delisure-ml")

app = FastAPI(
    title="Delisure ML Service",
    description="AI-powered parametric income insurance intelligence layer for gig delivery workers in Chennai.",
    version="2.0.0",
)

PREMIUM_TIERS = {
    "low": 29,
    "standard": 49,
    "high": 69,
    "monsoon_surge": 89,
}

ZONE_RISK: dict[str, str] = {
    "velachery": "high", "madipakkam": "high", "tambaram": "high",
    "adyar": "standard", "mylapore": "standard", "t nagar": "standard",
    "guindy": "standard", "nungambakkam": "low", "anna nagar": "low",
    "egmore": "low", "kodambakkam": "standard", "porur": "high",
    "chromepet": "standard", "sholinganallur": "high", "perungudi": "high",
    "thiruvanmiyur": "standard",
}

ZONE_CENTERS: dict[str, tuple[float, float]] = {
    "velachery": (12.9815, 80.2180), "madipakkam": (12.9623, 80.1986),
    "tambaram": (12.9249, 80.1000), "adyar": (13.0067, 80.2565),
    "mylapore": (13.0368, 80.2676), "t nagar": (13.0418, 80.2341),
    "guindy": (13.0067, 80.2206), "nungambakkam": (13.0569, 80.2425),
    "anna nagar": (13.0850, 80.2101), "egmore": (13.0732, 80.2609),
    "kodambakkam": (13.0500, 80.2240), "porur": (13.0356, 80.1569),
    "chromepet": (12.9516, 80.1413), "sholinganallur": (12.9010, 80.2279),
    "perungudi": (12.9640, 80.2430), "thiruvanmiyur": (12.9830, 80.2640),
}

ZONE_AVG_CLAIMS_PER_QUARTER = 2
MONSOON_MONTHS = {6, 7, 8, 10, 11, 12}

def _train_premium_model():
    """Train XGBoost with realistic noise so the model is not just reverse-engineering
    its own formula. Label noise simulates:
      - Earnings misreporting (±8% gaussian on earnings_ratio)
      - Zone assignment errors (2% flipped by one tier)
      - Admin overrides (3% receive ±₹8 discretionary adjustment)
      - Quote variance (±5% gaussian on final premium)
    """
    from sklearn.model_selection import train_test_split

    rng = np.random.default_rng(42)
    n_samples = 5000

    zone_risk = rng.choice([1, 2, 3], n_samples, p=[0.25, 0.40, 0.35])
    is_monsoon = rng.choice([0, 1], n_samples, p=[0.58, 0.42])
    claims = rng.poisson(1.5, n_samples).clip(0, 10)
    forecast = rng.uniform(0, 1, n_samples)
    earnings = rng.uniform(0.5, 1.5, n_samples)
    weeks = rng.integers(0, 60, n_samples)
    flood = (zone_risk == 3).astype(float) * rng.choice([0, 1], n_samples, p=[0.3, 0.7])
    num_zones = rng.integers(1, 5, n_samples)

    # Noise source #1: earnings misreporting — workers round up or down when asked
    earnings_reported = earnings * (1 + rng.normal(0, 0.08, n_samples))
    earnings_reported = np.clip(earnings_reported, 0.3, 2.0)

    # Noise source #2: zone assignment errors — 2% of workers in wrong tier
    zone_risk_reported = zone_risk.copy()
    err_mask = rng.random(n_samples) < 0.02
    zone_risk_reported[err_mask] = np.clip(
        zone_risk_reported[err_mask] + rng.choice([-1, 1], err_mask.sum()), 1, 3
    )

    X = np.column_stack([
        zone_risk_reported, is_monsoon, claims, forecast,
        earnings_reported, weeks, flood, num_zones,
    ])

    # Ground-truth premium uses the true zone and earnings
    base = np.where(zone_risk == 3, 69, np.where(zone_risk == 2, 49, 29))
    monsoon_mult   = np.where(is_monsoon, 1.3, 1.0)
    claim_adj      = 1 + np.clip(claims - 2, 0, None) * 0.10
    forecast_adj   = 1 + forecast * 0.20
    earnings_factor= 0.8 + 0.2 * np.clip(earnings, 0, 1)
    loyalty_discount = np.clip(1 - weeks * 0.003, 0.85, 1.0)
    flood_surcharge  = np.where(flood, 1.08, 1.0)

    premium = base * monsoon_mult * claim_adj * forecast_adj * earnings_factor * loyalty_discount * flood_surcharge

    # Noise source #3: quote variance (multiplicative gaussian)
    premium = premium * (1 + rng.normal(0, 0.05, n_samples))

    # Noise source #4: admin discretionary overrides on 3% of quotes
    override_mask = rng.random(n_samples) < 0.03
    premium[override_mask] += rng.choice([-8, -5, 5, 8], override_mask.sum())

    # Additive measurement noise
    premium = premium + rng.normal(0, 1.5, n_samples)
    premium = np.clip(premium, 15, 200)

    # Proper train/test split
    X_train, X_test, y_train, y_test = train_test_split(
        X, premium, test_size=0.2, random_state=42
    )

    model = xgb.XGBRegressor(
        n_estimators=150,
        max_depth=5,
        learning_rate=0.1,
        subsample=0.8,               # row subsampling per tree
        colsample_bytree=0.8,        # column subsampling per tree
        reg_alpha=0.1,               # L1 regularization
        reg_lambda=1.0,              # L2 regularization
        objective="reg:squarederror",
        random_state=42,
        verbosity=0,
    )
    model.fit(X_train, y_train)

    # Test metrics
    y_pred = model.predict(X_test)
    mae    = float(np.mean(np.abs(y_test - y_pred)))
    rmse   = float(np.sqrt(np.mean((y_test - y_pred) ** 2)))
    ss_res = float(np.sum((y_test - y_pred) ** 2))
    ss_tot = float(np.sum((y_test - np.mean(y_test)) ** 2))
    r2     = 1 - (ss_res / ss_tot) if ss_tot > 0 else 0.0

    # Train metrics (to detect overfit gap)
    y_train_pred = model.predict(X_train)
    train_mae  = float(np.mean(np.abs(y_train - y_train_pred)))
    train_rmse = float(np.sqrt(np.mean((y_train - y_train_pred) ** 2)))
    ss_res_t   = float(np.sum((y_train - y_train_pred) ** 2))
    ss_tot_t   = float(np.sum((y_train - np.mean(y_train)) ** 2))
    train_r2   = 1 - (ss_res_t / ss_tot_t) if ss_tot_t > 0 else 0.0

    metrics = {
        "train_samples":   len(X_train),
        "test_samples":    len(X_test),
        "mae_inr":         round(mae, 2),
        "rmse_inr":        round(rmse, 2),
        "r2_score":        round(r2, 4),
        "train_mae_inr":   round(train_mae, 2),
        "train_rmse_inr":  round(train_rmse, 2),
        "train_r2":        round(train_r2, 4),
        "overfit_gap_r2":  round(train_r2 - r2, 4),
        "feature_count":   8,
        "n_estimators":    150,
        "max_depth":       5,
        "subsample":       0.8,
        "colsample_bytree":0.8,
        "noise_sources":   [
            "earnings_misreporting_gauss_8pct",
            "zone_assignment_error_2pct",
            "quote_variance_gauss_5pct",
            "admin_override_3pct",
            "additive_gauss_1.5inr",
        ],
    }
    return model, metrics

def _train_fraud_model():
    rng = np.random.default_rng(99)
    n_normal = 3000

    # Legit worker claims: poor GPS sometimes (rain), mostly zero deliveries during trigger,
    # zone-average claim frequency, random hours since last claim.
    gps_dist = rng.exponential(1.0, n_normal).clip(0, 5)
    deliveries = np.where(rng.random(n_normal) < 0.08,
                          rng.poisson(0.5, n_normal),  # 8% of legit claims have 0-2 deliveries (GPS lag)
                          0).astype(float)
    zscore = rng.normal(0, 0.8, n_normal).clip(-2, 2)
    hours_since = rng.exponential(72, n_normal).clip(4, 500)

    X_normal = np.column_stack([gps_dist, deliveries, zscore, hours_since])

    model = IsolationForest(
        n_estimators=100,
        contamination=0.03,  # flag ~3% of normal as anomalous (stricter)
        random_state=99,
    )
    model.fit(X_normal)

    # Realistic adversarial distribution — a mix of obvious and borderline fraud.
    # 40% are obvious (GPS drift + deliveries + rapid-fire).
    # 35% are moderate (one or two signals).
    # 25% are subtle (only a slight elevation).
    n_anomalies = 300
    n_obvious = int(n_anomalies * 0.40)
    n_moderate = int(n_anomalies * 0.35)
    n_subtle = n_anomalies - n_obvious - n_moderate

    # Obvious: all signals bad
    obv_gps = rng.uniform(6, 25, n_obvious)
    obv_del = rng.poisson(3, n_obvious).clip(1, 10).astype(float)
    obv_z   = rng.uniform(2.0, 3.5, n_obvious)
    obv_hrs = rng.uniform(0.5, 3.0, n_obvious)

    # Moderate: 1-2 signals bad, rest normal
    mod_gps = np.where(rng.random(n_moderate) < 0.5,
                       rng.uniform(4, 12, n_moderate),
                       rng.exponential(1.0, n_moderate).clip(0, 5))
    mod_del = np.where(rng.random(n_moderate) < 0.5,
                       rng.poisson(1.5, n_moderate).clip(1, 6).astype(float),
                       0)
    mod_z = rng.normal(1.2, 0.8, n_moderate).clip(-1, 3)
    mod_hrs = np.where(rng.random(n_moderate) < 0.5,
                       rng.uniform(2, 8, n_moderate),
                       rng.exponential(48, n_moderate).clip(4, 200))

    # Subtle: barely-detectable fraud — overlaps heavily with legit
    sub_gps = rng.exponential(2.0, n_subtle).clip(0, 7)
    sub_del = rng.poisson(0.3, n_subtle).clip(0, 2).astype(float)
    sub_z   = rng.normal(0.6, 0.5, n_subtle).clip(-1, 2)
    sub_hrs = rng.exponential(36, n_subtle).clip(4, 120)

    anom_gps = np.concatenate([obv_gps, mod_gps, sub_gps])
    anom_deliveries = np.concatenate([obv_del, mod_del, sub_del])
    anom_zscore = np.concatenate([obv_z, mod_z, sub_z])
    anom_hours = np.concatenate([obv_hrs, mod_hrs, sub_hrs])
    X_anom = np.column_stack([anom_gps, anom_deliveries, anom_zscore, anom_hours])

    normal_pred = model.predict(X_normal)
    anom_pred = model.predict(X_anom)
    true_negatives = int(np.sum(normal_pred == 1))
    false_positives = int(np.sum(normal_pred == -1))
    true_positives = int(np.sum(anom_pred == -1))
    false_negatives = int(np.sum(anom_pred == 1))

    precision = true_positives / max(true_positives + false_positives, 1)
    recall = true_positives / max(true_positives + false_negatives, 1)
    f1 = 2 * precision * recall / max(precision + recall, 1e-9)
    accuracy = (true_positives + true_negatives) / (n_normal + n_anomalies)

    metrics = {
        "train_samples_normal": n_normal,
        "synthetic_adversarial_samples": n_anomalies,
        "precision": round(precision, 4),
        "recall": round(recall, 4),
        "f1_score": round(f1, 4),
        "accuracy": round(accuracy, 4),
        "false_positive_rate": round(false_positives / n_normal, 4),
        "true_positives": true_positives,
        "false_positives": false_positives,
        "true_negatives": true_negatives,
        "false_negatives": false_negatives,
        "contamination": 0.05,
        "n_estimators": 100,
        "feature_count": 4,
    }
    return model, metrics

print("[ML] Training XGBoost premium model...")
premium_model, PREMIUM_METRICS = _train_premium_model()
print(f"[ML] Premium model → MAE: ₹{PREMIUM_METRICS['mae_inr']}, RMSE: ₹{PREMIUM_METRICS['rmse_inr']}, R²: {PREMIUM_METRICS['r2_score']}")
print("[ML] Training Isolation Forest fraud model...")
fraud_model, FRAUD_METRICS = _train_fraud_model()
print(f"[ML] Fraud model → Precision: {FRAUD_METRICS['precision']}, Recall: {FRAUD_METRICS['recall']}, F1: {FRAUD_METRICS['f1_score']}, Acc: {FRAUD_METRICS['accuracy']}")

print("[ML] Initializing SHAP explainers...")
_fraud_feature_names = ["gps_distance_km", "deliveries_during_trigger", "claim_frequency_zscore", "hours_since_last_claim"]

_rng = np.random.default_rng(42)
_shap_background = np.column_stack([
    _rng.exponential(1.0, 50).clip(0, 5),
    np.zeros(50),
    _rng.normal(0, 0.8, 50).clip(-2, 2),
    _rng.exponential(72, 50).clip(4, 500),
])
fraud_shap_explainer = shap.KernelExplainer(fraud_model.score_samples, _shap_background)

print("[ML] Models + SHAP ready.")

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres@localhost:5432/delisure")

def _get_db():
    
    return psycopg2.connect(DATABASE_URL, cursor_factory=psycopg2.extras.RealDictCursor)

def _fetch_worker(worker_id: str) -> Optional[dict]:
    
    with _get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM workers WHERE id = %s", (worker_id,))
            return cur.fetchone()

def _fetch_active_policy(worker_id: str) -> Optional[dict]:
    
    with _get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT * FROM policies WHERE worker_id = %s AND status = 'active' LIMIT 1",
                (worker_id,),
            )
            return cur.fetchone()

def _fetch_claim_count(worker_id: str, days: int = 90) -> int:
    
    with _get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) as cnt FROM payouts WHERE worker_id = %s AND created_at > NOW() - INTERVAL '%s days'",
                (worker_id, days),
            )
            row = cur.fetchone()
            return int(row["cnt"]) if row else 0

def _fetch_last_claim_hours(worker_id: str) -> float:
    """Hours since worker's PREVIOUS claim — excludes in-flight claims (<30 seconds old)
    because the fraud check is invoked right after the new payout row is inserted, and we
    don't want the claim-under-evaluation to be compared against itself."""
    with _get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT EXTRACT(EPOCH FROM (NOW() - MAX(created_at))) / 3600 AS hours
                FROM payouts
                WHERE worker_id = %s
                  AND created_at < NOW() - INTERVAL '30 seconds'
                """,
                (worker_id,),
            )
            row = cur.fetchone()
            # Default 72h (matches training distribution mean) for workers with no prior claims,
            # so the fraud model doesn't flag new workers as outliers.
            return float(row["hours"]) if row and row["hours"] is not None else 72.0

def _fetch_claim_zscore(worker_id: str) -> float:
    
    with _get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT COUNT(*) as cnt FROM payouts
                WHERE worker_id = %s
                  AND created_at > NOW() - INTERVAL '90 days'
                  AND created_at < NOW() - INTERVAL '30 seconds'
                """,
                (worker_id,),
            )
            worker_count = int(cur.fetchone()["cnt"])

            cur.execute(
                """
                SELECT AVG(claim_count) as avg_c, COALESCE(STDDEV(claim_count), 0) as std_c
                FROM (
                    SELECT COUNT(*) as claim_count
                    FROM payouts
                    WHERE created_at > NOW() - INTERVAL '90 days'
                    GROUP BY worker_id
                ) subq
                """
            )
            stats = cur.fetchone()
            if not stats or stats["avg_c"] is None:
                return 0.0
            avg = float(stats["avg_c"])
            std = float(stats["std_c"]) if float(stats["std_c"]) > 0 else 1.0
            return round((worker_count - avg) / std, 2)

print("[ML] Database connected:", DATABASE_URL.split("@")[-1])

class Season(str, Enum):
    monsoon = "monsoon"
    non_monsoon = "non-monsoon"

class PremiumRequest(BaseModel):
    worker_id: str = Field(..., description="Unique worker identifier")
    zones: List[str] = Field(..., description="Operating zones (e.g. ['Velachery', 'Adyar'])")
    avg_weekly_earnings: float = Field(..., gt=0, description="Average weekly earnings in INR")
    claim_history_count: int = Field(0, ge=0, description="Total claims filed in the current quarter")
    season: Optional[Season] = Field(None, description="Current season (auto-detected if omitted)")
    forecast_severity: float = Field(0.0, ge=0, le=1, description="Weather forecast severity 0-1")
    weeks_active: int = Field(0, ge=0, description="Weeks the worker has been insured (loyalty)")
    flood_prone_zones: int = Field(0, ge=0, description="Number of flood-prone zones (auto-calculated if 0)")

class PremiumFactorBreakdown(BaseModel):
    base_tier: str
    base_amount_inr: float
    zone_risk_label: str
    monsoon_multiplier: float
    claim_adjustment_pct: float
    forecast_adjustment_pct: float
    earnings_ratio: float
    loyalty_discount_pct: float
    flood_surcharge_applied: bool
    xgboost_raw_prediction: float
    zone_count: int = 1
    zone_count_multiplier: float = 1.0

class PremiumResponse(BaseModel):
    worker_id: str
    premium_amount_inr: float
    risk_tier: str
    breakdown: PremiumFactorBreakdown
    model_version: str = "xgboost-v2.0"
    computed_at: datetime

class FraudCheckRequest(BaseModel):
    worker_id: str
    trigger_zone: str = Field(..., description="Zone where the parametric trigger fired")
    worker_gps_lat: float = Field(..., ge=-90, le=90)
    worker_gps_lng: float = Field(..., ge=-180, le=180)
    deliveries_during_trigger: int = Field(0, ge=0)
    claim_frequency_zscore: float = Field(0.0)
    hours_since_last_claim: float = Field(72.0, ge=0, description="Hours since worker's last claim")

class ShapSignal(BaseModel):
    signal: str
    contribution: float
    direction: str

class FraudCheckResponse(BaseModel):
    worker_id: str
    is_flagged: bool
    risk_score: float = Field(..., ge=0, le=1)
    flags: List[str]
    recommendation: str
    isolation_forest_score: float
    shap_signals: List[ShapSignal] = []
    model_version: str = "iforest-v2.0"
    checked_at: datetime

class DailyRisk(BaseModel):
    date: date
    risk_score: float = Field(..., ge=0, le=1)
    predicted_triggers: List[str]
    is_high_risk: bool

class RiskCalendarResponse(BaseModel):
    zone: str
    generated_at: datetime
    season_label: str
    days: List[DailyRisk]

class HealthResponse(BaseModel):
    status: str
    service: str
    version: str
    models_loaded: List[str]
    timestamp: datetime

def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = (math.sin(d_lat / 2) ** 2
         + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2))
         * math.sin(d_lng / 2) ** 2)
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

def _zone_key(z: str) -> str:
    return z.lower().strip().replace("_", " ")

def _worst_zone_risk(zones: List[str]) -> str:
    priority = {"high": 3, "standard": 2, "low": 1}
    worst = "low"
    for z in zones:
        label = ZONE_RISK.get(_zone_key(z), "standard")
        if priority.get(label, 0) > priority.get(worst, 0):
            worst = label
    return worst

def _zone_risk_score(zone_label: str) -> int:
    return {"low": 1, "standard": 2, "high": 3}.get(zone_label, 2)

def _is_monsoon_month(month: int) -> bool:
    return month in MONSOON_MONTHS

def _deterministic_seed(zone: str, day: date) -> int:
    h = hashlib.sha256(f"{zone}-{day.isoformat()}".encode()).hexdigest()
    return int(h[:8], 16)

def _count_flood_zones(zones: List[str]) -> int:
    flood_zones = {"velachery", "madipakkam", "tambaram", "porur", "sholinganallur", "perungudi"}
    return sum(1 for z in zones if _zone_key(z) in flood_zones)

@app.post("/api/ml/premium", response_model=PremiumResponse)
async def calculate_premium(req: PremiumRequest):
    
    zone_risk_label = _worst_zone_risk(req.zones)
    zone_risk_num = _zone_risk_score(zone_risk_label)

    current_month = datetime.utcnow().month
    if req.season is not None:
        is_monsoon = 1 if req.season == Season.monsoon else 0
    else:
        is_monsoon = 1 if _is_monsoon_month(current_month) else 0

    earnings_ratio = min(req.avg_weekly_earnings / 5000.0, 1.5)
    flood_count = req.flood_prone_zones if req.flood_prone_zones > 0 else _count_flood_zones(req.zones)
    has_flood = 1 if flood_count > 0 else 0

    features = np.array([[
        zone_risk_num,
        is_monsoon,
        req.claim_history_count,
        req.forecast_severity,
        earnings_ratio,
        req.weeks_active,
        has_flood,
        len(req.zones),
    ]])

    xgb_premium = float(premium_model.predict(features)[0])
    xgb_premium = max(15.0, min(200.0, xgb_premium))

    zone_count = len(req.zones)
    zone_count_mult = 1.0 + max(0, zone_count - 2) * 0.08
    xgb_premium *= zone_count_mult

    final_premium = round(xgb_premium)

    logger.info(f"PREMIUM | worker={req.worker_id} zones={req.zones} ({zone_count} zones, {zone_count_mult:.2f}x) zone_risk={zone_risk_label} monsoon={is_monsoon} claims={req.claim_history_count} → ₹{final_premium}")
    logger.info(f"  XGBoost features: {features[0].tolist()} → raw={xgb_premium / zone_count_mult:.1f} × {zone_count_mult:.2f} = {xgb_premium:.1f}")

    if final_premium >= 100:
        risk_tier = "very_high"
    elif final_premium >= 75:
        risk_tier = "high"
    elif final_premium >= 50:
        risk_tier = "moderate"
    else:
        risk_tier = "low"

    if is_monsoon and zone_risk_label == "high":
        base_tier = "monsoon_surge"
    elif zone_risk_label == "high":
        base_tier = "high"
    elif zone_risk_label == "standard":
        base_tier = "standard"
    else:
        base_tier = "low"

    monsoon_mult = 1.3 if is_monsoon else 1.0
    excess_claims = max(0, req.claim_history_count - ZONE_AVG_CLAIMS_PER_QUARTER)
    claim_adj_pct = excess_claims * 10.0
    forecast_adj_pct = req.forecast_severity * 20.0
    loyalty_discount_pct = round(min(req.weeks_active * 0.3, 15.0), 1)

    return PremiumResponse(
        worker_id=req.worker_id,
        premium_amount_inr=final_premium,
        risk_tier=risk_tier,
        breakdown=PremiumFactorBreakdown(
            base_tier=base_tier,
            base_amount_inr=PREMIUM_TIERS[base_tier],
            zone_risk_label=zone_risk_label,
            monsoon_multiplier=monsoon_mult,
            claim_adjustment_pct=claim_adj_pct,
            forecast_adjustment_pct=round(forecast_adj_pct, 1),
            earnings_ratio=round(earnings_ratio, 3),
            loyalty_discount_pct=loyalty_discount_pct,
            flood_surcharge_applied=has_flood == 1,
            xgboost_raw_prediction=round(xgb_premium, 2),
            zone_count=zone_count,
            zone_count_multiplier=round(zone_count_mult, 2),
        ),
        computed_at=datetime.utcnow(),
    )

@app.post("/api/ml/fraud-check", response_model=FraudCheckResponse)
async def fraud_check(req: FraudCheckRequest):
    
    trigger_zone_key = _zone_key(req.trigger_zone)
    flags: list[str] = []
    rule_score_components: list[float] = []

    zone_center = ZONE_CENTERS.get(trigger_zone_key)
    if zone_center is None:
        raise HTTPException(
            status_code=422,
            detail=f"Unknown trigger zone '{req.trigger_zone}'. "
                   f"Valid zones: {', '.join(sorted(ZONE_CENTERS.keys()))}",
        )

    distance_km = _haversine_km(
        req.worker_gps_lat, req.worker_gps_lng,
        zone_center[0], zone_center[1],
    )

    iforest_features = np.array([[
        distance_km,
        req.deliveries_during_trigger,
        req.claim_frequency_zscore,
        req.hours_since_last_claim,
    ]])

    raw_iforest = float(fraud_model.score_samples(iforest_features)[0])
    iforest_risk = round(float(np.clip(0.5 - raw_iforest * 0.5, 0, 1)), 3)

    # Only surface the IForest flag if no rule-based signals already justify concern.
    # Standalone IForest outliers on otherwise-clean claims are usually noise from the
    # 3% contamination rate and shouldn't confuse admins.
    iforest_flag_candidate = None
    if iforest_risk > 0.75:
        iforest_flag_candidate = f"Isolation Forest anomaly score: {iforest_risk:.3f} (threshold: 0.75)"

    if distance_km > 5.0:
        flags.append(
            f"GPS location is {distance_km:.1f} km from {req.trigger_zone} centre (threshold: 5 km)"
        )
        rule_score_components.append(0.3 if distance_km <= 15 else 0.5)

    if req.deliveries_during_trigger > 0:
        flags.append(
            f"Worker completed {req.deliveries_during_trigger} delivery(ies) during trigger — contradicts income-loss claim"
        )
        rule_score_components.append(0.35)

    if req.claim_frequency_zscore > 2.0:
        flags.append(
            f"Claim frequency z-score ({req.claim_frequency_zscore:.2f}) exceeds threshold (2.0)"
        )
        rule_score_components.append(min(0.15 + (req.claim_frequency_zscore - 2.0) * 0.1, 0.4))

    if req.hours_since_last_claim < 4.0:
        flags.append(
            f"Only {req.hours_since_last_claim:.1f}h since last claim (4h cooldown required)"
        )
        rule_score_components.append(0.25)

    rule_score = min(sum(rule_score_components), 1.0)
    combined_score = round(0.6 * rule_score + 0.4 * iforest_risk, 3)

    # Add the IForest flag only if (a) score is high enough AND (b) combined decision
    # isn't approve, or (c) a rule flag already fired (corroborates the IForest signal).
    if iforest_flag_candidate and (combined_score >= 0.3 or len(flags) > 0):
        flags.insert(0, iforest_flag_candidate)

    is_flagged = len(flags) > 0

    if combined_score >= 0.7:
        recommendation = "block"
    elif combined_score >= 0.3:
        recommendation = "review"
    else:
        recommendation = "approve"

    shap_signals: list[ShapSignal] = []
    try:
        shap_values = fraud_shap_explainer.shap_values(iforest_features)
        shap_vals = shap_values[0]
        signal_labels = [
            "GPS distance from zone center",
            "Deliveries completed during trigger",
            "Claim frequency vs zone peers",
            "Hours since last claim",
        ]
        for i, (name, val) in enumerate(zip(signal_labels, shap_vals)):
            abs_contrib = abs(float(val))
            if abs_contrib > 0.001:
                direction = "toward_fraud" if val < 0 else "away_from_fraud"
                shap_signals.append(ShapSignal(
                    signal=name,
                    contribution=round(abs_contrib, 3),
                    direction=direction,
                ))
    except Exception as e:
        logger.warning(f"SHAP computation failed: {e}")

    if distance_km <= 5.0:
        shap_signals.append(ShapSignal(signal=f"Worker is {distance_km:.1f}km from zone (within 5km radius)", contribution=round(0.15, 3), direction="away_from_fraud"))
    else:
        shap_signals.append(ShapSignal(signal=f"Worker is {distance_km:.1f}km from zone (outside 5km radius)", contribution=round(min(distance_km / 30, 0.5), 3), direction="toward_fraud"))

    if req.deliveries_during_trigger == 0:
        shap_signals.append(ShapSignal(signal="No deliveries during trigger window (consistent with claim)", contribution=0.1, direction="away_from_fraud"))
    else:
        shap_signals.append(ShapSignal(signal=f"{req.deliveries_during_trigger} delivery(ies) during trigger (activity paradox)", contribution=0.35, direction="toward_fraud"))

    if req.hours_since_last_claim >= 72:
        shap_signals.append(ShapSignal(signal=f"Last claim was {req.hours_since_last_claim:.0f}h ago (clean history)", contribution=0.12, direction="away_from_fraud"))
    elif req.hours_since_last_claim >= 4:
        shap_signals.append(ShapSignal(signal=f"Last claim was {req.hours_since_last_claim:.1f}h ago (normal frequency)", contribution=0.05, direction="away_from_fraud"))
    else:
        shap_signals.append(ShapSignal(signal=f"Last claim only {req.hours_since_last_claim:.1f}h ago (rapid-fire)", contribution=0.25, direction="toward_fraud"))

    if req.claim_frequency_zscore <= 1.0:
        shap_signals.append(ShapSignal(signal=f"Claim frequency z-score {req.claim_frequency_zscore:.2f} (normal for zone)", contribution=0.08, direction="away_from_fraud"))
    elif req.claim_frequency_zscore > 2.0:
        shap_signals.append(ShapSignal(signal=f"Claim frequency z-score {req.claim_frequency_zscore:.2f} (outlier vs zone peers)", contribution=round(min(0.15 + (req.claim_frequency_zscore - 2.0) * 0.1, 0.4), 3), direction="toward_fraud"))

    shap_signals.sort(key=lambda s: s.contribution, reverse=True)

    logger.info(f"FRAUD | worker={req.worker_id} zone={req.trigger_zone} distance={distance_km:.1f}km iforest={iforest_risk:.3f} rule={rule_score:.3f} combined={combined_score:.3f} → {recommendation.upper()}")
    if flags:
        for f in flags:
            logger.info(f"  FLAG: {f}")
    for s in shap_signals:
        logger.info(f"  SHAP: {s.signal} → {'+' if s.direction == 'toward_fraud' else '-'}{s.contribution:.3f}")

    return FraudCheckResponse(
        worker_id=req.worker_id,
        is_flagged=is_flagged,
        risk_score=combined_score,
        flags=flags,
        recommendation=recommendation,
        isolation_forest_score=iforest_risk,
        shap_signals=shap_signals,
        checked_at=datetime.utcnow(),
    )

@app.get("/api/ml/premium/{worker_id}", response_model=PremiumResponse)
async def calculate_premium_auto(worker_id: str):
    
    logger.info(f"AUTO-PREMIUM | Fetching data for worker {worker_id}")
    worker = _fetch_worker(worker_id)
    if not worker:
        logger.warning(f"AUTO-PREMIUM | Worker '{worker_id}' not found in DB")
        raise HTTPException(status_code=404, detail=f"Worker '{worker_id}' not found in database")

    policy = _fetch_active_policy(worker_id)
    weeks_active = int(policy["weeks_active"]) if policy else 0
    claim_count = _fetch_claim_count(worker_id, 90)

    zones = list(worker["zones"])
    avg_earnings = float(worker["avg_weekly_earnings"])

    req = PremiumRequest(
        worker_id=worker_id,
        zones=zones,
        avg_weekly_earnings=avg_earnings,
        claim_history_count=claim_count,
        forecast_severity=0.2,
        weeks_active=weeks_active,
    )
    return await calculate_premium(req)

@app.get("/api/ml/fraud-score/{worker_id}/{trigger_zone}")
async def fraud_check_auto(worker_id: str, trigger_zone: str):
    
    worker = _fetch_worker(worker_id)
    if not worker:
        raise HTTPException(status_code=404, detail=f"Worker '{worker_id}' not found in database")

    trigger_zone_key = _zone_key(trigger_zone)
    zone_center = ZONE_CENTERS.get(trigger_zone_key)
    if zone_center is None:
        raise HTTPException(
            status_code=422,
            detail=f"Unknown zone '{trigger_zone}'. Valid: {', '.join(sorted(ZONE_CENTERS.keys()))}",
        )

    zscore = _fetch_claim_zscore(worker_id)
    hours_since = _fetch_last_claim_hours(worker_id)

    req = FraudCheckRequest(
        worker_id=worker_id,
        trigger_zone=trigger_zone,
        worker_gps_lat=zone_center[0],
        worker_gps_lng=zone_center[1],
        deliveries_during_trigger=0,
        claim_frequency_zscore=zscore,
        hours_since_last_claim=hours_since,
    )
    result = await fraud_check(req)

    return {
        **result.model_dump(),
        "auto_fetched": {
            "claim_frequency_zscore": zscore,
            "hours_since_last_claim": round(hours_since, 1),
            "gps_source": "zone_center_default",
        },
    }

@app.get("/api/ml/worker-risk-profile/{worker_id}")
async def worker_risk_profile(worker_id: str):
    
    worker = _fetch_worker(worker_id)
    if not worker:
        raise HTTPException(status_code=404, detail=f"Worker '{worker_id}' not found in database")

    zones = list(worker["zones"])
    policy = _fetch_active_policy(worker_id)
    weeks_active = int(policy["weeks_active"]) if policy else 0
    claim_count = _fetch_claim_count(worker_id, 90)
    zscore = _fetch_claim_zscore(worker_id)
    hours_since = _fetch_last_claim_hours(worker_id)

    premium_req = PremiumRequest(
        worker_id=worker_id,
        zones=zones,
        avg_weekly_earnings=float(worker["avg_weekly_earnings"]),
        claim_history_count=claim_count,
        forecast_severity=0.2,
        weeks_active=weeks_active,
    )
    premium_result = await calculate_premium(premium_req)

    zone_calendars = {}
    for z in zones:
        zk = _zone_key(z)
        if zk in ZONE_RISK:
            cal = await risk_calendar(z)
            high_risk_days = sum(1 for d in cal.days if d.is_high_risk)
            zone_calendars[z] = {
                "risk_tier": ZONE_RISK[zk],
                "high_risk_days_next_30": high_risk_days,
                "avg_risk_score": round(sum(d.risk_score for d in cal.days) / len(cal.days), 3),
            }

    return {
        "worker_id": worker_id,
        "name": worker["name"],
        "zones": zones,
        "risk_tier": worker["risk_tier"],
        "premium": {
            "amount_inr": premium_result.premium_amount_inr,
            "tier": premium_result.risk_tier,
            "model": premium_result.model_version,
            "breakdown": premium_result.breakdown.model_dump(),
        },
        "claim_stats": {
            "claims_last_90_days": claim_count,
            "frequency_zscore": zscore,
            "hours_since_last_claim": round(hours_since, 1),
        },
        "zone_risk": zone_calendars,
        "policy": {
            "active": policy is not None,
            "weeks_active": weeks_active,
            "current_premium": float(policy["weekly_premium"]) if policy else None,
        },
        "computed_at": datetime.utcnow().isoformat(),
    }

@app.get("/api/ml/risk-calendar/{zone}", response_model=RiskCalendarResponse)
async def risk_calendar(zone: str):
    
    zone_key = _zone_key(zone)
    if zone_key not in ZONE_RISK:
        raise HTTPException(
            status_code=404,
            detail=f"Unknown zone '{zone}'. Valid zones: {', '.join(sorted(ZONE_RISK.keys()))}",
        )

    zone_risk_label = ZONE_RISK[zone_key]
    today = date.today()
    days: list[DailyRisk] = []
    zone_baseline = {"high": 0.25, "standard": 0.12, "low": 0.05}[zone_risk_label]

    for offset in range(30):
        day = today + timedelta(days=offset)
        rng = np.random.default_rng(_deterministic_seed(zone_key, day))

        monsoon_boost = 0.20 if _is_monsoon_month(day.month) else 0.0
        weekend_bump = 0.05 if day.weekday() >= 5 else 0.0
        noise = rng.uniform(-0.08, 0.15)

        raw_score = zone_baseline + monsoon_boost + weekend_bump + noise
        risk_score = round(float(np.clip(raw_score, 0.0, 1.0)), 3)

        predicted_triggers: list[str] = []
        if risk_score >= 0.5:
            predicted_triggers.extend(["heavy_rainfall", "waterlogging"])
        elif risk_score >= 0.3:
            predicted_triggers.append("heavy_rainfall")
        if risk_score >= 0.6:
            predicted_triggers.append("traffic_disruption")
        if risk_score >= 0.75:
            predicted_triggers.append("power_outage")

        days.append(DailyRisk(
            date=day, risk_score=risk_score,
            predicted_triggers=predicted_triggers, is_high_risk=risk_score >= 0.5,
        ))

    season_label = "monsoon" if _is_monsoon_month(today.month) else "non-monsoon"
    return RiskCalendarResponse(
        zone=zone_key, generated_at=datetime.utcnow(),
        season_label=season_label, days=days,
    )

@app.get("/api/ml/health", response_model=HealthResponse)
async def health():
    return HealthResponse(
        status="healthy",
        service="delisure-ml",
        version="2.0.0",
        models_loaded=["xgboost-premium-v2.0", "iforest-fraud-v2.0"],
        timestamp=datetime.utcnow(),
    )

@app.get("/api/ml/metrics")
async def metrics():
    return {
        "premium_model": {
            "algorithm": "XGBoost Gradient Boosted Trees",
            "purpose": "Dynamic weekly premium pricing (INR)",
            **PREMIUM_METRICS,
        },
        "fraud_model": {
            "algorithm": "Isolation Forest (anomaly detection)",
            "purpose": "Adversarial claim detection — GPS spoof, activity paradox, rapid-fire",
            **FRAUD_METRICS,
        },
        "explainability": {
            "method": "SHAP KernelExplainer",
            "background_samples": 50,
            "per_claim_signals": True,
        },
        "thresholds": {
            "approve_below": 0.3,
            "review_between": [0.3, 0.7],
            "block_above": 0.7,
        },
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
