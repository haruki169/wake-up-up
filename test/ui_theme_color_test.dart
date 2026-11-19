// テーマカラー変更の機能テスト。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/domain/app_settings.dart';
import 'package:wake_up_up/presentation/theme_options.dart';

import 'helpers/fakes.dart';

Color _primary(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold))).colorScheme.primary;

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
}

void main() {
  test('選べる色の数は設定のパレット数と一致する', () {
    expect(themeChoices.length, AppSettings.paletteSize);
  });

  test('範囲外の番号はオレンジ(0番)と同じテーマになる', () {
    for (final i in [-1, 8, 99]) {
      expect(
        buildTheme(i, Brightness.light).colorScheme.primary,
        buildTheme(0, Brightness.light).colorScheme.primary,
        reason: '$i',
      );
    }
  });

  test('8色すべてで見た目(主色)が異なる', () {
    final primaries = {
      for (var i = 0; i < themeChoices.length; i++)
        buildTheme(i, Brightness.light).colorScheme.primary,
    };
    expect(primaries.length, themeChoices.length);
  });

  testWidgets('初期値はオレンジで、設定画面に8色のチップが並ぶ', (tester) async {
    setScreen(tester, const Size(390, 1200));
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
    );
    await tester.pumpAndSettle();
    expect(
      _primary(tester),
      buildTheme(0, Brightness.light).colorScheme.primary,
    );
    await _openSettings(tester);
    for (var i = 0; i < 8; i++) {
      expect(find.byKey(Key('color_chip_$i')), findsOneWidget);
    }
  });

  testWidgets('色を選ぶと全画面のテーマが変わり、設定に保存される', (tester) async {
    setScreen(tester, const Size(390, 1200));
    final settings = FakeSettings();
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0), settings: settings),
    );
    await tester.pumpAndSettle();
    await _openSettings(tester);

    await tester.tap(find.byKey(const Key('color_chip_4')));
    await tester.pumpAndSettle();
    expect(
      _primary(tester),
      buildTheme(4, Brightness.light).colorScheme.primary,
    );
    expect(settings.s.themeColorIndex, 4);

    // ほかの画面でも同じテーマが使われる。
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(
      _primary(tester),
      buildTheme(4, Brightness.light).colorScheme.primary,
    );
  });

  testWidgets('保存済みの色で起動する', (tester) async {
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 19, 6, 0),
        settings: FakeSettings(const AppSettings(themeColorIndex: 6)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      _primary(tester),
      buildTheme(6, Brightness.light).colorScheme.primary,
    );
  });

  testWidgets('色を変えても目標時刻などほかの設定は変わらない', (tester) async {
    setScreen(tester, const Size(390, 1200));
    final settings = FakeSettings();
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0), settings: settings),
    );
    await tester.pumpAndSettle();
    await _openSettings(tester);
    await tester.tap(find.byKey(const Key('color_chip_2')));
    await tester.pumpAndSettle();
    expect(settings.s.targetTime, settings.t);
    expect(settings.s.targetTime.toString(), '06:30');
  });

  testWidgets('チップは色の名前で読み上げられ、選択中が分かる', (tester) async {
    setScreen(tester, const Size(390, 1200));
    final h = tester.ensureSemantics();
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
    );
    await tester.pumpAndSettle();
    await _openSettings(tester);
    expect(
      tester.getSemantics(find.byKey(const Key('color_chip_0'))),
      matchesSemantics(
        label: 'オレンジ',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('color_chip_4'))),
      matchesSemantics(
        label: '青',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    h.dispose();
  });

  testWidgets('履歴の成功/失敗の色はテーマ連動(StatusColors)', (tester) async {
    setScreen(tester, const Size(390, 1200));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 20, 6, 0),
        repo: FakeRecordRepository([
          rec('2026-11-18', true),
          rec('2026-11-19', false),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    final status = Theme.of(tester.element(find.byType(Scaffold)))
        .extension<StatusColors>()!;
    expect(
      tester.widget<Icon>(find.byIcon(Icons.check_circle)).color,
      status.success,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.cancel)).color,
      status.failure,
    );
  });
}
