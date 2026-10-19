import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as m;

import 'i18n_en.dart';

/// 界面语言。设置里选「自动 / 中文 / English」。
class I18n {
  static String lang = 'zh'; // 实际生效的语言：zh 或 en
  static final ValueNotifier<int> rev = ValueNotifier<int>(0);

  static bool get isEn => lang == 'en';

  /// setting：auto / zh / en。
  static void apply(String setting) {
    String resolved;
    if (setting == 'zh' || setting == 'en') {
      resolved = setting;
    } else {
      resolved =
          PlatformDispatcher.instance.locale.languageCode == 'zh' ? 'zh' : 'en';
    }
    if (resolved != lang) {
      lang = resolved;
      rev.value++;
    }
  }
}

final RegExp _cjk = RegExp(r'[\u4e00-\u9fff]');

class _Pat {
  _Pat(String re, this.template) : re = RegExp(re);
  final RegExp re;
  final String template;

  String render(Match match) {
    return template.replaceAllMapped(RegExp(r'([\$%])(\d)'), (x) {
      final g = match.group(int.parse(x.group(2)!)) ?? '';
      return x.group(1) == '%' ? _toEn(g) : g;
    });
  }
}

final List<_Pat> _patterns = [for (final p in kEnPatterns) _Pat(p[0], p[1])];

/// 兜底：把字符串里能认出的中文词按词典逐个替换（长词优先）。
final List<String> _segKeys = () {
  final keys = kEn.keys
      .where((k) => _cjk.hasMatch(k) && !k.contains('\n'))
      .where((k) => k.length >= 2 || '天时分秒低中高'.contains(k))
      .toList();
  keys.sort((a, b) => b.length.compareTo(a.length));
  return keys;
}();

String _toEn(String zh) {
  if (!_cjk.hasMatch(zh)) return zh;
  final exact = kEn[zh];
  if (exact != null) return exact;
  for (final p in _patterns) {
    final match = p.re.firstMatch(zh);
    if (match != null) return p.render(match);
  }
  var out = zh;
  for (final k in _segKeys) {
    if (out.contains(k)) out = out.replaceAll(k, ' ${kEn[k]} ');
  }
  return out.replaceAll(RegExp(r' {2,}'), ' ').trim();
}

/// 翻译一段界面文字：中文界面原样返回，英文界面返回英文。
String tr(String zh) => I18n.isEn ? _toEn(zh) : zh;

/// 语言切换时让依赖它的组件重建（包括 const 组件）。
class I18nScope extends m.InheritedNotifier<ValueNotifier<int>> {
  I18nScope({super.key, required super.child}) : super(notifier: I18n.rev);

  static void watch(m.BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<I18nScope>();
  }
}

/// 替代 Flutter 的 Text：显示前按当前语言翻译。
/// 用户自己输入的内容（任务名、日子名）请用 Text.verbatim，不做翻译。
class Text extends m.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  }) : verbatim = false;

  const Text.verbatim(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  }) : verbatim = true;

  final String data;
  final bool verbatim;
  final m.TextStyle? style;
  final m.TextAlign? textAlign;
  final int? maxLines;
  final m.TextOverflow? overflow;
  final bool? softWrap;

  @override
  m.Widget build(m.BuildContext context) {
    I18nScope.watch(context);
    return m.Text(
      verbatim ? data : tr(data),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}
