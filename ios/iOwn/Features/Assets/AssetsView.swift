import SwiftUI

/// 资产页骨架 —— M2 全套（B1-B4）：深蓝净资产卡 + 四指标卡 + 现金/信用账户组 + 琥珀 $ FAB
struct AssetsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Radius.cardSpacing) {
                    // TODO(M2-B3): 深蓝净资产卡（#5661B8→#47509E 渐变 + 波浪底）
                    LinearGradient(colors: [Theme.indigo, Theme.indigoDeep], startPoint: .top, endPoint: .bottom)
                        .frame(height: 140)
                        .cornerRadius(Radius.large)
                        .overlay(
                            VStack(alignment: .leading, spacing: 6) {
                                Text("净资产").font(.footnote).foregroundStyle(.white.opacity(0.8))
                                Text("¥ 0.00").font(.system(size: 34, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white).monospacedDigit()
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(18),
                            alignment: .topLeading
                        )

                    // TODO(M2-B1/B2): 现金/信用账户组（SwiftData Account）
                    EmptyStateCard(icon: "💳", title: "还没有账户", hint: "点右下角 $ 添加第一个账户")
                }
                .padding(.horizontal, Radius.pagePadding)
                .padding(.top, 8)
            }
            .background(Theme.bg)
            .navigationTitle("资产")
        }
    }
}

#Preview { AssetsView() }
