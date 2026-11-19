import 'package:characters/characters.dart';

/// ご褒美の名前の最大文字数。
const int maxRewardNameLength = 30;

/// ご褒美に必要なポイントの最小値。
const int minRewardCost = 1;

/// ご褒美に必要なポイントの最大値。
const int maxRewardCost = 99999;

/// 登録できる(アーカイブしていない)ご褒美の最大件数。
const int maxActiveRewards = 20;

/// ご褒美に関する操作の結果。
enum RewardResult {
  /// 成功した。
  ok,

  /// 名前が不正(空、または [maxRewardNameLength] 文字を超える)。
  invalidName,

  /// 必要ポイントが不正([minRewardCost]〜[maxRewardCost] の範囲外)。
  invalidCost,

  /// 登録数の上限([maxActiveRewards] 件)に達している。
  limitReached,

  /// 対象のご褒美が存在しない(または既にアーカイブされている)。
  notFound,

  /// ポイントの残高が足りない。
  insufficientBalance,
}

/// 登録されたご褒美。
class Reward {
  const Reward({
    required this.id,
    required this.name,
    required this.cost,
    required this.createdAt,
  });

  /// データベース上の識別子。
  final int id;

  /// 名前(前後の空白は取り除いてある)。
  final String name;

  /// 交換に必要なポイント。
  final int cost;

  /// 登録した日時。
  final DateTime createdAt;
}

/// ご褒美との交換の記録。
///
/// 名前とポイントは交換した時点の値を保存しているため、後でご褒美を
/// 編集・削除しても、履歴は変わらない。
class Redemption {
  const Redemption({
    required this.id,
    required this.rewardId,
    required this.rewardName,
    required this.cost,
    required this.redeemedAt,
  });

  /// 交換の識別子。
  final int id;

  /// 交換したご褒美の識別子(ご褒美が削除済みでも残る)。
  final int? rewardId;

  /// 交換時のご褒美の名前。
  final String rewardName;

  /// 交換で使ったポイント。
  final int cost;

  /// 交換した日時。
  final DateTime redeemedAt;
}

/// ご褒美の名前を整える(前後の空白を取り除く)。
String normalizeRewardName(String raw) => raw.trim();

/// ご褒美の名前と必要ポイントを検証する。問題がなければ `null`。
///
/// 名前は整えた後に1〜[maxRewardNameLength] 文字(絵文字・全角も1文字)、
/// 必要ポイントは [minRewardCost]〜[maxRewardCost]。
RewardResult? validateReward(String name, int cost) {
  final n = normalizeRewardName(name);
  if (n.isEmpty || n.characters.length > maxRewardNameLength) {
    return RewardResult.invalidName;
  }
  if (cost < minRewardCost || cost > maxRewardCost) {
    return RewardResult.invalidCost;
  }
  return null;
}

/// ポイントの残高(累計獲得 − 使用済み)。
int pointBalance({required int earned, required int spent}) => earned - spent;
