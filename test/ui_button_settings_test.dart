// ホームのボタンの文言・アイコン設定のテスト。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/domain/app_settings.dart';
import 'package:wake_up_up/presentation/wake_button.dart';

import 'helpers/fakes.dart';

Future<void> _pump(
  WidgetTester tester, {
  FakeSettings? settings,
  Size size = const Size(390, 1600),
  double textScale = 1.0,
}) async {
  setScreen(tester, size, textScale: textScale);
  await tester.pumpWidget(
    buildApp(
      clock: () => DateTime(2026, 11, 19, 6, 0),
      settings: settings ?? FakeSettings(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
}

Future<void> _openHome(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(Icons.wb_sunny),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('label_field')), text);
  await tester.pumpAndSettle();
}

Finder _inPreview(Finder f) =>
    find.descendant(of: find.byKey(const Key('wake_preview')), matching: f);

Finder _inHomeButton(Finder f) =>
    find.descendant(of: find.byKey(const Key('wake_button')), matching: f);

String _fieldText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const Key('label_field')))
    .controller!
    .text;

void main() {
  test('アイコンの選択肢のキーは設定のキー一覧と一致する', () {
    expect(wakeIconOptions.keys.toList(), wakeIconKeys);
  });

  testWidgets('初期状態は「起きた」でアイコンなし', (tester) async {
    await _pump(tester);
    expect(_inHomeButton(find.text('起きた')), findsOneWidget);
    expect(_inHomeButton(find.byType(Icon)), findsNothing);
  });

  group('文言', () {
    testWidgets('入力するとプレビューとホームのボタンに反映され、保存される', (tester) async {
      final fake = FakeSettings();
      await _pump(tester, settings: fake);
      await _openSettings(tester);
      await _enter(tester, '朝活');
      expect(_inPreview(find.text('朝活')), findsOneWidget);
      expect(fake.s.wakeLabel, '朝活');
      await _openHome(tester);
      expect(_inHomeButton(find.text('朝活')), findsOneWidget);
    });

    testWidgets('9文字以上は8文字までに制限される', (tester) async {
      final fake = FakeSettings();
      await _pump(tester, settings: fake);
      await _openSettings(tester);
      await _enter(tester, 'あいうえおかきくけこ');
      expect(_fieldText(tester), 'あいうえおかきく');
      expect(fake.s.wakeLabel, 'あいうえおかきく');
    });

    testWidgets('絵文字も1文字と数える(8個まで入る)', (tester) async {
      final fake = FakeSettings();
      await _pump(tester, settings: fake);
      await _openSettings(tester);
      await _enter(tester, '🌞🌞🌞🌞🌞🌞🌞🌞🌞');
      expect(fake.s.wakeLabel, '🌞🌞🌞🌞🌞🌞🌞🌞');
    });

    testWidgets('空にすると「起きた」に戻る', (tester) async {
      final fake = FakeSettings(const AppSettings(wakeLabel: '朝活'));
      await _pump(tester, settings: fake);
      await _openSettings(tester);
      await _enter(tester, '');
      expect(fake.s.wakeLabel, '起きた');
      expect(_inPreview(find.text('起きた')), findsOneWidget);
    });

    testWidgets('空白だけでも「起きた」に戻り、前後の空白は取り除かれる', (tester) async {
      final fake = FakeSettings();
      await _pump(tester, settings: fake);
      await _openSettings(tester);
      await _enter(tester, '   ');
      expect(fake.s.wakeLabel, '起きた');
      await _enter(tester, '  朝活  ');
      expect(fake.s.wakeLabel, '朝活');
    });

    testWidgets('保存済みの文言で起動する', (tester) async {
      await _pump(
        tester,
        settings: FakeSettings(const AppSettings(wakeLabel: '朝活')),
      );
      expect(_inHomeButton(find.text('朝活')), findsOneWidget);
    });

    testWidgets('記録後は文言を変えていても「記録済み」(アイコンなし)になる', (tester) async {
      await _pump(
        tester,
        settings: FakeSettings(
          const AppSettings(wakeLabel: '朝活', wakeIconKey: 'rocket'),
        ),
      );
      expect(_inHomeButton(find.byIcon(Icons.rocket_launch)), findsOneWidget);
      await tester.tap(find.byKey(const Key('wake_button')));
      await tester.pumpAndSettle();
      expect(_inHomeButton(find.text('記録済み')), findsOneWidget);
      expect(_inHomeButton(find.byType(Icon)), findsNothing);
    });
  });

  group('アイコン', () {
    testWidgets('選ぶとプレビューとホームに反映され、保存される', (tester) async {
      final fake = FakeSettings();
      await _pump(tester, settings: fake);
      await _openSettings(tester);
      await tester.tap(find.byKey(const Key('icon_chip_rocket')));
      await tester.pumpAndSettle();
      expect(_inPreview(find.byIcon(Icons.rocket_launch)), findsOneWidget);
      expect(fake.s.wakeIconKey, 'rocket');
      await _openHome(tester);
      expect(_inHomeButton(find.byIcon(Icons.rocket_launch)), findsOneWidget);
    });

    testWidgets('「なし」を選ぶとアイコンが消える', (tester) async {
      final fake = FakeSettings(const AppSettings(wakeIconKey: 'heart'));
      await _pump(tester, settings: fake);
      await _openSettings(tester);
      await tester.tap(find.byKey(const Key('icon_chip_none')));
      await tester.pumpAndSettle();
      expect(_inPreview(find.byType(Icon)), findsNothing);
      expect(fake.s.wakeIconKey, 'none');
    });

    testWidgets('すべてのアイコンを選べる', (tester) async {
      final fake = FakeSettings();
      await _pump(tester, settings: fake);
      await _openSettings(tester);
      for (final key in wakeIconKeys) {
        await tester.tap(find.byKey(Key('icon_chip_$key')));
        await tester.pumpAndSettle();
        expect(fake.s.wakeIconKey, key);
      }
    });
  });

  testWidgets('「初期値に戻す」で文言とアイコンが初期値になる', (tester) async {
    final fake = FakeSettings(
      const AppSettings(wakeLabel: '朝活', wakeIconKey: 'bolt'),
    );
    await _pump(tester, settings: fake);
    await _openSettings(tester);
    await tester.ensureVisible(find.byKey(const Key('reset_button')));
    await tester.tap(find.byKey(const Key('reset_button')));
    await tester.pumpAndSettle();
    expect(fake.s.wakeLabel, '起きた');
    expect(fake.s.wakeIconKey, 'none');
    expect(_fieldText(tester), '起きた');
  });

  testWidgets('文言・アイコンを変えてもほかの設定は変わらない', (tester) async {
    final fake = FakeSettings(
      const AppSettings(themeColorIndex: 3, themeMode: AppThemeMode.dark),
    );
    await _pump(tester, settings: fake);
    await _openSettings(tester);
    await _enter(tester, '朝活');
    await tester.tap(find.byKey(const Key('icon_chip_sun')));
    await tester.pumpAndSettle();
    expect(fake.s.themeColorIndex, 3);
    expect(fake.s.themeMode, AppThemeMode.dark);
  });

  testWidgets('プレビューは押しても記録されない', (tester) async {
    final repo = FakeRecordRepository();
    setScreen(tester, const Size(390, 1600));
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0), repo: repo),
    );
    await tester.pumpAndSettle();
    await _openSettings(tester);
    await tester.tap(
      find.byKey(const Key('wake_preview')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect((await repo.all()), isEmpty);
  });

  group('レイアウト', () {
    for (final (label, size, scale) in [
      ('通常', const Size(390, 844), 1.0),
      ('小さい画面 320x568', const Size(320, 568), 1.0),
      ('小さい画面 + 文字3倍', const Size(320, 568), 3.0),
    ]) {
      testWidgets('8文字の長い文言+アイコンでも、ボタンが画面内に収まる($label)', (tester) async {
        await _pump(
          tester,
          settings: FakeSettings(
            const AppSettings(wakeLabel: 'あいうえおかきく', wakeIconKey: 'meditation'),
          ),
          size: size,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        final rect = tester.getRect(find.byKey(const Key('wake_button')));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(
          rect.bottom,
          lessThanOrEqualTo(tester.getTopLeft(find.byType(NavigationBar)).dy),
        );
        // 設定画面のプレビュー・入力欄も崩れない。
        await _openSettings(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('ボタンは設定した文言で読み上げられる', (tester) async {
    final h = tester.ensureSemantics();
    await _pump(
      tester,
      settings: FakeSettings(
        const AppSettings(wakeLabel: '朝活', wakeIconKey: 'alarm'),
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('wake_button'))),
      matchesSemantics(
        label: '朝活',
        isButton: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    h.dispose();
  });

  testWidgets('アイコンのチップは名前で読み上げられ、タップ領域の基準を満たす', (tester) async {
    final h = tester.ensureSemantics();
    await _pump(tester);
    await _openSettings(tester);
    expect(find.bySemanticsLabel('ロケット'), findsWidgets);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    h.dispose();
  });
}
