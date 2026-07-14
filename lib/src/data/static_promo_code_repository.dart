import 'package:dvor_chatbot/src/data/promo_code_repository.dart';
import 'package:dvor_chatbot/src/domain/promo_code.dart';

final class StaticPromoCodeRepository implements PromoCodeRepository {
  const StaticPromoCodeRepository({
    List<PromoCode> items = const <PromoCode>[],
  }) : _items = items;

  final List<PromoCode> _items;

  @override
  List<PromoCode> all() => _items;

  @override
  PromoCode? findByCode(String code) {
    final normalized = code.trim().toUpperCase();
    for (final item in _items) {
      if (item.code.trim().toUpperCase() == normalized) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<bool> refresh({bool force = false}) async => true;
}
