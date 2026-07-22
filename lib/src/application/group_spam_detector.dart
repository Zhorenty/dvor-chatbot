/// Heuristic spam detector for typical Telegram recruitment / earnings ads.
///
/// Tuned for Russian-language spam like:
/// - «Заработок от 100 € в день … Писать в личные сообщения»
/// - «Ищу желающих на удаленную занятость … пишите в лс»
/// - «Оплата 110-190 EUR / день … пишите в личные сообщения»
///
/// Normal club chat is protected by category rules:
/// soft phrases («в лс», «обучение», «команда») alone never ban.
final class GroupSpamDetector {
  const GroupSpamDetector();

  /// Cyrillic-safe "word" chars after [_normalize] (lowercase, ё → е).
  static const String _w = r'[а-яa-z0-9_]*';

  static final List<_SpamPattern> _patterns = <_SpamPattern>[
    // --- job / money / recruiting (primary) ---
    _SpamPattern(
      RegExp('удаленн$_w\\s+занятост'),
      score: 45,
      reason: 'remote_job',
      category: _SpamCategory.job,
    ),
    _SpamPattern(
      RegExp('удаленн$_w\\s+работ'),
      score: 40,
      reason: 'remote_job',
      category: _SpamCategory.job,
    ),
    _SpamPattern(
      RegExp(r'набираем\s+людей'),
      score: 40,
      reason: 'recruiting',
      category: _SpamCategory.job,
    ),
    _SpamPattern(
      RegExp(r'ищу\s+желающих'),
      score: 40,
      reason: 'recruiting',
      category: _SpamCategory.job,
    ),
    _SpamPattern(
      RegExp(r'набор\s+в\s+команд'),
      score: 40,
      reason: 'recruiting',
      category: _SpamCategory.job,
    ),
    _SpamPattern(
      RegExp(r'масштабируем\s+проект'),
      score: 45,
      reason: 'project_scale',
      category: _SpamCategory.job,
    ),
    _SpamPattern(
      RegExp(r'заработок\s+от'),
      score: 45,
      reason: 'earnings',
      category: _SpamCategory.job,
    ),
    _SpamPattern(
      RegExp(r'доход\s+от'),
      score: 40,
      reason: 'earnings',
      category: _SpamCategory.job,
    ),
    _SpamPattern(
      RegExp(
        r'оплат[аы]?\s*[-–—:]?\s*\d+(\s*[-–—]\s*\d+)?\s*([€$₽]|eur|usd|rub|руб)',
      ),
      score: 35,
      reason: 'payment_rate',
      category: _SpamCategory.job,
    ),
    _SpamPattern(
      RegExp(
        r'\d+\s*[-–—]?\s*\d*\s*([€$₽]|eur|usd|rub|руб)\s*/?\s*'
        r'(день|час|сутки|недел|ежедневно)',
      ),
      score: 45,
      reason: 'earnings_amount',
      category: _SpamCategory.job,
    ),
    _SpamPattern(
      RegExp('оплачиваем$_w\\s+стажировк'),
      score: 40,
      reason: 'paid_internship',
      category: _SpamCategory.job,
    ),
    _SpamPattern(
      RegExp('пассивн$_w\\s+доход'),
      score: 45,
      reason: 'passive_income',
      category: _SpamCategory.job,
    ),
    _SpamPattern(
      RegExp('крипт$_w\\s+(сигнал|раздач|airdrop)'),
      score: 45,
      reason: 'crypto_spam',
      category: _SpamCategory.job,
    ),
    _SpamPattern(
      RegExp('гарантированн$_w\\s+(доход|прибыл|заработок)'),
      score: 45,
      reason: 'guaranteed_income',
      category: _SpamCategory.job,
    ),

    // --- contact CTA ---
    _SpamPattern(
      RegExp(r'писать\s+в\s+личн'),
      score: 40,
      reason: 'dm_invite',
      category: _SpamCategory.contact,
    ),
    _SpamPattern(
      RegExp(r'пиши(те)?\s+в\s+(лс|личн)'),
      score: 40,
      reason: 'dm_invite',
      category: _SpamCategory.contact,
    ),
    _SpamPattern(
      RegExp(r'за\s+деталями\s+пиши'),
      score: 40,
      reason: 'dm_invite',
      category: _SpamCategory.contact,
    ),
    _SpamPattern(
      RegExp('для\\s+подробност$_w\\s*[-–—:]?\\s*пиши'),
      score: 40,
      reason: 'dm_invite',
      category: _SpamCategory.contact,
    ),
    _SpamPattern(
      RegExp(r'пиши(те)?\s+мне\s+в\s+(лс|личк)'),
      score: 35,
      reason: 'dm_invite',
      category: _SpamCategory.contact,
    ),
    _SpamPattern(
      RegExp(r'(?:^|[^а-я0-9])в\s+лс(?:[^а-я0-9]|$)'),
      score: 20,
      reason: 'dm_short',
      category: _SpamCategory.contact,
    ),
    _SpamPattern(
      RegExp(r'в\s+личку'),
      score: 20,
      reason: 'dm_short',
      category: _SpamCategory.contact,
    ),
    _SpamPattern(
      RegExp(r'личн(ые|ых)\s+сообщен'),
      score: 25,
      reason: 'dm_short',
      category: _SpamCategory.contact,
    ),

    // --- fillers: only amplify job/contact combos ---
    _SpamPattern(
      RegExp(r'(удобный|гибкий)\s+график'),
      score: 15,
      reason: 'flexible_hours',
      category: _SpamCategory.filler,
    ),
    _SpamPattern(
      RegExp(r'совмещать.{0,40}работ'),
      score: 15,
      reason: 'side_job',
      category: _SpamCategory.filler,
    ),
    _SpamPattern(
      RegExp(r'бесплатн(ое|ый)\s+(курс\s+)?обучен'),
      score: 15,
      reason: 'free_training_ad',
      category: _SpamCategory.filler,
    ),
    _SpamPattern(
      RegExp(r'без\s+опыта'),
      score: 15,
      reason: 'no_experience',
      category: _SpamCategory.filler,
    ),
    _SpamPattern(
      RegExp(r'подходит\s+для\s+старта'),
      score: 15,
      reason: 'entry_level',
      category: _SpamCategory.filler,
    ),
    _SpamPattern(
      RegExp(r'хочешь\s+узнать\s+больше'),
      score: 10,
      reason: 'learn_more_cta',
      category: _SpamCategory.filler,
    ),
  ];

