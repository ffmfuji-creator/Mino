# Mino v0.6.0

Flutter 专注计时应用（番茄钟 + 任务 + 统计 + 成长）。

## 文件说明（扁平结构，方便在手机上传到 GitHub）
- pubspec.yaml — 依赖配置（仅 shared_preferences）
- main.dart — 入口、主题、底部导航
- app_state.dart — 数据模型、计时核心、持久化、等级/成就
- ui.dart — 通用组件与主题
- firebase_config.dart — 填写 Firebase 配置（未填则只有本地模式）
- cloud_sync.dart — Firebase 登录与 Firestore 读写
- notifier.dart — 后台结束提醒（本地通知）
- patch_android.py — 构建时补齐安卓权限/签名/兼容配置
- make_icon.py — 构建时生成应用图标、启动页和通知小图标
- make_sounds.py — 构建时生成白噪音（白/棕/雨声）和结束提示音
- effects.dart — 白噪音播放、屏幕常亮
- export_service.dart — 导出 CSV 表格并分享
- i18n.dart / i18n_en.dart — 中英文界面（词典：i18n_en.dart）
- sessions_screen.dart — 专注记录列表
- app_test.dart — 单元测试（日期计算、等级、翻译；工作流会自动运行）
- account_ui.dart — 登录/注册界面与设置页账号区块
- timer_screen / tasks_screen / stats_screen / growth_screen / moments_screen / settings_screen — 六个页面（moments = 纪念日与倒数日）
- .github/workflows/build-android.yml — 云端构建 APK

GitHub Actions 构建时会自动运行 `flutter create` 生成 android/ios 目录，并把根目录的 *.dart 移入 lib/。

## 在电脑上本地运行
```
flutter create --project-name mino --org com.mino --platforms=android,ios .
mkdir -p lib && mv -f *.dart lib/
rm -rf test analysis_options.yaml
flutter pub get
flutter run
```

## 已知限制（v0.1.0）
- 应用在后台被系统冻结时，不会有系统通知提醒（回到前台会立即校准并触发提醒）。v0.2 计划接入 flutter_local_notifications。
- v0.2.0 起已移除广告位。
- 源码未经真实 Flutter 编译验证。
