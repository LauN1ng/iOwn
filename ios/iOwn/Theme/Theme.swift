import SwiftUI

// MARK: - 颜色 Token（视觉基准-自用风-v1 §2；废止湖青 #0E7490 体系）

enum Theme {
    static let bg     = Color(hex: 0xF7F7F5)   // 暖灰白底
    static let card   = Color.white            // 全部卡片
    static let green  = Color(hex: 0x3ABF58)   // 主绿：FAB/金额一律绿（含支出，不评判）
    static let greenSoft = Color(hex: 0xEAF7EC)
    static let greenDeep = Color(hex: 0x2FA34A) // 净资产卡渐变终（起 #3ABF58，绿色重卡统一主色）
    static let red    = Color(hex: 0xF56358)   // 仅负债/超支/删除
    static let blue   = Color(hex: 0x4A8CF7)   // 仅跳转链接
    static let amber  = Color(hex: 0xF6B73C)   // 点缀/资产页 FAB
    static let iconBg = Color(hex: 0xEDEFEA)   // emoji 图标浅灰容器
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
