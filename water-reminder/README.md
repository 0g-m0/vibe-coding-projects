# 💧 Water Reminder

一个 macOS 菜单栏健康提醒小工具，定时通知你喝水、站立、上厕所。支持自定义提醒项、间隔、文案，以及"开会模式"一键静默。

## 功能

- 🚰 菜单栏常驻，一目了然当前提醒状态
- 💧 自定义提醒项（名称、emoji、间隔分钟数、提示文案）
- 🎤 开会模式：一键静默所有通知，适合投屏/演示
- 🔔 系统原生通知，支持唤醒/睡眠后自动恢复
- ⚙️ 偏好设置面板（SwiftUI）

## 环境要求

- macOS 13.0+
- Apple Silicon（编译 target 为 `arm64-apple-macos13`）

## 编译运行

```bash
./build.sh
```

脚本会编译源码、打包成 `WaterReminder.app`、ad-hoc 签名并自动打开。

## 目录结构

```
water-reminder/
├── WaterReminderApp.swift   # App 入口
├── AppDelegate.swift        # 菜单栏、定时器、通知逻辑
├── RemindersStore.swift     # 数据存储（UserDefaults）
├── SettingsView.swift       # 偏好设置面板
├── Info.plist
└── build.sh                 # 编译脚本
```

## License

[MIT](./LICENSE) © 0g-m0
