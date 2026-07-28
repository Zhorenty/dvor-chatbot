import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dvor_chatbot/src/application/group_announcement_service.dart';
import 'package:dvor_chatbot/src/data/booking_repository.dart';
import 'package:dvor_chatbot/src/data/job_dedupe_repository.dart';
import 'package:dvor_chatbot/src/data/sqlite/sqlite_database_handle.dart';
import 'package:dvor_chatbot/src/data/sqlite_booking_repository.dart';
import 'package:dvor_chatbot/src/domain/booking_status.dart';
import 'package:dvor_chatbot/src/domain/training_info.dart';
import 'package:dvor_chatbot/src/jobs/job_scheduler.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  group('concurrency safety nets', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('dvor-concurrency-');
    });

    tearDown(() async {
      if (tmpDir.existsSync()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('capacity limit holds under concurrent creates via isolates', () async {
      final dbPath = '${tmpDir.path}/bookings.sqlite';
      final bootstrap = SqliteBookingRepository(dbPath: dbPath);
      await bootstrap.init();
      await bootstrap.close();

      final training = TrainingInfo(
        title: 'Limited race',
        startsAt: DateTime.utc(2030, 6, 10, 19),
        location: 'Gym A',
        participantsLimit: 1,
      );

      Future<String> createInIsolate(int userId) {
        return Isolate.run(() async {
          Object? lastError;
          for (var attempt = 0; attempt < 8; attempt++) {
            final repository = SqliteBookingRepository(dbPath: dbPath);
            try {
              await repository.init();
              await repository.createPendingBooking(
                userId: userId,
                userUsername: 'user_$userId',
                training: training,
              );
              await repository.close();
              return 'ok';
            } on BookingParticipantsLimitExceededException {
              await repository.close();
              return 'limit';
            } on Object catch (error) {
              lastError = error;
              try {
                await repository.close();
              } on Object {
                // ignore
              }
              await Future<void>.delayed(Duration(milliseconds: 20 * (attempt + 1)));
            }
          }
          throw StateError('createInIsolate failed: $lastError');
        });
      }

      final outcomes = await Future.wait(<Future<String>>[
        createInIsolate(1001),
        createInIsolate(1002),
        createInIsolate(1003),
      ]);

      expect(outcomes.where((o) => o == 'ok'), hasLength(1));
      expect(outcomes.where((o) => o == 'limit'), hasLength(2));

      final verify = SqliteBookingRepository(dbPath: dbPath);
      await verify.init();
      final active = await verify.listByTrainingKeys(<String>{training.sessionKey});
      expect(
        active
            .where(
              (b) =>
                  b.status != BookingStatus.cancelled && b.status != BookingStatus.paymentRejected,
            )
            .length,
        1,
      );
      await verify.close();
    });

    test('job scheduler skips overlapping runs for same name', () async {
      final scheduler = JobScheduler();
      var runs = 0;
      final started = Completer<void>();
      final release = Completer<void>();

      scheduler.launch('slow', () async {
        runs += 1;
        started.complete();
        await release.future;
      });
      await started.future;
      scheduler.launch('slow', () async {
        runs += 1;
      });
      expect(scheduler.isInFlight('slow'), isTrue);
      release.complete();
      await scheduler.waitForIdle();
      expect(runs, 1);
    });

    test('group announcement publish serializes concurrent callers', () async {
      final sender = FakeSender(sendDelay: const Duration(milliseconds: 40));
      final service = GroupAnnouncementService(sender: sender);

      final results = await Future.wait(<Future<bool>>[
        service.publish(
          chatId: -100,
          type: GroupAnnouncementType.lowSpots,
          text: 'first',
        ),
        service.publish(
          chatId: -100,
          type: GroupAnnouncementType.scheduleBroadcast,
          text: 'second',
        ),
      ]);

      expect(results, everyElement(isTrue));
      expect(sender.messages.map((m) => m.text), <String>['first', 'second']);
      expect(sender.deletedMessages, hasLength(1));
    });

    test('job dedupe claims key once across repository instances', () async {
      final handle = SqliteDatabaseHandle.open('${tmpDir.path}/shared.sqlite');
      final first = JobDedupeRepository(databaseHandle: handle)..initSchema();
      final second = JobDedupeRepository(databaseHandle: handle);
      expect(first.tryClaim('promo|1'), isTrue);
      expect(second.tryClaim('promo|1'), isFalse);
      first.release('promo|1');
      expect(second.tryClaim('promo|1'), isTrue);
      handle.close();
    });
  });
}
