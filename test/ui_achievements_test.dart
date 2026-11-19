// 節目のお祝い・記録更新の通知・バッジ一覧の画面テスト。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/domain/achievements.dart';
import 'package:wake_up_up/domain/wake_record.dart';
import 'package:wake_up_up/presentation/achievement_ui.dart';
import 'package:wake_up_up/presentation/app.dart';
import 'package:wake_up_up/presentation/providers.dart';

import 'helpers/fakes.dart';

/// 指定の時刻・過去の記録でアプリを開く。
Future<void> _open(
  WidgetTester tester,
  DateTime now,
  List<WakeRecord> seed, {
  Size size = const Size(390, 1200),
  double textScale = 1.0,
}) async {
  setScreen(tester, size, textScale: textScale);
  await tester.pumpWidget(
    buildApp(clock: () => now, repo: FakeRecordRepository(seed)),
  );
  await tester.pumpAndSettle();
}

Future<void> _wake(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('wake_button')));
  await tester.pumpAndSettle();
}

WakeRecord _at(String date, int h, int m) {
  final d = DateTime.parse(date);
  return WakeRecord(
    date: date,
    wokeAt: DateTime(d.year, d.month, d.day, h, m),
    targetTime: const TargetTime(6, 30),
    success: true,
    points: 10,
  );
}

