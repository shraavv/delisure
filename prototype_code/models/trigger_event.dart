class TriggerEvent {
  final String id;
  final String type; // rainfall, heat, aqi, bandh, election, outage, traffic, order_collapse, platform_outage, cyclone
  final String zone;
  final DateTime startTime;
  final DateTime? endTime;
  final double intensity;
  final String description;
  final bool isActive;
  final double? nlpConfidence; // For civic triggers — 0.0–1.0
  final String? nlpSources; // Sources used for NLP verification

  const TriggerEvent({
    required this.id,
    required this.type,
    required this.zone,
    required this.startTime,
    this.endTime,
    required this.intensity,
    required this.description,
    required this.isActive,
    this.nlpConfidence,
    this.nlpSources,
  });
}
