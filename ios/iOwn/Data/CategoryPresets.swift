import Foundation

// MARK: - 分类预设表（Spec §4：struct 静态表，非 SwiftData 模型；二级可自定义 A5）

struct CategoryDef: Identifiable {
    let id: String
    let emoji: String
    let name: String
    let subs: [SubDef]

    struct SubDef: Identifiable {
        let id: String
        let emoji: String
        let name: String
    }
}

/// 六大消费意图（视觉基准 v1.1 §4）：固定支出🔒/生活所需🍞/弹性支出🎀/个人提升📖/旅行🗺️/大物件💎
enum CategoryPresets {
    static let all: [CategoryDef] = [
        CategoryDef(id: "fixed", emoji: "🔒", name: "固定支出", subs: [
            .init(id: "rent", emoji: "🏠", name: "房租"),
            .init(id: "utility", emoji: "💡", name: "水电费"),
            .init(id: "subscription", emoji: "📺", name: "订阅会员"),
            .init(id: "commute", emoji: "🚇", name: "通勤"),
        ]),
        CategoryDef(id: "needs", emoji: "🍞", name: "生活所需", subs: [
            .init(id: "grocery", emoji: "🛒", name: "买菜"),
            .init(id: "meal", emoji: "🍜", name: "吃饭"),
            .init(id: "daily", emoji: "🧴", name: "日用"),
            .init(id: "medical", emoji: "💊", name: "医药"),
        ]),
        CategoryDef(id: "flexible", emoji: "🎀", name: "弹性支出", subs: [
            .init(id: "coffee", emoji: "☕️", name: "咖啡"),
            .init(id: "snack", emoji: "🍰", name: "奶茶甜品"),
            .init(id: "fun", emoji: "🎮", name: "娱乐"),
            .init(id: "social", emoji: "🍻", name: "社交"),
        ]),
        CategoryDef(id: "growth", emoji: "📖", name: "个人提升", subs: [
            .init(id: "book", emoji: "📚", name: "书"),
            .init(id: "course", emoji: "🎓", name: "课程"),
            .init(id: "fitness", emoji: "🏋️", name: "健身"),
        ]),
        CategoryDef(id: "travel", emoji: "🗺️", name: "旅行", subs: [
            .init(id: "transport", emoji: "✈️", name: "大交通"),
            .init(id: "hotel", emoji: "🏨", name: "住宿"),
            .init(id: "ticket", emoji: "🎫", name: "门票"),
        ]),
        CategoryDef(id: "bigitem", emoji: "💎", name: "大物件", subs: [
            .init(id: "digital", emoji: "📱", name: "数码"),
            .init(id: "home", emoji: "🛋️", name: "家居"),
        ]),
    ]

    static func category(id: String) -> CategoryDef? { all.first { $0.id == id } }

    /// 快捷分类行（记一笔宫格顶部，M1 实现时定）
    static let quickIDs = ["needs:meal", "flexible:coffee", "needs:grocery", "fixed:commute"]
}
