import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_settings.dart';
import '../domain/auto_advance.dart';
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
              final turnedOff = await ref
                  .read(settingsProvider.notifier)
                  .setTargetTime(TargetTime(picked.hour, picked.minute));
              if (turnedOff && context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('最終目標より早い目標にしたため、自動前倒しをオフにしました'),
                    ),
                  );
              }
            }
          },
        ),
        _AutoAdvanceSettings(settings: settings),
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

/// 目標の自動前倒しの設定(オン/オフ、連続成功日数、前倒しの幅、最終目標)。
class _AutoAdvanceSettings extends ConsumerWidget {
  const _AutoAdvanceSettings({required this.settings});

  final AppSettings settings;

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 最終目標の問題を、利用者向けの文にする。
  String _problemText(GoalProblem p) => switch (p) {
    GoalProblem.tooEarly => '最終目標は${AutoAdvance.earliestGoal}以降の時刻にしてください',
    GoalProblem.notBeforeTarget => '最終目標は、現在の目標より早い時刻にしてください',
  };

  /// 「7日連続で成功すると、目標を15分早めます(07:00 → 06:45 → … → 06:00、全4段階)」。
  String _preview(AutoAdvance a, TargetTime target) {
    final steps = advanceSteps(target, a.goal, a.minutes);
    final head = '${a.days}日連続で成功すると、目標を${a.minutes}分早めます';
    if (steps.length < 2) {
      return '$head(最終目標 ${a.goal} は、現在の目標より早い時刻にしてください)';
    }
    final shown = steps.length <= 4
        ? steps.join(' → ')
        : '${steps[0]} → ${steps[1]} → … → ${steps.last}';
    return '$head($shown、全${steps.length - 1}段階)';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auto = settings.autoAdvance;
    final notifier = ref.read(settingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const Key('auto_switch'),
          title: const Text('自動で目標を早める'),
          subtitle: Text(
            auto.enabled
                ? _preview(auto, settings.targetTime)
                : '連続で成功したら、目標時刻を少しずつ早めます',
          ),
          value: auto.enabled,
          onChanged: (on) async {
            final problem = await notifier.setAutoEnabled(on);
            if (problem != null && context.mounted) {
              _snack(context, _problemText(problem));
            }
          },
        ),
        if (auto.enabled) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              '連続して成功する日数',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final d in AutoAdvance.dayOptions)
                  ChoiceChip(
                    key: Key('auto_days_$d'),
                    label: Text('$d日'),
                    selected: auto.days == d,
                    onSelected: (_) => notifier.setAutoRule(days: d),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              '1回に早める幅',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final m in AutoAdvance.minuteOptions)
                  ChoiceChip(
                    key: Key('auto_minutes_$m'),
                    label: Text('$m分'),
                    selected: auto.minutes == m,
                    onSelected: (_) => notifier.setAutoRule(minutes: m),
                  ),
              ],
            ),
          ),
          ListTile(
            key: const Key('auto_goal_tile'),
            title: const Text('最終目標'),
            subtitle: Text('${AutoAdvance.earliestGoal}以降で、現在の目標より早い時刻'),
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${auto.goal}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: auto.goal.hour,
                  minute: auto.goal.minute,
                ),
              );
              if (picked == null) return;
              final problem = await notifier.setAutoGoal(
                TargetTime(picked.hour, picked.minute),
              );
              if (problem != null && context.mounted) {
                _snack(context, _problemText(problem));
              }
            },
          ),
        ],
      ],
    );
  }
}
