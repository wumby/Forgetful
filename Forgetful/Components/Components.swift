import SwiftData
import SwiftUI

struct MemoryThumbnailCard: View {
    let thumbnail: UIImage?
    let badgeText: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(.tertiary.opacity(0.18))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
            }

            CountdownBadge(text: badgeText)
                .padding(10)
        }
        .frame(height: 136)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct CountdownBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.55), in: Capsule())
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Expires")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(ExpirationPreset.selectableCases) { preset in
                    Button {
                        selectedPreset = preset
                    } label: {
                        Text(preset.title)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedPreset == preset ? Color.primary.opacity(0.12) : Color.secondary.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct NoteInputCard: View {
    @Binding var note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Note")
                .font(.headline)

            TextField("Add a short note", text: $note, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...5)
                .padding(14)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

struct FolderPickerRow: View {
    let title: String
    let subtitle: String
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
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(items, id: \.id) { item in
                NavigationLink {
                    MemoryDetailView(item: item)
                } label: {
                    MemoryThumbnailCard(
                        thumbnail: assetStore.loadThumbnail(filename: item.thumbnailFilename),
                        badgeText: item.createdAt.formatted(date: .abbreviated, time: .omitted)
                    )
                }
                .buttonStyle(.plain)
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
