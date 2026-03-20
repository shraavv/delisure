import '../models/worker.dart';
import '../models/policy.dart';
import '../models/trigger_event.dart';
import '../models/payout.dart';
import '../models/flagged_claim.dart';

class MockData {
  // Current Worker — Arjun, 27, Chennai (from prompt persona)
  static const Worker currentWorker = Worker(
    id: 'w-001',
    name: 'Arjun',
    swiggyPartnerId: 'SWG-CHN-28491',
    phone: '+91 98765 43210',
    zones: ['Velachery', 'Adyar', 'Thiruvanmallur'],
    avgWeeklyEarnings: 5250,
    avgActiveHoursPerWeek: 52,
    riskTier: 'Standard',
    profileImageUrl: '',
  );

  // Active Policy
  static final Policy activePolicy = Policy(
    id: 'pol-001',
    workerId: 'w-001',
    status: 'active',
    weeklyPremium: 49,
    riskTier: 'Standard',
    startDate: DateTime(2026, 1, 6),
    zones: ['Velachery', 'Adyar', 'Thiruvanmallur'],
    nextDebitDate: DateTime(2026, 3, 23),
  );

  // Active Trigger Event — heavy rainfall right now (demo)
  static final TriggerEvent activeTrigger = TriggerEvent(
    id: 'trig-001',
    type: 'rainfall',
    zone: 'Velachery',
    startTime: DateTime(2026, 3, 20, 19, 0),
    endTime: null,
    intensity: 18,
    description:
        'Heavy rainfall detected in Velachery zone. Intensity: 18mm/hr, exceeding 14mm/hr threshold for 90+ minutes. Dinner rush window affected.',
    isActive: true,
  );

