// 履歴の月カレンダーの画面テスト。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/domain/app_settings.dart';
import 'package:wake_up_up/domain/wake_record.dart';

import 'helpers/fakes.dart';

final _seed = [
  rec('2026-10-30', true),
  rec('2026-11-16', true),
  rec('2026-11-17', true),
  rec('2026-11-18', false),
  rec('2026-11-19', true),
];

Future<void> _open(
  WidgetTester tester, {
  DateTime? now,
  List<WakeRecord>? records,
  Size size = const Size(390, 1800),
  double textScale = 1.0,
  AppSettings? settings,
}) async {
  setScreen(tester, size, textScale: textScale);
  await tester.pumpWidget(
    buildApp(
      clock: () => now ?? DateTime(2026, 11, 20, 6, 0),
      repo: FakeRecordRepository(records ?? _seed),
      settings: settings == null ? null : FakeSettings(settings),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.history));
  await tester.pumpAndSettle();
}

String _label(WidgetTester tester, String date) =>
    tester.getSemantics(find.byKey(Key('cell_$date'))).label;

/// 月の見出しが [text] のものを探す。
Finder _title(String text) => find.byWidgetPredicate(
  (w) => w is Text && w.key == const Key('month_title') && w.data == text,
);

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  group('表示', () {
    testWidgets('履歴を開くとカレンダー(今日の月)が初期表示される', (tester) async {
      await _open(tester);
      expect(find.byKey(const Key('calendar')), findsOneWidget);
      expect(find.text('2026年11月'), findsOneWidget);
      for (final w in ['日', '月', '火', '水', '木', '金', '土']) {
        expect(find.text(w), findsOneWidget, reason: w);
      }
      // リストの行は出ない。
      expect(find.byKey(const Key('day_2026-11-19')), findsNothing);
    });

    testWidgets('成功は✓、失敗は×のアイコンで示される(色だけに頼らない)', (tester) async {
      await _open(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('cell_2026-11-19')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('cell_2026-11-18')),
          matching: find.byIcon(Icons.close),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('cell_2026-11-10')),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
    });

    testWidgets('セルの読み上げラベル(成功・失敗・記録なし・今日・まだ先)', (tester) async {
      final h = tester.ensureSemantics();
      await _open(tester);
      await tester.pumpAndSettle();
      expect(_label(tester, '2026-11-19'), '11月19日、成功');
      expect(_label(tester, '2026-11-18'), '11月18日、失敗');
      expect(_label(tester, '2026-11-10'), '11月10日、記録なし');
      expect(_label(tester, '2026-11-20'), '11月20日、記録なし、今日');
      expect(_label(tester, '2026-11-25'), '11月25日、まだ先');
      h.dispose();
    });

    testWidgets('月の集計が表示される', (tester) async {
      await _open(tester);
      expect(find.text('成功 3 日 / 失敗 1 日 / 成功率 75%'), findsOneWidget);
    });

    testWidgets('記録のない月は「この月の記録はありません」', (tester) async {
      await _open(tester, records: [rec('2026-09-10', true)]);
      await _tap(tester, 'month_prev'); // 10月
      expect(find.text('この月の記録はありません'), findsOneWidget);
    });

    testWidgets('記録がないときはカレンダーではなく案内を表示する', (tester) async {
      await _open(tester, records: []);
      expect(find.text('まだ記録がありません'), findsOneWidget);
      expect(find.byKey(const Key('calendar')), findsNothing);
    });

    testWidgets('31日の月・閏年2月の末日がそろっている', (tester) async {
      await _open(
        tester,
        now: DateTime(2028, 3, 5, 6, 0),
        records: [rec('2028-02-29', true)],
      );
      await _tap(tester, 'month_prev'); // 2028年2月
      expect(find.text('2028年2月'), findsOneWidget);
      expect(find.byKey(const Key('cell_2028-02-29')), findsOneWidget);
      expect(find.byKey(const Key('cell_2028-02-30')), findsNothing);
    });
  });

  group('月の移動', () {
    testWidgets('前の月・次の月へ移動できる', (tester) async {
      await _open(tester);
      await _tap(tester, 'month_prev');
      expect(_title('2026年10月'), findsOneWidget);
      expect(find.byKey(const Key('cell_2026-10-30')), findsOneWidget);
      await _tap(tester, 'month_next');
      expect(_title('2026年11月'), findsOneWidget);
    });

    testWidgets('最初の記録の月で「前の月」が無効になる', (tester) async {
      await _open(tester); // 最初の記録は 10/30
      await _tap(tester, 'month_prev');
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('month_prev')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('month_next')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('今日の月で「次の月」が無効になる', (tester) async {
      await _open(tester);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('month_next')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('month_prev')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('年をまたぐ移動(1月 → 前の月 → 12月)', (tester) async {
      await _open(
        tester,
        now: DateTime(2027, 1, 10, 6, 0),
        records: [rec('2026-12-30', true), rec('2027-01-05', true)],
      );
      expect(_title('2027年1月'), findsOneWidget);
      await _tap(tester, 'month_prev');
      expect(_title('2026年12月'), findsOneWidget);
    });

    testWidgets('リストに切り替えてカレンダーに戻っても、表示中の月は維持される', (tester) async {
      await _open(tester);
      await _tap(tester, 'month_prev');
      await _tap(tester, 'view_list');
      await _tap(tester, 'view_calendar');
      expect(_title('2026年10月'), findsOneWidget);
    });

    testWidgets('月のボタンには読み上げ用の説明がある', (tester) async {
      await _open(tester);
      expect(find.byTooltip('前の月'), findsOneWidget);
      expect(find.byTooltip('次の月'), findsOneWidget);
    });
  });

  group('日付のタップ', () {
    testWidgets('成功の日: 詳細が表示される', (tester) async {
      await _open(tester);
      await _tap(tester, 'cell_2026-11-19');
      expect(find.byKey(const Key('day_sheet')), findsOneWidget);
      expect(find.text('2026年11月19日(木)'), findsOneWidget);
      expect(find.text('成功 +10 pt'), findsOneWidget);
      expect(find.text('起床時刻'), findsOneWidget);
      Finder inSheet(String t) => find.descendant(
        of: find.byKey(const Key('day_sheet')),
        matching: find.text(t),
      );
      expect(inSheet('06:00'), findsOneWidget);
      expect(inSheet('06:30'), findsOneWidget);
    });

    testWidgets('失敗の日: 失敗と表示される', (tester) async {
      await _open(tester);
      await _tap(tester, 'cell_2026-11-18');
      expect(find.text('失敗'), findsOneWidget);
    });

    testWidgets('記録のない日: 「記録なし」', (tester) async {
      await _open(tester);
      await _tap(tester, 'cell_2026-11-10');
      expect(find.text('記録なし'), findsOneWidget);
    });

    testWidgets('まだ先の日はタップできない', (tester) async {
      await _open(tester);
      await _tap(tester, 'cell_2026-11-25');
      expect(find.byKey(const Key('day_sheet')), findsNothing);
    });

    testWidgets('シートは外側をタップすると閉じる', (tester) async {
      await _open(tester);
      await _tap(tester, 'cell_2026-11-19');
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('day_sheet')), findsNothing);
    });
  });

  group('表示の切り替え', () {
    testWidgets('リストにすると日ごとの行が並び、カレンダーは消える', (tester) async {
      await _open(tester);
      await _tap(tester, 'view_list');
      expect(find.byKey(const Key('calendar')), findsNothing);
      expect(find.byKey(const Key('day_2026-11-19')), findsOneWidget);
      await _tap(tester, 'view_calendar');
      expect(find.byKey(const Key('calendar')), findsOneWidget);
    });

    testWidgets('切替の選択状態が分かる', (tester) async {
      await _open(tester);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('view_calendar')))
            .selected,
        isTrue,
      );
      await _tap(tester, 'view_list');
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('view_list'))).selected,
        isTrue,
      );
    });
  });

  group('日付の更新', () {
    testWidgets('午前3:00を過ぎると、今日の印が翌日に移る', (tester) async {
      final h = tester.ensureSemantics();
      var now = DateTime(2026, 11, 20, 6, 0);
      setScreen(tester, const Size(390, 1800));
      await tester.pumpWidget(
        buildApp(clock: () => now, repo: FakeRecordRepository(_seed)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();
      expect(_label(tester, '2026-11-20'), contains('今日'));
      expect(_label(tester, '2026-11-21'), isNot(contains('今日')));

      now = DateTime(2026, 11, 21, 4, 0);
      await tester.pump(const Duration(hours: 22));
      await tester.pumpAndSettle();
      expect(_label(tester, '2026-11-21'), contains('今日'));
      expect(_label(tester, '2026-11-20'), '11月20日、記録なし');
      h.dispose();
    });

    testWidgets('月を移動していなければ、月が替わると表示も新しい月に追従する(月末→月初)', (tester) async {
      var now = DateTime(2026, 11, 30, 6, 0);
      setScreen(tester, const Size(390, 1800));
      await tester.pumpWidget(
        buildApp(clock: () => now, repo: FakeRecordRepository(_seed)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();
      expect(_title('2026年11月'), findsOneWidget);
      now = DateTime(2026, 12, 1, 4, 0);
      await tester.pump(const Duration(hours: 22));
      await tester.pumpAndSettle();
      // 月を移動していなければ、表示は新しい今日の月(12月)に追従する。
      expect(_title('2026年12月'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('month_prev')))
            .onPressed,
        isNotNull,
      );
    });
  });

  group('レイアウト', () {
    for (final (label, size, scale) in [
      ('通常', const Size(390, 844), 1.0),
      ('小さい画面 320x568', const Size(320, 568), 1.0),
      ('小さい画面 + 文字3倍', const Size(320, 568), 3.0),
      ('横向き 844x390', const Size(844, 390), 1.0),
      ('タブレット 768x1024', const Size(768, 1024), 1.0),
    ]) {
      testWidgets('カレンダーが崩れない($label)', (tester) async {
        await _open(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byKey(const Key('month_summary')),
          200,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const Key('cell_2026-11-19')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('cell_2026-11-19')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('day_sheet')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('6週の月(2027年1月)でも崩れない', (tester) async {
      await _open(
        tester,
        now: DateTime(2027, 1, 20, 6, 0),
        records: [rec('2027-01-05', true)],
        size: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('アクセシビリティ', () {
    testWidgets('コントラスト・タップ領域・ラベルの基準を満たす', (tester) async {
      final h = tester.ensureSemantics();
      await _open(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      h.dispose();
    });

    testWidgets('ダークでもコントラスト基準を満たす', (tester) async {
      final h = tester.ensureSemantics();
      await _open(
        tester,
        settings: const AppSettings(themeMode: AppThemeMode.dark),
      );
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      h.dispose();
    });
  });
}
