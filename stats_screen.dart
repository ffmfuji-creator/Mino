import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import 'app_state.dart';
import 'i18n.dart';
import 'sessions_screen.dart';
import 'ui.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = s.statFor(now);
    final week = List<MapEntry<DateTime, DayStat>>.generate(7, (i) {
      final d = DateTime(now.year, now.month, now.day - (6 - i));
      return MapEntry(d, s.statFor(d));
    });
    final maxSec = week.fold<int>(0, (m, e) => math.max(m, e.value.focusSec));
    const labels = ['一', '二', '三', '四', '五', '六', '日'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text('统计',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ),
        Row(
          children: [
            Expanded(
              child: _Metric(
                  label: '今日专注',
                  value: hm(today.focusSec),
                  icon: Icons.timer,
                  color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Metric(
                  label: '今日番茄钟',
                  value: '${today.pomodoros} 个',
                  icon: Icons.local_fire_department,
                  color: const Color(0xFFFBBF24)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Metric(
                  label: '任务完成率',
                  value: '${(s.completionRate * 100).round()}%',
                  icon: Icons.task_alt,
                  color: const Color(0xFF34D399)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Metric(
                  label: '连续专注',
                  value: '${s.streak} 天',
                  icon: Icons.bolt,
                  color: const Color(0xFFA78BFA)),
            ),
          ],
        ),
        const SectionTitle('最近 7 天（分钟）'),
        Panel(
          child: SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < week.length; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          week[i].value.focusSec == 0
                              ? ''
                              : '${(week[i].value.focusSec / 60).round()}',
                          style: TextStyle(
                              fontSize: 11, color: mutedColor(context)),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 18,
                          height: maxSec == 0
                              ? 4.0
                              : math.max(
                                  4.0, 100.0 * week[i].value.focusSec / maxSec),
                          decoration: BoxDecoration(
                            color: i == week.length - 1
                                ? cs.primary
                                : alpha(cs.primary, 0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(labels[week[i].key.weekday - 1],
                            style: TextStyle(
                                fontSize: 12, color: mutedColor(context))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SectionTitle('累计'),
        Panel(
          child: Column(
            children: [
              _Line('累计专注时长', hm(s.totalFocusSec)),
              const SizedBox(height: 10),
              _Line('累计番茄钟', '${s.totalPomodoros} 个'),
              const SizedBox(height: 10),
              _Line('已完成任务', '${s.tasksDoneTotal} / ${s.tasks.length}'),
            ],
          ),
        ),
        if (_topTasks(s).isNotEmpty) ...[
          const SectionTitle('任务专注时长'),
          Panel(
            child: Column(
              children: [
                for (final t in _topTasks(s))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: _Line(t.title, hm(t.focusSec)),
                  ),
              ],
            ),
          ),
        ],
        const SectionTitle('最近专注'),
        Panel(
          child: s.sessions.isEmpty
              ? Text('还没有记录',
                  style: TextStyle(color: mutedColor(context)))
              : Column(
                  children: [
                    for (final x in s.sessionsNewestFirst.take(5))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Text(
                                '${dayKey(x.endedAt).substring(5)} ${x.endedAt.hour.toString().padLeft(2, '0')}:${x.endedAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                    fontSize: 12, color: mutedColor(context))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(x.taskTitle ?? '未关联任务',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text('${x.minutes} 分钟',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SessionsScreen()),
            ),
            child: const Text('查看全部记录'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text('仅完整结束的专注计入统计；跳过或重置不计入。',
              style: TextStyle(fontSize: 12, color: mutedColor(context))),
        ),
      ],
    );
  }
}

List<TaskItem> _topTasks(AppState s) {
  final list = s.tasks.where((t) => t.focusSec > 0).toList();
  list.sort((a, b) => b.focusSec.compareTo(a.focusSec));
  return list.take(5).toList();
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(value,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 12, color: mutedColor(context))),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: mutedColor(context))),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
