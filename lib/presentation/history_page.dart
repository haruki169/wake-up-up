import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'theme_options.dart';

/// 履歴画面。日ごとの起床時刻・目標時刻・成否・獲得ポイントを
/// 新しい日付順に一覧表示する。
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recordsProvider);
    final status = Theme.of(context).extension<StatusColors>()!;
    return records.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('読み込みに失敗しました: $e')),
      data: (list) {
        if (list.isEmpty) return const Center(child: Text('まだ記録がありません'));
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final r = list[i];
            final woke = TimeOfDay.fromDateTime(r.wokeAt).format(context);
            return ListTile(
              // 成功はチェック、失敗は×で示す(色はテーマに連動)。
              leading: Icon(
                r.success ? Icons.check_circle : Icons.cancel,
                color: r.success ? status.success : status.failure,
              ),
              title: Text(r.date),
              subtitle: Text('起床 $woke / 目標 ${r.targetTime}'),
              trailing: Text('+${r.points} pt'),
            );
          },
        );
      },
    );
  }
}
