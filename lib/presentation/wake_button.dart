import 'package:flutter/material.dart';

/// ボタンに付けられるアイコン1種類の表示用の情報。
class WakeIconOption {
  const WakeIconOption(this.label, this.icon);

  /// 選択肢に表示する名前(読み上げにも使う)。
  final String label;

  /// アイコン。`null` はアイコンなし。
  final IconData? icon;
}

/// アイコンの選択肢。キーは `wakeIconKeys`(domain)と一致させる。
const Map<String, WakeIconOption> wakeIconOptions = {
  'none': WakeIconOption('なし', null),
  'sun': WakeIconOption('太陽', Icons.wb_sunny),
  'alarm': WakeIconOption('アラーム', Icons.alarm),
  'coffee': WakeIconOption('コーヒー', Icons.coffee),
  'bolt': WakeIconOption('いなずま', Icons.bolt),
  'rocket': WakeIconOption('ロケット', Icons.rocket_launch),
  'meditation': WakeIconOption('瞑想', Icons.self_improvement),
  'trophy': WakeIconOption('トロフィー', Icons.emoji_events),
  'heart': WakeIconOption('ハート', Icons.favorite),
};

/// 「起きた」ボタン。ホームと、設定画面のプレビューで共通に使う。
///
/// [label] は文字が大きい端末でも1行に収まるよう縮小して表示する。
/// [iconKey] が `none` や未知のキーのときはアイコンなし。
/// [onPressed] が `null` のときは押せない状態(灰色)になる。
/// [key] は内側の [FilledButton] に付く。
FilledButton buildWakeButton({
  Key? key,
  required String label,
  required String iconKey,
  required VoidCallback? onPressed,
}) {
  final style = FilledButton.styleFrom(minimumSize: const Size.fromHeight(72));
  final text = FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 24)),
  );
  final icon = wakeIconOptions[iconKey]?.icon;
  if (icon == null) {
    return FilledButton(
      key: key,
      onPressed: onPressed,
      style: style,
      child: text,
    );
  }
  return FilledButton.icon(
    key: key,
    onPressed: onPressed,
    style: style,
    icon: Icon(icon, size: 28),
    // FilledButton.icon が内部で Flexible に包むため、ここでは包まない。
    label: text,
  );
}
