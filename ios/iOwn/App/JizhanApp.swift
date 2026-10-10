import SwiftUI
import SwiftData

@main
struct JizhanApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        // ⚠️ 新增 @Model 必须同步注册进来，否则 @Query 静默返回空、insert 进不了 schema
        // （2026-10-10 曾因漏注册 Liability.self 导致负债页永远空数据）
        .modelContainer(for: [Tx.self, Account.self, Liability.self, FixedExpense.self])
    }
}
