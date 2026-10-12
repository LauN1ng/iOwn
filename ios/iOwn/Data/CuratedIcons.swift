import Foundation

// ⚠️ 本文件由 `reports/_build_cur_icons.py` 自动生成 —— 请勿手改。
// 重新生成：python reports/_build_cur_icons.py
//
// curated 图标集（Microsoft Fluent Emoji 3D，MIT）：自定义二级分类的图标选择器。
// 共 135 个 / 9 组，素材 `cur_*` 已入 Assets.xcassets。

enum CuratedIcons {
    struct Item: Identifiable, Equatable {
        let asset: String      // Asset Catalog 名（cur_*）
        let name: String       // 中文名（VoiceOver / 无障碍标签）
        let emoji: String      // 兜底：asset 缺失时显示；也用于老数据（裸 emoji）反查
        var id: String { asset }
    }

    struct Group: Identifiable {
        let title: String
        let items: [Item]
        var id: String { title }
    }

    static let groups: [Group] = [
        Group(title: "吃 · 餐饮", items: [
            Item(asset: "cur_hot_beverage", name: "热饮咖啡", emoji: "☕"),
            Item(asset: "cur_bubble_tea", name: "奶茶", emoji: "🧋"),
            Item(asset: "cur_beer_mug", name: "喝酒", emoji: "🍺"),
            Item(asset: "cur_hamburger", name: "汉堡", emoji: "🍔"),
            Item(asset: "cur_pizza", name: "披萨", emoji: "🍕"),
            Item(asset: "cur_spaghetti", name: "意面", emoji: "🍝"),
            Item(asset: "cur_cooked_rice", name: "米饭", emoji: "🍚"),
            Item(asset: "cur_steaming_bowl", name: "面食", emoji: "🍜"),
            Item(asset: "cur_sushi", name: "寿司", emoji: "🍣"),
            Item(asset: "cur_takeout_box", name: "外卖", emoji: "🥡"),
            Item(asset: "cur_french_fries", name: "薯条", emoji: "🍟"),
            Item(asset: "cur_green_salad", name: "沙拉", emoji: "🥗"),
            Item(asset: "cur_red_apple", name: "水果", emoji: "🍎"),
            Item(asset: "cur_bread", name: "面包", emoji: "🍞"),
            Item(asset: "cur_shortcake", name: "甜点", emoji: "🍰"),
        ]),
        Group(title: "行 · 交通", items: [
            Item(asset: "cur_automobile", name: "开车", emoji: "🚗"),
            Item(asset: "cur_taxi", name: "打车", emoji: "🚕"),
            Item(asset: "cur_bus", name: "公交", emoji: "🚌"),
            Item(asset: "cur_metro", name: "地铁", emoji: "🚇"),
            Item(asset: "cur_bullet_train", name: "高铁", emoji: "🚄"),
            Item(asset: "cur_train", name: "火车", emoji: "🚆"),
            Item(asset: "cur_bicycle", name: "自行车", emoji: "🚲"),
            Item(asset: "cur_motor_scooter", name: "电动车", emoji: "🛵"),
            Item(asset: "cur_motorcycle", name: "摩托", emoji: "🏍️"),
            Item(asset: "cur_airplane", name: "飞机", emoji: "✈️"),
            Item(asset: "cur_helicopter", name: "直升机", emoji: "🚁"),
            Item(asset: "cur_ship", name: "轮船", emoji: "🚢"),
            Item(asset: "cur_sailboat", name: "帆船", emoji: "⛵"),
            Item(asset: "cur_rocket", name: "火箭", emoji: "🚀"),
            Item(asset: "cur_fuel_pump", name: "加油", emoji: "⛽"),
        ]),
        Group(title: "住 · 家居", items: [
            Item(asset: "cur_house", name: "房租", emoji: "🏠"),
            Item(asset: "cur_bed", name: "床品", emoji: "🛏️"),
            Item(asset: "cur_couch_and_lamp", name: "客厅", emoji: "🛋️"),
            Item(asset: "cur_chair", name: "家具", emoji: "🪑"),
            Item(asset: "cur_bathtub", name: "浴室", emoji: "🛁"),
            Item(asset: "cur_shower", name: "淋浴", emoji: "🚿"),
            Item(asset: "cur_toilet", name: "卫浴", emoji: "🚽"),
            Item(asset: "cur_door", name: "门窗", emoji: "🚪"),
            Item(asset: "cur_window", name: "窗户", emoji: "🪟"),
            Item(asset: "cur_light_bulb", name: "电费", emoji: "💡"),
            Item(asset: "cur_electric_plug", name: "插座", emoji: "🔌"),
            Item(asset: "cur_potable_water", name: "水费", emoji: "🚰"),
            Item(asset: "cur_soap", name: "洗护", emoji: "🧼"),
            Item(asset: "cur_broom", name: "清洁", emoji: "🧹"),
            Item(asset: "cur_bucket", name: "杂物", emoji: "🪣"),
        ]),
        Group(title: "娱乐 · 玩乐", items: [
            Item(asset: "cur_video_game", name: "游戏", emoji: "🎮"),
            Item(asset: "cur_television", name: "电视", emoji: "📺"),
            Item(asset: "cur_musical_note", name: "音乐", emoji: "🎵"),
            Item(asset: "cur_guitar", name: "吉他", emoji: "🎸"),
            Item(asset: "cur_violin", name: "乐器", emoji: "🎻"),
            Item(asset: "cur_headphone", name: "耳机", emoji: "🎧"),
            Item(asset: "cur_ticket", name: "门票", emoji: "🎫"),
            Item(asset: "cur_bowling", name: "保龄球", emoji: "🎳"),
            Item(asset: "cur_pool_8_ball", name: "台球", emoji: "🎱"),
            Item(asset: "cur_artist_palette", name: "美术", emoji: "🎨"),
            Item(asset: "cur_movie_camera", name: "电影", emoji: "🎥"),
            Item(asset: "cur_clapper_board", name: "拍摄", emoji: "🎬"),
            Item(asset: "cur_party_popper", name: "聚会", emoji: "🎉"),
            Item(asset: "cur_balloon", name: "布置", emoji: "🎈"),
            Item(asset: "cur_soccer_ball", name: "运动", emoji: "⚽"),
        ]),
        Group(title: "学习 · 办公", items: [
            Item(asset: "cur_books", name: "书", emoji: "📚"),
            Item(asset: "cur_open_book", name: "阅读", emoji: "📖"),
            Item(asset: "cur_notebook", name: "本子", emoji: "📓"),
            Item(asset: "cur_memo", name: "备忘", emoji: "📝"),
            Item(asset: "cur_pencil", name: "文具", emoji: "✏️"),
            Item(asset: "cur_fountain_pen", name: "钢笔", emoji: "🖋️"),
            Item(asset: "cur_paintbrush", name: "画笔", emoji: "🖌️"),
            Item(asset: "cur_straight_ruler", name: "尺子", emoji: "📏"),
            Item(asset: "cur_paperclip", name: "回形针", emoji: "📎"),
            Item(asset: "cur_scissors", name: "剪刀", emoji: "✂️"),
            Item(asset: "cur_file_folder", name: "资料", emoji: "📁"),
            Item(asset: "cur_label", name: "标签", emoji: "🏷️"),
            Item(asset: "cur_graduation_cap", name: "学费", emoji: "🎓"),
            Item(asset: "cur_school", name: "学校", emoji: "🏫"),
            Item(asset: "cur_briefcase", name: "工作", emoji: "💼"),
        ]),
        Group(title: "健康 · 医疗", items: [
            Item(asset: "cur_pill", name: "药", emoji: "💊"),
            Item(asset: "cur_syringe", name: "打针", emoji: "💉"),
            Item(asset: "cur_stethoscope", name: "体检", emoji: "🩺"),
            Item(asset: "cur_hospital", name: "看病", emoji: "🏥"),
            Item(asset: "cur_tooth", name: "看牙", emoji: "🦷"),
            Item(asset: "cur_adhesive_bandage", name: "创可贴", emoji: "🩹"),
            Item(asset: "cur_crutch", name: "康复", emoji: "🩼"),
            Item(asset: "cur_beating_heart", name: "心率", emoji: "💓"),
            Item(asset: "cur_drop_of_blood", name: "化验", emoji: "🩸"),
            Item(asset: "cur_thermometer", name: "体温", emoji: "🌡️"),
            Item(asset: "cur_anatomical_heart", name: "心脏", emoji: "🫀"),
            Item(asset: "cur_lungs", name: "肺部", emoji: "🫁"),
            Item(asset: "cur_brain", name: "心理", emoji: "🧠"),
            Item(asset: "cur_bone", name: "骨科", emoji: "🦴"),
            Item(asset: "cur_person_running", name: "跑步", emoji: "🏃"),
        ]),
        Group(title: "人情 · 礼物", items: [
            Item(asset: "cur_wrapped_gift", name: "送礼", emoji: "🎁"),
            Item(asset: "cur_red_heart", name: "心意", emoji: "❤️"),
            Item(asset: "cur_bouquet", name: "花束", emoji: "💐"),
            Item(asset: "cur_love_letter", name: "情书", emoji: "💌"),
            Item(asset: "cur_handshake", name: "应酬", emoji: "🤝"),
            Item(asset: "cur_raising_hands", name: "庆祝", emoji: "🙌"),
            Item(asset: "cur_money_bag", name: "红包", emoji: "💰"),
            Item(asset: "cur_red_paper_lantern", name: "节庆", emoji: "🏮"),
            Item(asset: "cur_sparkles", name: "惊喜", emoji: "✨"),
            Item(asset: "cur_birthday_cake", name: "生日", emoji: "🎂"),
            Item(asset: "cur_rose", name: "玫瑰", emoji: "🌹"),
            Item(asset: "cur_ring", name: "珠宝", emoji: "💍"),
            Item(asset: "cur_crown", name: "大牌", emoji: "👑"),
            Item(asset: "cur_trophy", name: "奖励", emoji: "🏆"),
            Item(asset: "cur_two_hearts", name: "恋爱", emoji: "💕"),
        ]),
        Group(title: "数码 · 电子", items: [
            Item(asset: "cur_mobile_phone", name: "手机", emoji: "📱"),
            Item(asset: "cur_laptop", name: "笔电", emoji: "💻"),
            Item(asset: "cur_desktop_computer", name: "台式机", emoji: "🖥️"),
            Item(asset: "cur_keyboard", name: "键盘", emoji: "⌨️"),
            Item(asset: "cur_computer_mouse", name: "鼠标", emoji: "🖱️"),
            Item(asset: "cur_printer", name: "打印", emoji: "🖨️"),
            Item(asset: "cur_floppy_disk", name: "存储", emoji: "💾"),
            Item(asset: "cur_optical_disk", name: "光盘", emoji: "💿"),
            Item(asset: "cur_battery", name: "电池", emoji: "🔋"),
            Item(asset: "cur_telephone", name: "固话", emoji: "☎️"),
            Item(asset: "cur_joystick", name: "手柄", emoji: "🕹️"),
            Item(asset: "cur_camera", name: "相机", emoji: "📷"),
            Item(asset: "cur_video_camera", name: "摄像", emoji: "📹"),
            Item(asset: "cur_flashlight", name: "手电", emoji: "🔦"),
            Item(asset: "cur_robot", name: "智能设备", emoji: "🤖"),
        ]),
        Group(title: "日用 · 宠物", items: [
            Item(asset: "cur_shopping_cart", name: "采购", emoji: "🛒"),
            Item(asset: "cur_convenience_store", name: "便利店", emoji: "🏪"),
            Item(asset: "cur_basket", name: "购物篮", emoji: "🧺"),
            Item(asset: "cur_package", name: "快递", emoji: "📦"),
            Item(asset: "cur_receipt", name: "小票", emoji: "🧾"),
            Item(asset: "cur_tear_off_calendar", name: "日历", emoji: "📆"),
            Item(asset: "cur_left_right_arrow", name: "互转", emoji: "🔄"),
            Item(asset: "cur_barber_pole", name: "理发", emoji: "💈"),
            Item(asset: "cur_dog_face", name: "狗", emoji: "🐶"),
            Item(asset: "cur_cat_face", name: "猫", emoji: "🐱"),
            Item(asset: "cur_paw_prints", name: "宠物", emoji: "🐾"),
            Item(asset: "cur_fish", name: "鱼", emoji: "🐟"),
            Item(asset: "cur_bird", name: "鸟", emoji: "🐦"),
            Item(asset: "cur_rabbit", name: "兔子", emoji: "🐰"),
            Item(asset: "cur_turtle", name: "乌龟", emoji: "🐢"),
        ]),
    ]

    static let all: [Item] = groups.flatMap(\.items)

    static func item(_ asset: String) -> Item? {
        all.first { $0.asset == asset }
    }

    /// 老数据兼容：`SubDef.emoji` 里存的可能是裸 emoji 字符 → 反查对应的 Fluent asset
    static func asset(forEmoji e: String) -> String? {
        all.first { $0.emoji == e }?.asset
    }

    /// 首选图标（新建子类时的默认选中项）—— 名字避开 `default` 关键字，免去调用点的反引号
    static let preferred = all.first { $0.asset == "cur_receipt" } ?? all[0]

    // MARK: 工资卡工作状态（WageTimerCard 的 StatusPill）

    /// asset 名与 `WorkState` 一一对应；调休三态共用 `makeup`
    enum State {
        static let beforeWork = "state_before_work"   // 未上班
        static let working = "state_working"   // 工作中
        static let lunch = "state_lunch"   // 午休中
        static let afterWork = "state_after_work"   // 已下班
        static let rest = "state_rest"   // 休息日
        static let makeup = "state_makeup"   // 调休
    }
}
