import 'package:dvor_chatbot/src/application/loyalty_math.dart';
import 'package:dvor_chatbot/src/domain/loyalty.dart';
import 'package:test/test.dart';

void main() {
  group('LoyaltyMath rounding', () {
    test('round_up_50 matches club anchors', () {
      expect(LoyaltyMath.roundUp50(175), 200);
      expect(LoyaltyMath.roundUp50(250), 250);
      expect(LoyaltyMath.roundUp50(1), 50);
      expect(LoyaltyMath.roundUp50(0), 0);
      expect(LoyaltyMath.roundUp50FromDouble(840), 850);
      expect(LoyaltyMath.roundUp50FromDouble(940), 950);
    });

    test('training earn is round_up_50(price / 2)', () {
      expect(LoyaltyMath.trainingEarnPeaks(350), 200);
      expect(LoyaltyMath.trainingEarnPeaks(500), 250);
      expect(LoyaltyMath.trainingEarnPeaks(400), 200);
      expect(LoyaltyMath.trainingEarnPeaks(1), 50);
      expect(LoyaltyMath.trainingEarnPeaks(0), 0);
    });

    test('four paid trainings accumulate as specified', () {
      expect(LoyaltyMath.trainingEarnPeaks(500) * 4, 1000);
      expect(LoyaltyMath.trainingEarnPeaks(350) * 4, 800);
      expect(LoyaltyMath.fullPayPeaks(500), 1000);
      expect(LoyaltyMath.fullPayPeaks(350), 700);
    });

    test('outdoor and card cash share is 10% in peaks', () {
      expect(LoyaltyMath.outdoorEarnPeaks(750), 150);
      expect(LoyaltyMath.outdoorEarnPeaks(1500), 300);
      expect(LoyaltyMath.outdoorEarnPeaks(4200), 850);
      expect(LoyaltyMath.boxingCardEarnPeaks(3500), 700);
      expect(LoyaltyMath.boxingCardEarnPeaks(4700), 950);
      expect(LoyaltyMath.boxingCardEarnPeaks(0), 0);
    });
  });

  group('LoyaltyMath spend quotes', () {
    test('training can cover fully or partially in 50-peak steps', () {
      final full = LoyaltyMath.quoteSpend(
        target: LoyaltySpendTarget.training,
        priceRub: 500,
        balance: 1000,
      );
      expect(full.peaks, 1000);
      expect(full.remainderRub, 0);
      expect(full.coversFully, isTrue);

      final partial = LoyaltyMath.quoteSpend(
        target: LoyaltySpendTarget.training,
        priceRub: 500,
        balance: 400,
      );
      expect(partial.peaks, 400);
      expect(partial.remainderRub, 300);
      expect(partial.coversFully, isFalse);
    });

    test('outdoor discount is capped at 30% and never covers fully', () {
      final quote = LoyaltyMath.quoteSpend(
        target: LoyaltySpendTarget.outdoor,
        priceRub: 1500,
        balance: 10000,
      );
      expect(quote.peaks, 900);
      expect(quote.remainderRub, 1050);
      expect(quote.coversFully, isFalse);

      final cheap = LoyaltyMath.quoteSpend(
        target: LoyaltySpendTarget.outdoor,
        priceRub: 100,
        balance: 10000,
      );
      expect(cheap.peaks, 50);
      expect(cheap.coversFully, isFalse);
      expect(cheap.remainderRub, greaterThan(0));
    });

    test('promo remainder is quoted from the discounted price', () {
      final quote = LoyaltyMath.quoteSpend(
        target: LoyaltySpendTarget.training,
        priceRub: 250,
        balance: 1000,
      );
      expect(quote.peaks, 500);
      expect(quote.remainderRub, 0);
      expect(quote.coversFully, isTrue);
    });

    test('unused every-fifth rewards and leftover progress convert at release', () {
      expect(
        LoyaltyMath.unusedEveryFifthRewards(
          qualifiedTrainingsCount: 4,
          usedRewardsCount: 0,
        ),
        1,
      );
      expect(LoyaltyMath.unusedEveryFifthPeaks(1), 1000);
      expect(
        LoyaltyMath.unusedEveryFifthRewards(
          qualifiedTrainingsCount: 3,
          usedRewardsCount: 0,
        ),
        0,
      );
      expect(
        LoyaltyMath.unusedEveryFifthRewards(
          qualifiedTrainingsCount: 8,
          usedRewardsCount: 1,
        ),
        1,
      );
    });

    test('boxing card full pay matches tariff', () {
      final baza = LoyaltyMath.quoteSpend(
        target: LoyaltySpendTarget.boxingCard,
        priceRub: 3500,
        balance: 7000,
      );
      expect(baza.peaks, 7000);
      expect(baza.coversFully, isTrue);

      final udar = LoyaltyMath.quoteSpend(
        target: LoyaltySpendTarget.boxingCard,
        priceRub: 4700,
        balance: 9400,
      );
      expect(udar.peaks, 9400);
      expect(udar.coversFully, isTrue);
    });
  });
}
