import 'stats.dart';
import 'wake_logic.dart';
import 'wake_record.dart';

/// 連続成功日数の節目(日)。
const List<int> milestones = [3, 7, 14, 30, 50, 100, 200, 365];

/// 記録を1件追加したときに達成した内容。
class Achievements {
  const Achievements({
    this.newMilestone,
    this.newEarliest = false,
    this.newLongest = false,
  });

  /// 達成した節目の日数。初めて到達した節目がなければ `null`。
  final int? newMilestone;

  /// 過去のどの記録よりも早く起きたか。
  final bool newEarliest;

  /// 連続成功日数が過去の最長を超えたか。
  final bool newLongest;

  /// 何か1つでも達成したか。
  bool get hasAny => newMilestone != null || newEarliest || newLongest;
}

/// 記録 [added] を [before] に追加したときの達成内容を調べる。
///
/// - 節目: 追加後の連続成功日数がちょうど節目になり、かつ過去の最長連続が
///   その節目に届いていなかったとき(初回の到達のみ。再到達では出ない)。
/// - 最も早い起床の更新: 成功で、過去に記録があり、過去のどれよりも早いとき。
/// - 最長連続の更新: 成功で、過去に成功があり、その最長を超えたとき。
///
/// 失敗した記録では何も達成しない。
Achievements detectAchievements(List<WakeRecord> before, WakeRecord added) {
  if (!added.success) return const Achievements();

  final after = [...before, added];
  final streak = currentStreak(after, added.date);
  final previousLongest = longestStreak(before)?.days ?? 0;

  final int? milestone = milestones.contains(streak) && previousLongest < streak
      ? streak
      : null;

  final previousEarliest = earliestWake(before);
  final newEarliest =
      previousEarliest != null &&
      minutesFromBoundary(added.wokeAt) <
          minutesFromBoundary(previousEarliest.wokeAt);

  final newLongest = previousLongest >= 1 && streak > previousLongest;

  return Achievements(
    newMilestone: milestone,
    newEarliest: newEarliest,
    newLongest: newLongest,
  );
}

/// バッジ1つ分(節目と取得済みかどうか)。
class BadgeStatus {
  const BadgeStatus({required this.days, required this.earned});

  /// 節目の日数。
  final int days;

  /// 取得済みか(最長連続成功がこの日数以上)。
  final bool earned;
}

/// すべてのバッジの取得状況を返す。バッジは保存せず、記録から導出する。
List<BadgeStatus> badgeStatuses(Iterable<WakeRecord> records) {
  final longest = longestStreak(records)?.days ?? 0;
  return [
    for (final m in milestones) BadgeStatus(days: m, earned: longest >= m),
  ];
}
