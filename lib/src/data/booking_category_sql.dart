import 'package:dvor_chatbot/src/domain/activity_category.dart';

/// Shared booking-category filter. Camps live in the trails bucket.
abstract final class BookingCategorySql {
  static const String campOrTrailTitle = '''
(
  training_title LIKE '%кэмп%'
  OR training_title LIKE '%Кэмп%'
  OR training_title LIKE '%КЭМП%'
  OR training_title LIKE '%кемп%'
  OR training_title LIKE '%Кемп%'
  OR training_title LIKE '%КЕМП%'
  OR lower(training_title) LIKE '% camp%'
  OR lower(training_title) LIKE 'camp%'
  OR training_title LIKE '🎯 Кэмп:%'
  OR training_title LIKE '🏃 Трейл:%'
)''';

  static String forCategory(ActivityCategory category) {
    return switch (category) {
      ActivityCategory.trainings => "(training_key NOT LIKE 'hikes|%' "
          "AND training_title NOT LIKE '🥾 Поход:%' "
          "AND training_key NOT LIKE 'trails|%' "
          'AND NOT $campOrTrailTitle)',
      ActivityCategory.hikes => "(training_key LIKE 'hikes|%' OR training_title LIKE '🥾 Поход:%')",
      ActivityCategory.trails => "(training_key LIKE 'trails|%' OR $campOrTrailTitle)",
    };
  }
}
