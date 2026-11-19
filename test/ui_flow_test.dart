// 観点1: 機能フロー(+ 観点8の一部: プラットフォーム別テーマでの動作)。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/domain/wake_record.dart';
import 'package:wake_up_up/presentation/app.dart';
import 'package:wake_up_up/presentation/providers.dart';

import 'helpers/fakes.dart';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(WakeUpUpApp)));

void main() {
  testWidgets('全プラットフォームで 未記録→記録→履歴 の流れが動く', (tester) async {
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
    );
    await tester.pumpAndSettle();
    expect(find.text('今日はまだ未記録'), findsOneWidget);
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    expect(find.text('記録済み'), findsOneWidget);
    await openHistoryList(tester);
    expect(find.byKey(const Key('day_2026-11-19')), findsOneWidget);
  }, variant: TargetPlatformVariant.all());

  testWidgets('目標時刻を変更すると以降の記録に適用される', (tester) async {
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 7, 30)),
    );
    await tester.pumpAndSettle();
    expect(find.text('目標 06:30'), findsOneWidget);

    await _container(tester)
        .read(settingsProvider.notifier)
        .setTargetTime(const TargetTime(8, 0));
    await tester.pumpAndSettle();
    expect(find.text('目標 08:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    // 30分早い → 10 + 3 = 13pt
    expect(find.text('成功！ +13 pt'), findsOneWidget);
  });

  testWidgets('目標を変えても過去の記録の目標時刻・成否は変わらない', (tester) async {
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 20)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();

    await _container(tester)
        .read(settingsProvider.notifier)
        .setTargetTime(const TargetTime(5, 0));
    await tester.pumpAndSettle();

    await openHistoryList(tester);
    expect(find.textContaining('目標 06:30'), findsOneWidget);
    expect(find.text('+11 pt'), findsOneWidget);
  });

  testWidgets('設定: 時刻ピッカーを開いてキャンセルすると目標は変わらない', (tester) async {
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('06:30'), findsOneWidget);

    await tester.tap(find.byKey(const Key('target_tile')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('06:30'), findsOneWidget);
  });

  testWidgets('設定: ピッカーでOKすると目標が保存される', (tester) async {
    final settings = FakeSettings();
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0), settings: settings),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('target_tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // 初期値のままOK → 同じ値が保存される(例外なく閉じる)
    expect(find.byType(Dialog), findsNothing);
    expect(settings.t, const TargetTime(6, 30));
  });
}
