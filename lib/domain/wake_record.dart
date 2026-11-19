/// 目標起床時刻(時・分)。日付を持たない「何時何分」だけの値。
class TargetTime {
  /// [hour] は 0〜23、[minute] は 0〜59。
  const TargetTime(this.hour, this.minute);

  /// 時(0〜23)。
  final int hour;

  /// 分(0〜59)。
  final int minute;

  /// `HH:mm` 形式の文字列(例: `06:30`)から作る。
  ///
  /// [toString] の出力を読み戻すために使う。形式が不正な場合は例外を投げる。
  factory TargetTime.parse(String s) {
    final parts = s.split(':');
    return TargetTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  /// `HH:mm` 形式(ゼロ埋め)の文字列。保存や表示に使う。
  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is TargetTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// 1日分の起床記録。
///
/// 目標時刻と判定結果を記録時点の値で保存するため、後から目標時刻を
/// 変更しても過去の記録の成否やポイントは変わらない。
class WakeRecord {
  const WakeRecord({
    required this.date,
    required this.wokeAt,
    required this.targetTime,
    required this.success,
    required this.points,
  });

  /// 論理日付 (yyyy-MM-dd)。午前3:00を境に日が替わる。1日1件の主キー。
  final String date;

  /// 「起きた」ボタンを押した実際の時刻。
  final DateTime wokeAt;

  /// 記録した時点の目標起床時刻。
  final TargetTime targetTime;

  /// 目標時刻以前に起きられたか。
  final bool success;

  /// この日に獲得したポイント。失敗した日は0。
  final int points;

  /// データベースの1行(カラム名 → 値)に変換する。
  ///
  /// [wokeAt] はエポックミリ秒、[success] は 0/1 で保存する。
  Map<String, Object?> toMap() => {
    'date': date,
    'woke_at': wokeAt.millisecondsSinceEpoch,
    'target_time': targetTime.toString(),
    'success': success ? 1 : 0,
    'points': points,
  };

  /// [toMap] の逆変換。データベースの1行から復元する。
  factory WakeRecord.fromMap(Map<String, Object?> m) => WakeRecord(
    date: m['date'] as String,
    wokeAt: DateTime.fromMillisecondsSinceEpoch(m['woke_at'] as int),
    targetTime: TargetTime.parse(m['target_time'] as String),
    success: (m['success'] as int) == 1,
    points: m['points'] as int,
  );
}
