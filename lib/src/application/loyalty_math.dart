import 'package:dvor_chatbot/src/domain/loyalty.dart';

/// Rounding and quotes for вершинки. Keep all money math here.
abstract final class LoyaltyMath {
  static const int lifetimeDays = 45;
  static const Duration lifetime = Duration(days: 45);
  static const int reminderLeadDays = 7;
  static const Duration reminderLead = Duration(days: 7);
  static const int unit = 10;
  static const int peaksPerRub = 2;
  static const int startBonusPeaks = 1000;
  static const int referralPeaks = 1000;
  static const int feedbackPeaks = 50;
  static const int feedbackPeaksMedium = 30;
  static const int feedbackPeaksShort = 10;
  static const int missingTrainingPriceEarnPeaks = 200;
  static const int missingEveryFifthDebitPeaks = 1000;
  static const int unusedEveryFifthVoucherPeaks = 1000;
  static const int starterConversionPeaks = 1000;

  /// Old «каждая 5-я»: 4 paid trainings earned 1 free slot.
  static int unusedEveryFifthRewards({
    required int qualifiedTrainingsCount,
    required int usedRewardsCount,
  }) {
    final earned = qualifiedTrainingsCount ~/ 4;
    final unused = earned - usedRewardsCount;
    return unused < 0 ? 0 : unused;
  }

  static int unusedEveryFifthPeaks(int availableRewards) {
    if (availableRewards <= 0) {
      return 0;
    }
    return availableRewards * unusedEveryFifthVoucherPeaks;
  }

  static const double outdoorDiscountShare = 0.30;
  static const double cashbackRate = 0.20;

  /// Fixed earn for one attended paid training. Less than the old 20% cashback.
  static const int trainingEarnPeaksAmount = 100;

  static int roundUp(int x) {
    if (x <= 0) {
      return 0;
    }
    return ((x + unit - 1) ~/ unit) * unit;
  }

  static int roundDown(int x) {
    if (x <= 0) {
      return 0;
    }
    return (x ~/ unit) * unit;
  }

  /// Fractional raw amounts: ceil to int, then round up to [unit].
  static int roundUpFromDouble(double x) {
    if (x <= 0) {
      return 0;
    }
    return roundUp(x.ceil());
  }

  static int roundUp50(int x) {
    if (x <= 0) {
      return 0;
    }
    return ((x + 49) ~/ 50) * 50;
  }

  static int roundDown50(int x) {
    if (x <= 0) {
      return 0;
    }
    return (x ~/ 50) * 50;
  }

  /// Outdoor / card cash-share still uses 50-step anchors.
  static int roundUp50FromDouble(double x) {
    if (x <= 0) {
      return 0;
    }
    return roundUp50(x.ceil());
  }

  static int fullPayPeaks(int priceRub) {
    if (priceRub <= 0) {
      return 0;
    }
    return priceRub * peaksPerRub;
  }

  static int remainderRub({required int priceRub, required int peaksSpent}) {
    if (priceRub <= 0) {
      return 0;
    }
    final cash = priceRub - (peaksSpent ~/ peaksPerRub);
    return cash < 0 ? 0 : cash;
  }