void main() {
  test('すべての節目にお祝いのひとことがある', () {
    for (final m in milestones) {
      expect(milestoneMessages[m], isNotNull, reason: '$m日');
    }
  });

  group('節目のダイアログ', () {
    testWidgets('3日連続に初めて到達するとお祝いが出て、閉じられる', (tester) async {
      await _open(tester, DateTime(2026, 11, 20, 6, 0), [
        rec('2026-11-18', true),
        rec('2026-11-19', true),
      ]);
      await _wake(tester);
      expect(find.byKey(const Key('milestone_dialog')), findsOneWidget);
      expect(find.text('3日連続達成！'), findsOneWidget);
      expect(find.text(milestoneMessages[3]!), findsOneWidget);
      await tester.tap(find.byKey(const Key('milestone_close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('milestone_dialog')), findsNothing);
      // 閉じた後は画面を操作できる。
      expect(find.text('記録済み'), findsOneWidget);
    });

    testWidgets('2日目では出ない', (tester) async {
      await _open(tester, DateTime(2026, 11, 19, 6, 0), [
        rec('2026-11-18', true),
      ]);
      await _wake(tester);
      expect(find.byKey(const Key('milestone_dialog')), findsNothing);
    });

    testWidgets('失敗した日には出ない', (tester) async {
      await _open(tester, DateTime(2026, 11, 20, 8, 0), [
        rec('2026-11-18', true),
        rec('2026-11-19', true),
      ]);
      await _wake(tester);
      expect(find.byKey(const Key('milestone_dialog')), findsNothing);
      expect(find.byKey(const Key('achievement_snackbar')), findsNothing);
    });

    testWidgets('途切れて再び同じ日数に到達しても出ない(初回のみ)', (tester) async {
      await _open(tester, DateTime(2026, 11, 7, 6, 0), [
        rec('2026-11-01', true),
        rec('2026-11-02', true),
        rec('2026-11-03', true), // ここで3日連続を達成済み
        rec('2026-11-04', false), // 途切れる
        rec('2026-11-05', true),
        rec('2026-11-06', true),
      ]);
      await _wake(tester); // 再び3日連続
      expect(find.byKey(const Key('milestone_dialog')), findsNothing);
    });

    testWidgets('同時に何度「起きた」が呼ばれても、保存と節目の通知は1回だけ', (tester) async {
      await _open(tester, DateTime(2026, 11, 20, 6, 0), [
        rec('2026-11-18', true),
        rec('2026-11-19', true),
      ]);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WakeUpUpApp)),
      );
      final results = await Future.wait([
        for (var i = 0; i < 5; i++)
          container.read(recordsProvider.notifier).wake(),
      ]);
      expect(results.where((r) => r.saved).length, 1);
      expect(results.where((r) => r.achievements.newMilestone == 3).length, 1);
      expect(
        results.where((r) => !r.saved).every((r) => !r.achievements.hasAny),
        isTrue,
      );
    });

    testWidgets('ダイアログの外をタップして閉じても、画面は壊れない', (tester) async {
      await _open(tester, DateTime(2026, 11, 20, 6, 0), [
        rec('2026-11-18', true),
        rec('2026-11-19', true),
      ]);
      await _wake(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('milestone_dialog')), findsNothing);
      expect(find.text('記録済み'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('節目はダイアログを優先し、スナックバーは出さない', (tester) async {
      await _open(tester, DateTime(2026, 11, 20, 5, 0), [
        _at('2026-11-18', 6, 10),
        _at('2026-11-19', 6, 10),
      ]);
      await _wake(tester);
      expect(find.byKey(const Key('milestone_dialog')), findsOneWidget);
      expect(find.byKey(const Key('achievement_snackbar')), findsNothing);
    });

    testWidgets('ダイアログ表示中に画面が破棄されても例外にならない', (tester) async {
      await _open(tester, DateTime(2026, 11, 20, 6, 0), [
        rec('2026-11-18', true),
        rec('2026-11-19', true),
      ]);
      await _wake(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('記録更新のスナックバー', () {
    testWidgets('最も早い起床を更新', (tester) async {
      await _open(tester, DateTime(2026, 11, 19, 5, 30), [
        _at('2026-11-17', 6, 0),
      ]);
      await _wake(tester);
      expect(find.text('最も早い起床を更新しました！'), findsOneWidget);
      expect(find.byKey(const Key('milestone_dialog')), findsNothing);
    });

    testWidgets('最長連続記録を更新', (tester) async {
      await _open(tester, DateTime(2026, 11, 19, 6, 0), [
        _at('2026-11-18', 5, 0),
      ]);
      await _wake(tester);
      expect(find.text('最長連続記録を更新しました！'), findsOneWidget);
    });

    testWidgets('両方更新したときは2行で表示', (tester) async {
      await _open(tester, DateTime(2026, 11, 19, 5, 30), [
        _at('2026-11-18', 6, 0),
      ]);
      await _wake(tester);
      expect(find.text('最も早い起床を更新しました！\n最長連続記録を更新しました！'), findsOneWidget);
    });

    testWidgets('最初の記録では何も出ない', (tester) async {
      await _open(tester, DateTime(2026, 11, 19, 5, 0), []);
      await _wake(tester);
      expect(find.byKey(const Key('achievement_snackbar')), findsNothing);
      expect(find.byKey(const Key('milestone_dialog')), findsNothing);
    });

    testWidgets('更新がなければ何も出ない', (tester) async {
      await _open(tester, DateTime(2026, 11, 19, 6, 20), [
        _at('2026-11-10', 5, 0),
      ]);
      await _wake(tester);
      expect(find.byKey(const Key('achievement_snackbar')), findsNothing);
    });
  });

  group('バッジ一覧', () {
    Future<void> openHistory(WidgetTester tester, List<WakeRecord> seed) async {
      await _open(
        tester,
        DateTime(2026, 11, 30, 6, 0),
        seed,
        size: const Size(390, 1600),
      );
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();
    }

    testWidgets('記録がなければバッジは出ない(案内のみ)', (tester) async {
      await _open(tester, DateTime(2026, 11, 20, 6, 0), []);
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('badges_card')), findsNothing);
    });

    testWidgets('最長連続が7日なら 3日・7日 が取得済み、残りは未取得', (tester) async {
      final h = tester.ensureSemantics();
      await openHistory(tester, [
        for (var i = 1; i <= 7; i++)
          rec('2026-11-${i.toString().padLeft(2, '0')}', true),
      ]);
      expect(find.text('バッジ(2/8)'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(const Key('badge_3'))).label,
        '3日連続のバッジ、取得済み',
      );
      expect(
        tester.getSemantics(find.byKey(const Key('badge_7'))).label,
        '7日連続のバッジ、取得済み',
      );
      expect(
        tester.getSemantics(find.byKey(const Key('badge_14'))).label,
        '14日連続のバッジ、未取得',
      );
      expect(
        tester.getSemantics(find.byKey(const Key('badge_365'))).label,
        '365日連続のバッジ、未取得',
      );
      h.dispose();
    });

    testWidgets('途切れても取得済みのバッジは残る', (tester) async {
      await openHistory(tester, [
        rec('2026-11-01', true),
        rec('2026-11-02', true),
        rec('2026-11-03', true),
        rec('2026-11-04', false),
      ]);
      expect(find.text('バッジ(1/8)'), findsOneWidget);
    });

    testWidgets('取得済みと未取得でアイコンが違う', (tester) async {
      await openHistory(tester, [
        for (var i = 1; i <= 3; i++) rec('2026-11-0$i', true),
      ]);
      expect(
        find.descendant(
          of: find.byKey(const Key('badge_3')),
          matching: find.byIcon(Icons.emoji_events),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('badge_7')),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsOneWidget,
      );
    });
  });

  group('レイアウト・アクセシビリティ', () {
    for (final (label, size, scale) in [
      ('通常', const Size(390, 844), 1.0),
      ('小さい画面 320x568', const Size(320, 568), 1.0),
      ('小さい画面 + 文字3倍', const Size(320, 568), 3.0),
      ('横向き 844x390', const Size(844, 390), 1.0),
    ]) {
      testWidgets('お祝いダイアログが崩れない($label)', (tester) async {
        await _open(
          tester,
          DateTime(2026, 11, 20, 6, 0),
          [rec('2026-11-18', true), rec('2026-11-19', true)],
          size: size,
          textScale: scale,
        );
        await _wake(tester);
        expect(find.byKey(const Key('milestone_dialog')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('milestone_close')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('バッジ一覧が崩れない($label)', (tester) async {
        await _open(
          tester,
          DateTime(2026, 11, 30, 6, 0),
          [for (var i = 1; i <= 7; i++) rec('2026-11-0$i', true)],
          size: size,
          textScale: scale,
        );
        await tester.tap(find.byIcon(Icons.history));
        await tester.pumpAndSettle();
        await tester.fling(find.byType(ListView), const Offset(0, -1500), 2000);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('お祝いダイアログのアクセシビリティ基準', (tester) async {
      final h = tester.ensureSemantics();
      await _open(tester, DateTime(2026, 11, 20, 6, 0), [
        rec('2026-11-18', true),
        rec('2026-11-19', true),
      ]);
      await _wake(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      h.dispose();
    });
  });
}