  // Past Trigger Events — diverse trigger types from prompt
  static final List<TriggerEvent> pastTriggers = [
    TriggerEvent(
      id: 'trig-002',
      type: 'rainfall',
      zone: 'Adyar',
      startTime: DateTime(2026, 3, 17, 12, 0),
      endTime: DateTime(2026, 3, 17, 13, 30),
      intensity: 15,
      description: 'Heavy rain in Adyar zone during lunch hours. 15mm/hr sustained for 90 minutes.',
      isActive: false,
    ),
    TriggerEvent(
      id: 'trig-003',
      type: 'cyclone',
      zone: 'Velachery',
      startTime: DateTime(2026, 3, 6, 6, 0),
      endTime: DateTime(2026, 3, 6, 22, 0),
      intensity: 22,
      description:
          'Cyclone pre-emptive trigger. IMD cyclone warning issued 48hrs prior. Full-day disruption across Velachery and Adyar zones.',
      isActive: false,
    ),
    TriggerEvent(
      id: 'trig-004',
      type: 'aqi',
      zone: 'Chennai-wide',
      startTime: DateTime(2026, 2, 18, 13, 0),
      endTime: DateTime(2026, 2, 18, 18, 0),
      intensity: 342,
      description: 'AQI spiked to 342 (Hazardous) across Chennai. CPCB confirmed. Sustained 5 hours.',
      isActive: false,
    ),
    TriggerEvent(
      id: 'trig-005',
      type: 'traffic',
      zone: 'Velachery',
      startTime: DateTime(2026, 2, 5, 17, 0),
      endTime: DateTime(2026, 2, 5, 19, 30),
      intensity: 6,
      description: 'Traffic paralysis in Velachery. Average speed dropped below 8km/h for 150 minutes. Google Maps API confirmed.',
      isActive: false,
    ),
    TriggerEvent(
      id: 'trig-006',
      type: 'outage',
      zone: 'Velachery',
      startTime: DateTime(2026, 1, 28, 11, 0),
      endTime: DateTime(2026, 1, 28, 16, 0),
      intensity: 5,
      description: 'TANGEDCO grid power outage in Velachery for 5 hours. Restaurant order volume collapsed. Cross-validated with Swiggy order data.',
      isActive: false,
    ),
    TriggerEvent(
      id: 'trig-007',
      type: 'bandh',
      zone: 'Chennai',
      startTime: DateTime(2026, 2, 12, 6, 0),
      endTime: DateTime(2026, 2, 12, 18, 0),
      intensity: 1,
      description: 'State-declared transport bandh across Tamil Nadu. Section 144 prohibitory orders in force. Movement restrictions confirmed.',
      isActive: false,
      nlpConfidence: 0.92,
      nlpSources: 'Tamil Nadu State Government notification + NDTV + The Hindu',
    ),
    TriggerEvent(
      id: 'trig-008',
      type: 'election',
      zone: 'Chennai',
      startTime: DateTime(2026, 1, 15, 7, 0),
      endTime: DateTime(2026, 1, 15, 18, 0),
      intensity: 1,
      description: 'Municipal by-election voting day. Election Commission of India published schedule. Reduced restaurant and delivery operations.',
      isActive: false,
      nlpConfidence: 1.0,
      nlpSources: 'Election Commission of India open data',
    ),
    TriggerEvent(
      id: 'trig-009',
      type: 'order_collapse',
      zone: 'Adyar',
      startTime: DateTime(2026, 2, 22, 19, 0),
      endTime: DateTime(2026, 2, 22, 22, 0),
      intensity: 72,
      description: 'Swiggy order volume in Adyar dropped 72% vs same slot on previous 3 days. Sustained 3 hours during dinner rush. Cause unknown \u2014 trigger measures work itself.',
      isActive: false,
    ),
    TriggerEvent(
      id: 'trig-010',
      type: 'platform_outage',
      zone: 'Chennai-wide',
      startTime: DateTime(2026, 1, 20, 12, 0),
      endTime: DateTime(2026, 1, 20, 14, 30),
      intensity: 2.5,
      description: 'Swiggy Partner app returned errors for active pings across Chennai for 2.5 hours during lunch peak. No deliveries possible.',
      isActive: false,
    ),
    TriggerEvent(
      id: 'trig-011',
      type: 'heat',
      zone: 'Velachery',
      startTime: DateTime(2026, 1, 10, 11, 0),
      endTime: DateTime(2026, 1, 10, 16, 0),
      intensity: 46,
      description: 'Feels-like temperature crossed 46\u00b0C in Velachery for 5 consecutive hours. Outdoor delivery medically inadvisable.',
      isActive: false,
    ),
  ];

  // Payouts — matching trigger events
  static final List<Payout> payouts = [
    Payout(
      id: 'pay-001',
      workerId: 'w-001',
      triggerEventId: 'trig-001',
      amount: 420,
      status: 'processing',
      timestamp: DateTime(2026, 3, 20, 19, 30),
      breakdown:
          'Heavy rain in Velachery exceeded 14mm/hr for 2hrs during dinner rush (7:00\u201310:30 PM). Earning weight: 1.5\u00d7. Payout rate: 70%. Hourly baseline: \u20b9100.96. Payout: \u20b9420.',
    ),
    Payout(
      id: 'pay-002',
      workerId: 'w-001',
      triggerEventId: 'trig-002',
      amount: 280,
      status: 'credited',
      timestamp: DateTime(2026, 3, 17, 14, 0),
      breakdown:
          'Heavy rain in Adyar exceeded 14mm/hr for 1.5hrs during lunch peak (11 AM\u20133 PM). Earning weight: 1.2\u00d7. Payout rate: 60%. Payout: \u20b9280.',
    ),
    Payout(
      id: 'pay-003',
      workerId: 'w-001',
      triggerEventId: 'trig-003',
      amount: 630,
      status: 'credited',
      timestamp: DateTime(2026, 3, 6, 22, 30),
      breakdown:
          'Cyclone pre-emptive trigger. IMD warning issued 48hrs before landfall. Full-day disruption in Velachery + Adyar. 40% pre-emptive rate applied, full rates post-landfall. Payout: \u20b9630.',
    ),
    Payout(
      id: 'pay-004',
      workerId: 'w-001',
      triggerEventId: 'trig-004',
      amount: 180,
      status: 'credited',
      timestamp: DateTime(2026, 2, 18, 19, 0),
      breakdown:
          'AQI hit 342 (Hazardous) across Chennai for 5hrs (1\u20136 PM). CPCB confirmed. Afternoon window: earning weight 0.7\u00d7, payout rate 40%. Payout: \u20b9180.',
    ),
    Payout(
      id: 'pay-005',
      workerId: 'w-001',
      triggerEventId: 'trig-005',
      amount: 250,
      status: 'credited',
      timestamp: DateTime(2026, 2, 5, 20, 0),
      breakdown:
          'Traffic paralysis in Velachery. Average speed below 8km/h for 2.5hrs during evening window. Google Maps Directions API confirmed. Time-weighted replacement: \u20b9250.',
    ),
    Payout(
      id: 'pay-006',
      workerId: 'w-001',
      triggerEventId: 'trig-006',
      amount: 255,
      status: 'credited',
      timestamp: DateTime(2026, 1, 28, 16, 30),
      breakdown:
          'TANGEDCO grid outage in Velachery for 5hrs. Restaurant order capacity collapsed \u2014 kitchens down, cold storage failing. Cross-validated with Swiggy order volume drop >65%. 50% income replacement: \u20b9255.',
    ),
  ];

