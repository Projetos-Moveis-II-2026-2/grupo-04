import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/water/domain/entities/water_intake_record.dart';

void main() {
  WaterIntakeRecord buildRecord({
    String date = '2026-09-16',
    DateTime? recordedAt,
    bool synced = false,
    int amountMl = 300,
  }) {
    return WaterIntakeRecord(
      id: 'record-1',
      userId: 'user-1',
      amountMl: amountMl,
      recordedAt: recordedAt ?? DateTime(2026, 9, 16, 10, 30),
      date: date,
      synced: synced,
    );
  }

  group('localRecordedAt', () {
    test('should return the local time when date matches', () {
      final record = buildRecord();
      expect(record.localRecordedAt, DateTime(2026, 9, 16, 10, 30));
    });

    test(
      'should rebuild the date when stored date differs from local date',
      () {
        final record = buildRecord(
          date: '2026-09-17',
          recordedAt: DateTime(2026, 9, 16, 23, 59, 50),
        );

        final result = record.localRecordedAt;

        expect(result, DateTime(2026, 9, 17, 23, 59, 50));
        expect(result.year, 2026);
        expect(result.month, 9);
        expect(result.day, 17);
      },
    );

    test('should fall back to local time when date is empty', () {
      final record = buildRecord(
        date: '',
        recordedAt: DateTime(2026, 9, 16, 8, 15),
      );
      expect(record.localRecordedAt, DateTime(2026, 9, 16, 8, 15));
    });

    test('should fall back to local time when date is malformed', () {
      final record = buildRecord(
        date: 'not-a-date',
        recordedAt: DateTime(2026, 9, 16, 8, 15),
      );
      expect(record.localRecordedAt, DateTime(2026, 9, 16, 8, 15));
    });

    test('should fall back to local time when date has fewer parts', () {
      final record = buildRecord(
        date: '2026-09',
        recordedAt: DateTime(2026, 9, 16, 8, 15),
      );
      expect(record.localRecordedAt, DateTime(2026, 9, 16, 8, 15));
    });
  });

  group('Equatable', () {
    test('should be equal when all props match', () {
      expect(buildRecord(), buildRecord());
    });

    test('should differ when amount changes', () {
      expect(buildRecord(), isNot(buildRecord(amountMl: 500)));
    });

    test('should differ when synced changes', () {
      expect(buildRecord(), isNot(buildRecord(synced: true)));
    });

    test('props should include all fields', () {
      expect(buildRecord().props, hasLength(7));
    });
  });
}
