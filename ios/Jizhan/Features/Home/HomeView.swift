import SwiftUI

/// 线索（首页）—— P0 A2：按日分组流水；顶卡 = 工资计时器趣味卡（D1，M4 前置实现于 M1 末）
/// 骨架期：空态 + 结构占位，A1/A2 在 M1 实现（对照 site/prototype.html #home）
struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Radius.cardSpacing) {
                    // TODO(M1-D1): 工资计时器卡（绿左边框 + Text(timerInterval:) 自走金额 + doodle）
                    PlaceholderCard(title: "工资计时器卡", hint: "M1 末接入：本月已赚自走金额")

                    // TODO(M1-A2): 按日分组流水（日期 + 日合计 / emoji + 意图分类小字 + 名称 + 心情胶囊 + 金额）
                    EmptyStateCard()
                }
                .padding(.horizontal, Radius.pagePadding)
                .padding(.top, 8)
            }
            .background(Theme.bg)
            .navigationTitle("线索")
        }
    }
}

struct PlaceholderCard: View {
    let title: String
    let hint: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(hint).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card)
        .cornerRadius(Radius.large)
    }
}

struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("🫙").font(.system(size: 44))
            Text("还没有记录").font(.subheadline).foregroundStyle(.secondary)
            Text("点右下角 + 记第一笔").font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Theme.card)
        .cornerRadius(Radius.large)
    }
}

#Preview { HomeView() }