  // Additional payouts for new trigger types
  static final List<Payout> additionalPayouts = [
    Payout(
      id: 'pay-007',
      workerId: 'w-001',
      triggerEventId: 'trig-007',
      amount: 630,
      status: 'credited',
      timestamp: DateTime(2026, 2, 12, 19, 0),
      breakdown:
          'State-declared bandh across Tamil Nadu. NLP confidence: 0.92 (auto-triggered). Full-day disruption. 60% income replacement for declared 12-hour duration. Payout: \u20b9630.',
    ),
    Payout(
      id: 'pay-008',
      workerId: 'w-001',
      triggerEventId: 'trig-008',
      amount: 315,
      status: 'credited',
      timestamp: DateTime(2026, 1, 15, 18, 30),
      breakdown:
          'Municipal by-election voting day. EC published schedule \u2014 single verified source. 50% income replacement for official voting hours (7 AM\u20136 PM). Payout: \u20b9315.',
    ),
    Payout(
      id: 'pay-009',
      workerId: 'w-001',
      triggerEventId: 'trig-009',
      amount: 320,
      status: 'credited',
      timestamp: DateTime(2026, 2, 22, 22, 30),
      breakdown:
          'Order volume collapse in Adyar. Orders dropped 72% vs same slot, sustained 3 hours during dinner rush (7\u201310 PM). Earning weight: 1.5\u00d7. Payout: \u20b9320.',
    ),
    Payout(
      id: 'pay-010',
      workerId: 'w-001',
      triggerEventId: 'trig-010',
      amount: 200,
      status: 'credited',
      timestamp: DateTime(2026, 1, 20, 15, 0),
      breakdown:
          'Swiggy Partner app outage across Chennai for 2.5hrs during lunch peak (12\u20132:30 PM). 50% income replacement. Payout: \u20b9200.',
    ),
    Payout(
      id: 'pay-011',
      workerId: 'w-001',
      triggerEventId: 'trig-011',
      amount: 210,
      status: 'credited',
      timestamp: DateTime(2026, 1, 10, 16, 30),
      breakdown:
          'Extreme heat in Velachery. Feels-like 46\u00b0C for 5hrs (11 AM\u20134 PM). 50% afternoon window replacement. Payout: \u20b9210.',
    ),
  ];

  // Coverage stats
  static const double totalPayoutsReceived = 3690;
  static const double totalPremiumsPaid = 1176; // 24 weeks x 49
  static const double netBenefit = 2514;
  static const int weeksActive = 24;

