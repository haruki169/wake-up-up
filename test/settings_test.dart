// 設定(AppSettings と保存・読み込み)の単体テスト。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wake_up_up/data/settings_repository.dart';
import 'package:wake_up_up/domain/app_settings.dart';
import 'package:wake_up_up/domain/auto_advance.dart';
import 'package:wake_up_up/domain/wake_record.dart';

Future<PrefsSettingsRepository> _repo([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return PrefsSettingsRepository(await SharedPreferences.getInstance());
}

void main() {
  group('AppSettings', () {
    test('初期値', () {
      const s = AppSettings();
      expect(s.targetTime, const TargetTime(7, 0));
      expect(s.themeColorIndex, 0);
      expect(s.themeMode, AppThemeMode.system);
      expect(s.wakeLabel, '起きた');
      expect(s.wakeIconKey, 'none');
    });

    test('copyWith は指定した項目だけ変える', () {
      final s = const AppSettings().copyWith(themeColorIndex: 3);
      expect(s.themeColorIndex, 3);
      expect(s.targetTime, const TargetTime(7, 0));
    });

    test('同じ値なら等しい', () {
      expect(const AppSettings(), const AppSettings());
      expect(const AppSettings().hashCode, const AppSettings().hashCode);
      expect(
        const AppSettings() == const AppSettings(themeColorIndex: 1),
        isFalse,
      );
    });

    group('normalizeLabel', () {
      test(
        '前後の空白を取り除く',
        () => expect(AppSettings.normalizeLabel('  朝活  '), '朝活'),
      );
      test('空は初期値', () => expect(AppSettings.normalizeLabel(''), '起きた'));
      test('空白のみは初期値', () => expect(AppSettings.normalizeLabel('  　 '), '起きた'));
      test(
        '8文字までそのまま',
        () => expect(AppSettings.normalizeLabel('あいうえおかきく'), 'あいうえおかきく'),
      );
      test(
        '9文字目以降は切り捨て',
        () => expect(AppSettings.normalizeLabel('あいうえおかきくけ'), 'あいうえおかきく'),
      );
      test('絵文字も1文字と数える', () {
        expect(
          AppSettings.normalizeLabel('🌞🌞🌞🌞🌞🌞🌞🌞🌞'),
          '🌞🌞🌞🌞🌞🌞🌞🌞',
        );
        expect(AppSettings.normalizeLabel('👨‍👩‍👧家族起きた'), '👨‍👩‍👧家族起きた');
      });
    });
  });

  group('PrefsSettingsRepository', () {
    test('未保存なら初期値', () async {
      expect((await _repo()).load(), const AppSettings());
    });

    test('保存した設定を読み戻せる', () async {
      final repo = await _repo();
      const s = AppSettings(
        targetTime: TargetTime(5, 45),
        themeColorIndex: 4,
        themeMode: AppThemeMode.dark,
        wakeLabel: '朝活',
        wakeIconKey: 'rocket',
      );
      await repo.save(s);
      expect(repo.load(), s);
    });

    test('既存の目標時刻だけの保存値(旧形式)も読める', () async {
      final repo = await _repo({'target_time': '06:15'});
      expect(repo.load().targetTime, const TargetTime(6, 15));
      expect(repo.load().themeColorIndex, 0);
    });

    test('範囲外のテーマカラーは0に戻る', () async {
      expect((await _repo({'theme_color': 99})).load().themeColorIndex, 0);
      expect((await _repo({'theme_color': -1})).load().themeColorIndex, 0);
    });

    test('未知のテーマモード・アイコンは初期値に戻る', () async {
      final s = (await _repo({'theme_mode': 'sepia', 'wake_icon': 'unknown'}))
          .load();
      expect(s.themeMode, AppThemeMode.system);
      expect(s.wakeIconKey, 'none');
    });

    test('壊れた目標時刻は初期値に戻る', () async {
      for (final bad in ['abc', '25:00', '07:99', '', '7', '-1:30']) {
        expect(
          (await _repo({'target_time': bad})).load().targetTime,
          const TargetTime(7, 0),
          reason: bad,
        );
      }
    });

    test('保存済みの長すぎる文言は整えて読み込む', () async {
      final s = (await _repo({'wake_label': 'あいうえおかきくけこ'})).load();
      expect(s.wakeLabel, 'あいうえおかきく');
    });

    test('空の文言は初期値', () async {
      expect((await _repo({'wake_label': '  '})).load().wakeLabel, '起きた');
    });

    group('自動前倒し', () {
      test('初期値はオフ・7日・15分・最終目標 6:00', () async {
        expect((await _repo()).load().autoAdvance, const AutoAdvance());
      });

      test('保存した設定を読み戻せる', () async {
        final repo = await _repo();
        const a = AutoAdvance(
          enabled: true,
          days: 10,
          minutes: 30,
          goal: TargetTime(5, 30),
        );
        await repo.save(const AppSettings().copyWith(autoAdvance: a));
        expect(repo.load().autoAdvance, a);
      });

      test('選択肢にない日数・幅は初期値に戻る', () async {
        final a = (await _repo({'auto_days': 4, 'auto_minutes': 20}))
            .load()
            .autoAdvance;
        expect(a.days, 7);
        expect(a.minutes, 15);
      });

      test('壊れた最終目標・4:00より早い最終目標は初期値に戻る', () async {
        for (final bad in ['abc', '03:30', '25:00', '06:99', '']) {
          expect(
            (await _repo({'auto_goal': bad})).load().autoAdvance.goal,
            const TargetTime(6, 0),
            reason: bad,
          );
        }
      });

      test('4:00 ちょうどは有効', () async {
        expect(
          (await _repo({'auto_goal': '04:00'})).load().autoAdvance.goal,
          const TargetTime(4, 0),
        );
      });

      test('ほかの設定と一緒に保存しても影響し合わない', () async {
        final repo = await _repo();
        const s = AppSettings(
          targetTime: TargetTime(6, 45),
          themeColorIndex: 2,
          autoAdvance: AutoAdvance(enabled: true),
        );
        await repo.save(s);
        expect(repo.load(), s);
      });
    });
  });
}
