class Payout {
  final String id;
  final String workerId;
  final String triggerEventId;
  final double amount;
  final String status;
  final DateTime timestamp;
  final String breakdown;

  const Payout({
    required this.id,
    required this.workerId,
    required this.triggerEventId,
    required this.amount,
    required this.status,
    required this.timestamp,
    required this.breakdown,
  });
}
