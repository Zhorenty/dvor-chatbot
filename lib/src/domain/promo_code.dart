import 'package:dvor_chatbot/src/domain/activity_category.dart';

final class PromoCode {
  const PromoCode({
    required this.code,
    required this.discountPercent,
    this.categories = const <ActivityCategory>{},
    this.singleUse = false,
  });

  final String code;
  final int discountPercent;

  /// Categories this promo code applies to. An empty set means it applies
  /// to all categories.
  final Set<ActivityCategory> categories;

  /// If true the promo code may only be applied to one booking globally.
  /// Subsequent attempts to apply it will be rejected.
  final bool singleUse;

  bool appliesTo(ActivityCategory category) {
    return categories.isEmpty || categories.contains(category);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PromoCode &&
            other.code == code &&
            other.discountPercent == discountPercent &&
            other.singleUse == singleUse &&
            other.categories.length == categories.length &&
            other.categories.containsAll(categories);
  }

  @override
  int get hashCode {
    final categoriesHash = categories.fold<int>(0, (acc, item) => acc ^ item.hashCode);
    return Object.hash(code, discountPercent, singleUse, categoriesHash);
  }
}
