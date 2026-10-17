import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ui.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tasks = s.sortedTasks;
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
                Text('已完成 $doneCount / ${tasks.length}',
                    style: TextStyle(color: mutedColor(context))),
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
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 16,
                          decoration:
                              task.done ? TextDecoration.lineThrough : null,
                          color: task.done ? mutedColor(context) : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: alpha(color, 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('优先级 ${priorityLabel(task.priority)}',
                                style: TextStyle(fontSize: 11, color: color)),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.timer_outlined,
                              size: 14, color: mutedColor(context)),
                          const SizedBox(width: 3),
                          Text('${task.pomodoros}',
                              style: TextStyle(
                                  fontSize: 12, color: mutedColor(context))),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!task.done)
                  IconButton(
                    tooltip: '设为当前任务',
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
  late Priority _priority;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.task?.title ?? '');
    _priority = widget.task?.priority ?? Priority.medium;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    final t = widget.task;
    if (t == null) {
      widget.state.addTask(title, _priority);
    } else {
      widget.state.updateTask(t, title: title, priority: _priority);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
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
            autofocus: true,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: '任务名称',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          const Text('优先级'),
          const SizedBox(height: 8),
          SegmentedButton<Priority>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<Priority>(value: Priority.low, label: Text('低')),
              ButtonSegment<Priority>(value: Priority.medium, label: Text('中')),
              ButtonSegment<Priority>(value: Priority.high, label: Text('高')),
            ],
            selected: {_priority},
            onSelectionChanged: (v) => setState(() => _priority = v.first),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: const Text('保存')),
          ),
        ],
      ),
    );
  }
}
