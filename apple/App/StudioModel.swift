import SwiftUI
import Observation
import ImageIO
import UniformTypeIdentifiers
#if os(iOS)
import Photos
#else
import AppKit
#endif

struct QueueJob: Identifiable, Codable {
    enum State: String, Codable { case waiting = "Wartet", connecting = "Sitzung wird geöffnet", running = "Wird berechnet", saving = "Wird heruntergeladen", cancelling = "Abbruch angefordert", done = "Lokal gespeichert", cancelled = "Abgebrochen", failed = "Fehler", uncertain = "Status unklar – Server prüfen" }
    var id = UUID()
    var created = Date()
    var request: GenerationRequest
    var state: State = .waiting
    var detail = ""
    var progress: Double?
    var batch = "0"
    var sessionID: String?
    var serverURL: String
    var active: Bool { [.connecting, .running, .saving, .cancelling].contains(state) }
}

@MainActor @Observable final class StudioModel {
    var draft = GenerationRequest()
    let configuredServerAddress = (Bundle.main.object(forInfoDictionaryKey: "VioraDefaultServerURL") as? String).flatMap { $0.isEmpty ? nil : $0 }
    var serverAddress = UserDefaults.standard.string(forKey: "serverAddress") ?? (Bundle.main.object(forInfoDictionaryKey: "VioraDefaultServerURL") as? String ?? "")
    var connected = false
    var connecting = false
    var connectionMessage = "Noch nicht verbunden"
    var connectionError: String?
    private var connectionAttempted = false
    private var lastConnectionAttempt = Date.distantPast
    var version = ""
    var models: [SwarmModel] = []
    var specs: [ParameterSpec] = []
    var jobs: [QueueJob] = []
    var gallery: [GalleryEntry] = []
    var galleryDirectory: URL?
    var selected: GalleryEntry?
    var previewData: Data?
    var videoSourceID: UUID?
    private var imageModeInput: String?
    private var videoModeInput: String?
    var recentImage: GalleryEntry? { selected?.mediaType == "image" ? selected : gallery.first(where: { $0.mediaType == "image" }) }
    var inputImageData: Data? {
        guard let raw=draft.initImage, let comma=raw.firstIndex(of:",") else { return nil }
        return Data(base64Encoded:String(raw[raw.index(after:comma)...]))
    }
    var error: String?
    var notice: String?
    var paused = false
    var tab = "Erstellen"
    var showSettings = false
    var serverStatus: ServerStatus?
    private var client: SwarmClient?
    private var activeClient: SwarmClient?
    private var worker: Task<Void, Never>?
    private var scope: URL?
    private let support: URL
    var activeJob: QueueJob? { jobs.first(where: \.active) }
    var activeStatusText: String {
        guard let job=activeJob else {return "Bereit"}
        if job.state == .running {
            if (serverStatus?.waiting_backends ?? 0) > 0 {return "Wartet auf freien Server"}
            if (serverStatus?.loading_models ?? 0) > 0 {return "Modelle werden geladen"}
            if (serverStatus?.waiting_gens ?? 0) > 0 && (serverStatus?.live_gens ?? 0) == 0 {return "Wartet auf dem Server"}
        }
        return job.state.rawValue
    }
    var busy: Bool { activeJob != nil }
    var videoSupported: Bool { specs.contains { $0.id == "videoswapmodel" } }
    var videoDuration: Double { Double(draft.frames-1)/Double(max(1,draft.fps)) }
    func setVideoDuration(_ seconds: Double) { draft.frames=VideoPlan.frameCount(seconds:seconds,fps:draft.fps) }
    func setVideoFPS(_ fps: Int) {
        let seconds=videoDuration
        draft.fps=fps; draft.frames=VideoPlan.frameCount(seconds:seconds,fps:fps)
    }
    var canGenerate: Bool { connected && !draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !draft.model.isEmpty && galleryDirectory != nil && (!draft.video || (draft.initImage != nil && !draft.videoModel.isEmpty && !draft.swapModel.isEmpty)) }
    init() {
        support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("VioraStudio", isDirectory: true)
        draft.width = 768; draft.height = 1344
        do {
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            let journal = support.appendingPathComponent("queue.json")
            if FileManager.default.fileExists(atPath: journal.path) {
                jobs = try JSONDecoder().decode([QueueJob].self, from: Data(contentsOf: journal))
                for index in jobs.indices where jobs[index].active || jobs[index].state == .waiting {
                    jobs[index].state = .uncertain
                    jobs[index].detail = "App wurde geschlossen. Dieser Auftrag wird nicht automatisch erneut gesendet."
                    paused = true
                }
            }
            #if os(macOS)
            if let bookmark = UserDefaults.standard.data(forKey: "galleryBookmark") {
                var stale = false
                let url = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &stale)
                guard url.startAccessingSecurityScopedResource() else { throw StudioError.message("Galerieordner nicht erreichbar. SSD anschließen und Ordner erneut wählen.") }
                scope = url
                galleryDirectory = url
                if stale { UserDefaults.standard.set(try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil), forKey: "galleryBookmark") }
            } else { galleryDirectory = support.appendingPathComponent("Gallery", isDirectory: true) }
            #else
            galleryDirectory = support.appendingPathComponent("Gallery", isDirectory: true)
            #endif
            try reloadGallery()
        } catch { self.error = "Lokale Daten: \(error.localizedDescription)" }
    }
    func restoreConnection() async {
        guard !connectionAttempted, !serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        await connect()
    }
    func reconnectIfNeeded() async {
        guard connectionAttempted, Date().timeIntervalSince(lastConnectionAttempt) > 20,
              !serverAddress.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return }
        await connect()
    }
    func serverAddressChanged() {
        guard !connecting else { return }
        connected = false; models = []; specs = []; version = ""; client = nil
        connectionError = nil; connectionMessage = "Bereit zum Verbinden"
    }
    func connect() async {
        guard !busy, !connecting else { return }
        connectionAttempted = true
        lastConnectionAttempt = Date()
        connected = false; connecting = true; models = []; specs = []; version = ""; client = nil
        connectionError = nil; connectionMessage = "Server wird kontaktiert …"
        defer { connecting = false }
        do {
            let endpoint = try ServerEndpoint.resolving(serverAddress, knownAddress: configuredServerAddress)
            serverAddress = endpoint.base.absoluteString
            let service = SwarmClient(endpoint: endpoint)
            let session = try await service.newSession()
            connectionMessage = "Modelle werden geladen …"
            let available = try await service.models(session.session_id)
            connectionMessage = "Funktionen werden geprüft …"
            let parameters = try await service.parameters(session.session_id)
            client = service; models = available; specs = parameters; version = session.version ?? "Unbekannt"; connected = true
            connectionMessage = "Verbunden · \(available.count) Modelle verfügbar"
            UserDefaults.standard.set(serverAddress, forKey: "serverAddress")
            UserDefaults.standard.set(Date(), forKey: "lastConnectedAt")
            UserDefaults.standard.set(version, forKey: "lastConnectedVersion")
            UserDefaults.standard.set(available.count, forKey: "lastConnectedModelCount")
            UserDefaults.standard.removeObject(forKey:"lastConnectionError")
            if !models.contains(where: { $0.name == draft.model }) { draft.model = models.first(where: { !$0.isVideo })?.name ?? "" }
            draft.videoModel = models.first(where: { $0.name.lowercased().contains("highnoise") })?.name ?? ""
            draft.swapModel = models.first(where: { $0.name.lowercased().contains("lownoise") })?.name ?? ""
        } catch {
            connectionError = Self.readableError(error)
            connectionMessage = "Verbindung fehlgeschlagen"
            UserDefaults.standard.set(connectionError,forKey:"lastConnectionError")
        }
    }
    func selectMode(_ video: Bool) {
        guard video != draft.video else { return }
        if draft.video { videoModeInput = draft.initImage } else { imageModeInput = draft.initImage }
        draft.video = video
        draft.initImage = video ? videoModeInput : imageModeInput
        draft.width = video ? 512 : 768; draft.height = video ? 320 : 1344
        draft.cfg = video ? 3.5 : 7; draft.scheduler = video ? "simple" : "normal"
        if video, let image=recentImage, videoSourceID != image.id || draft.initImage == nil { useGeneratedImage(image) }
    }
    func useGeneratedImage(_ entry: GalleryEntry? = nil) {
        guard let image=entry ?? recentImage, image.mediaType == "image", let url=mediaURL(image) else { return }
        if importImage(url) { videoSourceID=image.id }
    }
    func enqueue() {
        do {
            _ = try draft.payload(session: "validation", models: models, specs: specs)
            guard connected, galleryDirectory != nil else { throw StudioError.message("Bitte Server verbinden und Galerieordner wählen.") }
            jobs.append(QueueJob(request: draft, serverURL: serverAddress))
            try saveJournal()
            startNext()
        } catch { report(error) }
    }
    private func startNext() {
        guard worker == nil, !paused, let index = jobs.firstIndex(where: { $0.state == .waiting }) else { return }
        let id = jobs[index].id
        jobs[index].state = .connecting
        worker = Task { await run(id) }
    }
    private func change(_ id: UUID, _ body: (inout QueueJob) -> Void) { if let index = jobs.firstIndex(where: { $0.id == id }) { body(&jobs[index]) } }
    private func run(_ id: UUID) async {
        var monitor:Task<Void,Never>?
        defer { monitor?.cancel(); worker = nil; activeClient = nil; startNext() }
        guard let job = jobs.first(where: { $0.id == id }) else { return }
        var submitted = false
        do {
            let service = SwarmClient(endpoint: try ServerEndpoint(job.serverURL)); activeClient = service
            let session = try await service.newSession()
            try Task.checkCancellation()
            change(id) { $0.sessionID = session.session_id }
            let payload = try job.request.payload(session: session.session_id, models: models, specs: specs)
            change(id) { $0.state = .running; $0.detail = "Warte auf Serverfortschritt …" }
            try saveJournal()
            submitted = true; previewData = nil
            serverStatus=nil
            monitor=Task { [weak self] in
                while !Task.isCancelled {
                    if let status=try? await service.status(session.session_id) {self?.serverStatus=status}
                    do {try await Task.sleep(for:.seconds(3))} catch {return}
                }
            }
            let results = try await service.generate(payload) { [weak self] event in
                guard let self else { return }
                switch event {
                case .status(let status): self.serverStatus = status
                case .progress(let progress):
                    self.change(id) { $0.progress = progress.overall; $0.batch = progress.batch; $0.detail = "Server berechnet Ergebnis \((Int(progress.batch) ?? 0) + 1)" }
                    if let preview = progress.preview, let comma = preview.firstIndex(of: ","), preview.hasPrefix("data:image/") {
                        self.previewData = Data(base64Encoded: String(preview[preview.index(after: comma)...]))
                    }
                default: break
                }
            }
            try Task.checkCancellation()
            if jobs.first(where: { $0.id == id })?.state == .cancelling { return }
            guard !results.isEmpty else { throw StudioError.message("Der Server hat kein fertiges Ergebnis zurückgegeben.") }
            guard let galleryDirectory else { throw StudioError.message("Galerieordner fehlt.") }
            change(id) { $0.state = .saving; $0.progress = nil; $0.detail = "Ergebnisse werden auf diesem Gerät gespeichert." }
            let store = try GalleryStore(directory: galleryDirectory)
            for result in results {
                let temporary = try await service.download(result)
                defer { try? FileManager.default.removeItem(at: temporary) }
                let entry = try store.save(temporary: temporary, result: result, request: job.request)
                gallery.insert(entry, at: 0); selected = entry
            }
            change(id) { $0.state = .done; $0.detail = "\(results.count) Ergebnis(se) lokal gespeichert."; $0.progress = nil }
            previewData = nil; try saveJournal()
        } catch {
            let cancelled = jobs.first(where: { $0.id == id })?.state
            if cancelled != .cancelled && cancelled != .cancelling {
                change(id) { $0.state = submitted ? .uncertain : .failed; $0.detail = error.localizedDescription; $0.progress = nil }
                paused = true; connected = false
                report(error)
            }
            do { try saveJournal() } catch { report(error) }
        }
    }
    func cancel(_ id: UUID) async {
        guard let job = jobs.first(where: { $0.id == id }) else { return }
        if job.state == .waiting { change(id) { $0.state = .cancelled }; persist(); return }
        paused = true
        if job.state == .connecting { worker?.cancel(); change(id) { $0.state = .cancelled }; persist(); return }
        if job.state == .saving { worker?.cancel(); change(id) { $0.state = .cancelled; $0.detail = "Download gestoppt; bereits gespeicherte Ergebnisse bleiben erhalten." }; persist(); return }
        guard let sessionID = job.sessionID else { return }
        change(id) { $0.state = .cancelling }
        do {
            let service = try activeClient ?? SwarmClient(endpoint: ServerEndpoint(job.serverURL))
            try await service.interrupt(sessionID)
            worker?.cancel()
            change(id) { $0.state = .cancelled; $0.progress = nil; $0.detail = "Server bestätigt: Sitzung hat keine aktiven Aufträge." }
        } catch { change(id) { $0.state = .uncertain; $0.detail = error.localizedDescription }; report(error) }
        persist()
    }
    func resumeQueue() { paused = false; startNext() }
    func removeJob(_ id: UUID) async {
        guard let job=jobs.first(where:{$0.id == id}) else { return }
        if job.active || (job.state == .uncertain && job.sessionID != nil) {
            await cancel(id)
            guard let current=jobs.first(where:{$0.id == id}), current.state == .cancelled || current.state == .done else { return }
        }
        jobs.removeAll { $0.id == id }
        persist()
    }
    private func saveJournal() throws {
        var safe = jobs
        for i in safe.indices { safe[i].request = safe[i].request.withoutImage }
        try JSONEncoder().encode(safe).write(to: support.appendingPathComponent("queue.json"), options: .atomic)
    }
    private func persist() { do { try saveJournal() } catch { report(error) } }
    func reloadGallery() throws {
        guard let galleryDirectory else { return }
        gallery = try GalleryStore(directory: galleryDirectory).load()
    }
    func chooseGallery(_ url: URL) {
        guard !busy else { return }
        do {
            #if os(macOS)
            guard url.startAccessingSecurityScopedResource() else { throw StudioError.message("Zugriff auf diesen Ordner wurde nicht freigegeben.") }
            do {
                let store = try GalleryStore(directory: url)
                let entries = try store.load()
                let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                scope?.stopAccessingSecurityScopedResource(); scope = url
                UserDefaults.standard.set(bookmark, forKey: "galleryBookmark")
                galleryDirectory = url; gallery = entries; selected = nil
            } catch { url.stopAccessingSecurityScopedResource(); throw error }
            #endif
        } catch { report(error) }
    }
    func mediaURL(_ entry: GalleryEntry) -> URL? { galleryDirectory?.appendingPathComponent(entry.filename) }
    func toggleFavorite(_ entry: GalleryEntry) {
        guard let directory = galleryDirectory, let index = gallery.firstIndex(where: { $0.id == entry.id }) else { return }
        do {
            var updated = gallery[index]; updated.favorite.toggle()
            try GalleryStore(directory: directory).update(updated); gallery[index] = updated
            if selected?.id == updated.id { selected = updated }
        } catch { report(error) }
    }
    @discardableResult func importImage(_ url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 2048, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { throw StudioError.message("Dieses Bild konnte nicht geöffnet werden.") }
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { throw StudioError.message("Bildimport fehlgeschlagen.") }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw StudioError.message("Bildimport fehlgeschlagen.") }
            draft.initImage = "data:image/jpeg;base64,\((data as Data).base64EncodedString())"
            if draft.video { videoSourceID=nil }
            return true
        } catch { report(error); return false }
    }
    func animate(_ entry: GalleryEntry) {
        guard entry.mediaType == "image" else { return }
        selectMode(true); useGeneratedImage(entry); tab = "Erstellen"
    }
    #if os(iOS)
    func saveToPhotos(_ entry: GalleryEntry) async {
        guard let url = mediaURL(entry) else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { error = "Fotos-Zugriff wurde verweigert. Du kannst die Datei weiterhin teilen oder in Dateien sichern."; return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                if entry.mediaType == "video" { PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) }
                else { PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url) }
            }
            notice = "In Fotos gespeichert."
        } catch { report(error) }
    }
    #endif
    func report(_ error: Error) {
        self.error = Self.readableError(error)
    }
    private static func readableError(_ error: Error) -> String {
        if let url = error as? URLError {
            switch url.code {
            case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot: return "Die verschlüsselte Verbindung konnte nicht bestätigt werden. Tailscale und das Serverzertifikat prüfen."
            case .cannotFindHost: return "Servername nicht gefunden. Schreibweise und Tailscale-Verbindung auf diesem Gerät prüfen."
            case .cannotConnectToHost: return "Server nicht erreichbar. Port der Adresse, laufendes SwarmUI und Tailscale auf beiden Geräten prüfen."
            case .notConnectedToInternet: return "Keine Netzwerkverbindung. WLAN oder Mobilfunk und Tailscale einschalten."
            case .timedOut: return "Der Server antwortet nicht rechtzeitig. Tailscale auf diesem Gerät und den Windows-Server prüfen, dann erneut verbinden."
            default: return error.localizedDescription
            }
        } else { return error.localizedDescription }
    }
}
