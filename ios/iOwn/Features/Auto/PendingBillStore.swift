import Foundation

// MARK: - 待确认队列（M3 备忘 §1）：PendingBill 存 UserDefaults JSON，回前台逐条消费

enum PendingBillStore {
    private static let key = "pendingBills"
    private static let openAddKey = "autoOpenAddSheet"   // 无文本触发（背面/操作按钮）→ 直接弹记一笔

    static func all() -> [PendingBill] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PendingBill].self, from: data)) ?? []
    }

    static func append(_ bill: PendingBill) {
        var list = all()
        list.append(bill)
        save(list)
    }

    /// 取出最早一条（出卡即消费）
    static func popFirst() -> PendingBill? {
        var list = all()
        guard !list.isEmpty else { return nil }
        let first = list.removeFirst()
        save(list)
        return first
    }

    static func discard(_ bill: PendingBill) {
        save(all().filter { $0.id != bill.id })
    }

    private static func save(_ list: [PendingBill]) {
        let data = (try? JSONEncoder().encode(list)) ?? Data()
        UserDefaults.standard.set(data, forKey: key)
    }

    // 无文本触发标记
    static func requestOpenAdd() { UserDefaults.standard.set(true, forKey: openAddKey) }
    static func consumeOpenAdd() -> Bool {
        let v = UserDefaults.standard.bool(forKey: openAddKey)
        if v { UserDefaults.standard.set(false, forKey: openAddKey) }
        return v
    }
}
