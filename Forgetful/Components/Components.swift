import SwiftData
import SwiftUI

struct MemoryThumbnailCard: View {
    let thumbnail: UIImage?
    let note: String?
    let createdAt: Date
    let badgeText: String
    let badgeTone: ExpirationService.LibraryBadgeTone

    private let photoHeight: CGFloat = 168
    private let footerMinHeightWithNote: CGFloat = 48
    private let footerMinHeightWithoutNote: CGFloat = 34
    private let outerCornerRadius: CGFloat = 8
    private let innerCornerRadius: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Rectangle()
                        .fill(Color(red: 0.87, green: 0.86, blue: 0.82))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(height: photoHeight)
            .clipShape(RoundedRectangle(cornerRadius: innerCornerRadius))
            .overlay(alignment: .topTrailing) {
                CountdownBadge(text: badgeText, tone: badgeTone)
                    .padding(.trailing, 10)
                    .padding(.top, 10)
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let noteText {
                    Text(noteText)
                        .font(.custom("Noteworthy-Bold", size: 14))
                        .foregroundStyle(Color.black.opacity(0.76))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(dateText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.45))
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
            .frame(maxWidth: .infinity, minHeight: footerMinHeight, alignment: .topLeading)
            .padding(.top, noteText == nil ? 8 : 10)
            .padding(.bottom, noteText == nil ? 8 : 10)
            .padding(.horizontal, 12)
            .background(Color.white)
        }
        .padding(10)
        .frame(minWidth: 0, maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.97, blue: 0.94),
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: outerCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: outerCornerRadius)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 16, y: 9)
        .rotationEffect(.degrees(rotationAngle))
        .contentShape(RoundedRectangle(cornerRadius: outerCornerRadius))
    }

    private var noteText: String? {
        guard let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else {
            return nil
        }
        return note
    }

    private var dateText: String {
        createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    private var footerMinHeight: CGFloat {
        noteText == nil ? footerMinHeightWithoutNote : footerMinHeightWithNote
    }

    private var rotationAngle: Double {
        let seed = createdAt.timeIntervalSince1970.truncatingRemainder(dividingBy: 3)
        return (seed - 1.5) * 0.9
    }
}

struct CountdownBadge: View {
    let text: String
    let tone: ExpirationService.LibraryBadgeTone

    var body: some View {
        HStack(spacing: 0) {
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
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

struct ExpirationPresetPicker: View {
    @Binding var selectedPreset: ExpirationPreset

    private let presets: [ExpirationPreset] = [.oneDay, .threeDays, .sevenDays, .thirtyDays]

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
                        note: item.note,
                        createdAt: item.createdAt,
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
