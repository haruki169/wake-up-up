// 目標の自動前倒し(auto_advance.dart)の単体テスト。
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/domain/auto_advance.dart';
import 'package:wake_up_up/domain/wake_record.dart';

import 'helpers/fakes.dart';

TargetTime t(int h, int m) => TargetTime(h, m);

String d(int n) => '2026-11-${n.toString().padLeft(2, '0')}';

/// [days] の各日に、目標 [target] で成功(または失敗)した記録。
List<WakeRecord> run(
  Iterable<int> days,
  TargetTime target, {
  Set<int> failed = const {},
}) => [for (final n in days) rec(d(n), !failed.contains(n), target: target)];

const on = AutoAdvance(
  enabled: true,
  days: 7,
  minutes: 15,
  goal: TargetTime(6, 0),
);

void main() {
  group('targetOrder', () {
    test('午前3:00 が最も早く、翌 2:59 が最も遅い', () {
      expect(targetOrder(t(3, 0)), 0);
      expect(targetOrder(t(2, 59)), 1439);
    });
    test('早い順に並ぶ(5:00 < 6:30 < 23:00 < 1:00)', () {
      expect(targetOrder(t(5, 0)) < targetOrder(t(6, 30)), isTrue);
      expect(targetOrder(t(6, 30)) < targetOrder(t(23, 0)), isTrue);
      expect(targetOrder(t(23, 0)) < targetOrder(t(1, 0)), isTrue);
    });
  });

  group('nextTarget', () {
    test('幅の分だけ早める', () {
      expect(nextTarget(t(7, 0), t(6, 0), 15), t(6, 45));
      expect(nextTarget(t(7, 0), t(4, 0), 30), t(6, 30));
      expect(nextTarget(t(12, 0), t(6, 0), 5), t(11, 55));
    });
    test('時をまたぐ(7:05 → 6:50)', () {
      expect(nextTarget(t(7, 5), t(6, 0), 15), t(6, 50));
    });
    test('最終目標を飛び越えるときは最終目標で止まる', () {
      expect(nextTarget(t(6, 10), t(6, 0), 15), t(6, 0));
      expect(nextTarget(t(6, 5), t(6, 0), 5), t(6, 0));
    });
    test('最終目標ちょうどになるときはその時刻', () {
      expect(nextTarget(t(6, 15), t(6, 0), 15), t(6, 0));
    });
    test('既に最終目標と同じ・それより早いなら変わらない', () {
      expect(nextTarget(t(6, 0), t(6, 0), 15), t(6, 0));
      expect(nextTarget(t(5, 0), t(6, 0), 15), t(5, 0));
    });
    test('最も早い最終目標(4:00)の手前で止まる', () {
      expect(nextTarget(t(4, 10), t(4, 0), 30), t(4, 0));
    });
  });

  group('advanceSteps', () {
    test('現在の目標から最終目標までの経過', () {
      expect(advanceSteps(t(7, 0), t(6, 0), 15), [
        t(7, 0),
        t(6, 45),
        t(6, 30),
        t(6, 15),
        t(6, 0),
      ]);
    });
    test('幅で割り切れないときも、最終目標で終わる', () {
      expect(advanceSteps(t(7, 0), t(6, 10), 15), [
        t(7, 0),
        t(6, 45),
        t(6, 30),
        t(6, 15),
        t(6, 10),
      ]);
    });
    test('既に最終目標以前なら現在の目標だけ', () {
      expect(advanceSteps(t(5, 0), t(6, 0), 15), [t(5, 0)]);
    });
  });

  group('streakAtTarget', () {
    test('今日を含めて、同じ目標の成功が連続した日数', () {
      expect(streakAtTarget(run(1.to(7), t(7, 0)), t(7, 0), d(7)), 7);
      expect(streakAtTarget(run(1.to(6), t(7, 0)), t(7, 0), d(6)), 6);
    });
    test('今日の記録がない・失敗なら0', () {
      expect(streakAtTarget(run(1.to(6), t(7, 0)), t(7, 0), d(7)), 0);
      expect(
        streakAtTarget(run(1.to(7), t(7, 0), failed: {7}), t(7, 0), d(7)),
        0,
      );
    });
    test('失敗の日で途切れる(その後の分だけ数える)', () {
      expect(
        streakAtTarget(run(1.to(7), t(7, 0), failed: {4}), t(7, 0), d(7)),
        3,
      );
    });
    test('記録のない日で途切れる', () {
      expect(
        streakAtTarget(run([1, 2, 3, 5, 6, 7], t(7, 0)), t(7, 0), d(7)),
        3,
      );
    });
    test('目標が違う記録で途切れる(目標を変えると数え直し)', () {
      final records = [...run(1.to(4), t(7, 0)), ...run(5.to(7), t(6, 45))];
      expect(streakAtTarget(records, t(6, 45), d(7)), 3);
      expect(streakAtTarget(records, t(7, 0), d(7)), 0);
    });
    test('月をまたいだ連続', () {
      final records = [
        rec('2026-11-29', true, target: t(7, 0)),
        rec('2026-11-30', true, target: t(7, 0)),
        rec('2026-12-01', true, target: t(7, 0)),
      ];
      expect(streakAtTarget(records, t(7, 0), '2026-12-01'), 3);
    });
    test('記録なしは0', () {
      expect(streakAtTarget([], t(7, 0), d(1)), 0);
    });
  });

  group('evaluateAutoAdvance', () {
    test('オフなら何もしない', () {
      expect(
        evaluateAutoAdvance(
          run(1.to(7), t(7, 0)),
          const AutoAdvance(),
          t(7, 0),
          d(7),
        ),
        isNull,
      );
    });
    test('N日ちょうどで前倒しする(7日 → 15分早める)', () {
      final r = evaluateAutoAdvance(run(1.to(7), t(7, 0)), on, t(7, 0), d(7))!;
      expect(r.from, t(7, 0));
      expect(r.to, t(6, 45));
      expect(r.reachedGoal, isFalse);
    });
    test('N−1日では前倒ししない', () {
      expect(
        evaluateAutoAdvance(run(1.to(6), t(7, 0)), on, t(7, 0), d(6)),
        isNull,
      );
    });
    test('途中で失敗して途切れていれば前倒ししない', () {
      expect(
        evaluateAutoAdvance(
          run(1.to(7), t(7, 0), failed: {3}),
          on,
          t(7, 0),
          d(7),
        ),
        isNull,
      );
    });
    test('N日を超えて続いていても前倒しする(後からオンにした場合)', () {
      final r = evaluateAutoAdvance(run(1.to(10), t(7, 0)), on, t(7, 0), d(10));
      expect(r?.to, t(6, 45));
    });
    test('最終目標に着くときは reachedGoal が true', () {
      final r = evaluateAutoAdvance(
        run(1.to(7), t(6, 15)),
        on,
        t(6, 15),
        d(7),
      )!;
      expect(r.to, t(6, 0));
      expect(r.reachedGoal, isTrue);
    });
    test('幅が大きくても最終目標を飛び越えない', () {
      const cfg = AutoAdvance(
        enabled: true,
        days: 3,
        minutes: 30,
        goal: TargetTime(6, 0),
      );
      final r = evaluateAutoAdvance(
        run(1.to(3), t(6, 10)),
        cfg,
        t(6, 10),
        d(3),
      )!;
      expect(r.to, t(6, 0));
      expect(r.reachedGoal, isTrue);
    });
    test('既に最終目標(以前)なら何もしない', () {
      expect(
        evaluateAutoAdvance(run(1.to(7), t(6, 0)), on, t(6, 0), d(7)),
        isNull,
      );
      expect(
        evaluateAutoAdvance(run(1.to(7), t(5, 30)), on, t(5, 30), d(7)),
        isNull,
      );
    });
    test('選択肢の最小(3日・5分)で動く', () {
      const cfg = AutoAdvance(
        enabled: true,
        days: 3,
        minutes: 5,
        goal: TargetTime(6, 0),
      );
      expect(
        evaluateAutoAdvance(run(1.to(3), t(7, 0)), cfg, t(7, 0), d(3))?.to,
        t(6, 55),
      );
    });
  });

  test('シミュレーション: 7日連続ごとに15分ずつ早まり、最終目標で止まる', () {
    var target = t(7, 0);
    var cfg = on;
    final records = <WakeRecord>[];
    final changes = <(int, TargetTime)>[];
    for (var day = 1; day <= 28; day++) {
      records.add(rec(d(day), true, target: target));
      final r = evaluateAutoAdvance(records, cfg, target, d(day));
      if (r != null) {
        target = r.to;
        if (r.reachedGoal) cfg = cfg.copyWith(enabled: false);
        changes.add((day, r.to));
      }
    }
    expect(changes, [
      (7, t(6, 45)),
      (14, t(6, 30)),
      (21, t(6, 15)),
      (28, t(6, 0)),
    ]);
    expect(cfg.enabled, isFalse);
  });

  test('シミュレーション: 途中の失敗で数え直しになる', () {
    var target = t(7, 0);
    final records = <WakeRecord>[];
    var advancedOn = 0;
    for (var day = 1; day <= 20; day++) {
      final ok = day != 5; // 5日目に失敗
      records.add(rec(d(day), ok, target: target));
      final r = evaluateAutoAdvance(records, on, target, d(day));
      if (r != null && advancedOn == 0) {
        advancedOn = day;
        target = r.to;
      }
    }
    expect(advancedOn, 12); // 6日目から数え直して7日目 = 12日目
  });

  group('validateGoal', () {
    test('4:00 より早いと tooEarly(3:59、3:00)', () {
      expect(
        validateGoal(t(3, 59), t(7, 0), requireBeforeTarget: false),
        GoalProblem.tooEarly,
      );
      expect(
        validateGoal(t(3, 0), t(7, 0), requireBeforeTarget: true),
        GoalProblem.tooEarly,
      );
    });
    test('4:00 ちょうどは有効', () {
      expect(validateGoal(t(4, 0), t(7, 0), requireBeforeTarget: true), isNull);
    });
    test('オンにするには、現在の目標より早い時刻が必要(同じ時刻もだめ)', () {
      expect(
        validateGoal(t(7, 0), t(7, 0), requireBeforeTarget: true),
        GoalProblem.notBeforeTarget,
      );
      expect(
        validateGoal(t(8, 0), t(7, 0), requireBeforeTarget: true),
        GoalProblem.notBeforeTarget,
      );
      expect(
        validateGoal(t(6, 59), t(7, 0), requireBeforeTarget: true),
        isNull,
      );
    });
    test('オフのときは、現在の目標との前後を問わない', () {
      expect(
        validateGoal(t(8, 0), t(7, 0), requireBeforeTarget: false),
        isNull,
      );
    });
  });

  test('AutoAdvance の初期値・選択肢・等価性', () {
    const a = AutoAdvance();
    expect(a.enabled, isFalse);
    expect(a.days, 7);
    expect(a.minutes, 15);
    expect(a.goal, t(6, 0));
    expect(AutoAdvance.dayOptions, [3, 5, 7, 10, 14]);
    expect(AutoAdvance.minuteOptions, [5, 10, 15, 30]);
    expect(AutoAdvance.earliestGoal, t(4, 0));
    expect(a, const AutoAdvance());
    expect(a.copyWith(days: 3) == a, isFalse);
    expect(a.copyWith(days: 3).minutes, 15);
  });
}

extension on int {
  /// このの値から [end] まで(両端を含む)の整数。
  Iterable<int> to(int end) => [for (var i = this; i <= end; i++) i];
}
