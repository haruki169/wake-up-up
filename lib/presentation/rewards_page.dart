import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/reward.dart';
import 'providers.dart';

/// 候補として表示するご褒美(名前, 必要ポイント)。
const List<(String, int)> rewardSuggestions = [
  ('好きなお菓子', 100),
  ('コーヒー', 50),
  ('映画', 500),
];

/// 日時を `M/d HH:mm` にする。
String _dateTime(DateTime t) =>
    '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// ご褒美画面。ポイント残高、ご褒美の一覧(交換・編集・削除・追加)、交換履歴を表示する。
class RewardsPage extends ConsumerStatefulWidget {
  const RewardsPage({super.key});

  @override
  ConsumerState<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends ConsumerState<RewardsPage> {
  /// 交換の処理中か(連打で二重に処理しないため)。
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// ご褒美の追加(`reward` が null)または編集のダイアログを開く。
  Future<void> _openEditor({Reward? reward, String? name, int? cost}) async {
    final result = await showDialog<_EditorResult>(
      context: context,
      builder: (_) => _RewardEditor(
        initialName: reward?.name ?? name ?? '',
        initialCost: reward?.cost ?? cost,
        isEdit: reward != null,
      ),
    );
    if (result == null || !mounted) return;
    final notifier = ref.read(rewardsProvider.notifier);
    if (result.delete) {
      final ok = await _confirmDelete(reward!.name);
      if (ok != true) return;
      await notifier.archive(reward.id);
      _snack('「${reward.name}」を削除しました');
      return;
    }
    final r = reward == null
        ? await notifier.add(result.name, result.cost)
        : await notifier.updateReward(reward.id, result.name, result.cost);
    switch (r) {
      case RewardResult.ok:
        _snack(reward == null ? 'ご褒美を追加しました' : 'ご褒美を変更しました');
      case RewardResult.limitReached:
        _snack('ご褒美は最大$maxActiveRewards件までです');
      case RewardResult.notFound:
        _snack('ご褒美が見つかりませんでした');
      default:
        _snack('入力内容を確認してください');
    }
  }

  Future<bool?> _confirmDelete(String name) => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      key: const Key('delete_dialog'),
      scrollable: true,
      title: const Text('ご褒美を削除しますか？'),
      content: Text('「$name」を削除します。これまでの交換履歴は残ります。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          key: const Key('confirm_delete'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('削除する'),
        ),
      ],
    ),
  );

  /// 確認ダイアログを経て、ご褒美と交換する。
  Future<void> _redeem(Reward reward, int balance) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        key: const Key('redeem_dialog'),
        scrollable: true,
        title: const Text('ご褒美と交換しますか？'),
        content: Text(
          '「${reward.name}」を ${reward.cost} pt で交換します。\n'
          '残高 $balance → ${balance - reward.cost} pt\n'
          '交換は取り消せません。',
        ),
        actions: [
          TextButton(
            key: const Key('cancel_redeem'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('confirm_redeem'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('交換する'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(rewardsProvider.notifier).redeem(reward.id);
      _snack(switch (r) {
        RewardResult.ok => '「${reward.name}」と交換しました',
        RewardResult.insufficientBalance => 'ポイントが足りません',
        RewardResult.notFound => 'ご褒美が見つかりませんでした',
        _ => '交換できませんでした',
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rewardsProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('読み込みに失敗しました: $e')),
      data: (s) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _BalanceCard(state: s),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'ご褒美',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                key: const Key('add_reward'),
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('追加'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (s.rewards.isEmpty)
            _EmptyRewards(
              onPick: (name, cost) => _openEditor(name: name, cost: cost),
            )
          else
            for (final r in s.rewards)
              _RewardCard(
                reward: r,
                balance: s.balance,
                onRedeem: () => _redeem(r, s.balance),
                onEdit: () => _openEditor(reward: r),
              ),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text('交換履歴', style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          if (s.redemptions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('交換履歴はまだありません'),
            )
          else
            for (final h in s.redemptions)
              ListTile(
                key: Key('redemption_${h.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.card_giftcard),
                title: Text(h.rewardName),
                subtitle: Text(_dateTime(h.redeemedAt)),
                trailing: Text('−${h.cost} pt'),
              ),
        ],
      ),
    );
  }
}

/// ポイント残高・累計獲得・使用済みを表示するカード。
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.state});

  final RewardsState state;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('balance_card'),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('ポイント残高', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${state.balance} pt',
              key: const Key('balance_value'),
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 4,
            children: [
              Text('累計獲得 ${state.earned} pt', key: const Key('earned_value')),
              Text('使用済み ${state.spent} pt', key: const Key('spent_value')),
            ],
          ),
        ],
      ),
    ),
  );
}

/// ご褒美が1件もないときの案内と、候補のチップ。
class _EmptyRewards extends StatelessWidget {
  const _EmptyRewards({required this.onPick});

