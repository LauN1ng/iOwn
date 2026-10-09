import SwiftUI

/// 保存成功屏（A4）：绿勾 pop + 金额 + 分类/心情/连续天数，1.9s 自动返回
/// 视觉对照：site/prototype.html #done（罐子动效已按用户反馈移除）
struct SuccessOverlay: View {
    let info: SavedEntryInfo

    @State private var popped = false

    private var amountText: String {
        let v = NSDecimalNumber(decimal: info.amount).doubleValue
        return String(format: "%@¥%.2f", info.isOut ? "-" : "+", v)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // 绿勾（pop 弹性出现）
                ZStack {
                    Circle()
                        .fill(Theme.green)
                        .frame(width: 80, height: 80)
                        .shadow(color: Theme.green.opacity(0.42), radius: 17, y: 14)
                    Image(systemName: "checkmark")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .scaleEffect(popped ? 1 : 0.3)
                .opacity(popped ? 1 : 0)

                Text(amountText)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.green)
                    .monospacedDigit()
                    .padding(.top, 30)

                Text("\(info.categoryName) · \(info.subName) · 已入账")
                    .font(.system(size: 14.5))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                if let mood = info.mood {
                    Text("\(mood.label) \(mood.emoji)")
                        .font(.system(size: 14))
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(Theme.card)
                        .cornerRadius(999)
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                        .padding(.top, 18)
                }

                Spacer(minLength: 0)

                Text("今日第 \(info.todayCount) 笔 · 连续 \(info.streak) 天 · 记账日 +1")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { popped = true }
        }
    }
}
