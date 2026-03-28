import SwiftData
import SwiftUI

struct FolderCard: View {
    let folder: FolderEntity?
    let count: Int

    private var title: String { folder?.name ?? "Unsorted" }
    private var symbol: String { folder?.iconName ?? "tray" }
    private var tint: Color { Color(folderColorName: folder?.colorName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

            Spacer(minLength: 0)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text("\(count) active")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(.quaternary.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 16, y: 8)
    }
}

struct FolderBrowseCard: View {
    let folder: FolderEntity
    let count: Int
    let isSelected: Bool

    private var tint: Color { Color(folderColorName: folder.colorName) }
    private var symbol: String { folder.iconName ?? "folder" }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? tint : .secondary)
                .frame(width: 24, height: 24)
                .background((isSelected ? tint : Color.secondary).opacity(isSelected ? 0.16 : 0.1), in: RoundedRectangle(cornerRadius: 8))

            Text(folder.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            if count > 0 {
                Text("\(count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            isSelected ? Color.primary.opacity(0.08) : Color(.secondarySystemGroupedBackground),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(isSelected ? Color.primary.opacity(0.22) : Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

struct MemoryThumbnailCard: View {
    let item: MemoryItem
    let thumbnail: UIImage?
    let countdownText: String
    let folderName: String?

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

            CountdownBadge(text: countdownText)
                .padding(10)

            VStack {
                Spacer()

                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let folderName {
                            Label(folderName, systemImage: "folder")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.92))
                                .lineLimit(1)
                        }

                        if let note = item.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.95))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 6)

                    HStack(spacing: 6) {
                        if item.note?.isEmpty == false && folderName == nil {
                            Image(systemName: "note.text")
                        }
                        if item.wasExportedToPhotos {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                }
                .padding(10)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.68)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct CountdownBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
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
                ForEach(ExpirationPreset.allCases) { preset in
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
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
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
    let folderNameProvider: (MemoryItem) -> String?

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 14)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(items, id: \.id) { item in
                NavigationLink {
                    MemoryDetailView(item: item)
                } label: {
                    MemoryThumbnailCard(
                        item: item,
                        thumbnail: assetStore.loadThumbnail(filename: item.thumbnailFilename),
                        countdownText: expirationService.countdownText(for: item),
                        folderName: folderNameProvider(item)
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
