// ダークモード(端末に合わせる/ライト/ダーク)の機能テスト。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/domain/app_settings.dart';
import 'package:wake_up_up/presentation/theme_options.dart';

import 'helpers/fakes.dart';

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold))).brightness;

Future<void> _pump(
  WidgetTester tester, {
  AppSettings? settings,
  Brightness device = Brightness.light,
}) async {
  setScreen(tester, const Size(390, 1200));
  tester.platformDispatcher.platformBrightnessTestValue = device;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpWidget(
    buildApp(
      clock: () => DateTime(2026, 11, 19, 6, 0),
      settings: FakeSettings(settings),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
}

void main() {
  test('toThemeMode は3つの値を対応づける', () {
    expect(toThemeMode(AppThemeMode.system), ThemeMode.system);
    expect(toThemeMode(AppThemeMode.light), ThemeMode.light);
    expect(toThemeMode(AppThemeMode.dark), ThemeMode.dark);
  });

  test('ダークのテーマは暗く、成功色が明るい色になる', () {
    final light = buildTheme(0, Brightness.light);
    final dark = buildTheme(0, Brightness.dark);
    expect(dark.brightness, Brightness.dark);
    expect(
      dark.extension<StatusColors>()!.success,
      isNot(light.extension<StatusColors>()!.success),
    );
  });

  testWidgets('初期値は「端末の設定に合わせる」で、端末がライトならライト', (tester) async {
    await _pump(tester);
    await _openSettings(tester);
    expect(_brightness(tester), Brightness.light);
    final group = tester.widget<RadioListTile<AppThemeMode>>(
      find.widgetWithText(RadioListTile<AppThemeMode>, '端末の設定に合わせる'),
    );
    expect(group.value, AppThemeMode.system);
    expect(find.text('ライト'), findsOneWidget);
    expect(find.text('ダーク'), findsOneWidget);
  });

  testWidgets('端末がダークなら「端末に合わせる」はダークになる', (tester) async {
    await _pump(tester, device: Brightness.dark);
    expect(_brightness(tester), Brightness.dark);
  });

  testWidgets('「ダーク」を選ぶと、端末がライトでもダークになり保存される', (tester) async {
    final fake = FakeSettings();
    setScreen(tester, const Size(390, 1200));
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0), settings: fake),
    );
    await tester.pumpAndSettle();
    await _openSettings(tester);
    await tester.tap(find.text('ダーク'));
    await tester.pumpAndSettle();
    expect(_brightness(tester), Brightness.dark);
    expect(fake.s.themeMode, AppThemeMode.dark);
  });

  testWidgets('「ライト」を選ぶと、端末がダークでもライトになる', (tester) async {
    await _pump(tester, device: Brightness.dark);
    await _openSettings(tester);
    await tester.tap(find.text('ライト'));
    await tester.pumpAndSettle();
    expect(_brightness(tester), Brightness.light);
  });

  testWidgets('「端末に合わせる」に戻すと端末の明暗に追従する', (tester) async {
    await _pump(
      tester,
      settings: const AppSettings(themeMode: AppThemeMode.light),
      device: Brightness.dark,
    );
    expect(_brightness(tester), Brightness.light);
    await _openSettings(tester);
    await tester.tap(find.text('端末の設定に合わせる'));
    await tester.pumpAndSettle();
    expect(_brightness(tester), Brightness.dark);
  });

  testWidgets('端末の明暗が実行中に変わると、「端末に合わせる」だけ追従する', (tester) async {
    await _pump(tester);
    expect(_brightness(tester), Brightness.light);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(_brightness(tester), Brightness.dark);
  });

  testWidgets('保存済みのモードで起動する', (tester) async {
    await _pump(
      tester,
      settings: const AppSettings(themeMode: AppThemeMode.dark),
    );
    expect(_brightness(tester), Brightness.dark);
  });

  testWidgets('明暗を変えてもテーマカラーは維持される', (tester) async {
    await _pump(tester, settings: const AppSettings(themeColorIndex: 4));
    await _openSettings(tester);
    await tester.tap(find.text('ダーク'));
    await tester.pumpAndSettle();
    final scheme = Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
    expect(scheme.primary, buildTheme(4, Brightness.dark).colorScheme.primary);
  });

  testWidgets('ラジオは選択中が分かり、48dp以上のタップ領域がある', (tester) async {
    final h = tester.ensureSemantics();
    await _pump(tester);
    await _openSettings(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    h.dispose();
  });
}
