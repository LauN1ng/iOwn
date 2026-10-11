import SwiftUI
import UIKit

// MARK: - 卡面（浅色版 · 2026-10-11 视觉收编）
//
// 设计规则（用户拍板）：**App 只允许一个「彩色源」= Fluent 3D emoji**。
// 卡面全部退为浅色（白底 + 一抹 ≤5% 明度的同系浅 tint），账户辨识度靠
// ① 各自的细几何纹样 ② 右下角 acct_* 3D 图标 —— 不再靠彩虹渐变。
// 这样 emoji 的活泼不会被卡面抢戏（对标 Pool：活泼集中管理，不散落）。
//
// ⚠️ 卡面**全部用 SwiftUI 绘制**，不引入图片资源 —— 它是图形，不受
//    「彩色贴图不能用 .template」那条规则约束（那条只针对 Fluent Emoji 贴图）。

enum CardFace: String, CaseIterable, Codable, Identifiable {
    case alipayBlue, wechatGreen, classic, appleCash, ocean
    case geometric, minimal, techGrid, goldHoneycomb, businessStripe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alipayBlue: "支付宝蓝"
        case .wechatGreen: "微信绿"
        case .classic: "经典"
        case .appleCash: "Apple Cash"
        case .ocean: "海洋"
        case .geometric: "几何"
        case .minimal: "极简"
        case .techGrid: "科技网格"
        case .goldHoneycomb: "鎏金蜂巢"
        case .businessStripe: "商务条纹"
        }
    }

    /// 浅色卡：**全部**卡面 2026-10-11 视觉收编后走浅色（见文件头设计规则）
    var isLight: Bool { true }

    /// 主渐变（左上 → 右下）：白 → 一抹浅 tint（≤5% 明度的同系色，仅作账户区分）
    var gradient: [Color] {
        switch self {
        case .alipayBlue:     [Color(hex: 0xFFFFFF), Color(hex: 0xEAF3FE)]  // 支付宝 · 一抹蓝
        case .wechatGreen:    [Color(hex: 0xFFFFFF), Color(hex: 0xE9F7EE)]  // 微信 · 一抹绿
        case .classic:        [Color(hex: 0xFFFFFF), Color(hex: 0xEFF1F4)]  // 经典 · 石墨灰
        case .appleCash:      [Color(hex: 0xFFFFFF), Color(hex: 0xF3F2EE)]  // Apple Cash · 米白
        case .ocean:          [Color(hex: 0xFFFFFF), Color(hex: 0xE7F4F1)]  // 海洋 · 青
        case .geometric:      [Color(hex: 0xFFFFFF), Color(hex: 0xF0EDFB)]  // 几何 · 淡紫
        case .minimal:        [Color(hex: 0xFFFFFF), Color(hex: 0xEBEBE5)]  // 极简 · 暖白
        case .techGrid:       [Color(hex: 0xFFFFFF), Color(hex: 0xEBF1FA)]  // 科技网格 · 靛蓝
        case .goldHoneycomb:  [Color(hex: 0xFFFFFF), Color(hex: 0xFAF3E1)]  // 鎏金蜂巢 · 浅金
        case .businessStripe: [Color(hex: 0xFFFFFF), Color(hex: 0xEBEEFB)]  // 商务条纹 · 藏青
        }
    }

    /// 卡面文字色（浅色卡走深字）
    var foreground: Color { isLight ? Color(hex: 0x2B2F33) : .white }
    /// 卡面次级文字色
    var foregroundSoft: Color {
        isLight ? Color(hex: 0x2B2F33).opacity(0.60) : Color.white.opacity(0.86)
    }
    /// 卡面 logo/图标底衬
    var logoBackground: Color {
        isLight ? Color(hex: 0x2B2F33).opacity(0.08) : Color.white.opacity(0.22)
    }
    /// 纹样用色（浅色卡用深色纹样）
    private var pattern: Color {
        isLight ? Color(hex: 0x2B2F33) : Color.white
    }

    /// 类型 → 默认卡面（建户时自动带出，用户可改）
    static func `default`(for kind: AccountKind) -> CardFace {
        switch kind {
        case .cash:        .goldHoneycomb
        case .bankCard:    .ocean
        case .wechat:      .wechatGreen
        case .alipay:      .alipayBlue
        case .creditCard:  .classic
        case .huabei:      .geometric
        case .baitiao:     .businessStripe
        case .creditOther: .techGrid
        }
    }

    // MARK: 纹样

    @ViewBuilder
    fileprivate var ornament: some View {
        switch self {
        case .alipayBlue:
            ZStack {
                Ellipse().fill(pattern.opacity(0.10)).frame(width: 330, height: 150).offset(x: 46, y: 74)
                Ellipse().fill(pattern.opacity(0.08)).frame(width: 250, height: 112).offset(x: -40, y: 96)
                Ellipse().fill(pattern.opacity(0.05)).frame(width: 170, height: 76).offset(x: 110, y: 118)
            }
        case .wechatGreen:
            ZStack {
                Circle().fill(pattern.opacity(0.13)).frame(width: 118, height: 118).offset(x: 92, y: -6)
                Circle().fill(pattern.opacity(0.10)).frame(width: 72, height: 72).offset(x: 38, y: 44)
                Circle().fill(pattern.opacity(0.08)).frame(width: 46, height: 46).offset(x: 126, y: 52)
                Circle().fill(pattern.opacity(0.06)).frame(width: 30, height: 30).offset(x: 4, y: 84)
            }
        case .classic:
            ZStack {
                Circle().fill(pattern.opacity(0.07)).frame(width: 210, height: 210).offset(x: 96, y: 66)
                Circle().fill(pattern.opacity(0.05)).frame(width: 156, height: 156).offset(x: -46, y: 92)
            }
        case .appleCash:
            dotMatrix
        case .ocean:
            ZStack {
                Ellipse().fill(pattern.opacity(0.09)).frame(width: 340, height: 128).offset(y: 82)
                Ellipse().fill(pattern.opacity(0.06)).frame(width: 240, height: 96).offset(x: -60, y: 104)
            }
        case .geometric:
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(pattern.opacity(0.10), lineWidth: 1)
                        .frame(width: CGFloat(34 + i * 26), height: CGFloat(34 + i * 26))
                        .rotationEffect(.degrees(Double(i) * 16))
                        .offset(x: 74, y: 34)
                }
            }
        case .minimal:
            GeometryReader { geo in
                Path { p in
                    p.move(to: CGPoint(x: 0, y: geo.size.height * 0.84))
                    p.addCurve(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.30),
                               control1: CGPoint(x: geo.size.width * 0.34, y: geo.size.height * 0.98),
                               control2: CGPoint(x: geo.size.width * 0.62, y: geo.size.height * 0.16))
                }
                .stroke(Color(hex: 0xC7C7C1), lineWidth: 1)
            }
        case .techGrid:
            ZStack {
                VStack(spacing: 15) {
                    ForEach(0..<9, id: \.self) { _ in
                        Rectangle().fill(pattern.opacity(0.07)).frame(height: 0.7)
                    }
                }
                .frame(width: 340)
                HStack(spacing: 15) {
                    ForEach(0..<17, id: \.self) { _ in
                        Rectangle().fill(pattern.opacity(0.07)).frame(width: 0.7)
                    }
                }
                .frame(height: 200)
                // 浅色卡上不用饱和蓝点（会跟 emoji 抢戏），改青灰调低透明度
                Circle().fill(Color(hex: 0x7A8AA0).opacity(0.60)).frame(width: 6, height: 6).offset(x: 58, y: -16)
                Circle().fill(Color(hex: 0x7A8AA0).opacity(0.42)).frame(width: 5, height: 5).offset(x: -86, y: 34)
                Circle().fill(Color(hex: 0x7A8AA0).opacity(0.30)).frame(width: 4, height: 4).offset(x: 20, y: 62)
            }
        case .goldHoneycomb:
            VStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { r in
                    HStack(spacing: 5) {
                        ForEach(0..<11, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(pattern.opacity(0.20), lineWidth: 1)
                                .frame(width: 16, height: 14)
                        }
                    }
                    .offset(x: r % 2 == 0 ? 0 : 10)
                }
            }
            .rotationEffect(.degrees(-10))
            .offset(x: 30, y: 10)
        case .businessStripe:
            VStack(spacing: 10) {
                ForEach(0..<16, id: \.self) { i in
                    Rectangle()
                        .fill(pattern.opacity(i % 2 == 0 ? 0.07 : 0.03))
                        .frame(height: 5)
                }
            }
            .rotationEffect(.degrees(-24))
            .frame(width: 460)
        }
    }

    private var dotMatrix: some View {
        VStack(spacing: 7) {
            ForEach(0..<10, id: \.self) { r in
                HStack(spacing: 7) {
                    ForEach(0..<16, id: \.self) { c in
                        Circle()
                            .fill(pattern.opacity(max(0.0, 0.30 - Double(14 - c - r) * 0.022)))
                            .frame(width: 3, height: 3)
                    }
                }
            }
        }
        .rotationEffect(.degrees(-12))
        .frame(width: 320, height: 190)
    }
}

