part of '../private_handlers.dart';

extension PrivateHandlersScheduleOps on PrivateHandlers {
  String _scheduleTextByCategory(_ActivityCategory category) {
    return _scheduleQueryService.scheduleText(category);
  }

  Future<void> _refreshTrainerDirectoryForSchedule() async {
    final refreshOk = await _trainerDirectoryRepository.refresh();
    if (!refreshOk) {
      l.w('Trainer directory refresh failed before schedule rendering. Using cached trainers.');
    }
  }

  List<TrainingInfo> _bookableItemsByCategory(_ActivityCategory category) {
    return _catalogService.bookableItems(category);
  }

  int? _parseTrainingSelectionIndex(String text) {
    return _updateRouter.parseTrainingSelectionIndex(text);
  }

  int? _parseBookingSelectionId(String text) {
    return _updateRouter.parseBookingIdSelection(text);
  }

  int? _parseTrainerSelectionIndex(String text) {
    final match = RegExp(r'(\d+)\.').firstMatch(text);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  bool? _parseBookingSegmentSelection(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.contains('актуал') || normalized.contains('актив')) {
      return false;
    }
    if (normalized.contains('прошед') || normalized.contains('архив')) {
      return true;
    }
    return null;
  }

  bool? _parseMyBookingSegmentSelection(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.contains('актуал')) {
      return false;
    }
    if (normalized.contains('прошед')) {
      return true;
    }
    return null;
  }

  BookingStatus? _parsePaymentStatusSelection(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.contains('ожидает')) {
      return BookingStatus.pendingPayment;
    }
    if (normalized.contains('проверке') || normalized.contains('проверк')) {
      return BookingStatus.paymentSubmitted;
    }
    if (normalized.contains('предоплат') ||
        normalized.contains('аванс') ||
        normalized.contains('задат')) {
      return BookingStatus.partialPaid;
    }
    if (normalized.contains('оплачен') || normalized.contains('оплачено')) {
      return BookingStatus.paid;
    }
    if (normalized.contains('бесплат')) {
      return BookingStatus.freeTraining;
    }
    if (normalized.contains('отклон')) {
      return BookingStatus.paymentRejected;
    }
    return null;
  }

  String? _normalizeUsernameInput(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  }

  /// Parses a comma-separated list of usernames (with or without @).
  /// Returns null if the input is empty or any entry contains spaces.
  List<String>? _parseUsernameListInput(String text) {
    final parts = text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.startsWith('@') ? e.substring(1) : e)
        .toList();
    if (parts.isEmpty) return null;
    if (parts.any((u) => u.contains(' '))) return null;
    return parts;
  }
}
