// 月カレンダーのロジック(calendar.dart)の単体テスト。
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/domain/calendar.dart';
import 'package:wake_up_up/domain/wake_record.dart';

import 'helpers/fakes.dart';

/// 表の中の日付の一覧(null を除く)。
List<int> daysIn(List<List<DateTime?>> grid) => [
  for (final w in grid)
    for (final d in w)
      if (d != null) d.day,
];

void main() {
  group('monthGrid', () {
    test('2026年11月: 1日が日曜、30日で5週', () {
      final g = monthGrid(2026, 11);
      expect(g.length, 5);
      expect(g.first.first, DateTime(2026, 11, 1)); // 日曜日の位置
      expect(g.last[1], DateTime(2026, 11, 30)); // 月曜日の位置
      expect(g.last.sublist(2).every((d) => d == null), isTrue);
    });

    test('2026年2月: 1日が日曜、28日でちょうど4週', () {
      final g = monthGrid(2026, 2);
      expect(g.length, 4);
      expect(g.every((w) => w.every((d) => d != null)), isTrue);
    });

    test('2028年2月(閏年): 1日が火曜、29日で5週', () {
      final g = monthGrid(2028, 2);
      expect(g.length, 5);
      expect(g.first[0], isNull);
      expect(g.first[1], isNull);
      expect(g.first[2], DateTime(2028, 2, 1));
      expect(daysIn(g).last, 29);
    });

    test('2027年2月(平年): 28日', () {
      expect(daysIn(monthGrid(2027, 2)).last, 28);
    });

    test('2027年1月: 1日が金曜、31日で6週', () {
      final g = monthGrid(2027, 1);
      expect(g.length, 6);
      expect(g.first[5], DateTime(2027, 1, 1));
    });

    test('2026年8月: 1日が土曜、31日で6週', () {
      final g = monthGrid(2026, 8);
      expect(g.length, 6);
      expect(g.first[6], DateTime(2026, 8, 1));
    });

    test('30日の月・31日の月で日数が合う', () {
      expect(daysIn(monthGrid(2026, 4)).length, 30);
      expect(daysIn(monthGrid(2026, 12)).length, 31);
    });

    test('どの月も、各行が7要素で、日付が1日ずつ重複なく並ぶ', () {
      for (var y = 2026; y <= 2029; y++) {
        for (var m = 1; m <= 12; m++) {
          final g = monthGrid(y, m);
          expect(g.every((w) => w.length == 7), isTrue, reason: '$y-$m');
          final days = daysIn(g);
          expect(days, [
            for (var d = 1; d <= days.length; d++) d,
          ], reason: '$y-$m');
          expect(days.length, DateTime(y, m + 1, 0).day, reason: '$y-$m');
          expect(g.length, inInclusiveRange(4, 6), reason: '$y-$m');
        }
      }
    });
  });

  group('dayStatus', () {
    final byDate = {
      '2026-11-18': rec('2026-11-18', true),
      '2026-11-19': rec('2026-11-19', false),
    };
    const today = '2026-11-20';

    test('成功・失敗', () {
      expect(
        dayStatus(DateTime(2026, 11, 18), byDate, today),
        DayStatus.success,
      );
      expect(
        dayStatus(DateTime(2026, 11, 19), byDate, today),
        DayStatus.failure,
      );
    });
    test('記録のない過去は none、今日の未記録も none', () {
      expect(dayStatus(DateTime(2026, 11, 1), byDate, today), DayStatus.none);
      expect(dayStatus(DateTime(2026, 11, 20), byDate, today), DayStatus.none);
    });
    test('明日以降は future', () {
      expect(
        dayStatus(DateTime(2026, 11, 21), byDate, today),
        DayStatus.future,
      );
      expect(dayStatus(DateTime(2027, 1, 1), byDate, today), DayStatus.future);
    });
    test('今日が記録済みなら成功/失敗', () {
      final m = {'2026-11-20': rec('2026-11-20', true)};
      expect(dayStatus(DateTime(2026, 11, 20), m, today), DayStatus.success);
    });
  });

  group('summaryOfMonth', () {
    final records = [
      rec('2026-10-31', true),
      rec('2026-11-01', true),
      rec('2026-11-02', false),
      rec('2026-11-03', true),
      rec('2026-12-01', false),
    ];
    test('その月だけを集計する', () {
      final s = summaryOfMonth(records, 2026, 11);
      expect(s.success, 2);
      expect(s.failure, 1);
      expect(s.recorded, 3);
      expect(s.percent, 67);
    });
    test('記録のない月は0(ゼロ除算しない)', () {
      final s = summaryOfMonth(records, 2026, 9);
      expect(s.recorded, 0);
      expect(s.percent, 0);
    });
    test('月の境界(10/31 と 12/1)は含めない', () {
      expect(summaryOfMonth(records, 2026, 10).success, 1);
      expect(summaryOfMonth(records, 2026, 12).failure, 1);
    });
  });

  group('monthRange', () {
    test('最初の記録の月〜今日の月', () {
      final r = monthRange([
        rec('2026-09-15', true),
        rec('2026-11-01', true),
      ], '2026-11-20');
      expect(r.first, DateTime(2026, 9, 1));
      expect(r.last, DateTime(2026, 11, 1));
    });
    test('記録がなければ今日の月だけ', () {
      final r = monthRange(<WakeRecord>[], '2026-11-20');
      expect(r.first, DateTime(2026, 11, 1));
      expect(r.last, DateTime(2026, 11, 1));
      expect(r.canGoPrevious(r.last), isFalse);
      expect(r.canGoNext(r.last), isFalse);
    });
    test('年をまたぐ範囲での移動可否', () {
      final r = monthRange([rec('2025-12-31', true)], '2026-01-02');
      expect(r.first, DateTime(2025, 12, 1));
      expect(r.canGoPrevious(DateTime(2026, 1, 1)), isTrue);
      expect(r.canGoPrevious(DateTime(2025, 12, 1)), isFalse);
      expect(r.canGoNext(DateTime(2025, 12, 1)), isTrue);
      expect(r.canGoNext(DateTime(2026, 1, 1)), isFalse);
    });
    test('範囲外の月は範囲内に収める', () {
      final r = monthRange([rec('2026-09-15', true)], '2026-11-20');
      expect(r.clamp(DateTime(2026, 1, 1)), DateTime(2026, 9, 1));
      expect(r.clamp(DateTime(2027, 5, 1)), DateTime(2026, 11, 1));
      expect(r.clamp(DateTime(2026, 10, 15)), DateTime(2026, 10, 1));
    });
    test('未来の日付の記録があっても、今日の月を超えない', () {
      final r = monthRange([rec('2026-11-01', true)], '2026-11-20');
      expect(r.last, DateTime(2026, 11, 1));
    });
  });
}
