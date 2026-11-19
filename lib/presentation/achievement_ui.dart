import 'package:flutter/material.dart';

import '../domain/achievements.dart';

/// 節目ごとのお祝いのひとこと。
const Map<int, String> milestoneMessages = {
  3: 'いいスタートです！この調子で続けましょう',
  7: '1週間続けられました！',
  14: '2週間連続！習慣になってきました',
  30: '1か月連続！すばらしい継続力です',
  50: '50日連続！もう立派な早起きさんです',
  100: '100日連続！本当にすごい！',
  200: '200日連続！伝説級です',
  365: '1年間連続！おめでとうございます！',
};

/// 達成内容を画面に出す。
///
/// 節目に初めて到達したときはお祝いのダイアログ、そうでなく記録を更新した
/// ときはスナックバーを出す(ダイアログを優先し、両方は出さない)。
Future<void> showAchievements(
  BuildContext context,
  Achievements achievements,
) async {
  final milestone = achievements.newMilestone;
  if (milestone != null) {
    await showDialog<void>(
      context: context,
      builder: (_) => MilestoneDialog(days: milestone),
    );
    return;
  }
  final lines = [
    if (achievements.newEarliest) '最も早い起床を更新しました！',
    if (achievements.newLongest) '最長連続記録を更新しました！',
  ];
  if (lines.isEmpty) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: const Key('achievement_snackbar'),
        content: Text(lines.join('\n')),
      ),
    );
}

/// 連続成功が節目に到達したときのお祝いダイアログ。
class MilestoneDialog extends StatelessWidget {
  const MilestoneDialog({super.key, required this.days});

  /// 到達した節目の日数。
  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      key: const Key('milestone_dialog'),
      icon: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.3, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Icon(Icons.emoji_events, size: 64, color: scheme.primary),
      ),
      title: Text('$days日連続達成！', textAlign: TextAlign.center),
      content: Text(
        milestoneMessages[days] ?? '連続記録を達成しました！',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          key: const Key('milestone_close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
