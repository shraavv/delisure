class Policy {
  final String id;
  final String workerId;
  final String status; // active, paused, expired
  final double weeklyPremium;
  final String riskTier;
  final DateTime startDate;
  final List<String> zones;
  final DateTime nextDebitDate;

  const Policy({
    required this.id,
    required this.workerId,
    required this.status,
    required this.weeklyPremium,
    required this.riskTier,
    required this.startDate,
    required this.zones,
    required this.nextDebitDate,
  });
}
