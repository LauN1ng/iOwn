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

// MARK: - 立体绿色主按钮底（Fluent 3D 质感 · 2026-10-15 D5）
//
// 与 App 唯一彩色源（Fluent 3D emoji）同材质：把光源假想在**正上方** ——
//   ① 主面垂直渐变：上亮（受光）→ 下暗（背光），整块读成一块弧面
//   ② 顶部高光带：模拟镜面反射，落在外缘 ~1/3 处渐隐
//   ③ 底部 1pt 暗唇：把下缘「收」进去，强化厚度转折
//   ④ 同色环境投影：Fluent 3D 的落影是**彩色**的（不是黑），让按钮真的「离地」
// 只铺底，不动字号 / 内边距 / 按压反馈（`PressableButtonStyle` 原样保留）。
//
// 用法（替换原来的 `.background(color).cornerRadius(n)` 两件套）：
//   `.green3D(enabled: canSave)`               —— 默认圆角（Radius.control 14）
//   `.green3D(enabled: canSave, radius: Radius.medium)`
//   `.green3D(enabled: canSave, capsule: true)` —— 全药丸（工具条「保存」）
//   `.green3D(circle: true)`                    —— FAB
// `enabled == false`（禁用）退回扁平中性底，**不做立体**（禁用态不该有体积感）。
struct Green3DBackground: View {
    var enabled: Bool = true
    var radius: CGFloat = Radius.control
    var capsule: Bool = false
    var circle: Bool = false

    // ⚠️ 不要用类型擦除（`AnyShape` / `AnyInsettableShape`）—— 底部暗唇走 `strokeBorder`，
    //    它是 `InsettableShape` 的扩展，`AnyShape` 只是 `Shape` 编译不过；
    //    而 SwiftUI **没有** `AnyInsettableShape`（2026-10-15 CI 实测 `cannot find type`）。
    //    → 用泛型 `S: InsettableShape` 分派三种形状，零擦除、保住 `strokeBorder`。
    var body: some View {
        if circle {
            surface(Circle())
        } else if capsule {
            surface(Capsule())
        } else {
            surface(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    @ViewBuilder
    private func surface<S: InsettableShape>(_ shape: S) -> some View {
        if enabled {
            shape
                .fill(LinearGradient(colors: [Theme.greenTop, Theme.green, Theme.greenDeep],
                                     startPoint: .top, endPoint: .bottom))
                // 顶部高光带（受光面）
                .overlay {
                    shape.fill(LinearGradient(
                        stops: [.init(color: .white.opacity(0.34), location: 0.00),
                                .init(color: .white.opacity(0.07), location: 0.38),
                                .init(color: .clear,              location: 0.62)],
                        startPoint: .top, endPoint: .bottom))
                }
                // 底部暗唇
                .overlay { shape.strokeBorder(Theme.greenLip.opacity(0.50), lineWidth: 1) }
                // 同色环境投影
                .shadow(color: Theme.greenLip.opacity(0.32), radius: 5, y: 3)
        } else {
            shape.fill(Theme.disabled)
        }
    }
}

extension View {
    /// 给绿色主按钮铺「立体」底（见 `Green3DBackground` 注释）
    func green3D(enabled: Bool = true,
                 radius: CGFloat = Radius.control,
                 capsule: Bool = false,
                 circle: Bool = false) -> some View {
        background(Green3DBackground(enabled: enabled, radius: radius,
                                     capsule: capsule, circle: circle))
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

// MARK: - Dynamic Type 字体缩放（UI评审 v1 §3.5）
//
// SwiftUI 的 `Font.system(size:)` 固定字号，**不**随系统「文字大小」缩放；
// 而带 `relativeTo:` 参数的只有 `Font.custom(_:size:relativeTo:)`，系统字体没有这个重载。
// 因此用 `@ScaledMetric` 包一层：默认字号下取值 == 原 size（**视觉零变化**），
// 系统调大字号时按 `.body` 曲线放大。
//
// 用法：把 `.font(.system(size: 15, weight: .semibold))` 换成 `.scaledFont(.body, weight: .semibold)`。
// 不要直接用 `.font(.system(size:))`，除非是刻意不缩放的图形尺寸。

private struct ScaledFontModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    /// 跟随 Dynamic Type 的系统字体（替代 `.font(.system(size:weight:design:))`）
    /// 旧 API：仅供 `keyButton` 等动态 pt 场景保留使用，业务代码请走 token 版本
    func scaledFont(_ size: CGFloat,
                    weight: Font.Weight = .regular,
                    design: Font.Design = .default) -> some View {
        modifier(ScaledFontModifier(size: size, weight: weight, design: design))
    }

    /// 字号 token 入口（**业务代码统一用这个**）
    /// `display` 档固定不缩放；其余档跟随 Dynamic Type
    ///
    /// ⚠️ 必须标 `@ViewBuilder`：两个分支返回的是不同具体类型
    /// （`ModifiedContent<Self, ScaledFontModifier>` vs `ModifiedContent<Self, _EnvironmentKeyWritingModifier<…>>`），
    /// 不标会让 `some View` 推断失败 → `branches have mismatching types`（2026-10-15 CI 实测）。
    @ViewBuilder
    func scaledFont(_ token: Type,
                    weight: Font.Weight = .regular,
                    design: Font.Design = .default) -> some View {
        if token.scales {
            modifier(ScaledFontModifier(size: token.pt, weight: weight, design: design))
        } else {
            font(.system(size: token.pt, weight: weight, design: design))
        }
    }

    /// 视觉尺寸不变，把点击热区扩到至少 `side`×`side`（iOS HIG 44pt）
    /// 用法：`视觉.frame(width:34,height:34).tapTarget()` —— 圆点仍是 34，命中区 44
    func tapTarget(_ side: CGFloat = 44) -> some View {
        frame(width: side, height: side).contentShape(Rectangle())
    }
}

// MARK: - Dynamic Type 上限保护
//
// 本 App 的关键区（4 列键盘 keyH=54、净资产卡固定 190、流水行图标 42）是手调固定布局，
// 无条件放开到 AX 超大字号会撑破版式。故整体限制在标准区间（最大 .xxxLarge）；
// 想要支持 AX 字号需先做一轮弹性布局改造（见 UI评审 v1 §7 待办）。

struct TypeSizeCap: ViewModifier {
    var forceXXXL: Bool = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if forceXXXL {
            content.dynamicTypeSize(.xxxLarge)              // CI 截图用：强制大字号验证缩放生效
        } else {
            content.dynamicTypeSize(.xSmall ... .xxxLarge)  // 上限保护，默认字号下无任何影响
        }
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
