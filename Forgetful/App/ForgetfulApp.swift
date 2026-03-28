import SwiftData
import SwiftUI

@main
struct ForgetfulApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer
    @StateObject private var appManager: AppManager

    init() {
        let schema = Schema([
            FolderEntity.self,
            MemoryItem.self,
            UserPreferences.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create model container: \(error)")
        }

        let assetStore = AssetStore()
        _appManager = StateObject(wrappedValue: AppManager(assetStore: assetStore))

        #if DEBUG
        SeedDataService.seedIfNeeded(in: modelContainer.mainContext, assetStore: assetStore)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appManager)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            appManager.handleScenePhaseChange(newPhase, container: modelContainer)
        }
    }
}