  // Risk calendar data — 30 days for Velachery
  static final Map<DateTime, double> riskCalendarData = {
    DateTime(2026, 3, 1): 0.15,
    DateTime(2026, 3, 2): 0.10,
    DateTime(2026, 3, 3): 0.20,
    DateTime(2026, 3, 4): 0.25,
    DateTime(2026, 3, 5): 0.55,
    DateTime(2026, 3, 6): 0.92, // Cyclone day
    DateTime(2026, 3, 7): 0.70,
    DateTime(2026, 3, 8): 0.40,
    DateTime(2026, 3, 9): 0.18,
    DateTime(2026, 3, 10): 0.12,
    DateTime(2026, 3, 11): 0.08,
    DateTime(2026, 3, 12): 0.15,
    DateTime(2026, 3, 13): 0.22,
    DateTime(2026, 3, 14): 0.30,
    DateTime(2026, 3, 15): 0.35,
    DateTime(2026, 3, 16): 0.45,
    DateTime(2026, 3, 17): 0.78, // Heavy rain Adyar
    DateTime(2026, 3, 18): 0.50,
    DateTime(2026, 3, 19): 0.38,
    DateTime(2026, 3, 20): 0.85, // Today — heavy rain
    DateTime(2026, 3, 21): 0.65,
    DateTime(2026, 3, 22): 0.48,
    DateTime(2026, 3, 23): 0.30,
    DateTime(2026, 3, 24): 0.20,
    DateTime(2026, 3, 25): 0.55,
    DateTime(2026, 3, 26): 0.72,
    DateTime(2026, 3, 27): 0.40,
    DateTime(2026, 3, 28): 0.25,
    DateTime(2026, 3, 29): 0.18,
    DateTime(2026, 3, 30): 0.12,
  };

  // Next 7 days risk forecast
  static final List<double> next7DaysRisk = [
    0.85, 0.65, 0.48, 0.30, 0.20, 0.55, 0.72,
  ];

  static final List<String> next7DaysLabels = [
    'Today', 'Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu',
  ];

  // Premium payment history
  static final List<Map<String, dynamic>> premiumHistory = [
    {'week': 'Mar 16 - Mar 22', 'amount': 49.0, 'status': 'paid', 'date': DateTime(2026, 3, 16)},
    {'week': 'Mar 9 - Mar 15', 'amount': 49.0, 'status': 'paid', 'date': DateTime(2026, 3, 9)},
    {'week': 'Mar 2 - Mar 8', 'amount': 49.0, 'status': 'paid', 'date': DateTime(2026, 3, 2)},
    {'week': 'Feb 23 - Mar 1', 'amount': 49.0, 'status': 'paid', 'date': DateTime(2026, 2, 23)},
  ];

  // Chennai delivery zones for onboarding
  static const List<String> chennaiZones = [
    'Velachery',
    'Adyar',
    'Thiruvanmallur',
    'T. Nagar',
    'Anna Nagar',
    'Tambaram',
    'Porur',
    'Sholinganallur',
    'OMR',
    'Mylapore',
  ];

  // All payouts combined
  static List<Payout> get allPayouts => [...payouts, ...additionalPayouts];

  // ── Admin Dashboard Data ──────────────────────────────────────────

  // Platform-wide stats for admin view
  static const Map<String, dynamic> platformStats = {
    'totalWorkers': 2847,
    'activePolicies': 2103,
    'totalPayoutsToday': 142350,
    'triggersActiveNow': 3,
    'fraudFlagRate': 4.2,
    'avgClaimTime': '1.8 hrs',
    'weeklyPremiumPool': 103047,
    'claimsThisWeek': 312,
  };

