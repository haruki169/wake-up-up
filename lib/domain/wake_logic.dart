import 'wake_record.dart';

/// 日付の境界とする時(午前3:00)。
///
/// この時刻より前に記録した起床は前日分として扱う。
/// 深夜に押した記録が翌日扱いにならないようにするための定数で、
/// 境界を変えたい場合はここだけを変更する。
const int dayBoundaryHour = 3;

/// 成功した日に必ず得られる基本ポイント。
const int basePoints = 10;

/// 早起きボーナスの上限(ポイント)。
const int bonusMax = 5;

/// 目標より何分早いごとにボーナスを +1pt するか(分)。
const int bonusStepMinutes = 10;

/// 日付を `yyyy-MM-dd` 形式の文字列にする(時刻・午前3:00 の境界は考慮しない)。
String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// [now] が属する論理日付の 0:00 を返す。[dayBoundaryHour] より前なら前日。
DateTime _day(DateTime now) {
  final d = DateTime(now.year, now.month, now.day);
  return now.hour < dayBoundaryHour ? DateTime(d.year, d.month, d.day - 1) : d;
}

/// [now] の論理日付を `yyyy-MM-dd` で返す。
///
/// 午前3:00より前は前日扱い。例: 11/19 02:59 → `2026-11-18`、
/// 11/19 03:00 → `2026-11-19`。
String logicalDate(DateTime now) => formatDate(_day(now));

/// [now] の次に日付が替わる時刻(次の午前3:00)を返す。
///
/// 例: 11/19 06:00 → 11/20 03:00、11/19 02:00 → 11/19 03:00。
/// ちょうど境界の時刻(11/19 03:00)なら、次の日の 11/20 03:00。
DateTime nextDayBoundary(DateTime now) {
  final d = _day(now);
  return DateTime(d.year, d.month, d.day + 1, dayBoundaryHour);
}

/// [wokeAt] が属する論理日付における、目標時刻の日時を返す。
DateTime targetDateTime(DateTime wokeAt, TargetTime target) {
  final d = _day(wokeAt);
  return DateTime(d.year, d.month, d.day, target.hour, target.minute);
}

/// 起床が成功かどうかを判定する。
///
/// 目標時刻ちょうどは成功、1分でも遅れれば失敗。
/// 午前0:00〜2:59 の記録は前日扱いで目標時刻を過ぎているため失敗になる。
bool judge(DateTime wokeAt, TargetTime target) =>
    !wokeAt.isAfter(targetDateTime(wokeAt, target));

/// 獲得ポイントを計算する。
///
/// 失敗は0pt。成功は [basePoints] に、目標より [bonusStepMinutes] 分
/// 早いごとに +1pt(最大 [bonusMax]pt)を加える。
/// 例: 目標 6:30 に対し 6:20 起床 → 11pt、4:00 起床 → 15pt(上限)。
int calcPoints(DateTime wokeAt, TargetTime target) {
  if (!judge(wokeAt, target)) return 0;
  final early = targetDateTime(wokeAt, target).difference(wokeAt).inMinutes;
  final bonus = (early ~/ bonusStepMinutes).clamp(0, bonusMax);
  return basePoints + bonus;
}

/// 起床時刻 [wokeAt] と目標 [target] から、保存用の [WakeRecord] を組み立てる。
///
/// 論理日付・成否・ポイントをここで確定させる。
WakeRecord buildRecord(DateTime wokeAt, TargetTime target) => WakeRecord(
  date: logicalDate(wokeAt),
  wokeAt: wokeAt,
  targetTime: target,
  success: judge(wokeAt, target),
  points: calcPoints(wokeAt, target),
);

/// [records] の獲得ポイントの合計(累計ポイント)。
int totalPoints(Iterable<WakeRecord> records) =>
    records.fold(0, (sum, r) => sum + r.points);

/// 現在の連続成功日数。
///
/// [today] は今日の論理日付 (yyyy-MM-dd)。今日が成功していれば今日から、
/// 今日がまだ未記録なら昨日から、成功が途切れるまで日付を遡って数える。
/// 今日が失敗なら0。[records] の並び順は問わない。
int currentStreak(Iterable<WakeRecord> records, String today) {
  final byDate = {for (final r in records) r.date: r};
  var cursor = DateTime.parse(today);
  if (!byDate.containsKey(today)) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  var streak = 0;
  while (true) {
    final r = byDate[formatDate(cursor)];
    if (r == null || !r.success) break;
    streak++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return streak;
}
