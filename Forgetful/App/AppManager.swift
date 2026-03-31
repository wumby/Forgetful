import SwiftData
import SwiftUI

@MainActor
final class AppManager: ObservableObject {
    let assetStore: AssetStore
    @Published var lastCleanupRun: Date?

    init(assetStore: AssetStore) {
        self.assetStore = assetStore
    }

    func handleScenePhaseChange(_ phase: ScenePhase, container: ModelContainer) {
        guard phase == .active else { return }
        runCleanupIfNeeded(container: container)
    }

    func runCleanupIfNeeded(container: ModelContainer, force: Bool = false) {
        let context = container.mainContext
        let preferences = UserPreferences.fetchOrCreate(in: context)

        guard force || shouldRunCleanup(lastCleanupDate: preferences.lastCleanupDate) else { return }

        let expirationService = ExpirationService()
        let memoryService = MemoryService(context: context, assetStore: assetStore, expirationService: expirationService)
        memoryService.runExpirationCleanup(lastCleanupTracker: preferences)
        lastCleanupRun = Date.now
    }

    private func shouldRunCleanup(lastCleanupDate: Date?) -> Bool {
        guard let lastCleanupDate else { return true }
        return Calendar.current.dateComponents([.hour], from: lastCleanupDate, to: .now).hour ?? 0 >= 1
    }
}
