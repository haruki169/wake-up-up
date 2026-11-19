import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/wake_logic.dart';
import '../domain/wake_record.dart';
import 'achievement_ui.dart';
import 'providers.dart';
import 'wake_button.dart';

/// ホーム画面。目標時刻、今日の結果、ポイント残高、連続成功日数を表示し、
/// 画面下部に「起きた」ボタンを固定する。
///
/// ボタンはスクロールする領域の外に置くため、文字サイズが大きい端末でも
/// 常に画面内で押せる。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recordsProvider);
    final target = ref.watch(targetTimeProvider);
    final settings = ref.watch(settingsProvider);
    // ポイント残高(読み込み前・失敗時は累計獲得で代用)。
    final balance = ref.watch(rewardsProvider).value?.balance;
    // 日付の境界を過ぎると自動で更新される。
    final today = ref.watch(todayProvider);

    return records.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('読み込みに失敗しました: $e')),
      data: (list) {
        // 今日(論理日付)の記録。未記録なら null。
        WakeRecord? todayRecord;
        for (final r in list) {
          if (r.date == today) todayRecord = r;
        }
        return Column(
          children: [
            // 内容が多いとき(文字が大きいときなど)はここだけスクロールする。
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                children: [
                  Text(
                    '目標 $target',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  _TodayCard(record: todayRecord),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          label: 'ポイント残高',
                          value: '${balance ?? totalPoints(list)} pt',
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          label: '連続成功',
                          value: '${currentStreak(list, today)} 日',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 記録済みの日は onPressed を null にして押せなくする(1日1回)。
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: buildWakeButton(
                key: const Key('wake_button'),
                // 記録済みの日は固定の文言「記録済み」(アイコンなし)にする。
                label: todayRecord == null ? settings.wakeLabel : '記録済み',
                iconKey: todayRecord == null ? settings.wakeIconKey : 'none',
                onPressed: todayRecord == null
                    ? () async {
                        final result = await ref
                            .read(recordsProvider.notifier)
                            .wake();
                        // 節目の到達や記録の更新を知らせる(画面が残っているときだけ)。
                        if (context.mounted) {
                          await showAchievements(context, result.achievements);
                        }
                      }
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 今日の結果を表示するカード。
///
/// [record] が null なら未記録、それ以外は成功/失敗と起床時刻を表示する。
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.record});

  /// 今日の記録。未記録なら null。
  final WakeRecord? record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final String title;
    final String? detail;
    if (r == null) {
      title = '今日はまだ未記録';
      detail = null;
    } else {
      final t = TimeOfDay.fromDateTime(r.wokeAt).format(context);
      title = r.success ? '成功！ +${r.points} pt' : '残念、目標に間に合わず';
      detail = '起床 $t';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (detail != null) Text(detail),
          ],
        ),
      ),
    );
  }
}

/// ラベルと値を縦に並べた集計表示(ポイント残高、連続成功日数など)。
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  /// 項目名。
  final String label;

  /// 表示する値(単位付きの文字列)。
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label),
      Text(value, style: Theme.of(context).textTheme.headlineSmall),
    ],
  );
}
