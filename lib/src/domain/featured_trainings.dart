import 'package:dvor_chatbot/src/domain/training_info.dart';

/// One-off trainings that stay bookable even when the sheet row is missing.
abstract final class FeaturedTrainings {
  static final TrainingInfo frankRun = TrainingInfo(
    title: 'DVOR x FRANK — RUN & RAVE',
    startsAt: DateTime(2026, 10, 17, 8, 30),
    location: 'Мост поцелуев',
    price: 0,
    notes: '5 км под сет Ильи PZ. После — короткая силовая от Black Croc, кофе и завтраки '
        'Frank by Basta. Вода на дистанции и кофе после — для участников.',
  );

  static final TrainingInfo fourSons = TrainingInfo(
    title: 'DVOR X ЧЕТЫРЕ СЫНА',
    startsAt: DateTime(2026, 11, 7, 8, 30),
    location: 'Кубанская Набережная 39 (Четыре сына )',
    locationUrl: 'https://yandex.ru/maps/-/CXA2qYn~',
    price: 0,
    participantsLimit: 30,
    coach: 'Сергей Нагучев',
    notes: '🏃‍♂️ПРОГРАММА МЕРОПРИЯТИЯ 📋\n'
        ' \n'
        'Список:\n'
        'Разминка — 2 км 🏃‍♀️\n'
        'Динамическая растяжка 🤸‍♂️\n'
        'СБУ 🏋️‍♀️\n'
        'Силовой блок 💪\n'
        'Заминка — 2 км 🚶‍♂️\n'
        ' \n'
        '🍕 Вкусное продолжение тренировки в пиццерии «Четыре сына» ☕ '
        'с фильтр кофе и общением за общим столом\n'
        ' \n'
        '👟 Тренер: Тренировку проведет Сергей Нагучев (тренер по бегу) 🏅\n'
        ' \n'
        '🔗 Ссылка на карту лояльности с начислением приветственных баллов в «Четыре сына»: '
        'https://access.clientomer.ru/feedback/404401-1/?utm_source=4syna_egorova',
  );

  static final List<TrainingInfo> events = <TrainingInfo>[frankRun, fourSons];

  static List<TrainingInfo> upcoming(DateTime now) {
    return events.where((item) => item.startsAt.isAfter(now)).toList(growable: false);
  }
}

/// Sheet row wins when the same title falls on the same day, so the limit is shared.
TrainingInfo preferScheduledFeatured(TrainingInfo featured, List<TrainingInfo> schedule) {
  for (final item in schedule) {
    if (sameFeaturedSlot(item, featured)) {
      return item;
    }
  }
  return featured;
}

List<TrainingInfo> mergeFeaturedTrainings(List<TrainingInfo> items, DateTime now) {
  final extras = FeaturedTrainings.upcoming(now).where((featured) {
    return !items.any((item) => sameFeaturedSlot(item, featured));
  });
  if (extras.isEmpty) {
    return items;
  }
  return <TrainingInfo>[...items, ...extras]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
}

bool sameFeaturedSlot(TrainingInfo left, TrainingInfo right) {
  if (!_featuredTitlesMatch(left.title, right.title)) {
    return false;
  }
  final a = left.startsAt;
  final b = right.startsAt;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Sheet rows sometimes add an emoji or a different dash. «Четыре сына» still
/// counts as the same headline event.
bool _featuredTitlesMatch(String left, String right) {
  final a = left.trim().toLowerCase();
  final b = right.trim().toLowerCase();
  if (a == b) {
    return true;
  }
  return a.contains('четыре сына') && b.contains('четыре сына');
}
