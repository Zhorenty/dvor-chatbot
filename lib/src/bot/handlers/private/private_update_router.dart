final class PrivateUpdateRouter {
  const PrivateUpdateRouter();

  int? parseCommandId(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return null;
    }
    return int.tryParse(parts[1]);
  }

  int? parseTrainingSelectionIndex(String text) {
    final trimmed = text.trim();
    final direct = int.tryParse(trimmed);
    if (direct != null) {
      return direct;
    }
    final prefixed = RegExp(r'^🎯\s*(\d+)\.').firstMatch(trimmed);
    if (prefixed != null) {
      return int.tryParse(prefixed.group(1)!);
    }
    final numbered = RegExp(r'^(\d+)\.').firstMatch(trimmed);
    if (numbered != null) {
      return int.tryParse(numbered.group(1)!);
    }
    return null;
  }
}