// MARK: - 卡面绘制

/// 纯卡面（背景 + 纹样 + 受光）。卡堆 / 详情 hero / 建户预览 / 卡面选择器共用。
struct CardFaceView: View {
    let face: CardFace
    var cornerRadius: CGFloat = 20

    var body: some View {
        // ⚠️ 纹样必须走 overlay，**不能**跟渐变一起放进 ZStack 当兄弟：
        //    ZStack 的尺寸 = 最宽的子视图。businessStripe 的纹样 `.frame(width: 460)`
        //    再旋转 -24°，理想包围宽 ≈ 514pt → 会把整张卡撑到 514pt，
        //    进而把资产页整页撑到 514pt（截图里左右各被裁掉约 70pt）。
        //    overlay 的尺寸由父级决定、**不影响父级尺寸**，溢出部分交给 clipShape 裁掉。
        LinearGradient(colors: face.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay { face.ornament }
            // Fluent 3D 受光：顶部高光 + 底部压暗
            .overlay {
                LinearGradient(colors: [Color.white.opacity(face.isLight ? 0.55 : 0.16), .clear],
                               startPoint: .top, endPoint: .center)
            }
            .overlay {
                LinearGradient(colors: [.clear, Color.black.opacity(face.isLight ? 0.05 : 0.13)],
                               startPoint: .center, endPoint: .bottom)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - 卡面前景（卡堆 / 预览共用）
//
// 收原始值（不是 Account），因为建户 sheet 在保存前还没有 Account 实例。

struct CardFront: View {
    let name: String
    let amountText: String
    let face: CardFace
    /// 图标 asset（acct_*）；空则退回字块
    var iconName: String = ""
    /// 字块兜底单字
    var logoChar: String = ""
    /// 底部一行小字；nil = 只露卡头（被压住的卡片）
    var caption: String? = nil
    var height: CGFloat = 152
    var cornerRadius: CGFloat = 20

    var body: some View {
        ZStack {
            CardFaceView(face: face, cornerRadius: cornerRadius)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(name)
                        .scaledFont(17, weight: .bold)
                        .foregroundStyle(face.foreground)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(amountText)
                        .scaledFont(19, weight: .heavy)
                        .foregroundStyle(face.foreground)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if let caption {
                    HStack(alignment: .bottom, spacing: 8) {
                        Text(caption)
                            .scaledFont(11.5)
                            .foregroundStyle(face.foregroundSoft)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        badge
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        // maxWidth: .infinity —— 卡面在卡堆/建户预览里都应当撑满可用宽，
        // 否则 ZStack 里会塌成「内容理想宽」的窄卡
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 9, y: 6)
    }

    private var hasIcon: Bool {
        !iconName.isEmpty && UIImage(named: iconName) != nil
    }

    private var badge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(face.logoBackground)
                .frame(width: 36, height: 36)
            if hasIcon {
                // ⚠️ 彩色 Fluent 贴图：不要加 .renderingMode(.template)
                Image(iconName).resizable().scaledToFit().frame(width: 26, height: 26)
            } else {
                Text(logoChar)
                    .scaledFont(14, weight: .heavy)
                    .foregroundStyle(face.foreground)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 卡面选择器缩略图

struct CardFaceThumb: View {
    let face: CardFace
    var selected: Bool = false
    var width: CGFloat = 150
    var height: CGFloat = 92

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CardFaceView(face: face, cornerRadius: 12)
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(selected ? Theme.green : .clear, lineWidth: 2.5)
                )
                .shadow(color: .black.opacity(0.10), radius: 5, y: 3)
            Text(face.displayName)
                .scaledFont(11.5, weight: selected ? .bold : .medium)
                .foregroundStyle(selected ? Theme.greenText : .secondary)
        }
    }
}
