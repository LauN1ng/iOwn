import SwiftUI
import SwiftData

@main
struct JizhanApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [Tx.self, Account.self])
    }
}
