# ios/ —— iOwn iOS 工程

纯文本工程定义（XcodeGen），Windows 上不生成 .xcodeproj，一切构建在 GitHub Actions（见 `.github/workflows/ios-build.yml`）。

## 目录

```
project.yml          # 工程定义：目标 iOS 17.0 / 仅 iPhone / Swift v5 模式
iOwn/
  App/               # 入口 + RootTabView（4 Tab + FAB）
  Models/            # SwiftData：Tx / Account（Spec §4）
  Data/              # 分类预设表（六大消费意图 + 二级子项）
  Theme/             # 颜色/圆角 token（视觉基准 v1.1）
  Features/          # 6 屏：Home(线索) / AddSheet(M1) / Done(M1) / Assets / Insight / Settings
  Resources/         # Assets.xcassets（AccentColor=主绿 #3ABF58）
```

## 日常闭环

1. 改 `project.yml` 或 Swift 源码 → push 到 main
2. CI 跑完 → 下载 artifacts：截图（视觉核对）和 `unsigned-ipa`
3. 真机：Sideloadly + 免费 Apple ID 签名 unsigned-ipa → USB 装机（7 天重签）

Bundle ID：`com.iown.app`（免费 Apple ID 每天限 2 个 App ID，改包名会消耗额度）
