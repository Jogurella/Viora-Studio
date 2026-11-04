import Foundation

public enum StudioError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

public struct ServerEndpoint: Sendable {
    public let base: URL
    public init(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard var parts = URLComponents(string: address),
              parts.scheme?.lowercased() == "https", let host = parts.host, !host.isEmpty,
              !host.contains(where: { $0.isWhitespace }),
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil else {
            throw StudioError.message("Bitte eine vollständige HTTPS-Serveradresse ohne Zugangsdaten eingeben.")
        }
        parts.scheme = "https"
        if !parts.path.hasSuffix("/") { parts.path += "/" }
        guard let url = parts.url else { throw StudioError.message("Die Serveradresse ist ungültig.") }
        base = url
    }
    // A private build may supply its known endpoint without putting that address in source control.
    // Only complete a matching bare host; never replace a different user-entered server or port.
    public static func resolving(_ text: String, knownAddress: String?) throws -> ServerEndpoint {
        let endpoint = try ServerEndpoint(text)
        if let knownAddress, let known = try? ServerEndpoint(knownAddress),
           endpoint.base.host?.lowercased() == known.base.host?.lowercased(), endpoint.base.port == nil,
           endpoint.base.path == "/", known.base.path == "/" { return known }
        return endpoint
    }
    public func api(_ route: String) -> URL { base.appendingPathComponent("API").appendingPathComponent(route) }
    public var socket: URL {
        var parts = URLComponents(url: api("GenerateText2ImageWS"), resolvingAgainstBaseURL: false)!
        parts.scheme = "wss"
        return parts.url!
    }
    public func resultURL(_ path: String) throws -> URL {
        guard let url = URL(string: path, relativeTo: base)?.absoluteURL,
              url.scheme == base.scheme, url.host == base.host, url.port == base.port,
              url.user == nil, url.password == nil else {
            throw StudioError.message("Das Ergebnis verweist auf einen anderen Server. Download wurde abgelehnt.")
        }
        return url
    }
}

public struct SwarmModel: Codable, Identifiable, Hashable, Sendable {
    public let name: String
    public let architecture: String?
    public var id: String { name }
    public var isVideo: Bool { (architecture ?? name).lowercased().contains("video") || name.lowercased().contains("wan") || (architecture ?? "").contains("i2v") }
}
public struct SessionResponse: Decodable, Sendable { public let session_id: String; public let version: String? }
public struct ModelResponse: Decodable { public let files: [SwarmModel] }
public struct ParameterSpec: Decodable, Sendable {
    public let id: String
    public let values: [String]?
    public let min: Double?
    public let max: Double?
}
public struct ParametersResponse: Decodable { public let list: [ParameterSpec] }
public struct ServerStatus: Codable, Sendable {
    public let waiting_gens: Int?
    public let loading_models: Int?
    public let waiting_backends: Int?
    public let live_gens: Int?
    public var summary: String { "\(waiting_gens ?? 0) warten · \(loading_models ?? 0) laden · \(live_gens ?? 0) aktiv" }
}
public struct GenerationProgress: Sendable {
    public let batch: String
    public let overall: Double?
    public let current: Double?
    public let preview: String?
}
public struct GenerationResult: Codable, Sendable {
    public let path: String
    public let batch: String
    public let metadata: String?
    public var actualSeed: Int64? {
        guard let metadata, let data = metadata.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let parameters = json["sui_image_params"] as? [String: Any] else { return nil }
        if let seed = parameters["seed"] as? NSNumber { return seed.int64Value }
        return (parameters["seed"] as? String).flatMap(Int64.init)
    }
}
public enum ServerEvent: Sendable {
    case status(ServerStatus), progress(GenerationProgress), result(GenerationResult), discard([String]), complete, ignored
    public static func parse(_ data: Data) throws -> ServerEvent {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw StudioError.message("Ungültige Servernachricht.") }
        try checkError(root)
        if root["socket_intention"] as? String == "close" { return .complete }
        if let value = root["gen_progress"] as? [String: Any] {
            func fraction(_ key: String) -> Double? {
                guard let number = value[key] as? Double, number.isFinite, (0...1).contains(number) else { return nil }; return number
            }
            return .progress(.init(batch: string(value["batch_index"]) ?? "0", overall: fraction("overall_percent"), current: fraction("current_percent"), preview: value["preview"] as? String))
        }
        if let nested = root["image"] as? [String: Any], let path = nested["image"] as? String {
            return .result(.init(path: path, batch: string(nested["batch_index"]) ?? "0", metadata: nested["metadata"] as? String))
        }
        if let path = root["image"] as? String {
            return .result(.init(path: path, batch: string(root["batch_index"]) ?? "0", metadata: root["metadata"] as? String))
        }
        if let discarded = root["discard_indices"] as? [Any] { return .discard(discarded.compactMap(string)) }
        if let status = root["status"] as? [String: Any] {
            return .status(try JSONDecoder().decode(ServerStatus.self, from: JSONSerialization.data(withJSONObject: status)))
        }
        return .ignored
    }
    private static func string(_ value: Any?) -> String? { if let s = value as? String { return s }; return (value as? NSNumber)?.stringValue }
}
public func checkError(_ root: [String: Any]) throws {
    if let error = root["error"] as? String { throw StudioError.message(error) }
    if let error = root["error_id"] as? String { throw StudioError.message("SwarmUI: \(error)") }
}

