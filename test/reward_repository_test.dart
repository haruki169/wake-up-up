// ご褒美・交換・残高の SQLite 実装(reward_repository.dart)のテスト(実際の SQLite)。
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/data/record_repository.dart';
import 'package:wake_up_up/data/reward_repository.dart';
import 'package:wake_up_up/domain/reward.dart';

import 'helpers/db_helper.dart';
import 'helpers/fakes.dart';

final _now = DateTime(2026, 11, 20, 7, 0);

/// 日付ごとに [points] を獲得した記録を入れて、累計獲得をそのぶん増やす。
Future<void> _earn(SqliteRecordRepository records, int day, int points) =>
    records.insert(
      rec('2026-11-${day.toString().padLeft(2, '0')}', true, points: points),
    );

void main() {
  late SqliteRewardRepository repo;
  late SqliteRecordRepository records;

  setUp(() async {
    final db = await TestDb.create().open();
    repo = SqliteRewardRepository(db);
    records = SqliteRecordRepository(db);
  });

  Future<int> add(String name, int cost) async {
    expect(await repo.addReward(name, cost, _now), RewardResult.ok);
    return (await repo.activeRewards()).last.id;
  }

  group('追加・一覧', () {
    test('最初は空', () async => expect(await repo.activeRewards(), isEmpty));

    test('追加すると登録順に並ぶ', () async {
      await add('本', 300);
      await add('コーヒー', 50);
      await add('映画', 500);
      expect((await repo.activeRewards()).map((r) => r.name), [
        '本',
        'コーヒー',
        '映画',
      ]);
    });

    test('名前は前後の空白を取り除いて保存し、内容を読み戻せる', () async {
      await repo.addReward('  好きなお菓子  ', 100, _now);
      final r = (await repo.activeRewards()).single;
      expect(r.name, '好きなお菓子');
      expect(r.cost, 100);
      expect(r.createdAt, _now);
    });

    test('同じ名前でも追加できる', () async {
      await add('本', 100);
      await add('本', 200);
      expect((await repo.activeRewards()).length, 2);
    });

    test('不正な名前・ポイントは追加されない', () async {
      expect(await repo.addReward('', 100, _now), RewardResult.invalidName);
      expect(
        await repo.addReward('あ' * 31, 100, _now),
        RewardResult.invalidName,
      );
      expect(await repo.addReward('本', 0, _now), RewardResult.invalidCost);
      expect(await repo.addReward('本', 100000, _now), RewardResult.invalidCost);
      expect(await repo.activeRewards(), isEmpty);
    });

    test('名前30文字・ポイント1と99,999は追加できる', () async {
      expect(await repo.addReward('あ' * 30, 1, _now), RewardResult.ok);
      expect(await repo.addReward('b', 99999, _now), RewardResult.ok);
    });

    test('20件までで、21件目は上限エラー', () async {
      for (var i = 0; i < 20; i++) {
        await add('ご褒美$i', 10);
      }
      expect(await repo.addReward('21件目', 10, _now), RewardResult.limitReached);
      expect((await repo.activeRewards()).length, 20);
    });

    test('アーカイブした分は上限に数えない', () async {
      for (var i = 0; i < 20; i++) {
        await add('ご褒美$i', 10);
      }
      final first = (await repo.activeRewards()).first.id;
      await repo.archiveReward(first);
      expect(await repo.addReward('新しいご褒美', 10, _now), RewardResult.ok);
      expect((await repo.activeRewards()).length, 20);
    });

    test('同時に追加しても20件を超えない', () async {
      for (var i = 0; i < 18; i++) {
        await add('ご褒美$i', 10);
      }
      final results = await Future.wait([
        for (var i = 0; i < 6; i++) repo.addReward('同時$i', 10, _now),
      ]);
      expect(results.where((r) => r == RewardResult.ok).length, 2);
      expect(results.where((r) => r == RewardResult.limitReached).length, 4);
      expect((await repo.activeRewards()).length, 20);
    });
  });

  group('編集・アーカイブ', () {
    test('名前とポイントを変更できる', () async {
      final id = await add('本', 100);
      expect(await repo.updateReward(id, '漫画', 250), RewardResult.ok);
      final r = (await repo.activeRewards()).single;
      expect(r.name, '漫画');
      expect(r.cost, 250);
    });

    test('不正な値では変更されない', () async {
      final id = await add('本', 100);
      expect(await repo.updateReward(id, '', 100), RewardResult.invalidName);
      expect(await repo.updateReward(id, '本', 0), RewardResult.invalidCost);
      expect((await repo.activeRewards()).single.name, '本');
    });

    test('存在しない・アーカイブ済みは notFound', () async {
      expect(await repo.updateReward(999, '本', 100), RewardResult.notFound);
      final id = await add('本', 100);
      await repo.archiveReward(id);
      expect(await repo.updateReward(id, '本', 100), RewardResult.notFound);
    });

    test('アーカイブすると一覧から消え、2回目は notFound', () async {
      final id = await add('本', 100);
      expect(await repo.archiveReward(id), RewardResult.ok);
      expect(await repo.activeRewards(), isEmpty);
      expect(await repo.archiveReward(id), RewardResult.notFound);
      expect(await repo.archiveReward(999), RewardResult.notFound);
    });
  });

  group('交換と残高', () {
    test('記録も交換もなければ、累計・使用済み・残高はすべて0', () async {
      expect(await repo.totalEarned(), 0);
      expect(await repo.totalSpent(), 0);
      expect(await repo.balance(), 0);
    });

    test('残高 = 累計獲得 − 使用済み', () async {
      await _earn(records, 18, 13);
      await _earn(records, 19, 11);
      final id = await add('コーヒー', 10);
      expect(await repo.totalEarned(), 24);
      expect(await repo.redeem(id, _now), RewardResult.ok);
      expect(await repo.totalEarned(), 24); // 累計獲得は減らない
      expect(await repo.totalSpent(), 10);
      expect(await repo.balance(), 14);
    });

    test('残高ちょうどの交換は成功して残高0になる', () async {
      await _earn(records, 19, 100);
      final id = await add('本', 100);
      expect(await repo.redeem(id, _now), RewardResult.ok);
      expect(await repo.balance(), 0);
    });

    test('1ポイント不足なら失敗し、何も変わらない', () async {
      await _earn(records, 19, 99);
      final id = await add('本', 100);
      expect(await repo.redeem(id, _now), RewardResult.insufficientBalance);
      expect(await repo.balance(), 99);
      expect(await repo.redemptions(), isEmpty);
    });

    test('同じご褒美を何度でも交換できる(残高の範囲で)', () async {
      await _earn(records, 19, 100);
      final id = await add('コーヒー', 30);
      for (var i = 0; i < 3; i++) {
        expect(await repo.redeem(id, _now), RewardResult.ok);
      }
      expect(await repo.redeem(id, _now), RewardResult.insufficientBalance);
      expect(await repo.balance(), 10);
    });

    test('存在しない・アーカイブ済みのご褒美は交換できない', () async {
      await _earn(records, 19, 100);
      expect(await repo.redeem(999, _now), RewardResult.notFound);
      final id = await add('本', 10);
      await repo.archiveReward(id);
      expect(await repo.redeem(id, _now), RewardResult.notFound);
      expect(await repo.balance(), 100);
    });

    test('連打・同時実行でも残高がマイナスにならない(トランザクション)', () async {
      await _earn(records, 19, 30);
      final id = await add('コーヒー', 10);
      final results = await Future.wait([
        for (var i = 0; i < 10; i++) repo.redeem(id, _now),
      ]);
      expect(results.where((r) => r == RewardResult.ok).length, 3);
      expect(
        results.where((r) => r == RewardResult.insufficientBalance).length,
        7,
      );
      expect(await repo.balance(), 0);
      expect((await repo.redemptions()).length, 3);
    });

    test('記録が後から増えると残高も増える', () async {
      final id = await add('本', 50);
      expect(await repo.redeem(id, _now), RewardResult.insufficientBalance);
      await _earn(records, 19, 60);
      expect(await repo.redeem(id, _now), RewardResult.ok);
    });

    test('失敗した日(0pt)は残高に影響しない', () async {
      await records.insert(rec('2026-11-18', false));
      await _earn(records, 19, 20);
      expect(await repo.balance(), 20);
    });
  });

  group('交換履歴', () {
    test('新しい順に並び、交換時の名前・ポイント・日時が残る', () async {
      await _earn(records, 19, 100);
      final book = await add('本', 30);
      final coffee = await add('コーヒー', 10);
      await repo.redeem(book, DateTime(2026, 11, 20, 8, 0));
      await repo.redeem(coffee, DateTime(2026, 11, 21, 9, 0));
      final h = await repo.redemptions();
      expect(h.map((e) => e.rewardName), ['コーヒー', '本']);
      expect(h.first.cost, 10);
      expect(h.first.redeemedAt, DateTime(2026, 11, 21, 9, 0));
      expect(h.first.rewardId, coffee);
    });

    test('ご褒美を編集しても、過去の履歴の名前・ポイントは変わらない', () async {
      await _earn(records, 19, 100);
      final id = await add('本', 30);
      await repo.redeem(id, _now);
      await repo.updateReward(id, '漫画', 80);
      final h = (await repo.redemptions()).single;
      expect(h.rewardName, '本');
      expect(h.cost, 30);
      expect(await repo.totalSpent(), 30);
    });

    test('ご褒美をアーカイブしても、履歴と使用済みポイントは残る', () async {
      await _earn(records, 19, 100);
      final id = await add('本', 30);
      await repo.redeem(id, _now);
      await repo.archiveReward(id);
      expect((await repo.redemptions()).single.rewardName, '本');
      expect(await repo.totalSpent(), 30);
      expect(await repo.balance(), 70);
    });
  });
}
