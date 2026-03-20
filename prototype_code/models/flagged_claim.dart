class FlaggedClaim {
  final String id;
  final String workerId;
  final String workerName;
  final String triggerEventId;
  final String triggerType;
  final String zone;
  final double amount;
  final double fraudScore;
  final String tier; // clean, soft_hold, hard_flag
  final DateTime timestamp;
  final List<ShapSignal> shapSignals;
  final String status; // pending_review, approved, escalated, auto_approved

  const FlaggedClaim({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.triggerEventId,
    required this.triggerType,
    required this.zone,
    required this.amount,
    required this.fraudScore,
    required this.tier,
    required this.timestamp,
    required this.shapSignals,
    required this.status,
  });
}

class ShapSignal {
  final String signal;
  final double contribution;
  final String direction; // toward_fraud, away_from_fraud

  const ShapSignal({
    required this.signal,
    required this.contribution,
    required this.direction,
  });
}
