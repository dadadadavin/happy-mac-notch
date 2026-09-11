import SwiftUI
import UniformTypeIdentifiers
import AppKit

public struct DropZoneWidget: View {
    @ObservedObject var vm: NotchViewModel
    @State private var isTargeted: Bool = false

    public init(vm: NotchViewModel) {
        self.vm = vm
    }

    public var body: some View {
        ZStack {
            // Background container with interactive drop glow
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isTargeted ? Color.blue.opacity(0.18) : Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isTargeted ? Color.blue.opacity(0.7) : Color.white.opacity(0.08),
                            lineWidth: isTargeted ? 1.5 : 0.5
                        )
                )

            if vm.droppedFiles.isEmpty {
                emptyDropView
            } else {
                populatedDropView
            }
        }
        .frame(height: 76)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .onDrop(of: [.fileURL, .url], isTargeted: $isTargeted) { providers in
            DropFileLoader.loadFiles(from: providers) { url in
                vm.addDroppedFile(url)
            }
            return true
        }
    }

    // Empty state prompt
    private var emptyDropView: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isTargeted ? Color.blue.opacity(0.35) : Color.white.opacity(0.08))
                    .frame(width: 44, height: 44)

                Image(systemName: isTargeted ? "arrow.down.doc.fill" : "tray.and.arrow.down.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(isTargeted ? Color.blue : Color.white.opacity(0.85))
                    .scaleEffect(isTargeted ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isTargeted)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(isTargeted ? "Drop to Park Files" : "Drop Shelf")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isTargeted ? Color.blue : Color.white)

                Text(isTargeted ? "Release mouse to hold files across spaces" : "Drag and park files here to hold across all desktop spaces")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // Populated state with parked files
    private var populatedDropView: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.droppedFiles, id: \.self) { url in
                        ParkedFileCard(url: url, vm: vm)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }

            VStack(spacing: 5) {
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        vm.clearDroppedFiles()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                        Text("Clear")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.red.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.red.opacity(0.15)))
                }
                .buttonStyle(.plain)

                Text("\(vm.droppedFiles.count) parked")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.trailing, 10)
        }
    }
}

// MARK: - Parked File Card
private struct ParkedFileCard: View {
    let url: URL
    @ObservedObject var vm: NotchViewModel
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            // Native macOS file icon thumbnail
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 110, alignment: .leading)

                Text(fileSizeString)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Remove button
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    vm.removeDroppedFile(url)
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(isHovered ? Color.white.opacity(0.7) : Color.white.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        // Native Drag OUT to any application or Finder!
        .onDrag {
            let provider = NSItemProvider(object: url as NSURL)
            provider.suggestedName = url.lastPathComponent
            return provider
        }
        // Click to reveal in Finder
        .onTapGesture {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                self.isHovered = hovering
            }
        }
        .contextMenu {
            Button("Open File") {
                NSWorkspace.shared.open(url)
            }
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            Divider()
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
            }
            Button("Remove from Shelf", role: .destructive) {
                vm.removeDroppedFile(url)
            }
        }
    }

    private var fileSizeString: String {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            if values.isDirectory == true {
                return "Folder"
            }
            if let size = values.fileSize {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useAll]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: Int64(size))
            }
        } catch {}
        return "File"
    }
}

// MARK: - Robust Drop File Loader
public enum DropFileLoader {
    public static func loadFiles(from providers: [NSItemProvider], completion: @escaping @MainActor @Sendable (URL) -> Void) {
        for provider in providers {
            // First check for standard fileURL
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let url = parseItem(item) {
                        Task { @MainActor in
                            completion(url)
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    if let url = parseItem(item) {
                        Task { @MainActor in
                            completion(url)
                        }
                    }
                }
            }
        }
    }

    private static func parseItem(_ item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data {
            if let url = URL(dataRepresentation: data, relativeTo: nil) {
                return url
            }
            if let string = String(data: data, encoding: .utf8), let url = URL(string: string) {
                return url
            }
        }
        if let string = item as? String {
            if string.hasPrefix("file://") {
                return URL(string: string)
            }
            return URL(fileURLWithPath: string)
        }
        return nil
    }
}