  /// 候補をタップしたときに、名前とポイントで呼ばれる。
  final void Function(String name, int cost) onPick;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('empty_rewards'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ご褒美を登録しよう', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          const Text('貯めたポイントで、自分へのご褒美と交換できます。候補から選ぶこともできます。'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < rewardSuggestions.length; i++)
                ActionChip(
                  key: Key('suggest_$i'),
                  label: Text(
                    '${rewardSuggestions[i].$1} ${rewardSuggestions[i].$2}pt',
                  ),
                  onPressed: () =>
                      onPick(rewardSuggestions[i].$1, rewardSuggestions[i].$2),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// ご褒美1件分のカード(名前・必要ポイント・進捗・交換ボタン)。タップで編集。
class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.balance,
    required this.onRedeem,
    required this.onEdit,
  });

  final Reward reward;

  /// 現在のポイント残高。
  final int balance;

  final VoidCallback onRedeem;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final canRedeem = balance >= reward.cost;
    final progress = (balance / reward.cost).clamp(0.0, 1.0);
    final percent = (progress * 100).floor();
    return Card(
      key: Key('reward_${reward.id}'),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reward.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text('必要 ${reward.cost} pt'),
              const SizedBox(height: 8),
              Semantics(
                key: Key('progress_${reward.id}'),
                container: true,
                label: '残高の進み具合',
                value: '$percent%',
                excludeSemantics: true,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                canRedeem ? '交換できます' : 'あと ${reward.cost - balance} pt',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  container: true,
                  button: true,
                  enabled: canRedeem,
                  excludeSemantics: true,
                  label: '「${reward.name}」を${reward.cost}ポイントで交換',
                  onTap: canRedeem ? onRedeem : null,
                  child: FilledButton(
                    key: Key('redeem_${reward.id}'),
                    onPressed: canRedeem ? onRedeem : null,
                    child: const Text('交換'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ご褒美のダイアログの結果。
class _EditorResult {
  const _EditorResult.save(this.name, this.cost) : delete = false;
  const _EditorResult.delete() : name = '', cost = 0, delete = true;

  final String name;
  final int cost;

  /// 「削除」が選ばれたか。
  final bool delete;
}

/// ご褒美の追加・編集ダイアログ。入力を検証して、問題なければ結果を返す。
class _RewardEditor extends StatefulWidget {
  const _RewardEditor({
    required this.initialName,
    required this.initialCost,
    required this.isEdit,
  });

  final String initialName;
  final int? initialCost;

  /// 編集か(`true` なら「削除」ボタンを出す)。
  final bool isEdit;

  @override
  State<_RewardEditor> createState() => _RewardEditorState();
}

class _RewardEditorState extends State<_RewardEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _cost = TextEditingController(
    text: widget.initialCost?.toString() ?? '',
  );
  String? _nameError;
  String? _costError;

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    super.dispose();
  }

  void _save() {
    final cost = int.tryParse(_cost.text.trim()) ?? 0;
    final invalid = validateReward(_name.text, cost);
    setState(() {
      _nameError = invalid == RewardResult.invalidName
          ? (normalizeRewardName(_name.text).isEmpty
                ? '名前を入力してください'
                : '$maxRewardNameLength文字以内で入力してください')
          : null;
      _costError = (invalid == RewardResult.invalidCost)
          ? 'ポイントは$minRewardCost〜$maxRewardCostの整数で入力してください'
          : null;
    });
    // 名前が不正でもポイントの誤りは同時に示す。
    if (invalid == RewardResult.invalidName &&
        (cost < minRewardCost || cost > maxRewardCost)) {
      setState(
        () => _costError = 'ポイントは$minRewardCost〜$maxRewardCostの整数で入力してください',
      );
    }
    if (invalid != null) return;
    Navigator.of(context)
        .pop(_EditorResult.save(normalizeRewardName(_name.text), cost));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('reward_editor'),
    scrollable: true,
    title: Text(widget.isEdit ? 'ご褒美を編集' : 'ご褒美を追加'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('reward_name'),
          controller: _name,
          autofocus: true,
          maxLength: maxRewardNameLength,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: '名前',
            errorText: _nameError,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('reward_cost'),
          controller: _cost,
          keyboardType: TextInputType.number,
          maxLength: 5,
          decoration: InputDecoration(
            labelText: '必要ポイント',
            suffixText: 'pt',
            errorText: _costError,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    ),
    actions: [
      if (widget.isEdit)
        TextButton(
          key: const Key('reward_delete'),
          onPressed: () =>
              Navigator.of(context).pop(const _EditorResult.delete()),
          child: const Text('削除'),
        ),
      TextButton(
        key: const Key('reward_cancel'),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('キャンセル'),
      ),
      FilledButton(
        key: const Key('reward_save'),
        onPressed: _save,
        child: const Text('保存'),
      ),
    ],
  );
}
