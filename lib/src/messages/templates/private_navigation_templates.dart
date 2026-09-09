import 'package:dvor_chatbot/src/domain/activity_category.dart';
import 'package:dvor_chatbot/src/domain/boxing_title.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/messages/copy/message_copy.dart';
import 'package:dvor_chatbot/src/messages/html_escaper.dart';
import 'package:dvor_chatbot/src/messages/rich_html.dart';
import 'package:intl/intl.dart';

final class PrivateNavigationTemplates {
  const PrivateNavigationTemplates();

  String privateWelcome() {
    return RichHtml.screen(
      title: 'Добро пожаловать в DVOR',
      lead: 'Слоты здесь: выбрать, оплатить чеком, прийти.',
      paragraphs: <String>[
        'Внизу — запись, друг, штаб, профиль и помощь.',
      ],
    );
  }

  String onboardingWelcome() {
    return RichHtml.screen(
      title: 'Старт в DVOR',
      lead: 'Что сейчас важнее?',
    );
  }

  String onboardingQuizGoal() {
    return RichHtml.screen(
      title: 'Цель',
      lead: 'Что сейчас важнее?',
    );
  }

  String onboardingQuizExperience() {
    return RichHtml.screen(
      title: 'Опыт',
      lead: 'Какой у тебя опыт?',
    );
  }

  String onboardingTrackChoice() {
    return RichHtml.screen(
      title: 'Формат',
      lead: 'С чего начнём?',
    );
  }

  String onboardingClubMap({
    required bool starterBonusAvailable,
    List<TrainingInfo> citySlots = const <TrainingInfo>[],
  }) {
    final buffer = StringBuffer()
      ..write(RichHtml.heading('Карта клуба'))
      ..write(RichHtml.paragraph('Следующий шаг — слот.'))
      ..write(RichHtml.paragraph('В боте — расписание и запись.'));
    final slots = _citySlotsBlock(citySlots);
    if (slots.isNotEmpty) {
      buffer
        ..write(RichHtml.heading('Ближайшие слоты в городе', level: 3))
        ..write(slots);
    }
    buffer.write(
      RichHtml.paragraph(
        'Группа — афиши. Можно зайти и ничего не писать: '
        '<a href="${escapeHtml(MessageCopy.dvorGroupInviteUrl)}">'
        '${escapeHtml(MessageCopy.dvorGroupInviteUrl)}</a>',
        alreadyEscaped: true,
      ),
    );
    if (starterBonusAvailable) {
      buffer.write(RichHtml.paragraph('За старт есть одна бесплатная тренировка.'));
    }
    buffer.write(
      RichHtml.paragraph('Не с кем идти — приходи один. На площадке уже будут свои.'),
    );
    return buffer.toString();
  }

