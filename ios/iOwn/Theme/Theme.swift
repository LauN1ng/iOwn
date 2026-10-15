import SwiftUI

// MARK: - 颜色 Token（视觉基准-自用风-v1 §2；废止湖青 #0E7490 体系）

enum Theme {
    static let bg     = Color(hex: 0xF7F7F5)   // 暖灰白底
    static let card   = Color.white            // 全部卡片
    static let green  = Color(hex: 0x3ABF58)   // 主绿（仅填充/图形）：FAB、净资产卡、选中态底色、按钮底
    static let greenSoft = Color(hex: 0xEAF7EC)
    static let greenDeep = Color(hex: 0x2FA34A) // 净资产卡渐变终（起 #3ABF58，绿色重卡统一主色）

    // MARK: 立体主按钮专用（2026-10-15 · D5）—— 只服务「绿色主按钮」的 Fluent 3D 质感，
    // 光源假想在正上方：上表面受光（greenTop）→ 背光（greenDeep）→ 底缘再压一层暗唇（greenLip）。
    // ⚠️ 不要拿去当文字色或一般填充色，语义仅限「立体按钮的受光面 / 暗唇」。
    static let greenTop  = Color(hex: 0x5AD377) // 立体按钮：顶部受光面（比主绿亮）
    static let greenLip  = Color(hex: 0x23833A) // 立体按钮：底部暗唇 + 同色环境投影
    static let red    = Color(hex: 0xF56358)   // 红（仅填充/图形：⌫ 键底等）
    static let blue   = Color(hex: 0x4A8CF7)   // 蓝（仅填充/图形）
    static let amber  = Color(hex: 0xF6B73C)   // 点缀/资产页 FAB
    static let iconBg = Color(hex: 0xEDEFEA)   // emoji 图标浅灰容器

    // MARK: 文字档（v1.4 拆 token，见 UI评审 §3.1）
    // 亮色 #3ABF58 当**文字**只有 2.39:1，连大字门槛 3:1 都不到（AA 正文需 4.5:1）。
    // 所以「文字」用途一律改用下面这组同色相、加深后的色值；填充/图形继续用上面的亮色。
    // 实测（白卡底）：greenText 5.40:1 / redText 5.44:1 / blueText 5.43:1，全部达 AA。
    // ⚠️ 白字压在亮绿上（保存按钮/选中胶囊/净资产卡/FAB）仍是 2.39:1 —— 已定案保留，属已知取舍。
    static let greenText = Color(hex: 0x1E7A33)
    static let redText   = Color(hex: 0xC0392B)
    static let blueText  = Color(hex: 0x1D64D8)

    // 状态/构件色（v1.3 收敛原散落在各视图里的硬编码色值）
    static let grabber     = Color(hex: 0xD9DDD6)  // sheet 自绘把手
    static let disabled    = Color(hex: 0xE3E6E0)  // 禁用按钮底色
    static let disabledText = Color(hex: 0xAEB4AC) // 禁用按钮文字
    static let dangerSoft  = Color(hex: 0xFDECEB)  // ⌫ 键底（红系浅底）
    static let hairline    = Color(hex: 0xECEEEA)  // 极细分隔线
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// 形状 token（视觉基准 §3）：大卡 22 / 中 16 / 小 12
// 2026-10-15（D5）：原仓内实测 **9 种圆角数值**、token 命中率约 54% → 收敛为下面 5 档 + 胶囊，
// 全部走 `.continuous` 曲线（见 `View.corner(_:)`）。
// **归并规则 = 就近归并**（记在方案文档顶部表）：
//   5 / 6 / 7 / 8 / 9 → `micro 8`（小芯片 / 图标底 / 输入格 / 品牌小方块）
//   11 / 12           → `small 12`（iconBg 容器 / 小件）
//   14                → `control 14`（主按钮 / 次级按钮）
//   999               → `capsule`
enum Radius {
    static let large: CGFloat = 22
    static let medium: CGFloat = 16
    /// 主按钮 / 次级按钮（2026-10-15 · D5 立为 token）：绿色主按钮 6 处一致用 14，
    /// 已形成事实上的第二套令牌；**首个消费者 = `Green3DBackground` 默认值**
    static let control: CGFloat = 14
    static let small: CGFloat = 12
    /// 微型件：小芯片 / 图标底 / 输入格 / 品牌小方块
    static let micro: CGFloat = 8
    /// 全药丸
    static let capsule: CGFloat = 999
    static let pagePadding: CGFloat = 18
    static let cardSpacing: CGFloat = 14
}

// MARK: - 阴影 token（2026-10-15 · D5）
//
// 全仓原先 **零 token、7 处各异**（5 个纯黑 opacity 0.12/0.07/0.05/0.04/0.04 无规律）。
// 收敛为 **2 档 elevation + 2 档 glow**，其余一律不加阴影（靠明度分层）。
// 用法：`.shadowStyle(Elevation.e1)` / `.shadowStyle(Glow.green)`（见 `DesignSystem.swift`）。

/// 一档阴影的具体参数
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
}

enum Elevation {
    /// 常规白卡：**不加阴影**（不写修饰符即可；此档仅为语义完整，`radius == 0` 时修饰符是空操作）
    static let e0 = ShadowStyle(color: .clear, radius: 0, y: 0)
    /// 可点卡 / 内嵌卡（几乎不可见，只为「浮起 1px」）
    static let e1 = ShadowStyle(color: .black.opacity(0.04), radius: 3, y: 1)
    /// 悬浮物（**预留 · 当前无消费者**）：原消费者 FAB / 转账胶囊已改由
    /// `Green3DBackground` 的同色投影承担，此处保留档位以备后续悬浮物复用
    static let e2 = ShadowStyle(color: .black.opacity(0.12), radius: 8, y: 4)
}

enum Glow {
    /// 成功屏辉光（**仅** `SuccessOverlay`，不参与 elevation 阶梯）
    static let green = ShadowStyle(color: Theme.green.opacity(0.42), radius: 17, y: 14)
    /// 立体主按钮底的同色投影（**仅** `Green3DBackground`）
    static let greenSoft = ShadowStyle(color: Theme.greenLip.opacity(0.32), radius: 5, y: 3)
}

// MARK: - 动效 token（视觉基准 v1.3 §6）
// 统一命名与参数，避免各视图随手写 `.easeOut(duration:)` 造成节奏不一致。
// 参数取自 Apple「响应 / 阻尼比」两参数模型（apple-design §4）：
//   damping 1.0 = 不超调；仅当手势本身带惯性时降到 ~0.8 给一点回弹。

enum Motion {
    /// 按压反馈：轻微下压 + 快速回弹（所有可点元素共用）
    static let press = Animation.spring(response: 0.28, dampingFraction: 0.70)
    /// 阶段推进：宫格 ↔ 金额（位移转场，可被中途打断）
    static let stage = Animation.spring(response: 0.34, dampingFraction: 0.86)
    /// 成功勾 pop：此处允许一点弹性（首次/低频场景，为「达成感」服务）
    static let successPop = Animation.spring(response: 0.42, dampingFraction: 0.66)
    /// 展开 / 收起（账户组等）
    static let disclosure = Animation.spring(response: 0.32, dampingFraction: 0.88)
    /// 淡入淡出
    static let fade = Animation.easeOut(duration: 0.22)
    /// 减弱动效时的替代（位移/弹性一律退化为短淡入）
    static let reduceFallback = Animation.easeOut(duration: 0.20)
}
