/// Camp slot: boxing camp and other camps, not a trail and not a boxing-card visit.
///
/// «bootcamp» stays a training. A separate word «camp» / «кэмп» / «кемп» is a camp.
bool isCampActivityTitle(String title) {
  final normalized = title.toLowerCase();
  if (normalized.contains('кэмп') || normalized.contains('кемп')) {
    return true;
  }
  return RegExp(r'(^|[^a-z])camp').hasMatch(normalized);
}
