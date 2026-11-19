// 観点7: 見た目の回帰(ゴールデン)。
// テスト環境では文字がテスト用フォントで描画されるため、文字の形ではなく
// 配置・色・余白・コンポーネントの変化を検出する用途。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/domain/app_settings.dart';
import 'package:wake_up_up/presentation/app.dart';

import 'helpers/fakes.dart';

Future<void> _golden(WidgetTester tester, String name) => expectLater(
  find.byType(WakeUpUpApp),
  matchesGoldenFile('goldens/$name.png'),
);

void main() {
  testWidgets('ホーム: 未記録', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
    );
    await tester.pumpAndSettle();
    await _golden(tester, 'home_unrecorded');
  });

  testWidgets('ホーム: 成功', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    await _golden(tester, 'home_success');
  });

  testWidgets('ホーム: 失敗', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 8, 0)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    await _golden(tester, 'home_failure');
  });

  testWidgets('履歴', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 20, 6, 0),
        repo: FakeRecordRepository([
          rec('2026-11-17', true),
          rec('2026-11-18', false),
          rec('2026-11-19', true),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    await _golden(tester, 'history');
  });

  testWidgets('設定', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await _golden(tester, 'settings');
  });

  testWidgets('ホーム: 成功(青のテーマ)', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 19, 6, 0),
        settings: FakeSettings(const AppSettings(themeColorIndex: 4)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    await _golden(tester, 'home_success_blue');
  });

  testWidgets('設定(紫のテーマ・テーマカラー選択中)', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 19, 6, 0),
        settings: FakeSettings(const AppSettings(themeColorIndex: 3)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await _golden(tester, 'settings_purple');
  });
}
