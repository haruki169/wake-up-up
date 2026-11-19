import 'package:flutter/material.dart';

import '../domain/app_settings.dart';

/// テーマカラーの選択肢(名前とシード色)。
class ThemeChoice {
  const ThemeChoice(this.name, this.color);

  /// 読み上げや表示に使う色の名前。
  final String name;

  /// カラースキームの元になるシード色。
  final Color color;
}

/// 選べるテーマカラー(プリセット8色)。番号は設定の `themeColorIndex`。
const List<ThemeChoice> themeChoices = [
  ThemeChoice('オレンジ', Color(0xFFFF9800)),
  ThemeChoice('赤', Color(0xFFE53935)),
  ThemeChoice('ピンク', Color(0xFFEC407A)),
  ThemeChoice('紫', Color(0xFF7E57C2)),
  ThemeChoice('青', Color(0xFF1E88E5)),
  ThemeChoice('青緑', Color(0xFF00897B)),
  ThemeChoice('緑', Color(0xFF43A047)),
  ThemeChoice('茶', Color(0xFF8D6E63)),
];

/// 成功・失敗を示す色。ライト/ダークそれぞれで読みやすい色にする。
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({required this.success, required this.failure});

  /// 成功の色。
  final Color success;

  /// 失敗の色。
  final Color failure;

  @override
  StatusColors copyWith({Color? success, Color? failure}) => StatusColors(
    success: success ?? this.success,
    failure: failure ?? this.failure,
  );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      failure: Color.lerp(failure, other.failure, t)!,
    );
  }
}

/// [colorIndex] 番のテーマカラーと明暗から [ThemeData] を作る。
///
/// 番号が範囲外のときは0番(オレンジ)にする。
ThemeData buildTheme(int colorIndex, Brightness brightness) {
  final index = (colorIndex >= 0 && colorIndex < themeChoices.length)
      ? colorIndex
      : 0;
  final scheme = ColorScheme.fromSeed(
    seedColor: themeChoices[index].color,
    brightness: brightness,
  );
  final isLight = brightness == Brightness.light;
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    extensions: [
      StatusColors(
        success: isLight ? const Color(0xFF2E7D32) : const Color(0xFF81C784),
        failure: scheme.error,
      ),
    ],
  );
}

/// 設定の [AppThemeMode] を Flutter の [ThemeMode] に変換する。
ThemeMode toThemeMode(AppThemeMode m) => switch (m) {
  AppThemeMode.system => ThemeMode.system,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark => ThemeMode.dark,
};
