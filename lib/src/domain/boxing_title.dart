import 'package:dvor_chatbot/src/domain/camp_title.dart';

/// Single boxing-slot detector: case-insensitive match on training title.
/// A camp (including boxing camp) is not a boxing-card visit.
bool isBoxingTrainingTitle(String title) {
  if (isCampActivityTitle(title)) {
    return false;
  }
  final normalized = title.toLowerCase();
  const markers = <String>[
    'box',
    'boxing',
    'бокс',
    'бокса',
    'боксер',
    'боксёр',
  ];
  return markers.any(normalized.contains);
}
