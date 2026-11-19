// ご褒美の検証・残高計算(reward.dart)の単体テスト。
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/domain/reward.dart';

void main() {
  group('validateReward', () {
    test('名前・ポイントが範囲内なら null', () {
      expect(validateReward('好きなお菓子', 100), isNull);
    });

    test('名前: 空・空白のみは不正', () {
      expect(validateReward('', 100), RewardResult.invalidName);
      expect(validateReward('   ', 100), RewardResult.invalidName);
      expect(validateReward('　 　', 100), RewardResult.invalidName);
    });

    test('名前: 30文字までは有効、31文字は不正', () {
      expect(validateReward('あ' * 30, 100), isNull);
      expect(validateReward('あ' * 31, 100), RewardResult.invalidName);
    });

    test('名前: 前後の空白は数えない', () {
      expect(validateReward('  ${'あ' * 30}  ', 100), isNull);
    });

    test('名前: 絵文字も1文字と数える', () {
      expect(validateReward('🍰' * 30, 100), isNull);
      expect(validateReward('🍰' * 31, 100), RewardResult.invalidName);
      expect(validateReward('👨‍👩‍👧' * 30, 100), isNull);
    });

    test('ポイント: 1〜99,999 は有効', () {
      expect(validateReward('a', 1), isNull);
      expect(validateReward('a', 99999), isNull);
    });

    test('ポイント: 0・負・100,000 以上は不正', () {
      expect(validateReward('a', 0), RewardResult.invalidCost);
      expect(validateReward('a', -1), RewardResult.invalidCost);
      expect(validateReward('a', 100000), RewardResult.invalidCost);
    });

    test('名前もポイントも不正なら名前を優先して報告する', () {
      expect(validateReward('', 0), RewardResult.invalidName);
    });
  });

  test('normalizeRewardName は前後の空白だけを取り除く', () {
    expect(normalizeRewardName('  好きな 本  '), '好きな 本');
  });

  test('pointBalance は 累計獲得 − 使用済み', () {
    expect(pointBalance(earned: 250, spent: 100), 150);
    expect(pointBalance(earned: 100, spent: 100), 0);
  });

  test('上限の定数', () {
    expect(maxRewardNameLength, 30);
    expect(maxRewardCost, 99999);
    expect(maxActiveRewards, 20);
  });
}
