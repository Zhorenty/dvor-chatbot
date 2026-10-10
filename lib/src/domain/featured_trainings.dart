import 'package:dvor_chatbot/src/domain/training_info.dart';

/// One-off trainings that stay bookable even when the sheet row is missing.
abstract final class FeaturedTrainings {
  static final List<TrainingInfo> events = <TrainingInfo>[
    TrainingInfo(
      title: 'DVOR x FRANK — RUN & RAVE',
      startsAt: DateTime(2026, 10, 17, 8, 30),
      location: 'Мост поцелуев',
      price: 0,
      notes: '5 км под сет Ильи Пз. После — короткая силовая, кофе и завтраки '
          'Frank by Basta. Вода на дистанции и кофе после — для участников.',
    ),
  ];

  static List<TrainingInfo> upcoming(DateTime now) {
    return events.where((item) => item.startsAt.isAfter(now)).toList(growable: false);
  }
}

List<TrainingInfo> mergeFeaturedTrainings(List<TrainingInfo> items, DateTime now) {
  final extras = FeaturedTrainings.upcoming(now).where((featured) {
    return !items.any((item) => _sameFeaturedSlot(item, featured));
  });
  if (extras.isEmpty) {
    return items;
  }
  return <TrainingInfo>[...items, ...extras]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
}

bool _sameFeaturedSlot(TrainingInfo left, TrainingInfo right) {
  final sameTitle = left.title.trim().toLowerCase() == right.title.trim().toLowerCase();
  if (!sameTitle) {
    return false;
  }
  final a = left.startsAt;
  final b = right.startsAt;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
