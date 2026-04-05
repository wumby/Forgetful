import SwiftData
import SwiftUI

struct MemoryPolaroidCard: View {
    enum Style {
        case thumbnail
        case detail
        case export

        var metrics: Metrics {
            switch self {
            case .thumbnail:
                Metrics(
                    photoHeight: 168,
                    footerMinHeightWithNote: 48,
                    footerMinHeightWithoutNote: 34,
                    outerCornerRadius: 8,
                    innerCornerRadius: 3,
                    outerPadding: 10,
                    horizontalFooterPadding: 12,
                    topFooterPaddingWithNote: 10,
                    topFooterPaddingWithoutNote: 8,
                    bottomFooterPadding: 8,
                    noteFontSize: 14,
                    dateFontSize: 13,
                    badgeTopInset: 10,
                    badgeTrailingInset: 10
                )
            case .detail:
                Metrics(
                    photoHeight: 356,
                    footerMinHeightWithNote: 84,
                    footerMinHeightWithoutNote: 58,
                    outerCornerRadius: 16,
                    innerCornerRadius: 6,
                    outerPadding: 14,
                    horizontalFooterPadding: 16,
                    topFooterPaddingWithNote: 14,
                    topFooterPaddingWithoutNote: 12,
                    bottomFooterPadding: 14,
                    noteFontSize: 20,
                    dateFontSize: 14,
                    badgeTopInset: 14,
                    badgeTrailingInset: 14
                )
            case .export:
                Metrics(
                    photoHeight: 1180,
                    footerMinHeightWithNote: 220,
                    footerMinHeightWithoutNote: 156,
                    outerCornerRadius: 28,
                    innerCornerRadius: 10,
                    outerPadding: 24,
                    horizontalFooterPadding: 28,
                    topFooterPaddingWithNote: 24,
                    topFooterPaddingWithoutNote: 20,
                    bottomFooterPadding: 24,
                    noteFontSize: 54,
                    dateFontSize: 30,
                    badgeTopInset: 26,
                    badgeTrailingInset: 26
                )
            }
        }
    }

    struct Metrics {
        let photoHeight: CGFloat
        let footerMinHeightWithNote: CGFloat
        let footerMinHeightWithoutNote: CGFloat
        let outerCornerRadius: CGFloat
        let innerCornerRadius: CGFloat
        let outerPadding: CGFloat
        let horizontalFooterPadding: CGFloat
        let topFooterPaddingWithNote: CGFloat
        let topFooterPaddingWithoutNote: CGFloat
        let bottomFooterPadding: CGFloat
        let noteFontSize: CGFloat
        let dateFontSize: CGFloat
        let badgeTopInset: CGFloat
        let badgeTrailingInset: CGFloat
    }

    let image: UIImage?
    let note: String?
    let createdAt: Date
    let badgeText: String
    let badgeTone: ExpirationService.LibraryBadgeTone
    var style: Style = .thumbnail
    var showsBadge: Bool = true

    var body: some View {
        let metrics = style.metrics

        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let image {
                    Image(uiImage: image)
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
            .frame(height: metrics.photoHeight)
            .clipShape(RoundedRectangle(cornerRadius: metrics.innerCornerRadius))
            .overlay(alignment: .topTrailing) {
                if showsBadge {
                    CountdownBadge(text: badgeText, tone: badgeTone)
                        .padding(.trailing, metrics.badgeTrailingInset)
                        .padding(.top, metrics.badgeTopInset)
                        .allowsHitTesting(false)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if let noteText {
                    Text(noteText)
                        .font(.custom("Noteworthy-Bold", size: metrics.noteFontSize))
                        .foregroundStyle(Color.black.opacity(0.76))
                        .lineLimit(style == .thumbnail ? 2 : nil)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(dateText)
                    .font(.system(size: metrics.dateFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.45))
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
            .frame(maxWidth: .infinity, minHeight: footerMinHeight(for: metrics), alignment: .topLeading)
            .padding(.top, noteText == nil ? metrics.topFooterPaddingWithoutNote : metrics.topFooterPaddingWithNote)
            .padding(.bottom, metrics.bottomFooterPadding)
            .padding(.horizontal, metrics.horizontalFooterPadding)
            .background(Color.white)
        }
        .padding(metrics.outerPadding)
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
        .clipShape(RoundedRectangle(cornerRadius: metrics.outerCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: metrics.outerCornerRadius)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: style == .thumbnail ? 16 : 20, y: style == .thumbnail ? 9 : 10)
        .rotationEffect(.degrees(rotationAngle))
        .contentShape(RoundedRectangle(cornerRadius: metrics.outerCornerRadius))
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

    private func footerMinHeight(for metrics: Metrics) -> CGFloat {
        noteText == nil ? metrics.footerMinHeightWithoutNote : metrics.footerMinHeightWithNote
    }

    private var rotationAngle: Double {
        let seed = createdAt.timeIntervalSince1970.truncatingRemainder(dividingBy: 3)
        return (seed - 1.5) * 0.9
    }
}

struct MemoryThumbnailCard: View {
    let thumbnail: UIImage?
    let note: String?
    let createdAt: Date
    let badgeText: String
    let badgeTone: ExpirationService.LibraryBadgeTone

    var body: some View {
        MemoryPolaroidCard(
            image: thumbnail,
            note: note,
            createdAt: createdAt,
            badgeText: badgeText,
            badgeTone: badgeTone,
            style: .thumbnail
        )
    }
}

struct CountdownBadge: View {
    enum Style {
        case standard
        case prominent
    }

    let text: String
    let tone: ExpirationService.LibraryBadgeTone
    var style: Style = .standard

    var body: some View {
        HStack(spacing: 0) {
            Text(text)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
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

    private var fontSize: CGFloat {
        style == .prominent ? 12 : 10
    }

    private var horizontalPadding: CGFloat {
        style == .prominent ? 12 : 9
    }

    private var verticalPadding: CGFloat {
        style == .prominent ? 7 : 5
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

    private let presets: [ExpirationPreset] = [.threeDays, .sevenDays, .fourteenDays, .thirtyDays]

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
        case .sevenDays:
            return "7 Days"
        case .fourteenDays:
            return "14 Days"
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
