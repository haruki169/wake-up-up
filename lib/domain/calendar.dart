import 'stats.dart';
import 'wake_logic.dart';
import 'wake_record.dart';

/// カレンダーの1日分の状態。
enum DayStatus {
  /// 成功した日。
  success,

  /// 失敗した日。
  failure,

  /// 記録のない日(過去または今日)。
  none,

  /// まだ来ていない日。
  future,
}

/// [year] 年 [month] 月のカレンダーの表(日曜始まり)を返す。
///
/// 週ごとの行で、各行は日曜〜土曜の7要素。その月に属さない日は `null`。
/// 行数は、その月に必要な週の数(4〜6週)。
List<List<DateTime?>> monthGrid(int year, int month) {
  final first = DateTime(year, month, 1);
  final daysInMonth = DateTime(year, month + 1, 0).day;
  // DateTime.weekday は月曜=1〜日曜=7。日曜始まりの位置(日曜=0)に直す。
  final leading = first.weekday % 7;
  final weeks = ((leading + daysInMonth) / 7).ceil();
  return [
    for (var w = 0; w < weeks; w++)
      [
        for (var c = 0; c < 7; c++)
          () {
            final day = w * 7 + c - leading + 1;
            return (day >= 1 && day <= daysInMonth)
                ? DateTime(year, month, day)
                : null;
          }(),
      ],
  ];
}

/// [day] の状態を返す。[byDate] は日付 (yyyy-MM-dd) → 記録、[today] は今日の論理日付。
DayStatus dayStatus(
  DateTime day,
  Map<String, WakeRecord> byDate,
  String today,
) {
  final key = formatDate(day);
  final record = byDate[key];
  if (record != null) {
    return record.success ? DayStatus.success : DayStatus.failure;
  }
  return key.compareTo(today) > 0 ? DayStatus.future : DayStatus.none;
}

/// 月ごとの集計。
class MonthSummary {
  const MonthSummary({required this.success, required this.failure});

  /// 成功した日数。
  final int success;

  /// 失敗した日数。
  final int failure;

  /// 記録のある日数。
  int get recorded => success + failure;

  /// 成功率(パーセント、四捨五入)。記録がなければ0。
  int get percent => recorded == 0 ? 0 : (success * 100 / recorded).round();
}

/// [year] 年 [month] 月の集計を返す。
MonthSummary summaryOfMonth(Iterable<WakeRecord> records, int year, int month) {
  final prefix =
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-';
  final s = summary(records.where((r) => r.date.startsWith(prefix)));
  return MonthSummary(
    success: s.successDays,
    failure: s.recordedDays - s.successDays,
  );
}

/// カレンダーで移動できる月の範囲。
class MonthRange {
  const MonthRange({required this.first, required this.last});

  /// 最も古い月(最初の記録の月)。1日の日付で表す。
  final DateTime first;

  /// 最も新しい月(今日の月)。1日の日付で表す。
  final DateTime last;

  /// [month](1日の日付)から1つ前の月へ移動できるか。
  bool canGoPrevious(DateTime month) => _index(month) > _index(first);

  /// [month](1日の日付)から1つ先の月へ移動できるか。
  bool canGoNext(DateTime month) => _index(month) < _index(last);

  /// 範囲内に収めた月を返す。
  DateTime clamp(DateTime month) {
    if (_index(month) < _index(first)) return first;
    if (_index(month) > _index(last)) return last;
    return DateTime(month.year, month.month, 1);
  }

  static int _index(DateTime d) => d.year * 12 + d.month;
}

/// 記録と今日の論理日付から、移動できる月の範囲を求める。
///
/// 最初の記録の月〜今日の月。記録がなければ今日の月のみ。
MonthRange monthRange(Iterable<WakeRecord> records, String today) {
  final t = DateTime.parse(today);
  final last = DateTime(t.year, t.month, 1);
  DateTime first = last;
  for (final r in records) {
    final d = DateTime.parse(r.date);
    final m = DateTime(d.year, d.month, 1);
    if (m.isBefore(first)) first = m;
  }
  return MonthRange(first: first, last: last);
}