  /// Share of [feedbackPeaks]. Empty, filler, and one-word notes pay nothing.
  /// A short real note pays [feedbackPeaksShort], a useful one [feedbackPeaksMedium],
  /// and only a detailed comment pays the full [feedbackPeaks].
  static int feedbackRewardPeaks(String? comment) {
    final raw = comment?.trim() ?? '';
    if (raw.isEmpty) {
      return 0;
    }
    final normalized = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty || _feedbackFillers.contains(normalized)) {
      return 0;
    }
    final words = normalized.split(' ').where((word) => word.runes.length >= 2).toList();
    if (words.length < 4 || words.toSet().length < 3) {
      return 0;
    }
    final letters = normalized.replaceAll(' ', '').length;
    final detailed = words.length >= 18 || letters >= 120;
    if (detailed) {
      return feedbackPeaks;
    }
    if (words.length >= 8 || letters >= 40) {
      return feedbackPeaksMedium;
    }
    return feedbackPeaksShort;
  }

  /// After a paid training: fixed [trainingEarnPeaksAmount], independent of price.
  static int trainingEarnPeaks(int priceRub) {
    if (priceRub <= 0) {
      return 0;
    }
    return trainingEarnPeaksAmount;
  }

  /// 10% of cash paid through the bot, in peaks: round_up_50(paid_rub × 0.2).
  static int cashShareEarnPeaks(int paidRub) {
    if (paidRub <= 0) {
      return 0;
    }
    return roundUp50FromDouble(paidRub * cashbackRate);
  }

  static int outdoorEarnPeaks(int paidRub) => cashShareEarnPeaks(paidRub);

  static int boxingCardEarnPeaks(int paidRub) => cashShareEarnPeaks(paidRub);

  static LoyaltySpendQuote quoteSpend({
    required LoyaltySpendTarget target,
    required int priceRub,
    required int balance,
    int alreadySpent = 0,
  }) {
    if (priceRub <= 0 || balance <= 0) {
      return LoyaltySpendQuote(
          peaks: 0, remainderRub: priceRub < 0 ? 0 : priceRub, coversFully: false);
    }
    final currentRemainder = remainderRub(priceRub: priceRub, peaksSpent: alreadySpent);
    if (currentRemainder <= 0) {
      return const LoyaltySpendQuote(peaks: 0, remainderRub: 0, coversFully: true);
    }
    final available = roundDown(balance);
    if (available <= 0 && target != LoyaltySpendTarget.training) {
      return LoyaltySpendQuote(
        peaks: 0,
        remainderRub: currentRemainder,
        coversFully: false,
      );
    }
    final peaks = switch (target) {
      LoyaltySpendTarget.training => _quoteTrainingFullOnly(
          balance: balance,
          remainderRub: currentRemainder,
        ),
      LoyaltySpendTarget.boxingCard => _quoteFullOrPartial(
          available: available,
          remainderRub: currentRemainder,
        ),
      LoyaltySpendTarget.outdoor => _quoteOutdoor(
          available: available,
          priceRub: priceRub,
          remainderRub: currentRemainder,
        ),
    };
    final remainder = remainderRub(priceRub: currentRemainder, peaksSpent: peaks);
    final coversFully = target != LoyaltySpendTarget.outdoor && remainder <= 0;
    return LoyaltySpendQuote(
      peaks: peaks,
      remainderRub: remainder,
      coversFully: coversFully,
    );
  }

  static int _quoteTrainingFullOnly({
    required int balance,
    required int remainderRub,
  }) {
    final cap = fullPayPeaks(remainderRub);
    if (cap <= 0 || balance < cap) {
      return 0;
    }
    return cap;
  }

  static int _quoteFullOrPartial({
    required int available,
    required int remainderRub,
  }) {
    final cap = fullPayPeaks(remainderRub);
    final spend = available < cap ? available : cap;
    return roundDown(spend);
  }

  static int _quoteOutdoor({
    required int available,
    required int priceRub,
    required int remainderRub,
  }) {
    final cap = roundDown50((priceRub * outdoorDiscountShare * peaksPerRub).floor());
    var spend = available < cap ? available : cap;
    spend = roundDown(spend);
    final full = fullPayPeaks(remainderRub);
    while (spend > 0 && spend >= full) {
      spend -= unit;
    }
    if (spend < 0) {
      return 0;
    }
    return spend;
  }
}

const Set<String> _feedbackFillers = <String>{
  'ок',
  'окей',
  'okay',
  'ok',
  'норм',
  'нормально',
  'хорошо',
  'супер',
  'класс',
  'круто',
  'топ',
  'спасибо',
  'thanks',
  'thank you',
  'гуд',
  'good',
  'nice',
  'fine',
  'отлично',
  'плохо',
  'слабо',
  'ничего',
  'все ок',
  'всё ок',
  'сойдет',
  'сойдёт',
  'пойдет',
  'пойдёт',
  'нормас',
  'зачет',
  'зачёт',
  'ужас',
  'отстой',
  'огонь',
  'кайф',
};
