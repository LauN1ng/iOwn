import SwiftUI

/// 4 Tab 骨架：线索 / 洞察 / 资产 / 设置 + 绿 FAB（资产页琥珀 $ FAB，M2 接入）
/// 视觉对照物：site/prototype.html；Tab 规范见视觉基准 v1.1 §5
struct RootTabView: View {
    @State private var selection = 0
    @State private var showAdd = false
    @State private var savedInfo: SavedEntryInfo?
    @State private var showSuccess = false

    private let ciArgs = ProcessInfo.processInfo.arguments

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selection) {
                HomeView().tabItem { Label("线索", systemImage: "list.bullet") }.tag(0)
                InsightView().tabItem { Label("洞察", systemImage: "chart.bar") }.tag(1)
                AssetsView().tabItem { Label("资产", systemImage: "creditcard") }.tag(2)
                SettingsView().tabItem { Label("设置", systemImage: "gearshape") }.tag(3)
            }
            .tint(Theme.green)

            // FAB：线索/洞察/设置 = 绿 +（记一笔）；资产页 = 琥珀 $（M2）
            Button {
                if selection == 2 {
                    // TODO(M2): 建户/转账
                } else {
                    showAdd = true
                }
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

            // 成功屏（A4）：覆盖全屏，1.9s 自动返回（CI 截图模式常驻）
            if showSuccess, let info = savedInfo {
                SuccessOverlay(info: info)
                    .transition(.opacity)
                    .task {
                        guard !ciArgs.contains("-ci-show-done") else { return }
                        try? await Task.sleep(nanoseconds: 1_900_000_000)
                        withAnimation(.easeOut(duration: 0.25)) { showSuccess = false }
                    }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddEntrySheet { info, showOverlay in
                guard showOverlay else { return }   // 再记：sheet 保持打开
                savedInfo = info
                showAdd = false
                withAnimation { showSuccess = true }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .onAppear {
            // CI 截图钩子：自动打开记一笔 / 直接展示成功屏
            if ciArgs.contains("-ci-show-done") {
                savedInfo = SavedEntryInfo(
                    amount: 12, isOut: true, categoryName: "生活所需",
                    subName: "三餐", mood: .normal, todayCount: 1, streak: 1
                )
                showSuccess = true
            }
            if ciArgs.contains("-ci-open-sheet") {
                showAdd = true
            }
        }
    }
}

#Preview { RootTabView() }
