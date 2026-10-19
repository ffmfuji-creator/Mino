import 'package:flutter/material.dart' hide Text;

import 'app_state.dart';
import 'i18n.dart';
import 'ui.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 截止日期的文字和颜色。
({String text, Color color}) _dueInfo(BuildContext context, TaskItem t) {
  final due = t.due;
  if (due == null) return (text: '', color: mutedColor(context));
  final days = _dateOnly(due).difference(_dateOnly(DateTime.now())).inDays;
  if (t.done) {
    return (text: '${due.month} 月 ${due.day} 日', color: mutedColor(context));
  }
  if (days < 0) return (text: '逾期 ${-days} 天', color: const Color(0xFFF87171));
  if (days == 0) return (text: '今天到期', color: const Color(0xFFFBBF24));
  if (days == 1) return (text: '明天到期', color: const Color(0xFFFBBF24));
  return (
    text: '${due.month} 月 ${due.day} 日',
    color: mutedColor(context),
  );
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String? _tag; // 当前筛选的标签，null = 全部

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tags = s.allTags;
    if (_tag != null && !tags.contains(_tag)) _tag = null;
    final all = s.sortedTasks;
    final tasks =
        _tag == null ? all : all.where((t) => t.tag == _tag).toList();
    final doneCount = s.tasksDoneTotal;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskEditor(context, s),
        icon: const Icon(Icons.add),
        label: const Text('新任务'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Row(
              children: [
                const Text('任务',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('已完成 $doneCount / ${all.length}',
                    style: TextStyle(color: mutedColor(context))),
              ],
            ),
          ),
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('全部'),
                    selected: _tag == null,
                    onSelected: (_) => setState(() => _tag = null),
                  ),
                  for (final g in tags)
                    ChoiceChip(
                      label: Text.verbatim(g),
                      selected: _tag == g,
                      onSelected: (_) => setState(() => _tag = g),
                    ),
                ],
              ),
            ),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Center(
                child: Text('还没有任务\n点右下角「新任务」开始',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: mutedColor(context), height: 1.6)),
              ),
            ),
          for (final t in tasks) _TaskTile(task: t, state: s),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.state});
  final TaskItem task;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final isActive = state.activeTaskId == task.id;
    final color = priorityColor(task.priority);
    final due = _dueInfo(context, task);
    final tag = task.tag;
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) =>
          confirmDialog(context, '删除任务', '确定删除「${task.title}」吗？', okText: '删除'),
      onDismissed: (_) => state.deleteTask(task),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: alpha(const Color(0xFFF87171), 0.25),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Color(0xFFF87171)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => showTaskEditor(context, state, task: task),
          child: Panel(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            glow: isActive ? Theme.of(context).colorScheme.primary : null,
            child: Row(
              children: [
                Checkbox(
                  value: task.done,
                  shape: const CircleBorder(),
                  onChanged: (_) => state.toggleTask(task),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.verbatim(
                        task.title,
                        style: TextStyle(
                          fontSize: 16,
                          decoration:
                              task.done ? TextDecoration.lineThrough : null,
                          color: task.done ? mutedColor(context) : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Chip(
                              text: '优先级 ${priorityLabel(task.priority)}',
                              color: color),
                          if (tag != null)
                            _Chip(
                                text: '# $tag',
                                color: Theme.of(context).colorScheme.secondary),
                          if (task.due != null)
                            _Chip(text: due.text, color: due.color),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined,
                                  size: 14, color: mutedColor(context)),
                              const SizedBox(width: 3),
                              Text(
                                task.focusSec > 0
                                    ? '${task.pomodoros} · ${hm(task.focusSec)}'
                                    : '${task.pomodoros}',
                                style: TextStyle(
                                    fontSize: 12, color: mutedColor(context)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!task.done)
                  IconButton(
                    tooltip: tr('设为当前任务'),
                    onPressed: () =>
                        state.setActiveTask(isActive ? null : task.id),
                    icon: Icon(
                      isActive ? Icons.play_circle : Icons.play_circle_outline,
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : mutedColor(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: alpha(color, 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

Future<void> showTaskEditor(BuildContext context, AppState s,
    {TaskItem? task}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _TaskEditor(state: s, task: task),
  );
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({required this.state, this.task});
  final AppState state;
  final TaskItem? task;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final TextEditingController _controller;
  late final TextEditingController _tagController;
  late Priority _priority;
  DateTime? _due;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.task?.title ?? '');
    _tagController = TextEditingController(text: widget.task?.tag ?? '');
    _priority = widget.task?.priority ?? Priority.medium;
    _due = widget.task?.due;
  }

  @override
  void dispose() {
    _controller.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final today = _dateOnly(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _due = _dateOnly(d));
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    final tag = _tagController.text.trim();
    final t = widget.task;
    if (t == null) {
      widget.state.addTask(title, _priority, due: _due, tag: tag);
    } else {
      widget.state.updateTask(t,
          title: title, priority: _priority, due: _due, tag: tag);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final tags = widget.state.allTags;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.task == null ? '新任务' : '编辑任务',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: widget.task == null,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: tr('任务名称'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            const Text('优先级'),
            const SizedBox(height: 8),
            SegmentedButton<Priority>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<Priority>(value: Priority.low, label: Text('低')),
                ButtonSegment<Priority>(
                    value: Priority.medium, label: Text('中')),
                ButtonSegment<Priority>(
                    value: Priority.high, label: Text('高')),
              ],
              selected: {_priority},
              onSelectionChanged: (v) => setState(() => _priority = v.first),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDue,
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(_due == null ? '截止日期（可选）' : dayKey(_due!)),
                  ),
                ),
                if (_due != null)
                  IconButton(
                    tooltip: tr('清除截止日期'),
                    onPressed: () => setState(() => _due = null),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagController,
              maxLength: 12,
              decoration: InputDecoration(
                labelText: tr('分类标签（可选）'),
                hintText: tr('例如：工作 / 学习 / 生活'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (tags.isNotEmpty)
              Wrap(
                spacing: 8,
                children: [
                  for (final g in tags)
                    ActionChip(
                      label: Text.verbatim(g),
                      onPressed: () => setState(() => _tagController.text = g),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('保存')),
            ),
          ],
        ),
      ),
    );
  }
}