  String _citySlotsBlock(List<TrainingInfo> citySlots) {
    if (citySlots.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    for (final slot in citySlots) {
      final kind = switch (_citySlotKind(slot.title)) {
        'boxing' => 'Бокс',
        'strength' => 'Силовая',
        'run' => 'Забег',
        _ => '',
      };
      buffer.write(
        RichHtml.card(
          title: slot.title,
          lines: <String>[
            if (kind.isNotEmpty) kind,
            '🕒 ${_slotWhen(slot)}',
            '📍 ${RichHtml.locationHtml(
              location: slot.location,
              locationUrl: slot.locationUrl,
              link: slot.category == ActivityCategory.trainings,
            )}',
          ],
        ),
      );
    }
    return buffer.toString();
  }

  String _citySlotKind(String title) {
    final lower = title.toLowerCase();
    if (isBoxingTrainingTitle(title)) {
      return 'boxing';
    }
    if (lower.contains('сил')) {
      return 'strength';
    }
    if (lower.contains('забег') || lower.contains('бег')) {
      return 'run';
    }
    return '';
  }

  String onboardingNeedHelp() {
    return RichHtml.screen(
      title: 'Помощь',
      lead: 'На связи @dvor_support.',
      paragraphs: <String>[
        'Напиши, на каком шаге застрял.',
      ],
    );
  }

  String onboardingNudgeQuizReminder() {
    return RichHtml.screen(
      title: 'Один шаг',
      lead: 'Осталось ответить на пару вопросов — покажу слоты.',
    );
  }

  String onboardingNudgePrimaryCta({TrainingInfo? nearest}) {
    if (nearest == null) {
      return RichHtml.screen(
        title: 'Слоты',
        lead: 'Ближайшие слоты уже в расписании.',
        paragraphs: <String>['Выбери один и запишись.'],
      );
    }
    return RichHtml.screen(
      title: 'Ближайший слот',
      paragraphs: <String>[
        nearest.title,
        '${_slotWhen(nearest)} · ${nearest.location}',
        'Запишись, если подходит.',
      ],
    );
  }

  String _slotWhen(TrainingInfo nearest) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final weekday = switch (nearest.startsAt.weekday) {
      DateTime.monday => 'пн',
      DateTime.tuesday => 'вт',
      DateTime.wednesday => 'ср',
      DateTime.thursday => 'чт',
      DateTime.friday => 'пт',
      DateTime.saturday => 'сб',
      DateTime.sunday => 'вс',
      _ => '',
    };
    final formatted = formatter.format(nearest.startsAt);
    return weekday.isEmpty ? formatted : '$weekday, $formatted';
  }

  String onboardingNudgeDay5Alt() {
    return RichHtml.screen(
      title: 'Другой формат',
      lead: 'Если привычный формат не зашёл — попробуй другой: тренировка или outdoor.',
      paragraphs: <String>['Главное — выбрать слот и прийти.'],
    );
  }

  String onboardingNudgeDay7() {
    return RichHtml.screen(
      title: 'Неделя',
      lead: 'Неделя прошла. Ближайшие слоты — в расписании.',
      paragraphs: <String>['Если что-то мешает, напиши @dvor_support.'],
    );
  }

  String groupInviteNudge(int index) {
    return switch (index) {
      2 => RichHtml.screen(
          title: 'Группа DVOR',
          lead: 'Там афиши и живой чат. Бот их не дублирует.',
          paragraphs: <String>[
            'Представляться не обязательно.',
          ],
        ),
      3 => RichHtml.screen(
          title: 'Группа DVOR',
          lead: 'В боте — запись. В группе — новости.',
          paragraphs: <String>[
            'Можно просто читать.',
          ],
        ),
      _ => RichHtml.screen(
          title: 'Новости и общение — в группе DVOR',
          lead: 'В боте — расписание и запись. Афиши и чат — в группе.',
          paragraphs: <String>[
            'Если зайдёшь — можно ничего не писать.',
          ],
        ),
    };
  }

  String onboardingActivationSuccess() {
    return RichHtml.screen(
      title: 'Первая тренировка',
      lead: 'Первая тренировка в DVOR — есть.',
      paragraphs: <String>[
        'Дальше проще: вторая закрепляет ритм.',
        'Друга можно записать по рефералке в профиле.',
      ],
    );
  }

  String onboardingSnoozeAck() {
    return RichHtml.screen(
      title: 'Ок',
      lead: 'Без давления. Когда будет удобно — запись в меню.',
    );
  }

  String trainingFeedbackAsk({
    required String trainingTitle,
    ActivityCategory category = ActivityCategory.trainings,
  }) {
    final question = switch (category) {
      ActivityCategory.hikes => 'Как прошел поход «$trainingTitle»?',
      ActivityCategory.trails => 'Как прошел трейл «$trainingTitle»?',
      ActivityCategory.trainings => 'Как прошла тренировка «$trainingTitle»?',
    };
    return RichHtml.screen(
      title: 'Отзыв',
      lead: question,
      paragraphs: <String>['Ответ анонимный.'],
    );
  }

  String trainingFeedbackCommentAsk() {
    return RichHtml.screen(
      title: 'Комментарий',
      lead: 'Если хочешь — одним сообщением, что зашло или что улучшить.',
    );
  }

  String trainingFeedbackThanks() {
    return 'Спасибо.';
  }

  String trainingFeedbackAdminNotification({
    required String trainingTitle,
    required String ratingLabel,
    String? comment,
    ActivityCategory category = ActivityCategory.trainings,
  }) {
    final subject = switch (category) {
      ActivityCategory.hikes => 'походе',
      ActivityCategory.trails => 'трейле',
      ActivityCategory.trainings => 'тренировке',
    };
    final rows = <(String, String)>[
      ('Занятие', trainingTitle),
      ('Оценка', ratingLabel),
    ];
    final trimmed = comment?.trim();
    return RichHtml.screen(
      title: 'Новый анонимный отзыв о $subject',
      rows: rows,
      detailsSummary: trimmed == null || trimmed.isEmpty ? null : 'Комментарий',
      detailsBody: trimmed,
    );
  }

  String starterBonusOnboardingOffer() {
    return RichHtml.screen(
      title: 'Стартовая',
      lead: 'Тебе доступна бесплатная тренировка за старт.',
      paragraphs: <String>[
        'Выбери слот. На карточке записи будет кнопка «${MessageCopy.buttonUseStarterBonus}».',
      ],
    );
  }

  String privateHelp() {
    return RichHtml.screen(
      title: 'Помощь',
      lead: 'В боте — слоты, запись и статус.',
      bullets: <String>[
        'Запись — выбрать слот и прислать чек',
        'Нет мест — другое мероприятие в расписании',
        'Бокс-карта — в профиле, только групповой бокс',
        'Вершинки — 2 ⛰️ = 1 ₽, 45 дней, в профиле',
        'Группа — афиши, представляться не обязательно',
        'Человек на связи — @dvor_support',
      ],
      detailsSummary: 'Правила отмен',
      detailsBody: 'Походы и трейлы — не позже чем за 7 дней до старта.\n'
          'Бесплатные тренировки — в любой момент.\n'
          'Бокс-карта: перенос и возврат слота — за 24 часа, только на бокс.\n'
          'Платные тренировки — через @dvor_support.\n'
          'Перенос тренировки — на слот той же стоимости.',
    );
  }

  String privateFallback() {
    return RichHtml.screen(
      title: 'Не понял',
      lead: 'Пока не понял сообщение.',
    );
  }

  String privateMenuHint() {
    return RichHtml.screen(
      title: 'Меню',
      lead: 'Меню внизу.',
    );
  }

  String returnedToMainMenu() {
    return RichHtml.screen(
      title: 'Меню',
      lead: 'Главное меню.',
    );
  }

  String alreadyInMainMenu() {
    return RichHtml.screen(
      title: 'Меню',
      lead: 'Ты уже в главном меню.',
    );
  }

  String noBookingsYet() {
    return RichHtml.screen(
      title: 'Записи',
      lead: 'Пока нет записей на мероприятия.',
      paragraphs: <String>['Запись — в меню внизу.'],
    );
  }
}
