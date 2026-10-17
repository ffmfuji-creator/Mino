import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ui.dart';

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
}

/// 设置页里的「账号」区块。
class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final muted = TextStyle(fontSize: 12, color: mutedColor(context));

    if (!s.cloudAvailable) {
      return Panel(
        child: Text('云同步尚未配置。填写 firebase_config.dart 后，即可使用账号登录和跨设备保存。',
            style: muted),
      );
    }

    final email = s.userEmail;
    if (email == null) {
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('登录后，任务、统计、经验和日子会自动保存到云端，换手机也能恢复。', style: muted),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => showAuthSheet(context, s),
                icon: const Icon(Icons.login),
                label: const Text('登录 / 注册'),
              ),
            ),
          ],
        ),
      );
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_circle,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(s.syncStatus.isEmpty ? '等待同步' : s.syncStatus, style: muted),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => s.syncNow(),
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('立即同步'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _signOut(context, s),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('退出登录'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _deleteAccount(context, s),
              child: const Text('删除账号和云端数据',
                  style: TextStyle(color: Color(0xFFF87171))),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, AppState s) async {
    final ok = await confirmDialog(
      context,
      '退出登录',
      '退出前会先把数据同步到云端，然后清空本机数据。再次登录即可恢复。',
      okText: '退出',
    );
    if (!ok) return;
    final err = await s.signOut();
    if (err != null && context.mounted) _toast(context, err);
  }

  Future<void> _deleteAccount(BuildContext context, AppState s) async {
    final ok = await confirmDialog(
      context,
      '删除账号',
      '账号和云端数据会被永久删除，无法恢复。',
      okText: '继续',
    );
    if (!ok || !context.mounted) return;
    final password = await _askPassword(context);
    if (password == null || password.isEmpty) return;
    final err = await s.deleteAccount(password);
    if (!context.mounted) return;
    _toast(context, err ?? '账号已删除');
  }

  Future<String?> _askPassword(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认密码'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: '当前密码'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('删除')),
        ],
      ),
    );
  }
}

Future<void> showAuthSheet(BuildContext context, AppState s) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _AuthSheet(state: s),
  );
}

class _AuthSheet extends StatefulWidget {
  const _AuthSheet({required this.state});
  final AppState state;

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = '请填写邮箱和密码');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final err = _register
        ? await widget.state.register(email, password)
        : await widget.state.signIn(email, password);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = '请先填写邮箱');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final err = await widget.state.resetPassword(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      _info = err == null ? '重置密码邮件已发送，请查收（也看看垃圾邮件）' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_register ? '注册账号' : '登录',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '邮箱',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _register ? '密码（至少 6 位）' : '密码',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!,
                    style: const TextStyle(color: Color(0xFFF87171))),
              ),
            if (_info != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_info!,
                    style: const TextStyle(color: Color(0xFF34D399))),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_register ? '注册并登录' : '登录'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _register = !_register;
                            _error = null;
                            _info = null;
                          }),
                  child: Text(_register ? '已有账号？去登录' : '没有账号？去注册'),
                ),
                if (!_register)
                  TextButton(
                      onPressed: _busy ? null : _forgot,
                      child: const Text('忘记密码')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
