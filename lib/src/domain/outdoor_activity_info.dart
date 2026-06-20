enum OutdoorActivityType {
  hike,
  trail,
}

final class OutdoorActivityInfo {
  const OutdoorActivityInfo({
    required this.type,
    required this.title,
    required this.dateFrom,
    required this.dateTo,
    required this.description,
    this.location,
    this.equipment,
    this.itinerary,
    this.price,
    this.participantsLimit,
  });

  final OutdoorActivityType type;
  final String title;
  final DateTime dateFrom;
  final DateTime dateTo;
  final String description;
  final String? location;
  final String? equipment;
  final String? itinerary;
  final int? price;
  final int? participantsLimit;
}
