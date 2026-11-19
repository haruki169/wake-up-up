// ベスト記録の計算ロジック(stats.dart)の単体テスト。
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/domain/stats.dart';
import 'package:wake_up_up/domain/wake_record.dart';

/// 日付 [date] に [h]:[m]:[sec] に起きた記録を作る。
WakeRecord r(String date, bool ok, {int h = 6, int m = 0, int sec = 0}) {
  final d = DateTime.parse(date);
  return WakeRecord(
    date: date,
    wokeAt: DateTime(d.year, d.month, d.day, h, m, sec),
    targetTime: const TargetTime(6, 30),
    success: ok,
    points: ok ? 10 : 0,
  );
}

void main() {
  group('minutesFromBoundary', () {
    test('3:00 が0、翌 2:59 が1439', () {
      expect(minutesFromBoundary(DateTime(2026, 11, 19, 3, 0)), 0);
      expect(minutesFromBoundary(DateTime(2026, 11, 19, 2, 59)), 1439);
    });
    test('6:30 は 210分、23:59 は 1259分、0:00 は 1260分', () {
      expect(minutesFromBoundary(DateTime(2026, 11, 19, 6, 30)), 210);
      expect(minutesFromBoundary(DateTime(2026, 11, 19, 23, 59)), 1259);
      expect(minutesFromBoundary(DateTime(2026, 11, 19, 0, 0)), 1260);
    });
  });

  group('longestStreak', () {
    test('記録なしは null', () => expect(longestStreak([]), isNull));

    test('成功が1日もなければ null', () {
      expect(
        longestStreak([r('2026-11-18', false), r('2026-11-19', false)]),
        isNull,
      );
    });

    test('1件だけ成功なら1日', () {
      final s = longestStreak([r('2026-11-19', true)])!;
      expect(s.days, 1);
      expect(s.startDate, '2026-11-19');
      expect(s.endDate, '2026-11-19');
    });

    test('連続した成功の期間を返す(並び順は問わない)', () {
      final s = longestStreak([
        r('2026-11-19', true),
        r('2026-11-17', true),
        r('2026-11-18', true),
      ])!;
      expect(s.days, 3);
      expect(s.startDate, '2026-11-17');
      expect(s.endDate, '2026-11-19');
    });

    test('失敗の日で途切れる', () {
      final s = longestStreak([
        r('2026-11-15', true),
        r('2026-11-16', true),
        r('2026-11-17', false),
        r('2026-11-18', true),
      ])!;
      expect(s.days, 2);
      expect(s.startDate, '2026-11-15');
    });

    test('記録のない日で途切れる', () {
      final s = longestStreak([
        r('2026-11-10', true),
        r('2026-11-11', true),
        r('2026-11-13', true),
      ])!;
      expect(s.days, 2);
    });

    test('同じ日数なら新しい期間を返す', () {
      final s = longestStreak([
        r('2026-11-01', true),
        r('2026-11-02', true),
        r('2026-11-10', true),
        r('2026-11-11', true),
      ])!;
      expect(s.startDate, '2026-11-10');
    });

    test('最長は途中の期間でもよい', () {
      final s = longestStreak([
        r('2026-11-01', true),
        r('2026-11-05', true),
        r('2026-11-06', true),
        r('2026-11-07', true),
        r('2026-11-09', true),
      ])!;
      expect(s.days, 3);
      expect(s.startDate, '2026-11-05');
      expect(s.endDate, '2026-11-07');
    });

    test('月またぎ・年またぎ・閏日をまたぐ連続', () {
      expect(
        longestStreak([r('2026-11-30', true), r('2026-12-01', true)])!.days,
        2,
      );
      expect(
        longestStreak([r('2026-12-31', true), r('2027-01-01', true)])!.days,
        2,
      );
      expect(
        longestStreak([
          r('2028-02-28', true),
          r('2028-02-29', true),
          r('2028-03-01', true),
        ])!.days,
        3,
      );
    });

    test('夏時間の切り替わりをまたいでも連続と判定する', () {
      expect(
        longestStreak([
          r('2026-03-07', true),
          r('2026-03-08', true),
          r('2026-03-09', true),
        ])!.days,
        3,
      );
    });
  });

  group('earliestWake', () {
    test('記録なしは null', () => expect(earliestWake([]), isNull));

    test('最も早い時刻の記録を返す(成功・失敗を問わない)', () {
      final e = earliestWake([
        r('2026-11-17', true, h: 6, m: 10),
        r('2026-11-18', false, h: 5, m: 30),
        r('2026-11-19', true, h: 6, m: 0),
      ])!;
      expect(e.date, '2026-11-18');
    });

    test('3:00 は 2:59 より早い(日の境界で比べる)', () {
      final e = earliestWake([
        r('2026-11-18', false, h: 2, m: 59),
        r('2026-11-19', true, h: 3, m: 0),
      ])!;
      expect(e.date, '2026-11-19');
    });

    test('同じ時刻なら日付の古い方', () {
      final e = earliestWake([
        r('2026-11-19', true, h: 5, m: 0),
        r('2026-11-17', true, h: 5, m: 0),
        r('2026-11-18', true, h: 5, m: 0),
      ])!;
      expect(e.date, '2026-11-17');
    });

    test('秒は無視する(同じ分は同じ時刻)', () {
      final e = earliestWake([
        r('2026-11-18', true, h: 5, m: 0, sec: 59),
        r('2026-11-17', true, h: 5, m: 0, sec: 1),
      ])!;
      expect(e.date, '2026-11-17');
    });

    test('1件だけならその記録', () {
      expect(earliestWake([r('2026-11-19', true)])!.date, '2026-11-19');
    });
  });

  group('summary', () {
    test('記録なしは 0/0 で成功率0(ゼロ除算しない)', () {
      final s = summary([]);
      expect(s.successDays, 0);
      expect(s.recordedDays, 0);
      expect(s.successRate, 0);
      expect(s.successPercent, 0);
    });

    test('すべて成功は100%、すべて失敗は0%', () {
      expect(
        summary([r('2026-11-18', true), r('2026-11-19', true)]).successPercent,
        100,
      );
      expect(
        summary([r('2026-11-18', false), r('2026-11-19', false)])
            .successPercent,
        0,
      );
    });

    test('成功率は四捨五入する(2/3 → 67%、1/3 → 33%)', () {
      expect(
        summary([
          r('2026-11-17', true),
          r('2026-11-18', true),
          r('2026-11-19', false),
        ]).successPercent,
        67,
      );
      expect(
        summary([
          r('2026-11-17', true),
          r('2026-11-18', false),
          r('2026-11-19', false),
        ]).successPercent,
        33,
      );
    });

    test('日数を数える', () {
      final s = summary([
        r('2026-11-17', true),
        r('2026-11-18', false),
        r('2026-11-19', true),
      ]);
      expect(s.successDays, 2);
      expect(s.recordedDays, 3);
    });
  });
}
