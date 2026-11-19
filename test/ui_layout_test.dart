// 観点4: レイアウト(画面サイズ・向き・文字サイズ・ダークモード)。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wake_up_up/domain/app_settings.dart';

import 'helpers/fakes.dart';

/// 全画面を巡回して、レイアウト例外(オーバーフローなど)が出ないことを確認する。
Future<void> _tour(WidgetTester tester) async {
  await tester.pumpWidget(buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'ホーム(未記録)');

  // 「起きた」ボタンは常に画面内にあり、下部タブに隠れずに押せる。
  final button = find.byKey(const Key('wake_button'));
  expect(
    tester.getRect(button).bottom,
    lessThanOrEqualTo(tester.getTopLeft(find.byType(NavigationBar)).dy),
    reason: 'ボタンが下部タブと重なっている',
  );
  expect(tester.getRect(button).top, greaterThanOrEqualTo(0));
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'ホーム(記録後)');

  await tester.tap(find.byIcon(Icons.history));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: '履歴');

  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: '設定');
}

void main() {
  // タップ位置が他のウィジェットに隠れていたら、警告ではなく失敗にする。
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  const sizes = <String, Size>{
    'iPhone SE (320x568)': Size(320, 568),
    'iPhone 8 (375x667)': Size(375, 667),
    'iPhone 16 Pro Max (440x956)': Size(440, 956),
    'タブレット (768x1024)': Size(768, 1024),
    '横向き (844x390)': Size(844, 390),
  };

  for (final e in sizes.entries) {
    testWidgets('画面サイズ ${e.key}', (tester) async {
      setScreen(tester, e.value);
      await _tour(tester);
    });
  }

  for (final scale in [1.5, 2.0, 3.0]) {
    testWidgets('文字サイズ $scale倍(375x667)', (tester) async {
      setScreen(tester, const Size(375, 667), textScale: scale);
      await _tour(tester);
    });
  }

  testWidgets('小さい画面(320x568)+文字サイズ3倍', (tester) async {
    setScreen(tester, const Size(320, 568), textScale: 3.0);
    await _tour(tester);
  });

  testWidgets('ダークモード設定の端末でも崩れない', (tester) async {
    setScreen(tester, const Size(390, 844));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await _tour(tester);
  });

  testWidgets('履歴が多数でも小さい画面でスクロールできる', (tester) async {
    setScreen(tester, const Size(320, 568));
    final seed = [
      for (var i = 0; i < 60; i++)
        rec(fmtDate(DateTime(2026, 10, 1 + i)), i.isEven),
    ];
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 12, 31, 6, 0),
        repo: FakeRecordRepository(seed),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final (label, size, scale) in [
    ('小さい画面 320x568', const Size(320, 568), 1.0),
    ('小さい画面 + 文字3倍', const Size(320, 568), 3.0),
    ('横向き 844x390', const Size(844, 390), 1.0),
  ]) {
    testWidgets('設定画面を最後までスクロールできる($label)', (tester) async {
      setScreen(tester, size, textScale: scale);
      await tester.pumpWidget(
        buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // テーマカラーを選べる(スクロール後でも操作できる)。
      await tester.fling(find.byType(ListView), const Offset(0, 3000), 3000);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('color_chip_7')),
        100,
      );
      await tester.ensureVisible(find.byKey(const Key('color_chip_7')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('color_chip_7')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final (label, size, scale) in [
    ('通常', const Size(390, 844), 1.0),
    ('小さい画面 + 文字3倍', const Size(320, 568), 3.0),
  ]) {
    testWidgets('ダークモードで全画面を巡回できる($label)', (tester) async {
      setScreen(tester, size, textScale: scale);
      await tester.pumpWidget(
        buildApp(
          clock: () => DateTime(2026, 11, 19, 6, 0),
          settings: FakeSettings(
            const AppSettings(themeMode: AppThemeMode.dark),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wake_button')));
      await tester.pumpAndSettle();
      for (final icon in [Icons.history, Icons.settings, Icons.wb_sunny]) {
        await tester.tap(find.byIcon(icon));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
