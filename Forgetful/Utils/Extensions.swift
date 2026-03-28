import SwiftUI

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

extension Color {
    init(folderColorName: String?) {
        switch folderColorName {
        case "orange":
            self = .orange
        case "green":
            self = .green
        case "red":
            self = .red
        case "pink":
            self = .pink
        case "teal":
            self = .teal
        default:
            self = .blue
        }
    }
}

