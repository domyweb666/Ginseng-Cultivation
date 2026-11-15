import AppIntents

/// Siri 短語（片 H2）。每一句都要帶 app 的名字，Siri 才知道是找這個 app。
/// 一句裡只能帶一個參數，而且只能是選項型的（功法）；重量、次數塞不進短語，Siri 會接著問。
/// 短語是編譯時抽走的，陣列只能寫字面值，所以每個陣列寫成一行。
struct RencanShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogLiftIntent(),
            phrases: ["用\(.applicationName)記一下\(\.$move)", "用\(.applicationName)記修煉"],
            shortTitle: "記修煉",
            systemImageName: "dumbbell"
        )
        AppShortcut(
            intent: RealmStatusIntent(),
            phrases: ["\(.applicationName)我現在什麼境界", "用\(.applicationName)問境界"],
            shortTitle: "問境界",
            systemImageName: "mountain.2"
        )
    }
}
