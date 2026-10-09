import SwiftUI

/// 4 Tab 骨架：线索 / 洞察 / 资产 / 设置 + 绿 FAB（资产页琥珀 $ FAB，M2 接入）
/// 视觉对照物：site/prototype.html；Tab 规范见视觉基准 v1.1 §5
struct RootTabView: View {
    @State private var selection = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selection) {
                HomeView().tabItem { Label("线索", systemImage: "list.bullet") }.tag(0)
                InsightView().tabItem { Label("洞察", systemImage: "chart.bar") }.tag(1)
                AssetsView().tabItem { Label("资产", systemImage: "creditcard") }.tag(2)
                SettingsView().tabItem { Label("设置", systemImage: "gearshape") }.tag(3)
            }
            .tint(Theme.green)

            // FAB：M1 接「记一笔」sheet；资产页（selection==2）为琥珀 $ FAB
            Button {
                // TODO(M1): 打开 AddEntrySheet
            } label: {
                Image(systemName: selection == 2 ? "dollarsign" : "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(selection == 2 ? Theme.amber : Theme.green)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            }
            .padding(.trailing, 18)
            .padding(.bottom, 76)
        }
    }
}

#Preview { RootTabView() }
