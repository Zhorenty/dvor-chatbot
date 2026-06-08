import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
import 'package:dvor_chatbot/src/domain/outdoor_activity_info.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';

final class StaticScheduleRepository implements TrainingScheduleRepository {
  const StaticScheduleRepository();

  @override
  List<TrainingInfo> upcoming({DateTime? now, int limit = 5}) {
    final current = now ?? DateTime.now();
    final upcomingItems = _items.where((item) => item.startsAt.isAfter(current)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return upcomingItems.take(limit).toList(growable: false);
  }

  @override
  List<OutdoorActivityInfo> upcomingOutdoorActivities({DateTime? now, int limit = 8}) {
    final current = now ?? DateTime.now();
    final upcomingItems = _outdoorItems.where((item) => !item.dateTo.isBefore(current)).toList()
      ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    return upcomingItems.take(limit).toList(growable: false);
  }

  @override
  Future<bool> refresh({bool force = false}) async => true;
}

final List<TrainingInfo> _items = <TrainingInfo>[
  TrainingInfo(
    title: 'Функциональная тренировка',
    startsAt: DateTime(2026, 6, 2, 19, 0),
    location: 'Спортзал DVOR, ул. Центральная, 10',
    price: 500,
    participantsLimit: 20,
    coach: 'Алексей',
    notes: 'Возьмите воду и удобную сменную обувь',
  ),
  TrainingInfo(
    title: 'Кардио + выносливость',
    startsAt: DateTime(2026, 6, 4, 19, 30),
    location: 'Стадион DVOR, сектор B',
    price: 500,
    participantsLimit: 0,
    coach: 'Мария',
  ),
  TrainingInfo(
    title: 'Силовая база',
    startsAt: DateTime(2026, 6, 7, 11, 0),
    location: 'Спортзал DVOR, ул. Центральная, 10',
    price: 500,
    participantsLimit: 15,
    coach: 'Алексей',
  ),
];

final List<OutdoorActivityInfo> _outdoorItems = <OutdoorActivityInfo>[
  OutdoorActivityInfo(
    type: OutdoorActivityType.hike,
    title: 'Поход выходного дня',
    dateFrom: DateTime(2026, 6, 14),
    dateTo: DateTime(2026, 6, 14, 23, 59, 59),
    description: 'Легкий маршрут для всех уровней с привалом у озера.',
    price: 1500,
    participantsLimit: 30,
  ),
  OutdoorActivityInfo(
    type: OutdoorActivityType.trail,
    title: 'Горный трейл “Рассвет”',
    dateFrom: DateTime(2026, 6, 21),
    dateTo: DateTime(2026, 6, 22, 23, 59, 59),
    description: 'Двухдневный трейл с ночевкой и набором высоты.',
    price: 4200,
    participantsLimit: 0,
  ),
];
