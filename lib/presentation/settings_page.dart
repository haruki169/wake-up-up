import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_settings.dart';
import '../domain/wake_record.dart';
import 'providers.dart';
import 'theme_options.dart';
import 'wake_button.dart';

/// 設定画面。目標起床時刻を時刻ピッカーで変更する。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final target = settings.targetTime;
    return ListView(
      children: [
        const _SectionHeader('目標'),
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
        const _SectionHeader('外観'),
        _ThemeColorPicker(selected: settings.themeColorIndex),
        _ThemeModePicker(selected: settings.themeMode),
        const _SectionHeader('ホームのボタン'),
        const _ButtonSettings(),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// 設定のセクション見出し。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    ),
  );
}

/// テーマカラーを選ぶ円形のチップの並び。
class _ThemeColorPicker extends ConsumerWidget {
  const _ThemeColorPicker({required this.selected});

  /// 選択中のテーマカラーの番号。
  final int selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('テーマカラー', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < themeChoices.length; i++)
              _ColorChip(
                index: i,
                selected: i == selected,
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .update((s) => s.copyWith(themeColorIndex: i)),
              ),
          ],
        ),
      ],
    ),
  );
}

/// テーマカラー1色分のチップ。タップ領域は48dp。
class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  /// 色の番号([themeChoices] の添字)。
  final int index;

  /// 選択中かどうか。
  final bool selected;

  /// タップされたときの処理。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final choice = themeChoices[index];
    return Semantics(
      label: choice.name,
      button: true,
      selected: selected,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        key: Key('color_chip_$index'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: choice.color,
            shape: BoxShape.circle,
            border: selected
                ? Border.all(
                    width: 3,
                    color: Theme.of(context).colorScheme.onSurface,
                  )
                : null,
          ),
          child: selected ? const Icon(Icons.check, color: Colors.white) : null,
        ),
      ),
    );
  }
}

/// 画面の明暗(端末に合わせる/ライト/ダーク)を選ぶラジオの並び。
///
/// 文字が大きい端末や小さい画面でも崩れないよう、縦に並べる。
class _ThemeModePicker extends ConsumerWidget {
  const _ThemeModePicker({required this.selected});

  /// 選択中の明暗。
  final AppThemeMode selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) => RadioGroup<AppThemeMode>(
    groupValue: selected,
    onChanged: (mode) {
      if (mode == null) return;
      ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(themeMode: mode));
    },
    child: const Column(
      children: [
        RadioListTile<AppThemeMode>(
          value: AppThemeMode.system,
          title: Text('端末の設定に合わせる'),
        ),
        RadioListTile<AppThemeMode>(
          value: AppThemeMode.light,
          title: Text('ライト'),
        ),
        RadioListTile<AppThemeMode>(
          value: AppThemeMode.dark,
          title: Text('ダーク'),
        ),
      ],
    ),
  );
}

/// ホームの「起きた」ボタンの文言とアイコンの設定。
class _ButtonSettings extends ConsumerStatefulWidget {
  const _ButtonSettings();

  @override
  ConsumerState<_ButtonSettings> createState() => _ButtonSettingsState();
}

class _ButtonSettingsState extends ConsumerState<_ButtonSettings> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(settingsProvider).wakeLabel,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 入力のたびに、整えた文言を保存する(空なら初期値になる)。
  void _onChanged(String text) => ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(wakeLabel: AppSettings.normalizeLabel(text)));

  /// 文言とアイコンを初期値に戻す。
  void _reset() {
    _controller.text = AppSettings.defaultWakeLabel;
    ref
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            wakeLabel: AppSettings.defaultWakeLabel,
            wakeIconKey: 'none',
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 押せないプレビュー(見た目の確認用)。
          ExcludeSemantics(
            child: IgnorePointer(
              child: buildWakeButton(
                key: const Key('wake_preview'),
                label: settings.wakeLabel,
                iconKey: settings.wakeIconKey,
                onPressed: () {},
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('label_field'),
            controller: _controller,
            maxLength: AppSettings.maxLabelLength,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'ボタンの文言',
              helperText: '空にすると「${AppSettings.defaultWakeLabel}」に戻ります',
              border: OutlineInputBorder(),
            ),
            onChanged: _onChanged,
          ),
          const SizedBox(height: 8),
          Text('アイコン', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final entry in wakeIconOptions.entries)
                ChoiceChip(
                  key: Key('icon_chip_${entry.key}'),
                  label: Text(entry.value.label),
                  avatar: entry.value.icon == null
                      ? null
                      : Icon(entry.value.icon, size: 18),
                  selected: settings.wakeIconKey == entry.key,
                  onSelected: (_) => ref
                      .read(settingsProvider.notifier)
                      .update((s) => s.copyWith(wakeIconKey: entry.key)),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('reset_button'),
              onPressed: _reset,
              child: const Text('初期値に戻す'),
            ),
          ),
        ],
      ),
    );
  }
}
