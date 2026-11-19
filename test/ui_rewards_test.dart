// ご褒美タブ(登録・編集・削除・交換・履歴)と、ホームの残高表示の画面テスト。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/data/record_repository.dart';
import 'package:wake_up_up/domain/wake_record.dart';
import 'package:wake_up_up/presentation/rewards_page.dart';

import 'helpers/fakes.dart';

final _now = DateTime(2026, 11, 20, 6, 0);

/// 獲得ポイントの合計が [points] になる記録(1日1件、10pt刻みで調整)。
List<WakeRecord> _earned(int points) => [
  if (points > 0) rec('2026-11-19', true, points: points),
];

class _Env {
  _Env(this.records, this.rewards);

  final FakeRecordRepository records;
  final FakeRewardRepository rewards;
}

/// アプリを開いて「ご褒美」タブを表示する。
Future<_Env> _open(
  WidgetTester tester, {
  int points = 0,
  List<(String, int)> rewards = const [],
  Size size = const Size(390, 1600),
  double textScale = 1.0,
  RecordRepository? recordsOverride,
}) async {
  setScreen(tester, size, textScale: textScale);
  final records = FakeRecordRepository(_earned(points));
  final fake = FakeRewardRepository(records);
  for (final (name, cost) in rewards) {
    await fake.addReward(name, cost, _now);
  }
  await tester.pumpWidget(
    buildApp(
      clock: () => _now,
      repo: recordsOverride ?? records,
      rewards: fake,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.card_giftcard));
  await tester.pumpAndSettle();
  return _Env(records, fake);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  // 一覧が長いと、画面外の項目はまだ作られていない。見つかるまでスクロールする。
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 300);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, {String? name, String? cost}) async {
  if (name != null) {
    await tester.enterText(find.byKey(const Key('reward_name')), name);
  }
  if (cost != null) {
    await tester.enterText(find.byKey(const Key('reward_cost')), cost);
  }
  await tester.pumpAndSettle();
}

