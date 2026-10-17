import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ui.dart';

class GrowthScreen extends StatelessWidget {
  const GrowthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final info = levelFor(s.xp);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text('成长',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ),
        Panel(
          glow: cs.primary,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Lv.${info.level}',
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: cs.primary)),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(levelTitle(info.level),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: info.into / info.need,
                  minHeight: 10,
                  backgroundColor: lineColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text('${info.into} / ${info.need} XP  ·  总计 ${s.xp} XP',
                  style: TextStyle(fontSize: 12, color: mutedColor(context))),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('每完成一个番茄钟获得「专注分钟数 × 2」XP；完成任务首次 +20 XP。',
              style: TextStyle(fontSize: 12, color: mutedColor(context))),
        ),
        SectionTitle(
            '成就  ${s.unlocked.length} / ${kAchievements.length}'),
        for (final a in kAchievements)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s.unlocked.contains(a.id)
                          ? alpha(cs.primary, 0.18)
                          : lineColor(context),
                    ),
                    child: Icon(a.icon,
                        color: s.unlocked.contains(a.id)
                            ? cs.primary
                            : mutedColor(context)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(a.desc,
                            style: TextStyle(
                                fontSize: 12, color: mutedColor(context))),
                      ],
                    ),
                  ),
                  Icon(
                    s.unlocked.contains(a.id)
                        ? Icons.check_circle
                        : Icons.lock_outline,
                    color: s.unlocked.contains(a.id)
                        ? const Color(0xFF34D399)
                        : mutedColor(context),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
