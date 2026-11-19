import 'stats.dart';
import 'wake_logic.dart';
import 'wake_record.dart';

/// 目標の自動前倒しの設定。
///
/// 「[days] 日連続で成功したら、目標時刻を [minutes] 分早める」を、
/// 最終目標 [goal] に達するまで繰り返す。
class AutoAdvance {
  const AutoAdvance({
    this.enabled = false,
    this.days = 7,
    this.minutes = 15,
    this.goal = const TargetTime(6, 0),
  });

  /// 選べる連続成功日数。
  static const List<int> dayOptions = [3, 5, 7, 10, 14];

  /// 選べる前倒しの幅(分)。
  static const List<int> minuteOptions = [5, 10, 15, 30];

  /// 最終目標に設定できる最も早い時刻(午前3:00 が日の境界のため、それより前は意味がない)。
  static const TargetTime earliestGoal = TargetTime(4, 0);

  /// 自動前倒しを使うか。
  final bool enabled;

  /// 何日連続で成功したら前倒しするか。
  final int days;

  /// 1回に早める分数。
  final int minutes;

  /// 最終目標の時刻。
  final TargetTime goal;

  /// 一部の項目だけ変えた新しい設定を返す。
  AutoAdvance copyWith({
    bool? enabled,
    int? days,
    int? minutes,
    TargetTime? goal,
  }) => AutoAdvance(
    enabled: enabled ?? this.enabled,
    days: days ?? this.days,
    minutes: minutes ?? this.minutes,
    goal: goal ?? this.goal,
  );

  @override
  bool operator ==(Object other) =>
      other is AutoAdvance &&
      other.enabled == enabled &&
      other.days == days &&
      other.minutes == minutes &&
      other.goal == goal;

  @override
  int get hashCode => Object.hash(enabled, days, minutes, goal);
}

/// 前倒しの結果。
class AutoAdvanceResult {
  const AutoAdvanceResult({
    required this.from,
    required this.to,
    required this.reachedGoal,
  });

  /// 前倒し前の目標時刻。
  final TargetTime from;

  /// 前倒し後の目標時刻。
  final TargetTime to;

  /// 最終目標に到達したか。
  final bool reachedGoal;
}

/// 目標時刻の早さを比べるための値(午前3:00 からの経過分)。小さいほど早い。
int targetOrder(TargetTime t) =>
    minutesFromBoundary(DateTime(2000, 1, 1, t.hour, t.minute));

/// [current] を [minutes] 分早めた時刻。ただし [goal] より早くならない。
///
/// [current] が既に [goal] と同じか早い場合は [current] のまま。
TargetTime nextTarget(TargetTime current, TargetTime goal, int minutes) {
  if (targetOrder(current) <= targetOrder(goal)) return current;
  final order = targetOrder(current) - minutes;
  if (order <= targetOrder(goal)) return goal;
  final total = (order + dayBoundaryHour * 60) % (24 * 60);
  return TargetTime(total ~/ 60, total % 60);
}

/// 前倒しの経過(現在の目標から最終目標まで)。表示用。
List<TargetTime> advanceSteps(
  TargetTime current,
  TargetTime goal,
  int minutes,
) {
  final steps = [current];
  var t = current;
  while (targetOrder(t) > targetOrder(goal)) {
    t = nextTarget(t, goal, minutes);
    steps.add(t);
  }
  return steps;
}

/// 今日 [today] を含めて、現在の目標 [target] と同じ目標で記録された成功が
/// 日付の連続で何日続いているか。
///
/// 今日の記録がない・失敗のとき、目標が違うとき、日付が途切れたときに数え終わる。
/// 目標が変わる(自動・手動どちらでも)と、新しい目標では0から数え直しになる。
int streakAtTarget(
  Iterable<WakeRecord> records,
  TargetTime target,
  String today,
) {
  final byDate = {for (final r in records) r.date: r};
  var cursor = DateTime.parse(today);
  var count = 0;
  while (true) {
    final r = byDate[formatDate(cursor)];
    if (r == null || !r.success || r.targetTime != target) break;
    count++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return count;
}

/// 成功の記録を保存した直後に、目標を前倒しするかを判定する。
///
/// [records] は今日の記録を含む全記録、[target] は現在の目標、[today] は今日の論理日付。
/// 前倒ししないときは `null`。
AutoAdvanceResult? evaluateAutoAdvance(
  Iterable<WakeRecord> records,
  AutoAdvance config,
  TargetTime target,
  String today,
) {
  if (!config.enabled) return null;
  if (targetOrder(target) <= targetOrder(config.goal)) return null;
  if (streakAtTarget(records, target, today) < config.days) return null;
  final to = nextTarget(target, config.goal, config.minutes);
  return AutoAdvanceResult(
    from: target,
    to: to,
    reachedGoal: to == config.goal,
  );
}

/// 最終目標 [goal] の入力の問題。
enum GoalProblem {
  /// [AutoAdvance.earliestGoal](4:00)より早い。
  tooEarly,

  /// 現在の目標より早い時刻になっていない。
  notBeforeTarget,
}

/// 最終目標 [goal] を検証する。問題がなければ `null`。
///
/// [target] は現在の目標。自動前倒しを使う場合は、[goal] が [target] より
/// 早い時刻である必要がある([requireBeforeTarget] が `true` のとき確認する)。
GoalProblem? validateGoal(
  TargetTime goal,
  TargetTime target, {
  required bool requireBeforeTarget,
}) {
  if (targetOrder(goal) < targetOrder(AutoAdvance.earliestGoal)) {
    return GoalProblem.tooEarly;
  }
  if (requireBeforeTarget && targetOrder(goal) >= targetOrder(target)) {
    return GoalProblem.notBeforeTarget;
  }
  return null;
}