  SpamDetectionResult evaluate(String? rawText) {
    if (rawText == null || rawText.trim().isEmpty) {
      return const SpamDetectionResult.clean();
    }

    final text = _normalize(rawText);
    if (text.isEmpty) {
      return const SpamDetectionResult.clean();
    }

    var jobScore = 0;
    var contactScore = 0;
    var fillerScore = 0;
    final reasons = <String>{};

    for (final pattern in _patterns) {
      if (!pattern.regex.hasMatch(text)) {
        continue;
      }
      reasons.add(pattern.reason);
      switch (pattern.category) {
        case _SpamCategory.job:
          jobScore += pattern.score;
        case _SpamCategory.contact:
          contactScore += pattern.score;
        case _SpamCategory.filler:
          fillerScore += pattern.score;
      }
    }

    final score = jobScore + contactScore + fillerScore;
    final isSpam = _isSpam(
      jobScore: jobScore,
      contactScore: contactScore,
      fillerScore: fillerScore,
    );

    return SpamDetectionResult(
      isSpam: isSpam,
      score: score,
      reasons: reasons.toList(growable: false),
    );
  }

  /// Requires a job/money signal. Contact or fillers alone never ban.
  static bool _isSpam({
    required int jobScore,
    required int contactScore,
    required int fillerScore,
  }) {
    if (jobScore <= 0) {
      return false;
    }

    // Explicit job ad + DM CTA.
    if (jobScore >= 35 && contactScore >= 20) {
      return true;
    }

    // Very strong job/money signal even without CTA.
    if (jobScore >= 60) {
      return true;
    }

    // Softer job signal supported by CTA and ad filler phrases.
    if (jobScore >= 30 && contactScore >= 20 && fillerScore >= 15) {
      return true;
    }

    return false;
  }

  static String _normalize(String value) {
    final withoutInvisible = value
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll('Ё', 'Е')
        .replaceAll('ё', 'е');
    return withoutInvisible.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

final class SpamDetectionResult {
  const SpamDetectionResult({
    required this.isSpam,
    required this.score,
    required this.reasons,
  });

  const SpamDetectionResult.clean()
      : isSpam = false,
        score = 0,
        reasons = const <String>[];

  final bool isSpam;
  final int score;
  final List<String> reasons;
}

enum _SpamCategory { job, contact, filler }

final class _SpamPattern {
  const _SpamPattern(
    this.regex, {
    required this.score,
    required this.reason,
    required this.category,
  });

  final RegExp regex;
  final int score;
  final String reason;
  final _SpamCategory category;
}
