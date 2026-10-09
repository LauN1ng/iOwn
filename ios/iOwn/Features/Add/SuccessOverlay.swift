import SwiftUI

/// 保存成功屏（A4）：绿勾 pop + 罐子掉豆动效 + 连续天数，1.9s 自动返回
/// 视觉对照：site/prototype.html #done
struct SuccessOverlay: View {
    let info: SavedEntryInfo

    @State private var popped = false
    @State private var beansFell = false

    private var amountText: String {
        let v = NSDecimalNumber(decimal: info.amount).doubleValue
        return String(format: "%@¥%.2f", info.isOut ? "-" : "+", v)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
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

                jarView
                    .padding(.top, 26)

                Text(amountText)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.green)
                    .monospacedDigit()
                    .padding(.top, 22)

                Text("\(info.categoryName) · \(info.subName) · 已入账")
                    .font(.system(size: 14.5))
                    .foregroundStyle(.secondary)
                    .padding(.top, 7)

                if let mood = info.mood {
                    Text("\(mood.label) \(mood.emoji)")
                        .font(.system(size: 14))
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(Theme.card)
                        .cornerRadius(999)
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                        .padding(.top, 18)
                }

                Text("今日第 \(info.todayCount) 笔 · 连续 \(info.streak) 天 · 记账日 +1")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .padding(.top, 22)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { popped = true }
            withAnimation(.easeIn(duration: 0.38).delay(0.25)) { beansFell = true }
        }
    }

    // MARK: 罐子掉豆：豆子从上方依次掉进罐子

    private var jarView: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .top) {
                // 掉落的豆子
                HStack(spacing: 14) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(Theme.green)
                            .frame(width: 9, height: 9)
                            .offset(y: beansFell ? 34 : -160)
                            .opacity(beansFell ? 0.9 : 0)
                            .animation(.easeIn(duration: 0.34).delay(Double(i) * 0.1), value: beansFell)
                    }
                }
                Text("🫙")
                    .font(.system(size: 58))
                    .offset(y: 30)
            }
            .frame(height: 90)
            Text("连续 \(info.streak) 天")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.green)
        }
    }
}
