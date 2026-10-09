import SwiftUI

/// 洞察页骨架 —— M4（D2）：12 月柱状图 + 支出日历热力格 + 心情账单 + 分类占比
struct InsightView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Radius.cardSpacing) {
                    PlaceholderCard(title: "洞察看板", hint: "M4 接入：12 月柱状图 / 日历热力格 / 心情账单 / 分类占比")
                    EmptyStateCard(icon: "📊", title: "还没有洞察数据", hint: "记几笔账后这里生成图表")
                }
                .padding(.horizontal, Radius.pagePadding)
                .padding(.top, 8)
            }
            .background(Theme.bg)
            .navigationTitle("洞察")
        }
    }
}

#Preview { InsightView() }
