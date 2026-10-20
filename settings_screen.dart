import 'package:flutter/material.dart' hide Text;

import 'account_ui.dart';
import 'app_state.dart';
import 'export_service.dart';
import 'i18n.dart';
import 'ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final st = s.settings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Text('设置',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ),
        const SectionTitle('账号'),
        const AccountSection(),
        const SectionTitle('时长（分钟）'),
        Panel(
          child: Column(
            children: [
              _SliderRow(
                label: '专注',
                value: st.focusMin,
                min: 1,
                max: 90,
                onChanged: (v) => s.updateSettings((x) => x.focusMin = v),
              ),
              _SliderRow(
                label: '短休息',
                value: st.shortMin,
                min: 1,
                max: 30,
                onChanged: (v) => s.updateSettings((x) => x.shortMin = v),
              ),
              _SliderRow(
                label: '长休息',
                value: st.longMin,
                min: 5,
                max: 60,
                onChanged: (v) => s.updateSettings((x) => x.longMin = v),
              ),
              _SliderRow(
                label: '长休息间隔（个番茄钟）',
                value: st.longEvery,
                min: 2,
                max: 8,
                onChanged: (v) => s.updateSettings((x) => x.longEvery = v),
              ),
              _SliderRow(
                label: '每日专注目标（分钟，0 = 关闭）',
                value: st.dailyGoalMin,
                min: 0,
                max: 480,
                step: 10,
                onChanged: (v) => s.updateSettings((x) => x.dailyGoalMin = v),
              ),
            ],
          ),
        ),
        const SectionTitle('行为与提醒'),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('自动切换下一阶段'),
                subtitle: const Text('专注与休息结束后自动开始下一段'),
                value: st.autoStart,
                onChanged: (v) => s.updateSettings((x) => x.autoStart = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('提示音'),
                subtitle: const Text('应用内和后台通知都会使用'),
                value: st.sound,
                onChanged: (v) => s.updateSettings((x) => x.sound = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('振动'),
                value: st.vibrate,
                onChanged: (v) => s.updateSettings((x) => x.vibrate = v),
              ),
            ],
          ),
        ),
        const SectionTitle('专注体验'),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('计时中保持屏幕常亮'),
                value: st.keepAwake,
                onChanged: (v) => s.updateSettings((x) => x.keepAwake = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('白噪音只在专注时播放'),
                subtitle: const Text('关闭后，休息时也会继续播放（音效在「专注」页选择）'),
                value: st.ambientOnlyFocus,
                onChanged: (v) =>
                    s.updateSettings((x) => x.ambientOnlyFocus = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('中途结束也计入专注时长'),
                subtitle: const Text('重置或跳过时，已专注满 1 分钟的部分会计入时长（不算番茄钟、没有经验）'),
                value: st.countPartial,
                onChanged: (v) => s.updateSettings((x) => x.countPartial = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('专注时提示开启勿扰模式'),
                value: st.dndTip,
                onChanged: (v) => s.updateSettings((x) => x.dndTip = v),
              ),
            ],
          ),
        ),
        const SectionTitle('外观'),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('深色主题'),
            value: st.darkMode,
            onChanged: (v) => s.updateSettings((x) => x.darkMode = v),
          ),
        ),
        const SectionTitle('语言 / Language'),
        Panel(
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<String>(value: 'auto', label: Text('自动')),
                ButtonSegment<String>(value: 'zh', label: Text('中文')),
                ButtonSegment<String>(value: 'en', label: Text('English')),
              ],
              selected: {st.language},
              onSelectionChanged: (v) =>
                  s.updateSettings((x) => x.language = v.first),
            ),
          ),
        ),
        const SectionTitle('数据'),
        OutlinedButton.icon(
          onPressed: () async {
            final err = await ExportService.exportAll(s);
            if (err != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(err), behavior: SnackBarBehavior.floating),
              );
            }
          },
          icon: const Icon(Icons.ios_share),
          label: const Text('导出为表格（CSV）'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final ok = await confirmDialog(
                context, '清除所有数据', '任务、统计、经验和设置都会被清空，且无法恢复。',
                okText: '清除');
            if (ok) await s.resetAll();
          },
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('清除所有数据'),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text('Mino v0.6.0',
              style: TextStyle(fontSize: 12, color: mutedColor(context))),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });
  final int step;
  final String label;
  final int value;
  final int min;
  final int max;
  final void Function(int v) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label),
            const Spacer(),
            Text('$value',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary)),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: (max - min) ~/ step,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
