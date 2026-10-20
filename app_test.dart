import 'package:flutter_test/flutter_test.dart';
import 'package:mino/app_state.dart';
import 'package:mino/i18n.dart';

void main() {
  group('calendarDiff', () {
    test('整年整月整天', () {
      expect(calendarDiff(DateTime(2025, 1, 1), DateTime(2026, 3, 5)), [1, 2, 4]);
    });
    test('月底不会算出负数天', () {
      expect(calendarDiff(DateTime(2025, 1, 31), DateTime(2025, 3, 1)), [0, 1, 1]);
    });
    test('当天时间没到不算满一天', () {
      expect(
        calendarDiff(DateTime(2025, 1, 1, 12), DateTime(2025, 1, 2, 11)),
        [0, 0, 0],
      );
    });
    test('闰日到下一年平年的月底刚好满一年', () {
      expect(calendarDiff(DateTime(2024, 2, 29), DateTime(2025, 2, 28)), [1, 0, 0]);
    });
    test('结束早于开始返回 0', () {
      expect(calendarDiff(DateTime(2026, 1, 1), DateTime(2025, 1, 1)), [0, 0, 0]);
    });
  });

  group('momentTarget', () {
    Moment m(DateTime t, {bool yearly = false}) =>
        Moment(id: 'x', title: 't', time: t, yearly: yearly);

    test('不重复：就是它自己', () {
      expect(momentTarget(m(DateTime(2025, 1, 1)), DateTime(2026, 10, 20)),
          DateTime(2025, 1, 1));
    });
    test('每年重复：指向下一次', () {
      expect(
        momentTarget(m(DateTime(2020, 3, 10, 10), yearly: true), DateTime(2026, 10, 20)),
        DateTime(2027, 3, 10, 10),
      );
    });
    test('每年重复：今年还没到', () {
      expect(
        momentTarget(m(DateTime(2020, 3, 10, 10), yearly: true), DateTime(2026, 3, 1)),
        DateTime(2026, 3, 10, 10),
      );
    });
    test('2 月 29 日在平年落到 2 月 28 日', () {
      expect(
        momentTarget(m(DateTime(2024, 2, 29), yearly: true), DateTime(2026, 10, 20)),
        DateTime(2027, 2, 28),
      );
    });
    test('2 月 29 日遇到闰年仍是 29 日', () {
      expect(
        momentTarget(m(DateTime(2024, 2, 29), yearly: true), DateTime(2027, 10, 20)),
        DateTime(2028, 2, 29),
      );
    });
    test('第一次发生在未来：指向它', () {
      expect(
        momentTarget(m(DateTime(2030, 5, 1), yearly: true), DateTime(2026, 10, 20)),
        DateTime(2030, 5, 1),
      );
    });
  });

  test('levelFor 等级曲线', () {
    expect(levelFor(0).level, 1);
    expect(levelFor(99).level, 1);
    expect(levelFor(100).level, 2);
    expect(levelFor(100).into, 0);
    expect(levelFor(249).level, 2);
    expect(levelFor(250).level, 3);
  });

  group('数据往返', () {
    test('TaskItem', () {
      final t = TaskItem(
        id: '1',
        title: 'a',
        due: DateTime(2026, 1, 2),
        tag: '工作',
        focusSec: 90,
      );
      final r = TaskItem.fromJson(t.toJson());
      expect(r.tag, '工作');
      expect(r.focusSec, 90);
      expect(r.due, DateTime(2026, 1, 2));
    });
    test('Settings', () {
      final s = Settings()
        ..dailyGoalMin = 30
        ..ambient = 'rain'
        ..countPartial = false;
      final r = Settings.fromJson(s.toJson());
      expect(r.dailyGoalMin, 30);
      expect(r.ambient, 'rain');
      expect(r.countPartial, false);
    });
    test('Session 的 partial 字段', () {
      final s = Session(
          id: '1', endedAt: DateTime(2026, 1, 1, 8), minutes: 7, partial: true);
      expect(Session.fromJson(s.toJson()).partial, true);
    });
  });

  group('翻译', () {
    setUp(() => I18n.apply('en'));
    tearDown(() => I18n.apply('zh'));

    test('整句词典', () {
      expect(tr('专注'), 'Focus');
    });
    test('带数字的句式', () {
      expect(tr('3 个 · 75 分钟'), '3 sessions · 75 min');
      expect(tr('已完成 3 / 10'), 'Done 3 / 10');
      expect(tr('优先级 高'), 'Priority: High');
      expect(tr('75 / 100 分钟'), '75 / 100 min');
    });
    test('没有中文的内容原样返回', () {
      expect(tr('Lv.3'), 'Lv.3');
    });
    test('中文界面不翻译', () {
      I18n.apply('zh');
      expect(tr('专注'), '专注');
    });
  });
}
