/// Single boxing-slot detector: case-insensitive match on training title.
bool isBoxingTrainingTitle(String title) {
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
