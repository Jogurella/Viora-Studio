import Foundation

public struct GalleryEntry: Codable, Identifiable, Sendable {
    public let id: UUID
    public let filename: String
    public let date: Date
    public let mediaType: String
    public let request: GenerationRequest
    public let seed: Int64?
    public let serverMetadata: String?
    public var favorite: Bool
}
public struct GalleryStore {
    public let directory: URL
    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    public func load() throws -> [GalleryEntry] {
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return try urls.filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("viora-") }.map { url in
            let entry = try JSONDecoder().decode(GalleryEntry.self, from: Data(contentsOf: url))
            guard entry.filename == URL(fileURLWithPath: entry.filename).lastPathComponent else { throw StudioError.message("Ungültiger Dateiname in Galerie-Metadaten.") }
            return entry
        }.filter { FileManager.default.fileExists(atPath: directory.appendingPathComponent($0.filename).path) }.sorted { $0.date > $1.date }
    }
    public func save(temporary: URL, result: GenerationResult, request: GenerationRequest) throws -> GalleryEntry {
        try Task.checkCancellation()
        let handle = try FileHandle(forReadingFrom: temporary)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: 32) ?? Data()
        let bytes = [UInt8](header)
        let ext: String
        if bytes.starts(with: [137,80,78,71,13,10,26,10]) { ext = "png" }
        else if bytes.starts(with: [255,216,255]) { ext = "jpg" }
        else if String(data: header.prefix(3), encoding: .ascii) == "GIF" { ext = "gif" }
        else if bytes.count >= 12 && String(bytes: bytes[4..<8], encoding: .ascii) == "ftyp" { ext = "mp4" }
        else if bytes.count >= 12 && String(bytes: bytes[0..<4], encoding: .ascii) == "RIFF" && String(bytes: bytes[8..<12], encoding: .ascii) == "WEBP" { ext = "webp" }
        else { throw StudioError.message("Der Download ist kein unterstütztes Bild oder Video.") }
        let id = UUID()
        let filename = "viora-\(id.uuidString).\(ext)"
        let destination = directory.appendingPathComponent(filename)
        let staging = directory.appendingPathComponent(".\(id.uuidString).download")
        defer { try? FileManager.default.removeItem(at: staging) }
        try FileManager.default.copyItem(at: temporary, to: staging)
        try Task.checkCancellation()
        try FileManager.default.moveItem(at: staging, to: destination)
        let entry = GalleryEntry(id: id, filename: filename, date: Date(), mediaType: ext == "mp4" ? "video" : "image", request: request.withoutImage, seed: result.actualSeed ?? (request.seed >= 0 ? request.seed : nil), serverMetadata: result.metadata, favorite: false)
        do { try update(entry) } catch { try? FileManager.default.removeItem(at: destination); throw error }
        return entry
    }
    public func update(_ entry: GalleryEntry) throws {
        let data = try JSONEncoder().encode(entry)
        try data.write(to: directory.appendingPathComponent("viora-\(entry.id.uuidString).json"), options: .atomic)
    }
}
