import 'package:dvor_chatbot/src/data/training_schedule_repository.dart';
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
  Future<bool> refresh({bool force = false}) async => true;
}

final List<TrainingInfo> _items = <TrainingInfo>[
  TrainingInfo(
    title: 'Функциональная тренировка',
    startsAt: DateTime(2026, 6, 2, 19, 0),
    location: 'Спортзал DVOR, ул. Центральная, 10',
    coach: 'Алексей',
    notes: 'Возьмите воду и удобную сменную обувь',
  ),
  TrainingInfo(
    title: 'Кардио + выносливость',
    startsAt: DateTime(2026, 6, 4, 19, 30),
    location: 'Стадион DVOR, сектор B',
    coach: 'Мария',
  ),
  TrainingInfo(
    title: 'Силовая база',
    startsAt: DateTime(2026, 6, 7, 11, 0),
    location: 'Спортзал DVOR, ул. Центральная, 10',
    coach: 'Алексей',
  ),
];
