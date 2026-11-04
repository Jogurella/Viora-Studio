import Foundation

// Default platform certificate validation is always used. Reject redirects to other origins.
private final class OriginDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let old = task.originalRequest?.url, let new = request.url,
              old.scheme == new.scheme, old.host == new.host, old.port == new.port else { completionHandler(nil); return }
        completionHandler(request)
    }
}
@MainActor public final class SwarmClient {
    public let endpoint: ServerEndpoint
    private let session: URLSession
    private let delegate = OriginDelegate()
    private var socket: URLSessionWebSocketTask?
    public init(endpoint: ServerEndpoint) {
        self.endpoint = endpoint
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 3600
        configuration.httpCookieStorage = nil
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
    public func post(_ route: String, _ input: [String: Any]) async throws -> Data {
        var request = URLRequest(url: endpoint.api(route))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: input)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw StudioError.message("Serverantwort HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0). Bei Anmeldungspflicht den Serverzugang prüfen.")
        }
        if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] { try checkError(root) }
        return data
    }
    public func newSession() async throws -> SessionResponse { try await JSONDecoder().decode(SessionResponse.self, from: post("GetNewSession", [:])) }
    public func models(_ id: String) async throws -> [SwarmModel] {
        try await JSONDecoder().decode(ModelResponse.self, from: post("ListModels", ["session_id": id, "path": "", "depth": 10, "subtype": "Stable-Diffusion"])).files.sorted { $0.name < $1.name }
    }
    public func parameters(_ id: String) async throws -> [ParameterSpec] {
        try await JSONDecoder().decode(ParametersResponse.self, from: post("ListT2IParams", ["session_id": id])).list
    }
    public func status(_ id: String) async throws -> ServerStatus {
        struct Response: Decodable { let status: ServerStatus }
        return try await JSONDecoder().decode(Response.self,from:post("GetCurrentStatus",["session_id":id])).status
    }
    public func generate(_ payload: [String: Any], onEvent: (ServerEvent) -> Void) async throws -> [GenerationResult] {
        let ws = session.webSocketTask(with: endpoint.socket)
        ws.maximumMessageSize = 32 * 1024 * 1024
        socket = ws
        ws.resume()
        defer { ws.cancel(with: .normalClosure, reason: nil); socket = nil }
        // Deliberately sent once. A lost connection must never resubmit a GPU job.
        try await ws.send(.data(JSONSerialization.data(withJSONObject: payload)))
        var results: [String: GenerationResult] = [:]
        while true {
            try Task.checkCancellation()
            let message = try await ws.receive()
            let data: Data
            switch message { case .data(let d): data = d; case .string(let s): data = Data(s.utf8); @unknown default: continue }
            let event = try ServerEvent.parse(data)
            onEvent(event)
            switch event {
            case .result(let result): results[result.batch] = result
            case .discard(let indices): indices.forEach { results.removeValue(forKey: $0) }
            case .complete: return results.values.sorted { $0.batch < $1.batch }
            default: break
            }
        }
    }
    public func interrupt(_ id: String) async throws {
        _ = try await post("InterruptAll", ["session_id": id, "other_sessions": false])
        for _ in 0..<15 {
            let data = try await post("GetCurrentStatus", ["session_id": id])
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let value = root?["status"] as? [String: Any] {
                let keys = ["waiting_gens", "loading_models", "waiting_backends", "live_gens"]
                if keys.allSatisfy({ (value[$0] as? Int) == 0 }) { closeSocket(); return }
            }
            try await Task.sleep(for: .seconds(1))
        }
        throw StudioError.message("Abbruch angefordert, aber vom Server noch nicht bestätigt. Queue pausiert; Serverstatus prüfen.")
    }
    public func closeSocket() { socket?.cancel(with: .goingAway, reason: nil) }
    public func download(_ result: GenerationResult) async throws -> URL {
        if result.path.hasPrefix("data:") {
            guard let comma = result.path.firstIndex(of: ","), result.path[..<comma].hasSuffix(";base64"),
                  let data = Data(base64Encoded: String(result.path[result.path.index(after: comma)...])), data.count <= 32 * 1024 * 1024 else {
                throw StudioError.message("Ungültiges eingebettetes Ergebnis.")
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try data.write(to: url, options: .atomic)
            return url
        }
        let url = try endpoint.resultURL(result.path)
        let (temporary, response) = try await session.download(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw StudioError.message("Der Ergebnisdownload ist fehlgeschlagen.") }
        try Task.checkCancellation()
        return temporary
    }
}
