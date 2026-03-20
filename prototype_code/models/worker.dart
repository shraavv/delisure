class Worker {
  final String id;
  final String name;
  final String swiggyPartnerId;
  final String phone;
  final List<String> zones;
  final double avgWeeklyEarnings;
  final double avgActiveHoursPerWeek;
  final String riskTier;
  final String profileImageUrl;

  const Worker({
    required this.id,
    required this.name,
    required this.swiggyPartnerId,
    required this.phone,
    required this.zones,
    required this.avgWeeklyEarnings,
    required this.avgActiveHoursPerWeek,
    required this.riskTier,
    this.profileImageUrl = '',
  });
}
