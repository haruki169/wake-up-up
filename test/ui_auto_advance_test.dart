// 目標の自動前倒しの画面テスト(設定画面と、記録したときの通知・目標の更新)。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/domain/app_settings.dart';
import 'package:wake_up_up/domain/auto_advance.dart';
import 'package:wake_up_up/domain/wake_record.dart';
import 'package:wake_up_up/presentation/achievement_ui.dart';
import 'package:wake_up_up/presentation/app.dart';
import 'package:wake_up_up/presentation/providers.dart';
import 'package:wake_up_up/presentation/theme_options.dart';

import 'helpers/fakes.dart';

const _on = AutoAdvance(
  enabled: true,
  days: 7,
  minutes: 15,
  goal: TargetTime(6, 0),
);

String d(int n) => '2026-11-${n.toString().padLeft(2, '0')}';

/// [days] の各日に、目標 [target] で成功した記録。
List<WakeRecord> run(Iterable<int> days, TargetTime target) => [
  for (final n in days) rec(d(n), true, target: target),
];

Future<void> _openSettings(
  WidgetTester tester,
  FakeSettings settings, {
  Size size = const Size(390, 2000),
  double textScale = 1.0,
}) async {
  setScreen(tester, size, textScale: textScale);
  await tester.pumpWidget(
    buildApp(clock: () => DateTime(2026, 11, 20, 6, 0), settings: settings),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(WakeUpUpApp)));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  group('設定画面', () {
    testWidgets('初期はオフで、詳細項目は出ない', (tester) async {
      await _openSettings(tester, FakeSettings());
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('auto_switch')))
            .value,
        isFalse,
      );
      expect(find.byKey(const Key('auto_days_7')), findsNothing);
      expect(find.byKey(const Key('auto_goal_tile')), findsNothing);
      expect(find.text('連続で成功したら、目標時刻を少しずつ早めます'), findsOneWidget);
    });

    testWidgets('オンにすると詳細が出て、説明に経過が表示され、保存される', (tester) async {
      final fake = FakeSettings();
      await _openSettings(tester, fake);
      await _tap(tester, 'auto_switch');
      expect(fake.s.autoAdvance.enabled, isTrue);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('auto_days_7')))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('auto_minutes_15')))
            .selected,
        isTrue,
      );
      expect(find.text('06:00'), findsWidgets);
      // 現在の目標 6:30 → 最終目標 6:00、15分刻みで全2段階。
      expect(
        find.text('7日連続で成功すると、目標を15分早めます(06:30 → 06:15 → 06:00、全2段階)'),
        findsOneWidget,
      );
    });

    testWidgets('日数・幅を選ぶと保存され、説明が変わる', (tester) async {
      final fake = FakeSettings(
        const AppSettings(targetTime: TargetTime(7, 0), autoAdvance: _on),
      );
      await _openSettings(tester, fake);
      await _tap(tester, 'auto_days_3');
      await _tap(tester, 'auto_minutes_30');
      expect(fake.s.autoAdvance.days, 3);
      expect(fake.s.autoAdvance.minutes, 30);
      expect(
        find.text('3日連続で成功すると、目標を30分早めます(07:00 → 06:30 → 06:00、全2段階)'),
        findsOneWidget,
      );
    });

    testWidgets('段階が多いときは途中を省略して表示する', (tester) async {
      final fake = FakeSettings(
        const AppSettings(
          targetTime: TargetTime(8, 0),
          autoAdvance: AutoAdvance(
            enabled: true,
            days: 7,
            minutes: 15,
            goal: TargetTime(6, 0),
          ),
        ),
      );
      await _openSettings(tester, fake);
      expect(
        find.text('7日連続で成功すると、目標を15分早めます(08:00 → 07:45 → … → 06:00、全8段階)'),
        findsOneWidget,
      );
    });

    testWidgets('最終目標が現在の目標より早くないと、オンにできずメッセージが出る', (tester) async {
      final fake = FakeSettings(
        const AppSettings(targetTime: TargetTime(5, 30)),
      );
      await _openSettings(tester, fake);
      await _tap(tester, 'auto_switch');
      expect(find.text('最終目標は、現在の目標より早い時刻にしてください'), findsOneWidget);
      expect(fake.s.autoAdvance.enabled, isFalse);
      expect(find.byKey(const Key('auto_days_7')), findsNothing);
    });

    testWidgets('オフにすると詳細が消え、設定は残る', (tester) async {
      final fake = FakeSettings(
        const AppSettings(
          targetTime: TargetTime(7, 0),
          autoAdvance: AutoAdvance(
            enabled: true,
            days: 10,
            minutes: 5,
            goal: TargetTime(5, 30),
          ),
        ),
      );
      await _openSettings(tester, fake);
      await _tap(tester, 'auto_switch');
      expect(fake.s.autoAdvance.enabled, isFalse);
      expect(fake.s.autoAdvance.days, 10);
      expect(fake.s.autoAdvance.goal, const TargetTime(5, 30));
      expect(find.byKey(const Key('auto_days_10')), findsNothing);
    });

    testWidgets('最終目標のピッカーをOKで閉じても値は変わらない(有効な値)', (tester) async {
      final fake = FakeSettings(
        const AppSettings(targetTime: TargetTime(7, 0), autoAdvance: _on),
      );
      await _openSettings(tester, fake);
      await _tap(tester, 'auto_goal_tile');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(fake.s.autoAdvance.goal, const TargetTime(6, 0));
    });

    testWidgets('最終目標のピッカーをキャンセルしても変わらない', (tester) async {
      final fake = FakeSettings(
        const AppSettings(targetTime: TargetTime(7, 0), autoAdvance: _on),
      );
      await _openSettings(tester, fake);
      await _tap(tester, 'auto_goal_tile');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fake.s.autoAdvance.goal, const TargetTime(6, 0));
    });

    testWidgets('保存済みの設定で起動する', (tester) async {
      await _openSettings(
        tester,
        FakeSettings(
          const AppSettings(
            targetTime: TargetTime(7, 0),
            autoAdvance: AutoAdvance(
              enabled: true,
              days: 14,
              minutes: 10,
              goal: TargetTime(5, 0),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('auto_days_14')))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('auto_minutes_10')))
            .selected,
        isTrue,
      );
      expect(find.text('05:00'), findsWidgets);
    });
  });

  group('設定の変更ルール(状態管理)', () {
    testWidgets('最終目標: 4:00より早い・オン中に現在の目標以降は変更されない', (tester) async {
      final fake = FakeSettings(
        const AppSettings(targetTime: TargetTime(7, 0), autoAdvance: _on),
      );
      await _openSettings(tester, fake);
      final n = _container(tester).read(settingsProvider.notifier);
      expect(
        await n.setAutoGoal(const TargetTime(3, 59)),
        GoalProblem.tooEarly,
      );
      expect(
        await n.setAutoGoal(const TargetTime(7, 0)),
        GoalProblem.notBeforeTarget,
      );
      expect(
        await n.setAutoGoal(const TargetTime(8, 0)),
        GoalProblem.notBeforeTarget,
      );
      expect(fake.s.autoAdvance.goal, const TargetTime(6, 0));
      expect(await n.setAutoGoal(const TargetTime(4, 0)), isNull);
      expect(fake.s.autoAdvance.goal, const TargetTime(4, 0));
    });

    testWidgets('最終目標: オフのときは現在の目標より遅くても設定できる(4:00以降)', (tester) async {
      final fake = FakeSettings(
        const AppSettings(targetTime: TargetTime(7, 0)),
      );
      await _openSettings(tester, fake);
      final n = _container(tester).read(settingsProvider.notifier);
      expect(await n.setAutoGoal(const TargetTime(8, 0)), isNull);
      expect(await n.setAutoGoal(const TargetTime(3, 0)), GoalProblem.tooEarly);
    });

    testWidgets('手動で目標を最終目標より早くすると、自動前倒しがオフになる', (tester) async {
      final fake = FakeSettings(
        const AppSettings(targetTime: TargetTime(7, 0), autoAdvance: _on),
      );
      await _openSettings(tester, fake);
      final n = _container(tester).read(settingsProvider.notifier);
      expect(await n.setTargetTime(const TargetTime(5, 59)), isTrue);
      expect(fake.s.autoAdvance.enabled, isFalse);
      expect(fake.s.targetTime, const TargetTime(5, 59));
    });

    testWidgets('手動で目標を最終目標と同じ・それより遅くしても、オンのまま', (tester) async {
      final fake = FakeSettings(
        const AppSettings(targetTime: TargetTime(7, 0), autoAdvance: _on),
      );
      await _openSettings(tester, fake);
      final n = _container(tester).read(settingsProvider.notifier);
      expect(await n.setTargetTime(const TargetTime(6, 0)), isFalse);
      expect(fake.s.autoAdvance.enabled, isTrue);
      expect(await n.setTargetTime(const TargetTime(8, 0)), isFalse);
      expect(fake.s.autoAdvance.enabled, isTrue);
    });

    testWidgets('オフのときの目標変更は、自動前倒しに影響しない', (tester) async {
      final fake = FakeSettings(
        const AppSettings(targetTime: TargetTime(7, 0)),
      );
      await _openSettings(tester, fake);
      final n = _container(tester).read(settingsProvider.notifier);
      expect(await n.setTargetTime(const TargetTime(5, 0)), isFalse);
      expect(fake.s.autoAdvance.enabled, isFalse);
    });
  });

  group('記録したときの前倒し', () {
    /// 目標 [target]・自動前倒し [auto] で、[seed] の記録がある状態でホームを開く。
    Future<FakeSettings> openHome(
      WidgetTester tester, {
      required List<WakeRecord> seed,
      TargetTime target = const TargetTime(6, 30),
      AutoAdvance auto = _on,
      DateTime? now,
      FakeRecordRepository? repo,
    }) async {
      setScreen(tester, const Size(390, 1200));
      final settings = FakeSettings(
        AppSettings(targetTime: target, autoAdvance: auto),
      );
      await tester.pumpWidget(
        buildApp(
          clock: () => now ?? DateTime(2026, 11, 20, 6, 0),
          settings: settings,
          repo: repo ?? FakeRecordRepository(seed),
        ),
      );
      await tester.pumpAndSettle();
      return settings;
    }

    Future<void> wake(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('wake_button')));
      await tester.pumpAndSettle();
    }

    Future<void> closeIfShown(WidgetTester tester, String closeKey) async {
      if (find.byKey(Key(closeKey)).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(Key(closeKey)));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('7日連続で、目標が15分早まりダイアログが出る(明日から)', (tester) async {
      final repo = FakeRecordRepository(
        run(14.to(19), const TargetTime(6, 30)),
      );
      final settings = await openHome(tester, seed: const [], repo: repo);
      await wake(tester);
      // 7日連続の節目のお祝いが先、続けて前倒しの通知。
      await closeIfShown(tester, 'milestone_close');
      expect(find.byKey(const Key('advance_dialog')), findsOneWidget);
      expect(find.text('目標を前倒ししました'), findsOneWidget);
      expect(find.textContaining('06:30 → 06:15'), findsOneWidget);
      expect(find.textContaining('明日から'), findsOneWidget);
      await tester.tap(find.byKey(const Key('advance_close')));
      await tester.pumpAndSettle();
      expect(settings.s.targetTime, const TargetTime(6, 15));
      expect(find.text('目標 06:15'), findsOneWidget);
      expect(settings.s.autoAdvance.enabled, isTrue);
      // 今日の記録は古い目標(6:30)のまま。
      final today = (await repo.all()).firstWhere((r) => r.date == d(20));
      expect(today.targetTime, const TargetTime(6, 30));
    });

    testWidgets('6日目(N−1日)では前倒しされない', (tester) async {
      final settings = await openHome(
        tester,
        seed: run(15.to(19), const TargetTime(6, 30)),
      );
      await wake(tester);
      await closeIfShown(tester, 'milestone_close');
      expect(find.byKey(const Key('advance_dialog')), findsNothing);
      expect(settings.s.targetTime, const TargetTime(6, 30));
    });

    testWidgets('オフなら、7日連続でも前倒しされない', (tester) async {
      final settings = await openHome(
        tester,
        seed: run(14.to(19), const TargetTime(6, 30)),
        auto: const AutoAdvance(),
      );
      await wake(tester);
      await closeIfShown(tester, 'milestone_close');
      expect(find.byKey(const Key('advance_dialog')), findsNothing);
      expect(settings.s.targetTime, const TargetTime(6, 30));
    });

    testWidgets('今日が失敗なら前倒しされない', (tester) async {
      final settings = await openHome(
        tester,
        seed: run(14.to(19), const TargetTime(6, 30)),
        now: DateTime(2026, 11, 20, 9, 0), // 目標 6:30 に遅刻
      );
      await wake(tester);
      expect(find.byKey(const Key('advance_dialog')), findsNothing);
      expect(settings.s.targetTime, const TargetTime(6, 30));
    });

    testWidgets('途中で失敗があると数え直し(前倒しされない)', (tester) async {
      final seed = [
        rec(d(14), true),
        rec(d(15), true),
        rec(d(16), false),
        rec(d(17), true),
        rec(d(18), true),
        rec(d(19), true),
      ];
      final settings = await openHome(tester, seed: seed);
      await wake(tester);
      await closeIfShown(tester, 'milestone_close');
      expect(find.byKey(const Key('advance_dialog')), findsNothing);
      expect(settings.s.targetTime, const TargetTime(6, 30));
    });

    testWidgets('最終目標に着いたら、到達のダイアログが出て自動前倒しがオフになる', (tester) async {
      final settings = await openHome(
        tester,
        target: const TargetTime(6, 15),
        seed: run(14.to(19), const TargetTime(6, 15)),
      );
      await wake(tester);
      await closeIfShown(tester, 'milestone_close');
      expect(find.text('最終目標に到達しました！'), findsOneWidget);
      expect(find.textContaining('自動前倒しをオフにしました'), findsOneWidget);
      await tester.tap(find.byKey(const Key('advance_close')));
      await tester.pumpAndSettle();
      expect(settings.s.targetTime, const TargetTime(6, 0));
      expect(settings.s.autoAdvance.enabled, isFalse);
      expect(settings.s.autoAdvance.goal, const TargetTime(6, 0)); // 他の設定は残る
    });

    testWidgets('最終目標に到達済み(目標=最終目標)なら何もしない', (tester) async {
      final settings = await openHome(
        tester,
        target: const TargetTime(6, 0),
        seed: run(14.to(19), const TargetTime(6, 0)),
      );
      await wake(tester);
      await closeIfShown(tester, 'milestone_close');
      expect(find.byKey(const Key('advance_dialog')), findsNothing);
      expect(settings.s.targetTime, const TargetTime(6, 0));
    });

    testWidgets('翌日は新しい目標で記録され、数え直しになる(続けて前倒しされない)', (tester) async {
      var now = DateTime(2026, 11, 20, 6, 0);
      final repo = FakeRecordRepository(
        run(14.to(19), const TargetTime(6, 30)),
      );
      setScreen(tester, const Size(390, 1200));
      final settings = FakeSettings(
        const AppSettings(targetTime: TargetTime(6, 30), autoAdvance: _on),
      );
      await tester.pumpWidget(
        buildApp(clock: () => now, settings: settings, repo: repo),
      );
      await tester.pumpAndSettle();
      await wake(tester);
      await closeIfShown(tester, 'milestone_close');
      await closeIfShown(tester, 'advance_close');
      expect(settings.s.targetTime, const TargetTime(6, 15));

      now = DateTime(2026, 11, 21, 6, 0);
      await tester.pump(const Duration(hours: 22));
      await tester.pumpAndSettle();
      await wake(tester);
      expect(find.byKey(const Key('advance_dialog')), findsNothing);
      final next = (await repo.all()).firstWhere((r) => r.date == d(21));
      expect(next.targetTime, const TargetTime(6, 15));
      expect(settings.s.targetTime, const TargetTime(6, 15));
    });

    testWidgets('同時に何度「起きた」が呼ばれても、前倒しは1回だけ', (tester) async {
      final repo = FakeRecordRepository(
        run(14.to(19), const TargetTime(6, 30)),
      );
      final settings = await openHome(tester, seed: const [], repo: repo);
      final container = _container(tester);
      final results = await Future.wait([
        for (var i = 0; i < 5; i++)
          container.read(recordsProvider.notifier).wake(),
      ]);
      expect(results.where((r) => r.autoAdvance != null).length, 1);
      expect(settings.s.targetTime, const TargetTime(6, 15));
    });

    testWidgets('前倒しのダイアログは、節目のお祝いの後に出る', (tester) async {
      await openHome(tester, seed: run(14.to(19), const TargetTime(6, 30)));
      await tester.tap(find.byKey(const Key('wake_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('milestone_dialog')), findsOneWidget);
      expect(find.byKey(const Key('advance_dialog')), findsNothing);
      await tester.tap(find.byKey(const Key('milestone_close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('advance_dialog')), findsOneWidget);
    });
  });

  group('レイアウト・アクセシビリティ', () {
    for (final (label, size, scale) in [
      ('通常', const Size(390, 844), 1.0),
      ('小さい画面 320x568', const Size(320, 568), 1.0),
      ('小さい画面 + 文字3倍', const Size(320, 568), 3.0),
      ('横向き 844x390', const Size(844, 390), 1.0),
    ]) {
      testWidgets('設定のセクションとダイアログが崩れない($label)', (tester) async {
        final fake = FakeSettings(
          const AppSettings(targetTime: TargetTime(8, 0), autoAdvance: _on),
        );
        await _openSettings(tester, fake, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byKey(const Key('auto_goal_tile')),
          200,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const Key('auto_minutes_30')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('auto_minutes_30')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 通知ダイアログ
        await tester.tap(find.byIcon(Icons.wb_sunny).last);
        await tester.pumpAndSettle();
      });
    }

    for (final reached in [false, true]) {
      testWidgets('前倒しの通知ダイアログが小さい画面+文字3倍でも崩れない(到達=$reached)', (tester) async {
        setScreen(tester, const Size(320, 568), textScale: 3.0);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(0, Brightness.light),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showAutoAdvance(
                    context,
                    AutoAdvanceResult(
                      from: const TargetTime(6, 15),
                      to: reached
                          ? const TargetTime(6, 0)
                          : const TargetTime(6, 0),
                      reachedGoal: reached,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('advance_dialog')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('advance_close')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('advance_dialog')), findsNothing);
      });
    }

    testWidgets('設定画面(自動前倒しオン)のアクセシビリティ基準', (tester) async {
      final h = tester.ensureSemantics();
      await _openSettings(
        tester,
        FakeSettings(
          const AppSettings(targetTime: TargetTime(7, 0), autoAdvance: _on),
        ),
        size: const Size(390, 2400),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      h.dispose();
    });

    testWidgets('前倒しの通知ダイアログのアクセシビリティ基準', (tester) async {
      final h = tester.ensureSemantics();
      setScreen(tester, const Size(390, 1200));
      final repo = FakeRecordRepository(
        run(14.to(19), const TargetTime(6, 30)),
      );
      await tester.pumpWidget(
        buildApp(
          clock: () => DateTime(2026, 11, 20, 6, 0),
          settings: FakeSettings(
            const AppSettings(targetTime: TargetTime(6, 30), autoAdvance: _on),
          ),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wake_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('milestone_close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('advance_dialog')), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      h.dispose();
    });
  });
}

extension on int {
  /// この値から [end] まで(両端を含む)の整数。
  Iterable<int> to(int end) => [for (var i = this; i <= end; i++) i];
}
