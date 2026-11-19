import 'package:characters/characters.dart';

import 'wake_record.dart';

/// 画面の明暗の選び方。
enum AppThemeMode {
  /// 端末の設定に合わせる。
  system,

  /// 常にライト。
  light,

  /// 常にダーク。
  dark,
}

/// ボタンに付けられるアイコンの種類(キー)。先頭の `none` はアイコンなし。
///
/// 実際のアイコン画像との対応は画面側(`theme_options.dart`)で持つ。
const List<String> wakeIconKeys = [
  'none',
  'sun',
  'alarm',
  'coffee',
  'bolt',
  'rocket',
  'meditation',
  'trophy',
  'heart',
];

/// アプリの設定をまとめた不変の値。
class AppSettings {
  const AppSettings({
    this.targetTime = const TargetTime(7, 0),
    this.themeColorIndex = 0,
    this.themeMode = AppThemeMode.system,
    this.wakeLabel = defaultWakeLabel,
    this.wakeIconKey = 'none',
  });

  /// 「起きた」ボタンの文言の初期値。
  static const String defaultWakeLabel = '起きた';

  /// ボタンの文言の最大文字数(絵文字・全角も1文字と数える)。
  static const int maxLabelLength = 8;

  /// 選べるテーマカラーの数(プリセット)。
  static const int paletteSize = 8;

  /// 目標起床時刻。
  final TargetTime targetTime;

  /// テーマカラーの番号(0〜[paletteSize] - 1)。
  final int themeColorIndex;

  /// 画面の明暗。
  final AppThemeMode themeMode;

  /// 「起きた」ボタンの文言。
  final String wakeLabel;

  /// 「起きた」ボタンのアイコンのキー([wakeIconKeys] のいずれか)。
  final String wakeIconKey;

  /// 一部の項目だけ変えた新しい設定を返す。
  AppSettings copyWith({
    TargetTime? targetTime,
    int? themeColorIndex,
    AppThemeMode? themeMode,
    String? wakeLabel,
    String? wakeIconKey,
  }) => AppSettings(
    targetTime: targetTime ?? this.targetTime,
    themeColorIndex: themeColorIndex ?? this.themeColorIndex,
    themeMode: themeMode ?? this.themeMode,
    wakeLabel: wakeLabel ?? this.wakeLabel,
    wakeIconKey: wakeIconKey ?? this.wakeIconKey,
  );

  /// ボタンの文言として使える形に整える。
  ///
  /// 前後の空白を取り除き、[maxLabelLength] 文字を超える分は切り捨てる。
  /// 空(空白のみを含む)の場合は [defaultWakeLabel] を返す。
  static String normalizeLabel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return defaultWakeLabel;
    return trimmed.characters.take(maxLabelLength).toString();
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.targetTime == targetTime &&
      other.themeColorIndex == themeColorIndex &&
      other.themeMode == themeMode &&
      other.wakeLabel == wakeLabel &&
      other.wakeIconKey == wakeIconKey;

  @override
  int get hashCode => Object.hash(
    targetTime,
    themeColorIndex,
    themeMode,
    wakeLabel,
    wakeIconKey,
  );
}