  // Workers roster for admin (includes Arjun + others)
  static const List<Map<String, dynamic>> adminWorkers = [
    {
      'id': 'w-001', 'name': 'Arjun', 'zone': 'Velachery',
      'fraudScore': 0.08, 'claims': 11, 'status': 'clean',
      'churnRisk': 0.12, 'weeksActive': 24,
    },
    {
      'id': 'w-042', 'name': 'Priya', 'zone': 'Adyar',
      'fraudScore': 0.15, 'claims': 7, 'status': 'clean',
      'churnRisk': 0.45, 'weeksActive': 16,
    },
    {
      'id': 'w-087', 'name': 'Ravi', 'zone': 'T. Nagar',
      'fraudScore': 0.73, 'claims': 14, 'status': 'hard_flag',
      'churnRisk': 0.05, 'weeksActive': 8,
    },
    {
      'id': 'w-123', 'name': 'Deepa', 'zone': 'Tambaram',
      'fraudScore': 0.42, 'claims': 9, 'status': 'soft_hold',
      'churnRisk': 0.68, 'weeksActive': 12,
    },
    {
      'id': 'w-156', 'name': 'Karthik', 'zone': 'OMR',
      'fraudScore': 0.05, 'claims': 3, 'status': 'clean',
      'churnRisk': 0.82, 'weeksActive': 4,
    },
    {
      'id': 'w-201', 'name': 'Sundar', 'zone': 'Velachery',
      'fraudScore': 0.61, 'claims': 11, 'status': 'soft_hold',
      'churnRisk': 0.15, 'weeksActive': 20,
    },
    {
      'id': 'w-234', 'name': 'Meena', 'zone': 'Sholinganallur',
      'fraudScore': 0.03, 'claims': 5, 'status': 'clean',
      'churnRisk': 0.22, 'weeksActive': 18,
    },
  ];

  // Flagged claims with SHAP explainability
  static final List<FlaggedClaim> flaggedClaims = [
    FlaggedClaim(
      id: 'fc-001',
      workerId: 'w-087',
      workerName: 'Ravi',
      triggerEventId: 'trig-001',
      triggerType: 'rainfall',
      zone: 'T. Nagar',
      amount: 420,
      fraudScore: 0.73,
      tier: 'hard_flag',
      timestamp: DateTime(2026, 3, 20, 19, 45),
      status: 'pending_review',
      shapSignals: [
        ShapSignal(signal: 'Worker stationary 6hrs before trigger', contribution: 0.31, direction: 'toward_fraud'),
        ShapSignal(signal: 'Cell tower mismatch detected', contribution: 0.24, direction: 'toward_fraud'),
        ShapSignal(signal: 'Concurrent claim attempt blocked', contribution: 0.18, direction: 'toward_fraud'),
        ShapSignal(signal: '4-week clean claim history', contribution: 0.12, direction: 'away_from_fraud'),
        ShapSignal(signal: 'Zone density normal for event', contribution: 0.08, direction: 'away_from_fraud'),
      ],
    ),
    FlaggedClaim(
      id: 'fc-002',
      workerId: 'w-123',
      workerName: 'Deepa',
      triggerEventId: 'trig-001',
      triggerType: 'rainfall',
      zone: 'Tambaram',
      amount: 350,
      fraudScore: 0.42,
      tier: 'soft_hold',
      timestamp: DateTime(2026, 3, 20, 20, 10),
      status: 'pending_review',
      shapSignals: [
        ShapSignal(signal: 'GPS signal intermittent during window', contribution: 0.22, direction: 'toward_fraud'),
        ShapSignal(signal: 'Accelerometer data inconsistent', contribution: 0.15, direction: 'toward_fraud'),
        ShapSignal(signal: '12-week active coverage streak', contribution: 0.18, direction: 'away_from_fraud'),
        ShapSignal(signal: 'Historical zone match confirmed', contribution: 0.14, direction: 'away_from_fraud'),
        ShapSignal(signal: 'Battery drain pattern consistent with riding', contribution: 0.09, direction: 'away_from_fraud'),
      ],
    ),
    FlaggedClaim(
      id: 'fc-003',
      workerId: 'w-201',
      workerName: 'Sundar',
      triggerEventId: 'trig-001',
      triggerType: 'rainfall',
      zone: 'Velachery',
      amount: 420,
      fraudScore: 0.61,
      tier: 'soft_hold',
      timestamp: DateTime(2026, 3, 20, 19, 55),
      status: 'pending_review',
      shapSignals: [
        ShapSignal(signal: 'Mock location app detected on device', contribution: 0.28, direction: 'toward_fraud'),
        ShapSignal(signal: 'Registration cohort overlap with flagged ring', contribution: 0.19, direction: 'toward_fraud'),
        ShapSignal(signal: '20-week coverage history', contribution: 0.15, direction: 'away_from_fraud'),
        ShapSignal(signal: 'Consistent delivery pattern last 4 weeks', contribution: 0.11, direction: 'away_from_fraud'),
        ShapSignal(signal: 'Cell tower matches claimed location', contribution: 0.08, direction: 'away_from_fraud'),
      ],
    ),
    FlaggedClaim(
      id: 'fc-004',
      workerId: 'w-001',
      workerName: 'Arjun',
      triggerEventId: 'trig-001',
      triggerType: 'rainfall',
      zone: 'Velachery',
      amount: 420,
      fraudScore: 0.08,
      tier: 'clean',
      timestamp: DateTime(2026, 3, 20, 19, 30),
      status: 'auto_approved',
      shapSignals: [
        ShapSignal(signal: '24-week clean coverage streak', contribution: 0.22, direction: 'away_from_fraud'),
        ShapSignal(signal: 'GPS + cell tower + accelerometer all consistent', contribution: 0.18, direction: 'away_from_fraud'),
        ShapSignal(signal: 'Historical zone match: Velachery regular', contribution: 0.14, direction: 'away_from_fraud'),
        ShapSignal(signal: 'Battery drain consistent with outdoor riding', contribution: 0.08, direction: 'away_from_fraud'),
        ShapSignal(signal: 'No concurrent claim attempts', contribution: 0.06, direction: 'away_from_fraud'),
      ],
    ),
  ];

