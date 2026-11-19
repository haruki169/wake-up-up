import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/domain/wake_logic.dart';
import 'package:wake_up_up/domain/wake_record.dart';

void main() {
  const target = TargetTime(6, 30);

  group('logicalDate', () {
    test('3:00以降は当日', () {
      expect(logicalDate(DateTime(2026, 11, 19, 3, 0)), '2026-11-19');
    });
    test('3:00前は前日', () {
      expect(logicalDate(DateTime(2026, 11, 19, 2, 59)), '2026-11-18');
    });
    test('月初の3:00前は前月末', () {
      expect(logicalDate(DateTime(2026, 12, 1, 1, 0)), '2026-11-30');
    });
  });

  group('nextDayBoundary', () {
    test('朝6時の次の境界は翌日3:00', () {
      expect(
        nextDayBoundary(DateTime(2026, 11, 19, 6, 0)),
        DateTime(2026, 11, 20, 3, 0),
      );
    });
    test('深夜2時の次の境界は同日3:00', () {
      expect(
        nextDayBoundary(DateTime(2026, 11, 19, 2, 0)),
        DateTime(2026, 11, 19, 3, 0),
      );
    });
    test('ちょうど3:00なら翌日3:00', () {
      expect(
        nextDayBoundary(DateTime(2026, 11, 19, 3, 0)),
        DateTime(2026, 11, 20, 3, 0),
      );
    });
    test('月末・年末をまたぐ', () {
      expect(
        nextDayBoundary(DateTime(2026, 12, 31, 23, 0)),
        DateTime(2027, 1, 1, 3, 0),
      );
    });
  });

  group('judge / calcPoints', () {
    test('目標ちょうどは成功で10pt', () {
      final t = DateTime(2026, 11, 19, 6, 30);
      expect(judge(t, target), isTrue);
      expect(calcPoints(t, target), 10);
    });
    test('1分遅れは失敗で0pt', () {
      final t = DateTime(2026, 11, 19, 6, 31);
      expect(judge(t, target), isFalse);
      expect(calcPoints(t, target), 0);
    });
    test('10分早いと+1pt', () {
      expect(calcPoints(DateTime(2026, 11, 19, 6, 20), target), 11);
    });
    test('9分早いと+0pt', () {
      expect(calcPoints(DateTime(2026, 11, 19, 6, 21), target), 10);
    });
    test('ボーナスは上限+5pt', () {
      expect(calcPoints(DateTime(2026, 11, 19, 4, 0), target), 15);
    });
    test('深夜1時の記録は前日扱いで失敗', () {
      final t = DateTime(2026, 11, 19, 1, 0);
      expect(logicalDate(t), '2026-11-18');
      expect(judge(t, target), isFalse);
    });
  });

  group('currentStreak', () {
    WakeRecord rec(String date, bool ok) => WakeRecord(
      date: date,
      wokeAt: DateTime.parse(date),
      targetTime: target,
      success: ok,
      points: ok ? 10 : 0,
    );

    test('記録なしは0', () {
      expect(currentStreak([], '2026-11-19'), 0);
    });
    test('今日未記録なら昨日から数える', () {
      final rs = [rec('2026-11-18', true), rec('2026-11-17', true)];
      expect(currentStreak(rs, '2026-11-19'), 2);
    });
    test('今日を含めて連続', () {
      final rs = [
        rec('2026-11-19', true),
        rec('2026-11-18', true),
        rec('2026-11-17', false),
      ];
      expect(currentStreak(rs, '2026-11-19'), 2);
    });
    test('今日が失敗なら0', () {
      final rs = [rec('2026-11-19', false), rec('2026-11-18', true)];
      expect(currentStreak(rs, '2026-11-19'), 0);
    });
    test('月またぎ', () {
      final rs = [rec('2026-12-01', true), rec('2026-11-30', true)];
      expect(currentStreak(rs, '2026-12-01'), 2);
    });
  });

  test('totalPoints', () {
    final rs = [
      buildRecord(DateTime(2026, 11, 18, 6, 20), target),
      buildRecord(DateTime(2026, 11, 19, 7, 0), target),
    ];
    expect(totalPoints(rs), 11);
  });
}
