import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appManager: AppManager

    @State private var selectedPreset: ExpirationPreset = .sevenDays
    @State private var notificationsEnabled = false
    @State private var autoDeleteExpired = true

    var body: some View {
        let preferences = UserPreferences.fetchOrCreate(in: modelContext)

        Form {
            Section("Defaults") {
                Picker("Default Expiration", selection: $selectedPreset) {
                    ForEach(ExpirationPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .onChange(of: selectedPreset) { _, newValue in
                    preferences.defaultExpirationPreset = newValue.rawValue
                    try? modelContext.save()
                }

                Toggle("Auto-delete expired", isOn: $autoDeleteExpired)
                    .onChange(of: autoDeleteExpired) { _, newValue in
                        preferences.autoDeleteExpired = newValue
                        try? modelContext.save()
                    }

                Toggle("Notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        preferences.notificationsEnabled = newValue
                        try? modelContext.save()
                    }
            }

            Section("Maintenance") {
                Button("Run Cleanup Now") {
                    appManager.runCleanupIfNeeded(container: modelContext.container, force: true)
                }
            }

            Section("About") {
                Text("Forgetful keeps temporary memories local on your device. Images live in the app sandbox and metadata stays in SwiftData.")
                Text("Save important items to Photos before they expire. Exporting to Photos does not remove them from Forgetful.")
            }

            #if DEBUG
            Section("Debug") {
                Text("Last cleanup: \(preferences.lastCleanupDate?.formatted(date: .abbreviated, time: .shortened) ?? "Never")")
                Text("Asset store: Application Support/Forgetful")
            }
            #endif
        }
        .navigationTitle("Settings")
        .onAppear {
            selectedPreset = ExpirationPreset(rawValue: preferences.defaultExpirationPreset) ?? .sevenDays
            notificationsEnabled = preferences.notificationsEnabled
            autoDeleteExpired = preferences.autoDeleteExpired
        }
    }
}