public enum VisualStyle: String, CaseIterable, Codable, Sendable {
    case none = "Ohne Stil", realistic = "Realistisch", cinematic = "Filmisch", portrait = "Porträt", product = "Produktfotos", architecture = "Architektur"
    case anime = "Anime", manga = "Manga", comic = "Comic", animation = "Animation", clay = "Knetanimation", lowPoly = "Low Poly"
    case watercolor = "Aquarell", oil = "Ölgemälde", sketch = "Bleistift", digital = "Digital Art", pixel = "Pixel Art"
    case cyberpunk = "Cyberpunk", fantasy = "Fantasy", scienceFiction = "Science-Fiction", vintage = "Vintage", minimal = "Minimalistisch"
    public var suffix: String {
        switch self {
        case .none: return ""
        case .realistic: return "natural light, photographic detail"
        case .cinematic: return "cinematic composition, dramatic lighting, rich film color grading, subtle film grain"
        case .portrait: return "professional portrait photography, soft key light, shallow depth of field, natural skin texture"
        case .product: return "premium product photography, controlled studio lighting, clean composition, detailed materials"
        case .architecture: return "architectural photography, balanced geometry, refined materials, natural daylight"
        case .anime: return "anime illustration, expressive line art"
        case .manga: return "black and white manga, expressive ink linework, screentone shading"
        case .comic: return "comic book illustration, bold ink outlines, graphic shadows, vibrant colors"
        case .animation: return "stylized 3D animation, soft cinematic lighting"
        case .clay: return "handcrafted clay animation aesthetic, tactile clay textures, miniature set lighting"
        case .lowPoly: return "low poly 3D art, faceted geometric shapes, soft ambient lighting"
        case .watercolor: return "watercolor painting, translucent pigment washes, textured paper, soft organic edges"
        case .oil: return "oil painting, expressive brushwork, rich layered pigments, textured canvas"
        case .sketch: return "graphite pencil drawing, crosshatching, fine linework, textured paper"
        case .digital: return "polished digital illustration, expressive color palette, detailed concept art"
        case .pixel: return "pixel art, crisp pixel edges, limited color palette, retro game aesthetic"
        case .cyberpunk: return "cyberpunk aesthetic, neon lighting, futuristic city atmosphere, reflective surfaces"
        case .fantasy: return "fantasy art, enchanting atmosphere, intricate imaginative details, ethereal lighting"
        case .scienceFiction: return "science fiction aesthetic, futuristic design, advanced technology, atmospheric cinematic lighting"
        case .vintage: return "vintage color photography, muted warm tones, subtle film grain, nostalgic atmosphere"
        case .minimal: return "minimalist composition, simple shapes, restrained color palette, generous negative space"
        }
    }
}
public struct GenerationRequest: Codable, Sendable {
    public var prompt = ""
    public var negative = ""
    public var style: VisualStyle = .realistic
    public var styleSuffix = VisualStyle.realistic.suffix
    public var model = ""
    public var videoModel = ""
    public var swapModel = ""
    public var video = false
    public var width = 1024
    public var height = 1024
    public var steps = 20
    public var cfg = 7.0
    public var seed: Int64 = -1
    public var count = 1
    public var frames = 49
    public var fps = 16
    public var sampler = "euler"
    public var scheduler = "normal"
    public var initImage: String?
    public var creativity = 0.6
    public init() {}
    public func payload(session: String, models: [SwarmModel], specs: [ParameterSpec]) throws -> [String: Any] {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StudioError.message("Bitte einen Prompt eingeben.") }
        guard models.contains(where: { $0.name == model }) else { throw StudioError.message("Bitte ein verfügbares Basismodell auswählen.") }
        guard (1...4).contains(count), (1...80).contains(steps), (1...20).contains(cfg), seed >= -1,
              width >= 256, height >= 256, width <= 1536, height <= 1536, width % 32 == 0, height % 32 == 0 else {
            throw StudioError.message("Auflösung, Qualität, Seed oder Anzahl liegen außerhalb des unterstützten Bereichs.")
        }
        let ids = Set(specs.map(\.id))
        var values: [String: Any] = ["session_id": session, "images": count, "model": model,
            "prompt": [prompt, styleSuffix].filter { !$0.isEmpty }.joined(separator: ", "), "negativeprompt": negative,
            "width": width, "height": height, "steps": steps, "cfgscale": cfg, "seed": seed]
        for (key, value) in [("sampler", sampler), ("scheduler", scheduler)] where ids.contains(key) {
            if let allowed = specs.first(where: { $0.id == key })?.values, !allowed.map({ $0.components(separatedBy: "///")[0] }).contains(value) {
                throw StudioError.message("\(key): Auswahl wird vom Server nicht unterstützt.")
            }
            values[key] = value
        }
        if let initImage { values["initimage"] = initImage; values["initimagecreativity"] = creativity }
        if video {
            let required: Set<String> = ["videomodel", "videoswapmodel", "videoswappercent", "videoframes", "videofps", "videosteps", "videocfg", "videoresolution", "videoformat", "initimage", "initimagecreativity"]
            guard required.isSubset(of: ids) else { throw StudioError.message("Der Server meldet die benötigten Bild-zu-Video-Parameter nicht.") }
            guard initImage != nil else { throw StudioError.message("Für ein Video bitte ein Ausgangsbild auswählen.") }
            guard models.contains(where: { $0.name == videoModel }), models.contains(where: { $0.name == swapModel }), videoModel != swapModel else {
                throw StudioError.message("Bitte verfügbare HighNoise- und LowNoise-Modelle auswählen.")
            }
            let plan=try VideoPlan(frames:frames,fps:fps)
            values.merge(["videomodel": videoModel, "videoswapmodel": swapModel, "videoswappercent": 0.5,
                "videoframes": plan.segments[0], "videofps": fps, "videosteps": steps, "videocfg": cfg,
                "videoresolution": "Image", "videoformat": "h264-mp4", "initimagecreativity": 0.0,
                "outputintermediateimages": false]) { _, new in new }
            if plan.segments.count > 1 {
                let extendKeys:Set<String>=["videoextendmodel","videoextendswapmodel","videoextendswappercent","videoextendframeoverlap","videoextendformat"]
                guard extendKeys.isSubset(of:ids) else {throw StudioError.message("Dieser Server meldet keine Video-Fortsetzung. Eine kürzere Dauer wählen.")}
                let fullPrompt=[prompt,styleSuffix].filter{!$0.isEmpty}.joined(separator:", ")
                guard !fullPrompt.lowercased().contains("<extend:") else {throw StudioError.message("Bei automatischer Videolänge bitte keine zusätzlichen <extend:…>-Befehle in den Prompt schreiben.")}
                values["prompt"]=fullPrompt + plan.segments.dropFirst().map {"\n<extend:\($0)> \(fullPrompt)"}.joined()
                values.merge(["videoextendmodel":videoModel,"videoextendswapmodel":swapModel,"videoextendswappercent":0.5,"videoextendframeoverlap":1,"videoextendformat":"h264-mp4"]) {_,new in new}
            }
        }
        for spec in specs {
            if let number = values[spec.id] as? NSNumber {
                if let min = spec.min, let max = spec.max, max > min, !(min...max).contains(number.doubleValue) {
                    throw StudioError.message("\(spec.id) liegt außerhalb des vom Server gemeldeten Bereichs.")
                }
            }
        }
        return values
    }
    public var withoutImage: GenerationRequest { var copy = self; copy.initImage = nil; return copy }
}
