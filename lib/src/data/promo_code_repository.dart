import 'package:dvor_chatbot/src/domain/promo_code.dart';

abstract interface class PromoCodeRepository {
  List<PromoCode> all();

  PromoCode? findByCode(String code);

  Future<bool> refresh({bool force = false});
}

final class NoopPromoCodeRepository implements PromoCodeRepository {
  const NoopPromoCodeRepository();

  @override
  List<PromoCode> all() => const <PromoCode>[];

  @override
  PromoCode? findByCode(String code) => null;

  @override
  Future<bool> refresh({bool force = false}) async => true;
}
