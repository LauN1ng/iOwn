import SwiftUI

// MARK: - 颜色 Token（视觉基准-自用风-v1 §2；废止湖青 #0E7490 体系）

enum Theme {
    static let bg     = Color(hex: 0xF7F7F5)   // 暖灰白底
    static let card   = Color.white            // 全部卡片
    static let green  = Color(hex: 0x3ABF58)   // 主绿（仅填充/图形）：FAB、净资产卡、选中态底色、按钮底
    static let greenSoft = Color(hex: 0xEAF7EC)
    static let greenDeep = Color(hex: 0x2FA34A) // 净资产卡渐变终（起 #3ABF58，绿色重卡统一主色）
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
enum Radius {
    static let large: CGFloat = 22
    static let medium: CGFloat = 16
    static let small: CGFloat = 12
    static let pagePadding: CGFloat = 18
    static let cardSpacing: CGFloat = 14
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
