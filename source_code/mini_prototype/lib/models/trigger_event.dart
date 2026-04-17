class TriggerEvent {
  final String id;
  final String type;
  final String zone;
  final DateTime startTime;
  final DateTime? endTime;
  final double intensity;
  final String description;
  final bool isActive;
  final double? nlpConfidence;
  final String? nlpSources;

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
