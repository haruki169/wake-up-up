// 起床記録の SQLite 実装(record_repository.dart)のテスト(実際の SQLite)。
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/data/record_repository.dart';
import 'package:wake_up_up/domain/wake_logic.dart';
import 'package:wake_up_up/domain/wake_record.dart';

import 'helpers/db_helper.dart';
import 'helpers/fakes.dart';

void main() {
  test('追加した記録を新しい日付順に読める', () async {
    final repo = SqliteRecordRepository(await TestDb.create().open());
    await repo.insert(rec('2026-11-17', true));
    await repo.insert(rec('2026-11-19', false));
    await repo.insert(rec('2026-11-18', true));
    expect((await repo.all()).map((r) => r.date), [
      '2026-11-19',
      '2026-11-18',
      '2026-11-17',
    ]);
  });

  test('同じ日付の2件目は保存されず false を返す', () async {
    final repo = SqliteRecordRepository(await TestDb.create().open());
    expect(await repo.insert(rec('2026-11-19', true)), isTrue);
    expect(await repo.insert(rec('2026-11-19', false)), isFalse);
    final all = await repo.all();
    expect(all.length, 1);
    expect(all.single.success, isTrue);
  });

  test('保存して読み戻した値が一致する', () async {
    final repo = SqliteRecordRepository(await TestDb.create().open());
    final r = buildRecord(
      DateTime(2026, 11, 19, 6, 19, 30),
      const TargetTime(6, 30),
    );
    await repo.insert(r);
    final got = (await repo.all()).single;
    expect(got.date, '2026-11-19');
    expect(got.wokeAt, r.wokeAt);
    expect(got.targetTime, const TargetTime(6, 30));
    expect(got.success, isTrue);
    expect(got.points, 11);
  });

  test('同時に何度 insert しても1件だけ保存される', () async {
    final repo = SqliteRecordRepository(await TestDb.create().open());
    final results = await Future.wait([
      for (var i = 0; i < 10; i++) repo.insert(rec('2026-11-19', true)),
    ]);
    expect(results.where((e) => e).length, 1);
    expect((await repo.all()).length, 1);
  });
}
