// 節目・記録更新・バッジのロジック(achievements.dart)の単体テスト。
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/domain/achievements.dart';
import 'package:wake_up_up/domain/wake_logic.dart';
import 'package:wake_up_up/domain/wake_record.dart';

const target = TargetTime(6, 30);

/// [date] に [h]:[m] に起きて保存された記録(成否は目標 6:30 で判定)。
WakeRecord r(String date, {int h = 6, int m = 0}) {
  final d = DateTime.parse(date);
  return buildRecord(DateTime(d.year, d.month, d.day, h, m), target);
}

String d(int n) => '2026-11-${n.toString().padLeft(2, '0')}';

/// 11/1 から [n] 日連続で成功した記録。
List<WakeRecord> run(int n, {int h = 6, int m = 0}) => [
  for (var i = 1; i <= n; i++) r(d(i), h: h, m: m),
];

void main() {
  group('節目', () {
    test('2日目では出ず、3日目で初めて出る', () {
      expect(detectAchievements(run(1), r(d(2))).newMilestone, isNull);
      expect(detectAchievements(run(2), r(d(3))).newMilestone, 3);
    });

    test('4日目は節目ではない', () {
      expect(detectAchievements(run(3), r(d(4))).newMilestone, isNull);
    });

    test('すべての節目で、ちょうど到達した日だけ出る', () {
      for (final m in milestones) {
        final before = [
          for (var i = 0; i < m - 1; i++)
            r(DateTime(2026, 1, 1 + i).toIso8601String().substring(0, 10)),
        ];
        final added = r(
          DateTime(2026, 1, m).toIso8601String().substring(0, 10),
        );
        expect(
          detectAchievements(before, added).newMilestone,
          m,
          reason: '$m日',
        );
        final next = r(
          DateTime(2026, 1, m + 1).toIso8601String().substring(0, 10),
        );
        expect(
          detectAchievements([...before, added], next).newMilestone,
          isNull,
          reason: '${m + 1}日',
        );
      }
    });

    test('途中で途切れて再び同じ日数に到達しても出ない(初回のみ)', () {
      final before = [
        ...run(3), // 11/1〜11/3: 3日連続を達成済み
        r(d(4), h: 8), // 失敗で途切れる
        r(d(5)),
        r(d(6)),
      ];
      expect(detectAchievements(before, r(d(7))).newMilestone, isNull);
    });

    test('過去の最長を超えた節目では出る(7日目)', () {
      final before = [
        ...run(3),
        r(d(4), h: 8),
        r(d(5)),
        r(d(6)),
        r(d(7)),
        r(d(8)),
        r(d(9)),
        r(d(10)),
      ];
      // 11/5〜11/10 の6日連続 + 11/11 で7日
      expect(detectAchievements(before, r(d(11))).newMilestone, 7);
    });

    test('記録のない日があると途切れて、節目にならない', () {
      final before = [r(d(1)), r(d(2))];
      expect(detectAchievements(before, r(d(4))).newMilestone, isNull);
    });

    test('失敗した記録では何も達成しない', () {
      final a = detectAchievements(run(2), r(d(3), h: 9));
      expect(a.hasAny, isFalse);
    });

    test('月をまたいだ連続でも節目になる', () {
      final before = [r('2026-11-29'), r('2026-11-30')];
      expect(detectAchievements(before, r('2026-12-01')).newMilestone, 3);
    });
  });

  group('最も早い起床の更新', () {
    test('最初の記録では更新にならない', () {
      expect(detectAchievements([], r(d(1))).newEarliest, isFalse);
    });

    test('過去のどれよりも早ければ更新', () {
      expect(
        detectAchievements([
          r(d(1), h: 6, m: 10),
        ], r(d(2), h: 6, m: 0)).newEarliest,
        isTrue,
      );
    });

    test('同じ時刻・遅い時刻では更新にならない', () {
      expect(
        detectAchievements([
          r(d(1), h: 6, m: 0),
        ], r(d(2), h: 6, m: 0)).newEarliest,
        isFalse,
      );
      expect(
        detectAchievements([
          r(d(1), h: 6, m: 0),
        ], r(d(2), h: 6, m: 10)).newEarliest,
        isFalse,
      );
    });

    test('失敗の記録では更新にならない', () {
      // 過去が 23:00(失敗)なら、8:00 は早いが失敗なので祝わない。
      expect(
        detectAchievements([
          r(d(1), h: 23, m: 0),
        ], r(d(2), h: 8, m: 0)).newEarliest,
        isFalse,
      );
    });

    test('日の境界: 3:00 は 2:59 より早い扱い', () {
      expect(
        detectAchievements([
          r(d(1), h: 2, m: 59),
        ], r(d(2), h: 3, m: 0)).newEarliest,
        isTrue,
      );
    });
  });

  group('最長連続の更新', () {
    test('過去に成功がなければ更新にならない(最初の成功)', () {
      expect(detectAchievements([], r(d(1))).newLongest, isFalse);
      expect(detectAchievements([r(d(1), h: 9)], r(d(2))).newLongest, isFalse);
    });

    test('過去の最長を超えたら更新', () {
      expect(detectAchievements([r(d(1))], r(d(2))).newLongest, isTrue);
    });

    test('過去の最長に並んだだけでは更新にならない', () {
      // 11/1〜11/2 で最長2日。11/5 に再び成功して1日目、11/6 で2日目(並ぶだけ)。
      final before = [r(d(1)), r(d(2)), r(d(5))];
      expect(detectAchievements(before, r(d(6))).newLongest, isFalse);
    });

    test('更新を続ける間は毎日 true', () {
      expect(detectAchievements(run(2), r(d(3))).newLongest, isTrue);
      expect(detectAchievements(run(3), r(d(4))).newLongest, isTrue);
    });
  });

  group('複数の達成が同時に起きる', () {
    test('節目・最早・最長が同時に立つ', () {
      final a = detectAchievements(run(2, h: 6, m: 10), r(d(3), h: 5, m: 0));
      expect(a.newMilestone, 3);
      expect(a.newEarliest, isTrue);
      expect(a.newLongest, isTrue);
      expect(a.hasAny, isTrue);
    });
  });

  group('badgeStatuses', () {
    test('記録なしはすべて未取得', () {
      final b = badgeStatuses([]);
      expect(b.length, milestones.length);
      expect(b.every((e) => !e.earned), isTrue);
    });

    test('最長連続が節目以上なら取得済み(7日 → 3日と7日が取得)', () {
      final b = badgeStatuses(run(7));
      expect(b.where((e) => e.earned).map((e) => e.days), [3, 7]);
    });

    test('一度取った後に途切れても取得済みのまま(最長で判定)', () {
      final b = badgeStatuses([...run(3), r(d(4), h: 9)]);
      expect(b.first.earned, isTrue);
    });

    test('2日連続では未取得', () {
      expect(badgeStatuses(run(2)).first.earned, isFalse);
    });
  });
}