  // NLP Confidence log for civic triggers (admin view)
  static const List<Map<String, dynamic>> nlpConfidenceLog = [
    {
      'event': 'Tamil Nadu Transport Bandh',
      'date': '2026-02-12',
      'confidence': 0.92,
      'action': 'Auto-triggered',
      'sources': ['TN State Govt notification', 'NDTV', 'The Hindu'],
      'sourceCount': 3,
    },
    {
      'event': 'Chennai Municipal By-Election',
      'date': '2026-01-15',
      'confidence': 1.0,
      'action': 'Auto-triggered',
      'sources': ['Election Commission of India'],
      'sourceCount': 1,
    },
    {
      'event': 'Rumoured IT corridor strike',
      'date': '2026-03-08',
      'confidence': 0.38,
      'action': 'Withheld \u2014 manual review',
      'sources': ['Unverified Twitter post', 'WhatsApp forward'],
      'sourceCount': 0,
    },
    {
      'event': 'Partial transport strike (South TN)',
      'date': '2026-02-28',
      'confidence': 0.71,
      'action': 'Held 2hrs \u2014 confirmed',
      'sources': ['Deccan Chronicle', 'Local police advisory'],
      'sourceCount': 2,
    },
  ];

  // Micro-zone risk clusters (from DBSCAN Module 8)
  static const List<Map<String, dynamic>> microZoneClusters = [
    {
      'cluster': 'Velachery Lake Overflow Zone',
      'streets': ['100 Feet Road', 'Velachery Main Road', 'Tank Bund Road'],
      'riskMultiplier': 2.8,
      'claimDensity': 'Very High',
      'note': 'First area to flood when Adyar river breaches',
    },
    {
      'cluster': 'Adyar Bridge Bottleneck',
      'streets': ['LB Road', 'Lattice Bridge Road', 'Greenways Road'],
      'riskMultiplier': 2.1,
      'claimDensity': 'High',
      'note': 'Traffic paralysis epicentre during rain events',
    },
    {
      'cluster': 'OMR IT Corridor Dead Zone',
      'streets': ['Thoraipakkam', 'Perungudi', 'Kandanchavadi'],
      'riskMultiplier': 1.6,
      'claimDensity': 'Medium',
      'note': 'Power outage hotspot \u2014 TANGEDCO feeder line issues',
    },
  ];

