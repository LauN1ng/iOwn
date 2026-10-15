import Foundation

// MARK: - 工资卡「情绪脸」（F 语族 · 脸说情绪）
//
// 2026-10-15：工资卡从「状态标签」改成「心情翻译」。
//
// 原先的 6 个 `state_*` 全是【物品名词】—— 闹钟 / 公文包 / 面碗 / 房子 / 沙发 / 循环箭头。
// 它回答「我在干嘛」，不回答「我什么感觉」。所以即使放大到 40pt，得到的也只是
// 【一个更大的名词】。本表把语义层换成 6 张【脸】，回答「我什么感觉」。
//
// 素材：Microsoft Fluent Emoji 3D（MIT）。由 `reports/_build_face_icons.py` 生成，
//       归一化规则与全部现有图标一致（内容 bbox 最大边 = 画布 72%）。
//
// ⛔ 三套「脸」的语义必须隔离，不许串味：
//    · `mood_*` = 记账心情打标（用户对这笔钱的感觉）—— 已被 🤯 上头了 / 😤 买教训 占用
//    · `face_*` = 工资卡工作状态（用户此刻对上班的感觉）—— 本表
//    · `cur_*`  = 消费内容（吃 / 行 / 住…），物品语族，不表达情绪
//
// 旧素材 `state_*` **保留未删** —— 若情绪版不被接受，`WageConfig.iconAsset`
// 改回 `CuratedIcons.State.*` 即可一行回滚。
enum WageFace {
    static let yawning     = "face_yawning"        // 未上班 · 还没醒
    static let melting     = "face_melting"        // 工作中 · 忙到化掉
    static let savoring    = "face_savoring"       // 午休中 · 开饭了
    static let sunglasses  = "face_sunglasses"     // 已下班 · 下班，爽
    static let partying    = "face_partying"       // 休息日 · 今天属于我
    static let bitterSmile = "face_bitter_smile"   // 调休 · 苦笑
}
