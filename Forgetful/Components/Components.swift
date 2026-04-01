import SwiftData
import SwiftUI

struct MemoryThumbnailCard: View {
    let thumbnail: UIImage?
    let badgeText: String
    let badgeTone: ExpirationService.LibraryBadgeTone

    private let cardHeight: CGFloat = 178
    private let cornerRadius: CGFloat = 18

    var body: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Rectangle()
                    .fill(.tertiary.opacity(0.18))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: cardHeight)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            LinearGradient(
                colors: [.clear, .black.opacity(0.08), .black.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            CountdownBadge(text: badgeText, tone: badgeTone)
                .padding(.trailing, 10)
                .padding(.bottom, 10)
                .allowsHitTesting(false)
        }
    }
}

struct CountdownBadge: View {
    let text: String
    let tone: ExpirationService.LibraryBadgeTone

    var body: some View {
        HStack(spacing: 0) {
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            .ultraThinMaterial,
            in: Capsule()
        )
        .background(
            Capsule()
                .fill(tintColor.opacity(backgroundOpacity))
        )
        .overlay(
            Capsule()
                .strokeBorder(borderColor, lineWidth: 0.8)
        )
        .shadow(color: shadowColor, radius: 8, y: 3)
    }

    private var tintColor: Color {
        switch tone {
        case .urgent:
            return .red
        case .tomorrow:
            return Color(red: 1.0, green: 0.7, blue: 0.22)
        case .warning:
            return .orange
        case .calm:
            return Color(red: 0.95, green: 0.78, blue: 0.42)
        case .archived:
            return .gray
        }
    }

    private var backgroundOpacity: Double {
        switch tone {
        case .urgent:
            return 0.32
        case .tomorrow:
            return 0.28
        case .warning:
            return 0.22
        case .calm:
            return 0.14
        case .archived:
            return 0.12
        }
    }

    private var borderColor: Color {
        switch tone {
        case .urgent, .tomorrow, .warning:
            return tintColor.opacity(0.55)
        case .calm:
            return .white.opacity(0.18)
        case .archived:
            return .white.opacity(0.12)
        }
    }

    private var textColor: Color {
        switch tone {
        case .urgent, .tomorrow:
            return .white
        case .warning:
            return Color(red: 1.0, green: 0.96, blue: 0.9)
        case .calm, .archived:
            return .white
        }
    }

    private var shadowColor: Color {
        switch tone {
        case .urgent:
            return .red.opacity(0.22)
        case .tomorrow:
            return Color.orange.opacity(0.2)
        default:
            return .black.opacity(0.22)
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 62, height: 62)
                .background(.secondary.opacity(0.12), in: Circle())

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(.quaternary.opacity(0.8), lineWidth: 1)
        )
    }
}

struct ExpirationPresetPicker: View {
    @Binding var selectedPreset: ExpirationPreset

    private let presets: [ExpirationPreset] = [.oneDay, .sevenDays, .thirtyDays]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Expiration")
                .font(.subheadline.weight(.semibold))

            Menu {
                ForEach(presets) { preset in
                    Button {
                        selectedPreset = preset
                    } label: {
                        if selectedPreset == preset {
                            Label(title(for: preset), systemImage: "checkmark")
                        } else {
                            Text(title(for: preset))
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Text(title(for: selectedPreset))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
        }
    }

    private func title(for preset: ExpirationPreset) -> String {
        switch preset {
        case .oneDay:
            return "1 Day"
        case .sevenDays:
            return "7 Days"
        case .thirtyDays:
            return "1 Month"
        case .threeDays:
            return "3 Days"
        case .never:
            return "Never"
        }
    }
}

struct NoteInputCard: View {
    @Binding var note: String

    private let maxLength = 140
    private let warningThreshold = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note")
                .font(.subheadline.weight(.semibold))

            TextField("Optional note", text: $note, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...2)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                .onChange(of: note) { _, newValue in
                    if newValue.count > maxLength {
                        note = String(newValue.prefix(maxLength))
                    }
                }

            if note.count >= warningThreshold {
                HStack {
                    Spacer()
                    Text("\(note.count)/\(maxLength)")
                        .font(.caption)
                        .foregroundStyle(note.count >= maxLength ? .orange : .secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}

struct FolderPickerRow: View {
    let title: String
    let subtitle: String?
    let symbol: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(14)
            .background(Color.secondary.opacity(isSelected ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct MemoryCardGrid: View {
    let items: [MemoryItem]
    let assetStore: AssetStore
    let expirationService: ExpirationService

    private let columns = [
        GridItem(.flexible(), spacing: 10, alignment: .top),
        GridItem(.flexible(), spacing: 10, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 10) {
            ForEach(items, id: \.id) { item in
                NavigationLink {
                    MemoryDetailView(item: item)
                } label: {
                    MemoryThumbnailCard(
                        thumbnail: assetStore.loadThumbnail(filename: item.thumbnailFilename),
                        badgeText: expirationService.libraryBadgeText(for: item),
                        badgeTone: expirationService.libraryBadgeTone(for: item)
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct CompactEmptyStateView: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}
