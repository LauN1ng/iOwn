import SwiftUI

/// 保存成功屏（A4）：绿勾 pop + 金额 + 分类/心情/连续天数，1.9s 自动返回
/// v1.3：勾从 0.72 起弹（不再从 0.3 空降）；尊重减弱动效；金额大字收紧字距
/// 视觉对照：site/prototype.html #done（罐子动效已按用户反馈移除）
struct SuccessOverlay: View {
    let info: SavedEntryInfo

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popped = false

    private var amountText: String {
        let v = NSDecimalNumber(decimal: info.amount).doubleValue
        return (info.isOut ? "-" : "+") + "¥" + Money.string(v)
    }

    // MARK: 主视觉（2026-10-12「emoji 升权」）

    /// 有心情 → **心情图标 64pt 当主角 + 绿勾降为右上角 26pt 小徽章**
    /// 无心情 → 保持原「绿实心圆 + 白勾」
    ///
    /// ⚠️ **为什么不让心情直接替换绿勾**（方案文档 §5.3）：
    /// `Mood` 含 `impulsive`（🤯 上头了）与 `lesson`（😤 买教训）—— 若用户打了「买教训」，
    /// 成功屏就会在「记账成功」的庆祝时刻弹出一张生气的脸，读起来像 **App 在评判这笔消费**，
    /// 直接违反 `产品故事-定案-v1.md` §4.1 的非评判禁忌。
    /// 因此绿勾**不消失**（成功信号稳定），心情只作主角图案。副作用：emoji 权重从 18pt → 64pt，
    /// 提权目的同样达到。
    @ViewBuilder
    private var hero: some View {
        if let mood = info.mood {
            CategoryIcon(mood, size: 64)
                .frame(width: 80, height: 80)
                .overlay(alignment: .topTrailing) {
                    ZStack {
                        Circle().fill(Theme.green)
                        Image(systemName: "checkmark")
                            .scaledFont(11, weight: .heavy)
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)   // 装饰：结果由下方金额 + 分类文字承载
                    }
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Theme.bg, lineWidth: 2))   // 与心情图标之间留一圈底色缝
                }
        } else {
            ZStack {
                Circle()
                    .fill(Theme.green)
                    .frame(width: 80, height: 80)
                    .shadow(color: Theme.green.opacity(0.42), radius: 17, y: 14)
                Image(systemName: "checkmark")
                    .scaledFont(34, weight: .heavy)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)   // 装饰：结果由下方金额 + 分类文字承载
            }
        }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // 主视觉（pop 弹性出现）
                hero
                    .scaleEffect(popped ? 1 : 0.72)
                    .opacity(popped ? 1 : 0)

                Text(amountText)
                    .scaledFont(38, weight: .heavy, design: .rounded)
                    .foregroundStyle(Theme.greenText)
                    .monospacedDigit()
                    .tracking(-0.5)
                    .padding(.top, 30)

                Text("\(info.categoryName) · \(info.subName) · 已入账")
                    .scaledFont(14.5)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                // 2026-10-12：原 18pt 心情胶囊已删 —— 心情图标本身已是主视觉（见 hero），
                // 这里只留一行文字点明「这张脸是什么意思」。
                if let mood = info.mood {
                    Text(mood.label)
                        .scaledFont(13)
                        .foregroundStyle(.secondary)
                        .padding(.top, 18)
                }

                Spacer(minLength: 0)

                Text("今日第 \(info.todayCount) 笔 · 连续 \(info.streak) 天 · 记账日 +1")
                    .scaledFont(12.5)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .padding(.bottom, 48)
            }
        }
        .onAppear {
            // 减弱动效：不做弹性缩放，只淡入
            if reduceMotion {
                withAnimation(Motion.reduceFallback) { popped = true }
            } else {
                withAnimation(Motion.successPop) { popped = true }
            }
        }
    }
}