  // Churn risk predictions (Module 7)
  static const List<Map<String, dynamic>> churnAlerts = [
    {
      'workerName': 'Karthik',
      'workerId': 'w-156',
      'zone': 'OMR',
      'churnProbability': 0.82,
      'reason': 'Only 4 weeks active, zero payouts received, premium feels wasted',
      'suggestedAction': 'Send: "Chennai\'s monsoon starts in 3 weeks \u2014 this is exactly when your coverage matters most."',
    },
    {
      'workerName': 'Deepa',
      'workerId': 'w-123',
      'zone': 'Tambaram',
      'churnProbability': 0.68,
      'reason': 'Recent soft-hold delayed her payout by 4 hours, engagement dropped 40%',
      'suggestedAction': 'Send: "Your last payout took longer due to network conditions. We\'ve improved verification speed \u2014 stay covered."',
    },
    {
      'workerName': 'Priya',
      'workerId': 'w-042',
      'zone': 'Adyar',
      'churnProbability': 0.45,
      'reason': 'Premium increased by \u20b98 last week due to monsoon loading',
      'suggestedAction': 'Highlight net benefit: she has received \u20b91,120 more than she has paid in premiums',
    },
  ];

  // Earnings imputation cross-check (Module 3)
  static const List<Map<String, dynamic>> earningsImputation = [
    {
      'workerId': 'w-001',
      'workerName': 'Arjun',
      'declared': 5250,
      'imputed': 5180,
      'deviation': 1.3,
      'status': 'consistent',
    },
    {
      'workerId': 'w-087',
      'workerName': 'Ravi',
      'declared': 6800,
      'imputed': 4920,
      'deviation': 38.2,
      'status': 'flagged',
    },
    {
      'workerId': 'w-042',
      'workerName': 'Priya',
      'declared': 4800,
      'imputed': 4650,
      'deviation': 3.2,
      'status': 'consistent',
    },
  ];

  // All 6 trigger groups from prompt — with sub-triggers consolidated
  static const List<Map<String, dynamic>> triggerThresholds = [
    {
      'type': 'Weather & Climate',
      'icon': 'water_drop',
      'threshold': 'Rain >14mm/hr \u2022 Flood gauge breach \u2022 Cyclone warning \u2022 Heat >44\u00b0C \u2022 AQI >300',
      'description': 'Consolidated environmental disruption \u2014 rainfall, flooding, cyclone pre-emptive, extreme heat, and air quality',
    },
    {
      'type': 'Civic & Political',
      'icon': 'block',
      'threshold': 'Bandh / Section 144 / Transport strike / Election day',
      'description': 'Government-action events confirmed via NLP confidence scoring on 2+ verified sources',
    },
    {
      'type': 'Platform Outage',
      'icon': 'cloud_off',
      'threshold': 'Swiggy app errors for \u22652 continuous hours',
      'description': 'Partner API pings return errors during active delivery hours',
    },
    {
      'type': 'Traffic Paralysis',
      'icon': 'traffic',
      'threshold': 'Avg speed <8km/h for \u226590 minutes',
      'description': 'Roads flood before rain APIs fire \u2014 detects disruption 45\u201390 min earlier than rainfall triggers',
    },
    {
      'type': 'Grid Power Outage',
      'icon': 'power_off',
      'threshold': 'TANGEDCO outage \u22654 continuous hours',
      'description': 'Restaurant order capacity collapses \u2014 kitchens down, cold storage failing. Cross-validated with order volume',
    },
    {
      'type': 'Order Volume Collapse',
      'icon': 'trending_down',
      'threshold': 'Orders drop >65% vs same slot, sustained \u226560 min',
      'description': 'Measures the work itself \u2014 if orders aren\u0027t flowing, Arjun isn\u0027t earning, regardless of cause',
    },
  ];
}
