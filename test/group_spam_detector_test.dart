import 'package:dvor_chatbot/src/application/group_spam_detector.dart';
import 'package:test/test.dart';

void main() {
  const detector = GroupSpamDetector();

  group('GroupSpamDetector', () {
    test('flags earnings team recruitment spam', () {
      final result = detector.evaluate('''
Набираем людей в команду!
Удобный график - можно совмещать вместе с основной работой
Заработок от 100 € в день
Бесплатное обучение
Хочешь узнать больше?
Писать в личные сообщения
''');

      expect(result.isSpam, isTrue);
      expect(result.reasons, contains('earnings'));
      expect(result.reasons, contains('dm_invite'));
    });

    test('flags remote job spam with ls invite', () {
      final result = detector.evaluate(
        'Ищу желающих на удаленную занятость. Подходит для старта без опыта. За деталями пишите в лс.',
      );

      expect(result.isSpam, isTrue);
      expect(result.reasons, contains('remote_job'));
      expect(result.reasons, anyOf(contains('dm_invite'), contains('dm_short')));
    });

    test('flags project scale spam with eur day rates', () {
      final result = detector.evaluate('''
Масштабируем проект на работу.
Оплата - 110-190 EUR  / день
Оплата - 550-950 EUR / неделя
Гибкий график (можно совмещать с основной работой) и предоставляется бесплатный курс обучения с оплачиваемой стажировкой.
Для подробностей - пишите в личные сообщения.
''');

      expect(result.isSpam, isTrue);
      expect(result.reasons, contains('project_scale'));
      expect(result.reasons, contains('earnings_amount'));
      expect(result.reasons, contains('dm_invite'));
    });

    test('normalizes yo and invisible chars', () {
      final result = detector.evaluate(
        'Ищу желающих на удалённую занятость.\u200B Пишите в лс.',
      );

      expect(result.isSpam, isTrue);
    });

    test('keeps normal club chat', () {
      const cleanMessages = <String>[
        'Кто завтра на тренировку? Напишите мне если едете.',
        'Бесплатное обучение технике бега на разминке',
        'В команде сегодня 12 человек',
        'Напишите в лс, скину адрес зала',
        'Гибкий график у меня на работе, успею к 19:00',
        'Завтра оплата абонемента, кто ещё не скинул?',
        'Хочешь узнать больше про трейл — спроси тренера',
        'Пишите в личные сообщения, если нужна форма',
        'Оплата абонемента завтра, кто ещё не скинул?',
        'Оплата: 1500, напишите мне в лс реквизиты',
      ];

      for (final message in cleanMessages) {
        expect(
          detector.evaluate(message).isSpam,
          isFalse,
          reason: 'should keep: $message',
        );
      }
    });

    test('does not ban contact-only or filler-only messages', () {
      expect(detector.evaluate('Пишите в лс').isSpam, isFalse);
      expect(detector.evaluate('Писать в личные сообщения').isSpam, isFalse);
      expect(
        detector.evaluate('Удобный график и бесплатное обучение').isSpam,
        isFalse,
      );
    });

    test('treats empty text as clean', () {
      expect(detector.evaluate(null).isSpam, isFalse);
      expect(detector.evaluate('   ').isSpam, isFalse);
    });
  });
}
