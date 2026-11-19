import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/wake_record.dart';
import 'providers.dart';

/// 設定画面。目標起床時刻を時刻ピッカーで変更する。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(targetTimeProvider);
    return ListView(
      children: [
        ListTile(
          key: const Key('target_tile'),
          title: const Text('目標起床時刻'),
          subtitle: const Text('変更は今日以降の記録に適用されます'),
          // 文字サイズが大きい端末でも行の幅を使い切らないよう、
          // 最大幅を決めて、収まらない場合は時刻の文字を縮小する。
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$target',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: target.hour, minute: target.minute),
            );
            // キャンセルされた場合(null)は何も変更しない。
            if (picked != null) {
              await ref
                  .read(settingsProvider.notifier)
                  .setTargetTime(TargetTime(picked.hour, picked.minute));
            }
          },
        ),
      ],
    );
  }
}
