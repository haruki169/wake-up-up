import 'package:sqflite/sqflite.dart';

import '../domain/reward.dart';

/// ご褒美・交換・ポイント残高の保存先を抽象化したリポジトリ。
abstract class RewardRepository {
  /// アーカイブしていないご褒美を、登録順に返す。
  Future<List<Reward>> activeRewards();

  /// ご褒美を追加する。
  ///
  /// 名前・必要ポイントが不正なら [RewardResult.invalidName] /
  /// [RewardResult.invalidCost]、登録数が上限なら [RewardResult.limitReached]。
  Future<RewardResult> addReward(String name, int cost, DateTime now);

  /// ご褒美の名前と必要ポイントを変更する。過去の交換履歴は変わらない。
  ///
  /// 存在しない(またはアーカイブ済み)なら [RewardResult.notFound]。
  Future<RewardResult> updateReward(int id, String name, int cost);

  /// ご褒美をアーカイブする(一覧から消える。交換履歴は残る)。
  Future<RewardResult> archiveReward(int id);

  /// ご褒美とポイントを交換する。
  ///
  /// 残高の確認と記録を1つのトランザクションで行うため、残高がマイナスに
  /// なることはない。残高が足りなければ [RewardResult.insufficientBalance]。
  Future<RewardResult> redeem(int rewardId, DateTime now);

  /// 交換の履歴を新しい順に返す。
  Future<List<Redemption>> redemptions();

  /// これまでに獲得したポイントの合計(累計獲得)。
  Future<int> totalEarned();

  /// 交換に使ったポイントの合計(使用済み)。
  Future<int> totalSpent();

  /// ポイントの残高(累計獲得 − 使用済み)。
  Future<int> balance();
}

/// SQLite に保存する [RewardRepository] の実装。
class SqliteRewardRepository implements RewardRepository {
  SqliteRewardRepository(this._db);

  final Database _db;

  static Reward _toReward(Map<String, Object?> m) => Reward(
    id: m['id'] as int,
    name: m['name'] as String,
    cost: m['cost'] as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
  );

  /// 累計獲得(`wake_records` の獲得ポイントの合計)。
  static Future<int> _earned(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(points), 0) AS v FROM wake_records',
    );
    return rows.first['v'] as int;
  }

  /// 使用済み(`redemptions` の使用ポイントの合計)。
  static Future<int> _spent(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(cost), 0) AS v FROM redemptions',
    );
    return rows.first['v'] as int;
  }

  @override
  Future<List<Reward>> activeRewards() async {
    final rows = await _db.query(
      'rewards',
      where: 'archived = 0',
      orderBy: 'id ASC',
    );
    return rows.map(_toReward).toList();
  }

  @override
  Future<RewardResult> addReward(String name, int cost, DateTime now) async {
    final invalid = validateReward(name, cost);
    if (invalid != null) return invalid;
    return _db.transaction((txn) async {
      final count = Sqflite.firstIntValue(
        await txn.rawQuery('SELECT COUNT(*) FROM rewards WHERE archived = 0'),
      )!;
      if (count >= maxActiveRewards) return RewardResult.limitReached;
      await txn.insert('rewards', {
        'name': normalizeRewardName(name),
        'cost': cost,
        'archived': 0,
        'created_at': now.millisecondsSinceEpoch,
      });
      return RewardResult.ok;
    });
  }

  @override
  Future<RewardResult> updateReward(int id, String name, int cost) async {
    final invalid = validateReward(name, cost);
    if (invalid != null) return invalid;
    final changed = await _db.update(
      'rewards',
      {'name': normalizeRewardName(name), 'cost': cost},
      where: 'id = ? AND archived = 0',
      whereArgs: [id],
    );
    return changed == 0 ? RewardResult.notFound : RewardResult.ok;
  }

  @override
  Future<RewardResult> archiveReward(int id) async {
    final changed = await _db.update(
      'rewards',
      {'archived': 1},
      where: 'id = ? AND archived = 0',
      whereArgs: [id],
    );
    return changed == 0 ? RewardResult.notFound : RewardResult.ok;
  }

  @override
  Future<RewardResult> redeem(int rewardId, DateTime now) {
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'rewards',
        where: 'id = ? AND archived = 0',
        whereArgs: [rewardId],
      );
      if (rows.isEmpty) return RewardResult.notFound;
      final reward = _toReward(rows.first);
      final balance = pointBalance(
        earned: await _earned(txn),
        spent: await _spent(txn),
      );
      if (balance < reward.cost) return RewardResult.insufficientBalance;
      await txn.insert('redemptions', {
        'reward_id': reward.id,
        'reward_name': reward.name,
        'cost': reward.cost,
        'redeemed_at': now.millisecondsSinceEpoch,
      });
      return RewardResult.ok;
    });
  }

  @override
  Future<List<Redemption>> redemptions() async {
    final rows = await _db.query('redemptions', orderBy: 'id DESC');
    return rows
        .map(
          (m) => Redemption(
            id: m['id'] as int,
            rewardId: m['reward_id'] as int?,
            rewardName: m['reward_name'] as String,
            cost: m['cost'] as int,
            redeemedAt: DateTime.fromMillisecondsSinceEpoch(
              m['redeemed_at'] as int,
            ),
          ),
        )
        .toList();
  }

  @override
  Future<int> totalEarned() => _earned(_db);

  @override
  Future<int> totalSpent() => _spent(_db);

  @override
  Future<int> balance() async =>
      pointBalance(earned: await _earned(_db), spent: await _spent(_db));
}
