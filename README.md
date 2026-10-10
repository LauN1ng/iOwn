# iOwn

> 一个自己用的记账 App。用 SwiftUI 写，AI 辅助开发，边做边学 vibecoding。

## 这是什么

iOwn 是一个 iOS 记账应用。出发点很简单：市面的记账 App 都没解决我想要的东西——**记了流水，却不知道手里到底有多少钱**。

所以 iOwn 的核心是**资产视角**：账户余额随每笔记账自动推导，净资产、负债、可支配一目了然；再配上极速记账（两段式：意图宫格 → 四列键盘）、工资计时器、洞察报表。

## 特性

| 模块 | 说明 |
|------|------|
| **极速记账** | 两段式录入，≤3 秒记一笔；按日分组流水 + 心情标记 |
| **资产管理** | 手动建户（现金/银行卡/微信/支付宝/信用卡）→ 余额自动推导 → 净资产总览 |
| **负债与可支配** | 花呗/信用卡/白条分期建模，预测未来 12 个月可支配金额 |
| **洞察报表** | 分类占比、月度柱状图、日历热力格、心情账单 |
| **工资计时器** | 首页趣味卡，按秒显示"今天赚了多少" |

## 技术栈

- **SwiftUI** + **SwiftData**，部署目标 iOS 17.0，仅 iPhone 适配
- 工程用 **XcodeGen** 声明（`ios/project.yml`），仓库不存 `.xcodeproj`
- 纯本地存储，无账号、无网络、无广告

## 构建

代码在 Windows 上写，构建在 macOS 云端跑（GitHub Actions / Codemagic），产物是未签名 IPA，侧载真机。

```
Windows 改 Swift / project.yml
      │  git push
      ▼
CI（macOS）：xcodegen → 编译 → 模拟器截图 → 未签名 IPA
      ▼
下载 artifact → 侧载真机
```

本地构建（需 macOS + XcodeGen）：

```bash
cd ios
xcodegen generate
xcodebuild -project iOwn.xcodeproj -scheme iOwn \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## 目录

```
ios/project.yml          # XcodeGen 工程定义
ios/iOwn/
  App/                   # 入口 + RootTabView
  Models/                # SwiftData: Tx / Account / Liability
  Data/                  # 分类预设、洞察统计、节假日、工资配置
  Theme/                 # 颜色 / 圆角 token
  Features/              # Home / Add / Assets / Debt / Insight / Settings
  Resources/             # Assets.xcassets
.github/workflows/       # GitHub Actions 构建流水线
codemagic.yaml           # Codemagic 构建配置（备用通道）
```

## 说明

- 这是一个**个人学习项目**，不是商业产品。代码公开是为了记录和学习，不承诺维护。
- 仓库只包含 iOS 源码与构建配置；开发过程中的设计文档、原型、笔记不在其中。

## License

[MIT](LICENSE) © 2026 LauN1ng
