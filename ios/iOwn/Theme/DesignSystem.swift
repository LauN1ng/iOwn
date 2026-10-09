import SwiftUI
import UIKit

// MARK: - 按压反馈（emil-design-eng：按钮必须在「按下瞬间」给出反馈，不是松手时）

/// 按下即缩小、松手回弹。用于所有可点元素：卡片、宫格、键位、胶囊、FAB。
/// scale 会让 label 内的图标与文字按比例一起缩小 —— 这是特性，不是 bug。
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

// MARK: - Sheet 自绘把手（原先在记一笔/建户/转账三处各写一遍，收敛为一处）

struct SheetGrabber: View {
    var body: some View {
        Capsule()
            .fill(Theme.grabber)
            .frame(width: 40, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}

// MARK: - 触觉反馈（apple-design §13）
// 三条纪律：因果明确（绑在真正的动作上）、同帧触发、只在有意义的时刻用。
// 复用生成器避免每次新建（新建会丢掉 Taptic Engine 的预热状态）。

@MainActor
enum Haptics {
    private static let keyGen = UIImpactFeedbackGenerator(style: .light)
    private static let tapGen = UIImpactFeedbackGenerator(style: .soft)
    private static let notifyGen = UINotificationFeedbackGenerator()

    /// 键盘按键（高频、最轻）
    static func key() { keyGen.impactOccurred(intensity: 0.7) }
    /// 轻点：宫格 / 胶囊 / FAB
    static func tap() { tapGen.impactOccurred() }
    /// 保存成功（低频、明确）
    static func success() { notifyGen.notificationOccurred(.success) }
}
