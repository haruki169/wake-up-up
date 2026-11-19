import 'package:shared_preferences/shared_preferences.dart';

import '../domain/wake_record.dart';

/// アプリの設定の保存先を抽象化したリポジトリ。
abstract class SettingsRepository {
  /// 現在の目標起床時刻。未設定なら初期値を返す。
  TargetTime get targetTime;

  /// 目標起床時刻を [t] に変更して保存する。
  ///
  /// 過去の記録には影響せず、以降に記録する分から適用される。
  Future<void> setTargetTime(TargetTime t);
}

/// shared_preferences に設定を保存する [SettingsRepository] の実装。
class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  /// 目標時刻を保存するキー。値は `HH:mm` 形式の文字列。
  static const _key = 'target_time';

  /// 目標時刻が未設定のときの初期値(7:00)。
  static const defaultTarget = TargetTime(7, 0);

  @override
  TargetTime get targetTime {
    final s = _prefs.getString(_key);
    return s == null ? defaultTarget : TargetTime.parse(s);
  }

  @override
  Future<void> setTargetTime(TargetTime t) =>
      _prefs.setString(_key, t.toString());
}
