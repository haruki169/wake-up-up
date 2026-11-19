import 'wake_logic.dart';
import 'wake_record.dart';

/// 連続成功の期間。
class Streak {
  const Streak({
    required this.days,
    required this.startDate,
    required this.endDate,
  });

  /// 連続した日数。
  final int days;

  /// 最初の日の論理日付 (yyyy-MM-dd)。
  final String startDate;

  /// 最後の日の論理日付 (yyyy-MM-dd)。
  final String endDate;
}

/// 記録全体の集計。
class RecordSummary {
  const RecordSummary({required this.successDays, required this.recordedDays});

  /// 成功した日数。
  final int successDays;

  /// 記録のある日数(成功+失敗)。
  final int recordedDays;

  /// 成功率(0.0〜1.0)。記録がないときは0。
  double get successRate => recordedDays == 0 ? 0 : successDays / recordedDays;

  /// 成功率をパーセント(四捨五入した整数)で返す。
  int get successPercent => (successRate * 100).round();
}

/// 日付 (yyyy-MM-dd) をタイムゾーンの影響を受けない日付にする。
DateTime _utcDay(String date) {
  final d = DateTime.parse(date);
  return DateTime.utc(d.year, d.month, d.day);
}

/// 論理日の始まり(午前3:00)からの経過分(0〜1439)。
///
/// 3:00 が最も早い(0)、翌日の 2:59 が最も遅い(1439)。
/// 起床の早さを比べるときに使う。
int minutesFromBoundary(DateTime t) =>
    (t.hour * 60 + t.minute - dayBoundaryHour * 60) % (24 * 60);

/// 連続して成功した日数の最長記録を返す。成功が1日もなければ `null`。
///
/// 日付が連続し、かつ成功した日だけをつなげる(記録のない日・失敗の日で途切れる)。
/// 同じ日数の期間が複数あるときは、新しい方を返す。
Streak? longestStreak(Iterable<WakeRecord> records) {
  final dates = records.where((r) => r.success).map((r) => r.date).toList()
    ..sort();
  if (dates.isEmpty) return null;

  Streak? best;
  var start = dates.first;
  var prev = dates.first;
  var days = 1;

  void close() {
    // 同じ日数なら、後(新しい期間)で上書きする。
    if (best == null || days >= best!.days) {
      best = Streak(days: days, startDate: start, endDate: prev);
    }
  }

  for (final d in dates.skip(1)) {
    final isNextDay = _utcDay(d).difference(_utcDay(prev)).inDays == 1;
    if (isNextDay) {
      days++;
    } else {
      close();
      start = d;
      days = 1;
    }
    prev = d;
  }
  close();
  return best;
}

/// 起床時刻が最も早い記録を返す。記録がなければ `null`。
///
/// 早さは [minutesFromBoundary] で比べる(秒は無視)。
/// 同じ時刻のときは日付の古い方を返す。成功・失敗は問わない。
WakeRecord? earliestWake(Iterable<WakeRecord> records) {
  WakeRecord? best;
  for (final r in records) {
    if (best == null) {
      best = r;
      continue;
    }
    final a = minutesFromBoundary(r.wokeAt);
    final b = minutesFromBoundary(best.wokeAt);
    if (a < b || (a == b && r.date.compareTo(best.date) < 0)) {
      best = r;
    }
  }
  return best;
}

/// 成功日数と記録日数を集計する。
RecordSummary summary(Iterable<WakeRecord> records) {
  var success = 0;
  var total = 0;
  for (final r in records) {
    total++;
    if (r.success) success++;
  }
  return RecordSummary(successDays: success, recordedDays: total);
}
