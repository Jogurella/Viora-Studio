import Foundation

@main struct LiveSmoke {
    @MainActor static func main() async throws {
        setbuf(stdout,nil)
        let args = CommandLine.arguments
        guard args.count >= 3 else { throw StudioError.message("Usage: LiveSmoke https://server output-directory [input-image-for-video]") }
        let output = URL(fileURLWithPath: args[2], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let service = SwarmClient(endpoint: try ServerEndpoint(args[1]))
        let session = try await service.newSession()
        try Data(session.session_id.utf8).write(to: output.appendingPathComponent("session.local.txt"), options: .atomic)
        let models = try await service.models(session.session_id)
        let parameters = try await service.parameters(session.session_id)
        var request = GenerationRequest()
        request.model = models.first { !$0.isVideo }?.name ?? ""
        request.prompt = "a tiny ceramic fox on a plain dark blue table, soft studio light"
        request.styleSuffix = ""; request.seed = 762491; request.width = 512; request.height = 512; request.steps = 10; request.cfg = 6
        if args.count >= 4 {
            request.video = true; request.width = 512; request.height = 320; request.frames = 9; request.steps = 10; request.cfg = 3.5; request.scheduler = "simple"
            request.prompt = "The camera slowly moves closer to the stationary ceramic fox. Subtle light movement."
            request.videoModel = models.first { $0.name.lowercased().contains("highnoise") }?.name ?? ""
            request.swapModel = models.first { $0.name.lowercased().contains("lownoise") }?.name ?? ""
            request.initImage = "data:image/png;base64," + (try Data(contentsOf: URL(fileURLWithPath: args[3]))).base64EncodedString()
            if args.count >= 6, let seconds=Double(args[4]),let fps=Int(args[5]) {
                request.fps=fps;request.frames=VideoPlan.frameCount(seconds:seconds,fps:fps)
            }
            if args.count >= 7,let steps=Int(args[6]) {request.steps=steps;request.width=320;request.height=320}
        }
        let payload = try request.payload(session: session.session_id, models: models, specs: parameters)
        print("Connected:", session.version ?? "unknown", "models:", models.count, "mode:", request.video ? "video" : "image")
        let start = Date()
        let results = try await service.generate(payload) { event in
            switch event {
            case .progress(let p): print("progress", p.overall ?? -1, "step", p.current ?? -1)
            case .status(let s): print("status",s.summary)
            case .result(let r): print("result batch",r.batch)
            case .complete: print("server completed")
            case .discard(let d): print("discard",d)
            default: break
            }
        }
        guard !results.isEmpty else { throw StudioError.message("No results") }
        let store = try GalleryStore(directory: output)
        for result in results {
            let temporary = try await service.download(result)
            let entry = try store.save(temporary: temporary, result: result, request: request)
            try? FileManager.default.removeItem(at: temporary)
            print("SAVED",store.directory.appendingPathComponent(entry.filename).path)
        }
        let reopened = try GalleryStore(directory: output).load()
        print("REOPENED", reopened.count, "elapsed", Date().timeIntervalSince(start))
    }
}