Future<void> _add(WidgetTester tester, String name, String cost) async {
  await _tapKey(tester, 'add_reward');
  await _fill(tester, name: name, cost: cost);
  await _tapKey(tester, 'reward_save');
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

bool _redeemEnabled(WidgetTester tester, int id) =>
    tester.widget<FilledButton>(find.byKey(Key('redeem_$id'))).onPressed !=
    null;

void main() {
  group('表示', () {
    testWidgets('4つ目のタブ「ご褒美」で、残高カードと空の案内が出る', (tester) async {
      await _open(tester);
      expect(find.text('ご褒美'), findsWidgets);
      expect(_text(tester, 'balance_value'), '0 pt');
      expect(_text(tester, 'earned_value'), '累計獲得 0 pt');
      expect(_text(tester, 'spent_value'), '使用済み 0 pt');
      expect(find.byKey(const Key('empty_rewards')), findsOneWidget);
      expect(find.text('ご褒美を登録しよう'), findsOneWidget);
      expect(find.text('交換履歴はまだありません'), findsOneWidget);
    });

    testWidgets('残高・累計獲得・使用済みが正しく表示される', (tester) async {
      await _open(tester, points: 250, rewards: [('コーヒー', 50)]);
      expect(_text(tester, 'balance_value'), '250 pt');
      expect(_text(tester, 'earned_value'), '累計獲得 250 pt');
      await _tapKey(tester, 'redeem_1');
      await _tapKey(tester, 'confirm_redeem');
      expect(_text(tester, 'balance_value'), '200 pt');
      expect(_text(tester, 'earned_value'), '累計獲得 250 pt'); // 累計獲得は減らない
      expect(_text(tester, 'spent_value'), '使用済み 50 pt');
    });

    testWidgets('候補のチップが3つある', (tester) async {
      await _open(tester);
      for (var i = 0; i < rewardSuggestions.length; i++) {
        expect(find.byKey(Key('suggest_$i')), findsOneWidget);
      }
      expect(find.text('好きなお菓子 100pt'), findsOneWidget);
    });
  });

  group('追加', () {
    testWidgets('名前とポイントを入力して追加できる', (tester) async {
      final env = await _open(tester);
      await _add(tester, 'コーヒー', '50');
      expect(find.byKey(const Key('reward_editor')), findsNothing);
      expect(find.text('コーヒー'), findsOneWidget);
      expect(find.text('必要 50 pt'), findsOneWidget);
      expect(find.text('ご褒美を追加しました'), findsOneWidget);
      expect(find.byKey(const Key('empty_rewards')), findsNothing);
      expect((await env.rewards.activeRewards()).single.name, 'コーヒー');
    });

    testWidgets('候補をタップすると入力済みで開き、そのまま追加できる', (tester) async {
      await _open(tester);
      await _tapKey(tester, 'suggest_1');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('reward_name')))
            .controller!
            .text,
        'コーヒー',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('reward_cost')))
            .controller!
            .text,
        '50',
      );
      await _tapKey(tester, 'reward_save');
      expect(find.text('必要 50 pt'), findsOneWidget);
    });

    testWidgets('名前の前後の空白は取り除かれる', (tester) async {
      final env = await _open(tester);
      await _add(tester, '  本  ', '100');
      expect((await env.rewards.activeRewards()).single.name, '本');
    });

    testWidgets('名前が空・空白だけだとエラーで、ダイアログは閉じない', (tester) async {
      final env = await _open(tester);
      await _add(tester, '   ', '100');
      expect(find.text('名前を入力してください'), findsOneWidget);
      expect(find.byKey(const Key('reward_editor')), findsOneWidget);
      expect(await env.rewards.activeRewards(), isEmpty);
    });

    testWidgets('ポイントが空・0・数字以外だとエラー', (tester) async {
      await _open(tester);
      await _tapKey(tester, 'add_reward');
      for (final bad in ['', '0', 'abc']) {
        await _fill(tester, name: '本', cost: bad);
        await _tapKey(tester, 'reward_save');
        expect(
          find.text('ポイントは1〜99999の整数で入力してください'),
          findsOneWidget,
          reason: '"$bad"',
        );
        expect(find.byKey(const Key('reward_editor')), findsOneWidget);
      }
    });

    testWidgets('名前とポイントの両方の誤りが同時に示される', (tester) async {
      await _open(tester);
      await _add(tester, '', '0');
      expect(find.text('名前を入力してください'), findsOneWidget);
      expect(find.text('ポイントは1〜99999の整数で入力してください'), findsOneWidget);
    });

    testWidgets('エラーを直して保存し直せる', (tester) async {
      await _open(tester);
      await _add(tester, '', '100');
      await _fill(tester, name: '本');
      await _tapKey(tester, 'reward_save');
      expect(find.byKey(const Key('reward_editor')), findsNothing);
      expect(find.text('本'), findsOneWidget);
    });

    testWidgets('名前は30文字まで、ポイントは5桁までしか入力できない', (tester) async {
      await _open(tester);
      await _tapKey(tester, 'add_reward');
      await _fill(tester, name: 'あ' * 40, cost: '1234567');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('reward_name')))
            .controller!
            .text
            .length,
        30,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('reward_cost')))
            .controller!
            .text,
        '12345',
      );
    });

    testWidgets('最大値(30文字・99999pt)を追加できる', (tester) async {
      final env = await _open(tester);
      await _add(tester, 'あ' * 30, '99999');
      expect((await env.rewards.activeRewards()).single.cost, 99999);
    });

    testWidgets('キャンセルすると追加されない', (tester) async {
      final env = await _open(tester);
      await _tapKey(tester, 'add_reward');
      await _fill(tester, name: '本', cost: '100');
      await _tapKey(tester, 'reward_cancel');
      expect(find.byKey(const Key('reward_editor')), findsNothing);
      expect(await env.rewards.activeRewards(), isEmpty);
    });

    testWidgets('20件に達していると、追加できず上限のメッセージが出る', (tester) async {
      final env = await _open(
        tester,
        rewards: [for (var i = 0; i < 20; i++) ('ご褒美$i', 10)],
        size: const Size(390, 4000),
      );
      await _add(tester, '21件目', '10');
      expect(find.text('ご褒美は最大20件までです'), findsOneWidget);
      expect((await env.rewards.activeRewards()).length, 20);
    });
  });

  group('編集・削除', () {
    testWidgets('カードをタップすると現在の値が入った編集ダイアログが開く', (tester) async {
      await _open(tester, rewards: [('本', 300)]);
      await _tapKey(tester, 'reward_1');
      expect(find.text('ご褒美を編集'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('reward_name')))
            .controller!
            .text,
        '本',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('reward_cost')))
            .controller!
            .text,
        '300',
      );
      expect(find.byKey(const Key('reward_delete')), findsOneWidget);
    });

    testWidgets('名前とポイントを変更でき、交換の可否に反映される', (tester) async {
      await _open(tester, points: 100, rewards: [('本', 300)]);
      expect(_redeemEnabled(tester, 1), isFalse);
      await _tapKey(tester, 'reward_1');
      await _fill(tester, name: '漫画', cost: '80');
      await _tapKey(tester, 'reward_save');
      expect(find.text('漫画'), findsOneWidget);
      expect(find.text('必要 80 pt'), findsOneWidget);
      expect(find.text('ご褒美を変更しました'), findsOneWidget);
      expect(_redeemEnabled(tester, 1), isTrue);
    });

    testWidgets('削除: 確認してから消え、交換履歴は残る', (tester) async {
      await _open(tester, points: 100, rewards: [('本', 30)]);
      await _tapKey(tester, 'redeem_1');
      await _tapKey(tester, 'confirm_redeem');
      await _tapKey(tester, 'reward_1');
      await _tapKey(tester, 'reward_delete');
      expect(find.byKey(const Key('delete_dialog')), findsOneWidget);
      expect(find.textContaining('交換履歴は残ります'), findsOneWidget);
      await _tapKey(tester, 'confirm_delete');
      expect(find.byKey(const Key('reward_1')), findsNothing);
      expect(find.text('「本」を削除しました'), findsOneWidget);
      expect(find.byKey(const Key('empty_rewards')), findsOneWidget);
      // 履歴と使用済みは残る。
      expect(find.byKey(const Key('redemption_1')), findsOneWidget);
      expect(_text(tester, 'spent_value'), '使用済み 30 pt');
    });

    testWidgets('削除の確認でキャンセルすると残る', (tester) async {
      await _open(tester, rewards: [('本', 30)]);
      await _tapKey(tester, 'reward_1');
      await _tapKey(tester, 'reward_delete');
      await tester.tap(find.text('キャンセル').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reward_1')), findsOneWidget);
    });

    testWidgets('編集の入力が不正だと保存されない', (tester) async {
      final env = await _open(tester, rewards: [('本', 30)]);
      await _tapKey(tester, 'reward_1');
      await _fill(tester, name: '');
      await _tapKey(tester, 'reward_save');
      expect(find.text('名前を入力してください'), findsOneWidget);
      expect((await env.rewards.activeRewards()).single.name, '本');
    });
  });

  group('交換', () {
    testWidgets('残高が足りないと「交換」は押せず、あと何ポイントか分かる', (tester) async {
      await _open(tester, points: 99, rewards: [('本', 100)]);
      expect(_redeemEnabled(tester, 1), isFalse);
      expect(find.text('あと 1 pt'), findsOneWidget);
    });

    testWidgets('残高ちょうどなら押せて、交換すると残高が0になる', (tester) async {
      await _open(tester, points: 100, rewards: [('本', 100)]);
      expect(_redeemEnabled(tester, 1), isTrue);
      expect(find.text('交換できます'), findsOneWidget);
      await _tapKey(tester, 'redeem_1');
      await _tapKey(tester, 'confirm_redeem');
      expect(_text(tester, 'balance_value'), '0 pt');
      expect(_redeemEnabled(tester, 1), isFalse);
    });

    testWidgets('確認ダイアログに、ご褒美・ポイント・残高の変化・取り消せない旨が出る', (tester) async {
      await _open(tester, points: 250, rewards: [('好きなお菓子', 100)]);
      await _tapKey(tester, 'redeem_1');
      expect(find.byKey(const Key('redeem_dialog')), findsOneWidget);
      expect(find.textContaining('「好きなお菓子」を 100 pt で交換します。'), findsOneWidget);
      expect(find.textContaining('残高 250 → 150 pt'), findsOneWidget);
      expect(find.textContaining('交換は取り消せません'), findsOneWidget);
    });

    testWidgets('交換するとメッセージが出て、残高・使用済み・履歴が更新される', (tester) async {
      await _open(tester, points: 250, rewards: [('好きなお菓子', 100)]);
      await _tapKey(tester, 'redeem_1');
      await _tapKey(tester, 'confirm_redeem');
      expect(find.text('「好きなお菓子」と交換しました'), findsOneWidget);
      expect(_text(tester, 'balance_value'), '150 pt');
      expect(find.byKey(const Key('redemption_1')), findsOneWidget);
      expect(find.text('−100 pt'), findsOneWidget);
      expect(find.text('交換履歴はまだありません'), findsNothing);
    });

    testWidgets('キャンセルすると何も変わらない', (tester) async {
      final env = await _open(tester, points: 250, rewards: [('本', 100)]);
      await _tapKey(tester, 'redeem_1');
      await _tapKey(tester, 'cancel_redeem');
      expect(_text(tester, 'balance_value'), '250 pt');
      expect(env.rewards.redeemCalls, 0);
    });

    testWidgets('同じご褒美を何度でも交換できる(残高の範囲で)', (tester) async {
      await _open(tester, points: 100, rewards: [('コーヒー', 30)]);
      for (var i = 0; i < 3; i++) {
        await _tapKey(tester, 'redeem_1');
        await _tapKey(tester, 'confirm_redeem');
      }
      expect(_text(tester, 'balance_value'), '10 pt');
      expect(_redeemEnabled(tester, 1), isFalse);
      expect(find.byKey(const Key('redemption_3')), findsOneWidget);
    });

    testWidgets('交換履歴は新しい順', (tester) async {
      await _open(tester, points: 100, rewards: [('本', 30), ('コーヒー', 10)]);
      await _tapKey(tester, 'redeem_1');
      await _tapKey(tester, 'confirm_redeem');
      await _tapKey(tester, 'redeem_2');
      await _tapKey(tester, 'confirm_redeem');
      final first = tester.getTopLeft(find.byKey(const Key('redemption_2'))).dy;
      final second = tester
          .getTopLeft(find.byKey(const Key('redemption_1')))
          .dy;
      expect(first, lessThan(second));
    });

    testWidgets('確認中に残高が減っていたら、交換されず「ポイントが足りません」', (tester) async {
      final env = await _open(
        tester,
        points: 100,
        rewards: [('本', 100), ('コーヒー', 100)],
      );
      await _tapKey(tester, 'redeem_1');
      // 確認ダイアログを開いている間に、別のご褒美で残高を使い切る。
      await env.rewards.redeem(2, _now);
      await _tapKey(tester, 'confirm_redeem');
      expect(find.text('ポイントが足りません'), findsOneWidget);
      expect((await env.rewards.redemptions()).length, 1);
    });

    testWidgets('確認中にご褒美が削除されていたら、「見つかりませんでした」', (tester) async {
      final env = await _open(tester, points: 100, rewards: [('本', 50)]);
      await _tapKey(tester, 'redeem_1');
      await env.rewards.archiveReward(1);
      await _tapKey(tester, 'confirm_redeem');
      expect(find.text('ご褒美が見つかりませんでした'), findsOneWidget);
      expect(await env.rewards.redemptions(), isEmpty);
    });

    testWidgets('交換ボタンを素早く連打しても、交換は1回だけ', (tester) async {
      final env = await _open(tester, points: 300, rewards: [('本', 100)]);
      await tester.tap(find.byKey(const Key('redeem_1')));
      await tester.tap(find.byKey(const Key('redeem_1')), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_redeem')));
      await tester.pumpAndSettle();
      expect(env.rewards.redeemCalls, 1);
      expect(_text(tester, 'balance_value'), '200 pt');
    });
  });

  group('ホームとの連動', () {
    testWidgets('ホームは「ポイント残高」を表示し、交換すると減る', (tester) async {
      await _open(tester, points: 100, rewards: [('本', 30)]);
      await tester.tap(find.byIcon(Icons.wb_sunny));
      await tester.pumpAndSettle();
      expect(find.text('ポイント残高'), findsOneWidget);
      expect(find.text('累計ポイント'), findsNothing);
      expect(find.text('100 pt'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.card_giftcard));
      await tester.pumpAndSettle();
      await _tapKey(tester, 'redeem_1');
      await _tapKey(tester, 'confirm_redeem');
      await tester.tap(find.byIcon(Icons.wb_sunny));
      await tester.pumpAndSettle();
      expect(find.text('70 pt'), findsOneWidget);
    });

    testWidgets('新しく記録すると、ご褒美タブの残高・累計獲得も増える', (tester) async {
      await _open(tester, points: 100);
      await tester.tap(find.byIcon(Icons.wb_sunny));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wake_button'))); // 6:00 起床 → +13pt
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.card_giftcard));
      await tester.pumpAndSettle();
      expect(_text(tester, 'balance_value'), '113 pt');
      expect(_text(tester, 'earned_value'), '累計獲得 113 pt');
    });

    testWidgets('記録で残高が足りるようになると、交換できるようになる', (tester) async {
      await _open(tester, points: 100, rewards: [('本', 110)]);
      expect(_redeemEnabled(tester, 1), isFalse);
      await tester.tap(find.byIcon(Icons.wb_sunny));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wake_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.card_giftcard));
      await tester.pumpAndSettle();
      expect(_redeemEnabled(tester, 1), isTrue);
    });
  });

  group('エラー', () {
    testWidgets('読み込みに失敗したらエラー文を表示する', (tester) async {
      setScreen(tester, const Size(390, 1600));
      await tester.pumpWidget(
        buildApp(clock: () => _now, repo: ThrowingRecordRepository()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.card_giftcard));
      await tester.pumpAndSettle();
      expect(find.textContaining('読み込みに失敗しました'), findsOneWidget);
    });
  });

  group('レイアウト', () {
    for (final (label, size, scale) in [
      ('通常', const Size(390, 844), 1.0),
      ('小さい画面 320x568', const Size(320, 568), 1.0),
      ('小さい画面 + 文字3倍', const Size(320, 568), 3.0),
      ('横向き 844x390', const Size(844, 390), 1.0),
    ]) {
      testWidgets('一覧・ダイアログが崩れない($label)', (tester) async {
        final env = await _open(
          tester,
          points: 500,
          rewards: [('あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほ', 99999), ('コーヒー', 50)],
          size: size,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.fling(find.byType(ListView), const Offset(0, 3000), 3000);
        await tester.pumpAndSettle();
        // 追加ダイアログ
        await _tapKey(tester, 'add_reward');
        expect(tester.takeException(), isNull);
        await _tapKey(tester, 'reward_cancel');
        // 交換の確認ダイアログ(コーヒー)
        await _tapKey(tester, 'redeem_2');
        expect(find.byKey(const Key('redeem_dialog')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _tapKey(tester, 'confirm_redeem');
        expect(tester.takeException(), isNull);
        expect((await env.rewards.redemptions()).length, 1);
      });
    }

    testWidgets('4つのタブが小さい画面・文字3倍でも崩れない', (tester) async {
      await _open(tester, size: const Size(320, 568), textScale: 3.0);
      for (final icon in [
        Icons.history,
        Icons.wb_sunny,
        Icons.settings,
        Icons.card_giftcard,
      ]) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.byIcon(icon),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('アクセシビリティ', () {
    testWidgets('一覧のコントラスト・タップ領域・ラベルの基準を満たす', (tester) async {
      final h = tester.ensureSemantics();
      await _open(tester, points: 120, rewards: [('本', 100), ('映画', 500)]);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      h.dispose();
    });

    testWidgets('交換ボタンは「ご褒美名とポイント」で読み上げられる', (tester) async {
      final h = tester.ensureSemantics();
      await _open(tester, points: 120, rewards: [('好きなお菓子', 100)]);
      expect(
        tester.getSemantics(find.byKey(const Key('redeem_1'))).label,
        '「好きなお菓子」を100ポイントで交換',
      );
      h.dispose();
    });

    testWidgets('進捗バーは割合が読み上げられる', (tester) async {
      final h = tester.ensureSemantics();
      await _open(tester, points: 50, rewards: [('本', 100)]);
      final node = tester.getSemantics(find.byKey(const Key('progress_1')));
      expect(node.label, contains('残高の進み具合'));
      expect(node.value, contains('50%'));
      h.dispose();
    });

    testWidgets('ダイアログのコントラスト・ラベルの基準を満たす', (tester) async {
      final h = tester.ensureSemantics();
      await _open(tester, points: 120, rewards: [('本', 100)]);
      await _tapKey(tester, 'redeem_1');
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await _tapKey(tester, 'cancel_redeem');
      await _tapKey(tester, 'add_reward');
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      h.dispose();
    });
  });
}
