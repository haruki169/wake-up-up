import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:wake_up_up/data/record_repository.dart';
import 'package:wake_up_up/data/settings_repository.dart';
import 'package:wake_up_up/domain/wake_record.dart';
import 'package:wake_up_up/presentation/app.dart';
import 'package:wake_up_up/presentation/providers.dart';

/// メモリ上の記録リポジトリ(テスト用)。同じ日付は2件目を無視する。
class FakeRecordRepository implements RecordRepository {
  FakeRecordRepository([Iterable<WakeRecord> seed = const []]) {
    for (final r in seed) {
      _m[r.date] = r;
    }
  }

  final Map<String, WakeRecord> _m = {};

  /// insert が呼ばれた回数(重複で無視された分も含む)。
  int insertCalls = 0;

  @override
  Future<List<WakeRecord>> all() async =>
      (_m.values.toList()..sort((a, b) => b.date.compareTo(a.date)));

  @override
  Future<bool> insert(WakeRecord r) async {
    insertCalls++;
    if (_m.containsKey(r.date)) return false;
    _m[r.date] = r;
    return true;
  }
}

/// 読み込みが常に失敗するリポジトリ(エラー表示の確認用)。
class ThrowingRecordRepository implements RecordRepository {
  @override
  Future<List<WakeRecord>> all() async => throw Exception('boom');

  @override
  Future<bool> insert(WakeRecord r) async => throw Exception('boom');
}

class FakeSettings implements SettingsRepository {
  FakeSettings([this.t = const TargetTime(6, 30)]);

  TargetTime t;

  @override
  TargetTime get targetTime => t;

  @override
  Future<void> setTargetTime(TargetTime v) async => t = v;
}

/// 日付文字列 yyyy-MM-dd。
String fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 成功/失敗の記録を作る。
WakeRecord rec(String date, bool ok, {int points = 10}) => WakeRecord(
  date: date,
  wokeAt: DateTime.parse(date).add(const Duration(hours: 6)),
  targetTime: const TargetTime(6, 30),
  success: ok,
  points: ok ? points : 0,
);

/// テスト対象のアプリ。[clock] は呼ぶたびに現在時刻を返す関数。
Widget buildApp({
  required DateTime Function() clock,
  RecordRepository? repo,
  SettingsRepository? settings,
}) => ProviderScope(
  overrides: [
    recordRepositoryProvider.overrideWithValue(repo ?? FakeRecordRepository()),
    settingsRepositoryProvider.overrideWithValue(settings ?? FakeSettings()),
    clockProvider.overrideWithValue(clock),
  ],
  child: const WakeUpUpApp(),
);

/// 画面サイズ(論理px)を設定する。テスト終了時に元へ戻す。
void setScreen(
  dynamic tester,
  Size logical, {
  double dpr = 3,
  double textScale = 1.0,
}) {
  tester.view.physicalSize = logical * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}
