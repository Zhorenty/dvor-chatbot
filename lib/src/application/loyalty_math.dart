import 'package:dvor_chatbot/src/domain/loyalty.dart';

/// Rounding and quotes for вершинки. Keep all money math here.
abstract final class LoyaltyMath {
  static const int lifetimeDays = 45;
  static const Duration lifetime = Duration(days: 45);
  static const int reminderLeadDays = 7;
  static const Duration reminderLead = Duration(days: 7);
  static const int unit = 50;
  static const int peaksPerRub = 2;
  static const int startBonusPeaks = 1000;
  static const int referralPeaks = 1000;
  static const int feedbackPeaks = 50;
  static const int missingTrainingPriceEarnPeaks = 250;
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

  /// Fractional raw amounts: ceil to int, then round up to a multiple of 50.
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

  /// 25% back from this training's cash remainder: round_up_50(price_rub / 2).
  static int trainingEarnPeaks(int priceRub) {
    if (priceRub <= 0) {
      return 0;
    }
    return roundUp50FromDouble(priceRub / 2.0);
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
    final available = roundDown50(balance);
    if (available <= 0) {
      return LoyaltySpendQuote(
        peaks: 0,
        remainderRub: currentRemainder,
        coversFully: false,
      );
    }
    final peaks = switch (target) {
      LoyaltySpendTarget.training ||
      LoyaltySpendTarget.boxingCard =>
        _quoteFullOrPartial(available: available, remainderRub: currentRemainder),
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

  static int _quoteFullOrPartial({
    required int available,
    required int remainderRub,
  }) {
    final cap = fullPayPeaks(remainderRub);
    final spend = available < cap ? available : cap;
    return roundDown50(spend);
  }

  static int _quoteOutdoor({
    required int available,
    required int priceRub,
    required int remainderRub,
  }) {
    final cap = roundDown50((priceRub * outdoorDiscountShare * peaksPerRub).floor());
    var spend = available < cap ? available : cap;
    spend = roundDown50(spend);
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
