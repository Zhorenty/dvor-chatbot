import 'package:dvor_chatbot/src/application/economic_summary_service.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/domain/economic_summary.dart';
import 'package:dvor_chatbot/src/messages/message_templates.dart';
import 'package:dvor_chatbot/src/telegram/message_sender.dart';
import 'package:l/l.dart';

final class EconomicSummaryJob {
  const EconomicSummaryJob({
    required BookingRepository bookingRepository,
    required EconomicSummaryService economicSummaryService,
    required MessageSender sender,
    required MessageTemplates templates,
    required int? adminChatId,
    DateTime Function()? nowProvider,
  })  : _bookingRepository = bookingRepository,
        _economicSummaryService = economicSummaryService,
        _sender = sender,
        _templates = templates,
        _adminChatId = adminChatId,
        _nowProvider = nowProvider ?? DateTime.now;

  final BookingRepository _bookingRepository;
  final EconomicSummaryService _economicSummaryService;
  final MessageSender _sender;
  final MessageTemplates _templates;
  final int? _adminChatId;
  final DateTime Function() _nowProvider;

  Future<void> run() async {
    final adminChatId = _adminChatId;
    if (adminChatId == null) {
      return;
    }
    final now = _nowProvider();
    final weekly = _economicSummaryService.latestCompletedWeeklyPeriod(now);
    final monthly = _economicSummaryService.latestCompletedMonthlyPeriod(now);
    await _sendIfNeeded(adminChatId: adminChatId, period: weekly, now: now);
    await _sendIfNeeded(adminChatId: adminChatId, period: monthly, now: now);
  }

  Future<void> _sendIfNeeded({
    required int adminChatId,
    required EconomicSummaryPeriod period,
    required DateTime now,
  }) async {
    if (period.endExclusive.isAfter(now.toLocal())) {
      return;
    }
    final marked = await _bookingRepository.tryMarkEconomicReportSent(
      reportType: period.type.name,
      periodStart: period.startInclusive,
      periodEnd: period.endExclusive,
      sentAt: now,
    );
    if (!marked) {
      return;
    }
    final summary = await _economicSummaryService.buildSummary(period);
    final text = _templates.economicSummary(summary);
    try {
      await _sender.sendMessage(
        adminChatId,
        text,
        parseMode: 'HTML',
      );
    } on Object catch (error, stackTrace) {
      await _bookingRepository.rollbackEconomicReportSent(
        reportType: period.type.name,
        periodStart: period.startInclusive,
        periodEnd: period.endExclusive,
      );
      l.w('Failed to send economic summary report: $error', stackTrace);
    }
  }
}
