import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import 'app_state.dart';
import 'i18n.dart';
import 'ui.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  Color _phaseColor(BuildContext context, Phase p) {
    switch (p) {
      case Phase.focus:
        return Theme.of(context).colorScheme.primary;
      case Phase.shortBreak:
        return const Color(0xFF34D399);
      case Phase.longBreak:
        return const Color(0xFFA78BFA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final color = _phaseColor(context, s.phase);
    final running = s.status == RunStatus.running;
    final info = levelFor(s.xp);
    final task = s.activeTask;
    final statusText = running
        ? '${phaseLabel(s.phase)}中'
        : (s.status == RunStatus.paused ? '已暂停' : '准备开始');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Row(
          children: [
            const Text('Mino',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: alpha(Theme.of(context).colorScheme.primary, 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Lv.${info.level} ${levelTitle(info.level)}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<Phase>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment<Phase>(value: Phase.focus, label: Text('专注')),
            ButtonSegment<Phase>(value: Phase.shortBreak, label: Text('短休息')),
            ButtonSegment<Phase>(value: Phase.longBreak, label: Text('长休息')),
          ],
          selected: {s.phase},
          onSelectionChanged: running ? null : (v) => s.selectPhase(v.first),
        ),
        const SizedBox(height: 28),
        Center(
          child: SizedBox(
            width: 280,
            height: 280,
            child: CustomPaint(
              painter: _RingPainter(
                progress: s.progress,
                color: color,
                track: lineColor(context),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mmss(s.remaining),
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(statusText,
                        style: TextStyle(
                            color: color, letterSpacing: 2, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(s.settings.longEvery, (i) {
            final filled = s.phase == Phase.longBreak || i < s.focusInCycle;
            return Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? color : lineColor(context),
              ),
            );
          }),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.outlined(
              onPressed: s.resetCurrent,
              tooltip: tr('重置'),
              iconSize: 26,
              icon: const Icon(Icons.replay),
            ),
            const SizedBox(width: 24),
            IconButton.filled(
              onPressed: running ? s.pause : s.start,
              iconSize: 40,
              style: IconButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.black,
                minimumSize: const Size(84, 84),
              ),
              icon: Icon(running ? Icons.pause : Icons.play_arrow),
            ),
            const SizedBox(width: 24),
            IconButton.outlined(
              onPressed: s.skip,
              tooltip: tr('跳过'),
              iconSize: 26,
              icon: const Icon(Icons.skip_next),
            ),
          ],
        ),
        if (running && s.phase == Phase.focus && s.settings.dndTip)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Center(
              child: Text('专注中 · 建议打开手机「勿扰模式」，减少打扰',
                  style: TextStyle(fontSize: 12, color: mutedColor(context))),
            ),
          ),
        const SizedBox(height: 22),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _pickTask(context, s),
          child: Panel(
            glow: task == null ? null : color,
            child: Row(
              children: [
                Icon(Icons.flag_outlined, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('当前任务',
                          style: TextStyle(
                              fontSize: 12, color: mutedColor(context))),
                      const SizedBox(height: 2),
                      Text(
                        task == null ? '点击选择要专注的任务' : task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: mutedColor(context)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _GoalBar(),
        const _AmbientPanel(),
      ],
    );
  }

  void _pickTask(BuildContext context, AppState s) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final open = s.sortedTasks.where((t) => !t.done).toList();
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.link_off),
                title: const Text('不关联任务'),
                onTap: () {
                  s.setActiveTask(null);
                  Navigator.pop(ctx);
                },
              ),
              for (final t in open)
                ListTile(
                  leading:
                      Icon(Icons.circle, size: 12, color: priorityColor(t.priority)),
                  title: Text(t.title),
                  subtitle: Text('优先级 ${priorityLabel(t.priority)} · 已专注 ${t.pomodoros} 个番茄钟'),
                  onTap: () {
                    s.setActiveTask(t.id);
                    Navigator.pop(ctx);
                  },
                ),
              if (open.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('还没有待办任务，去「任务」页添加一个吧')),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 14;
    final rect = Rect.fromCircle(center: c, radius: r);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = track;
    canvas.drawCircle(c, r, trackPaint);

    final sweep = 2 * math.pi * math.min(1.0, math.max(0.0, progress));
    if (sweep <= 0) return;

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..color = alpha(color, 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, glow);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// 白噪音快捷选择：专注时播放，可调音量。
class _AmbientPanel extends StatelessWidget {
  const _AmbientPanel();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cur = s.settings.ambient;
    const kinds = <String, String>{
      'none': '无',
      'white': '白噪音',
      'brown': '棕噪音',
      'rain': '雨声',
    };
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.graphic_eq, size: 20, color: mutedColor(context)),
              const SizedBox(width: 8),
              Text('专注音效',
                  style: TextStyle(fontSize: 13, color: mutedColor(context))),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final e in kinds.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: cur == e.key,
                  onSelected: (_) => s.updateSettings((x) => x.ambient = e.key),
                ),
            ],
          ),
          if (cur != 'none')
            Row(
              children: [
                Icon(Icons.volume_down, size: 18, color: mutedColor(context)),
                Expanded(
                  child: Slider(
                    value: s.settings.ambientVolume.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: (v) =>
                        s.updateSettings((x) => x.ambientVolume = v.round()),
                  ),
                ),
                Icon(Icons.volume_up, size: 18, color: mutedColor(context)),
              ],
            ),
        ],
      ),
    );
  }
}

/// 今日专注目标进度条（目标为 0 时不显示）。
class _GoalBar extends StatelessWidget {
  const _GoalBar();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final goal = s.settings.dailyGoalMin;
    if (goal <= 0) return const SizedBox.shrink();
    final doneMin = s.statFor(DateTime.now()).focusSec ~/ 60;
    final value = math.min(1.0, doneMin / goal);
    final reached = doneMin >= goal;
    final color =
        reached ? const Color(0xFF34D399) : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.track_changes, size: 20, color: color),
                const SizedBox(width: 8),
                Text('今日目标',
                    style: TextStyle(fontSize: 13, color: mutedColor(context))),
                const Spacer(),
                Text('$doneMin / $goal 分钟',
                    style: TextStyle(fontWeight: FontWeight.w600, color: color)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                color: color,
                backgroundColor: lineColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
