import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_settings.dart';
import '../domain/wake_record.dart';

/// アプリの設定の保存先を抽象化したリポジトリ。
abstract class SettingsRepository {
  /// 保存されている設定を読み込む。未設定や不正な値は初期値になる。
  AppSettings load();

  /// 設定をまとめて保存する。
  Future<void> save(AppSettings settings);
}

/// shared_preferences に設定を保存する [SettingsRepository] の実装。
class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _kTarget = 'target_time';
  static const _kColor = 'theme_color';
  static const _kMode = 'theme_mode';
  static const _kLabel = 'wake_label';
  static const _kIcon = 'wake_icon';

  /// 目標時刻が未設定のときの初期値(7:00)。
  static const defaultTarget = TargetTime(7, 0);

  @override
  AppSettings load() => AppSettings(
    targetTime: _readTarget(),
    themeColorIndex: _readColor(),
    themeMode: _readMode(),
    wakeLabel: AppSettings.normalizeLabel(
      _prefs.getString(_kLabel) ?? AppSettings.defaultWakeLabel,
    ),
    wakeIconKey: _readIcon(),
  );

  @override
  Future<void> save(AppSettings s) async {
    await _prefs.setString(_kTarget, s.targetTime.toString());
    await _prefs.setInt(_kColor, s.themeColorIndex);
    await _prefs.setString(_kMode, s.themeMode.name);
    await _prefs.setString(_kLabel, s.wakeLabel);
    await _prefs.setString(_kIcon, s.wakeIconKey);
  }

  /// 壊れた文字列(形式違い、範囲外の時刻)は初期値に戻す。
  TargetTime _readTarget() {
    final s = _prefs.getString(_kTarget);
    if (s == null) return defaultTarget;
    try {
      final t = TargetTime.parse(s);
      final ok = t.hour >= 0 && t.hour < 24 && t.minute >= 0 && t.minute < 60;
      return ok ? t : defaultTarget;
    } catch (_) {
      return defaultTarget;
    }
  }

  int _readColor() {
    final i = _prefs.getInt(_kColor);
    return (i != null && i >= 0 && i < AppSettings.paletteSize) ? i : 0;
  }

  AppThemeMode _readMode() {
    final s = _prefs.getString(_kMode);
    return AppThemeMode.values.firstWhere(
      (m) => m.name == s,
      orElse: () => AppThemeMode.system,
    );
  }

  String _readIcon() {
    final s = _prefs.getString(_kIcon);
    return (s != null && wakeIconKeys.contains(s)) ? s : 'none';
  }
}
