import XCTest
@testable import VioraCore

final class ProtocolTests: XCTestCase {
    func testEndpointRequiresTLSAndKeepsBasePath() throws {
        XCTAssertThrowsError(try ServerEndpoint("http://server.test"))
        XCTAssertThrowsError(try ServerEndpoint("https://name:password@server.test"))
        XCTAssertEqual(try ServerEndpoint("Https://server.test").base.scheme, "https")
        let endpoint = try ServerEndpoint("https://server.test:8443/swarm")
        XCTAssertEqual(endpoint.api("ListModels").absoluteString, "https://server.test:8443/swarm/API/ListModels")
        XCTAssertEqual(endpoint.socket.scheme, "wss")
        XCTAssertEqual(try endpoint.resultURL("View/a%20b.png").path, "/swarm/View/a b.png")
        XCTAssertThrowsError(try endpoint.resultURL("https://outside.test/file.png"))
        XCTAssertThrowsError(try endpoint.resultURL("//outside.test/file.png"))
        XCTAssertThrowsError(try endpoint.resultURL("file:///etc/passwd"))
    }
    func testFlatAndNestedResultsAndActualSeed() throws {
        for input in [#"{"image":"View/test.png","batch_index":"2","metadata":"{\"sui_image_params\":{\"seed\":123}}"}"#, #"{"image":{"image":"View/test.png","batch_index":2,"metadata":"{\"sui_image_params\":{\"seed\":123}}"}}"#] {
            guard case .result(let result) = try ServerEvent.parse(Data(input.utf8)) else { return XCTFail("Expected result") }
            XCTAssertEqual(result.batch, "2"); XCTAssertEqual(result.actualSeed, 123)
        }
    }
    func testPairingCompletesKnownBareHostWithoutChangingOtherServers() throws {
        let known = "https://private.example.test:8443/"
        XCTAssertEqual(try ServerEndpoint.resolving("  private.example.test\n", knownAddress: known).base.absoluteString, known)
        XCTAssertEqual(try ServerEndpoint.resolving("https://private.example.test", knownAddress: known).base.absoluteString, known)
        XCTAssertEqual(try ServerEndpoint.resolving("private.example.test:9443", knownAddress: known).base.port, 9443)
        XCTAssertEqual(try ServerEndpoint.resolving("other.example.test", knownAddress: known).base.absoluteString, "https://other.example.test/")
        XCTAssertEqual(try ServerEndpoint("server.test:8443/swarm").api("GetNewSession").absoluteString, "https://server.test:8443/swarm/API/GetNewSession")
        XCTAssertThrowsError(try ServerEndpoint.resolving("http://private.example.test", knownAddress: known))
        XCTAssertThrowsError(try ServerEndpoint("server name"))
        XCTAssertThrowsError(try ServerEndpoint(""))
    }
    func testInvalidProgressIsNotFabricated() throws {
        guard case .progress(let p) = try ServerEvent.parse(Data(#"{"gen_progress":{"overall_percent":80,"current_percent":0.5}}"#.utf8)) else { return XCTFail() }
        XCTAssertNil(p.overall); XCTAssertEqual(p.current, 0.5)
        XCTAssertThrowsError(try ServerEvent.parse(Data(#"{"error_id":"invalid_session_id"}"#.utf8)))
    }
    func testCompletionAndDiscardRemainDistinct() throws {
        guard case .discard(let indices) = try ServerEvent.parse(Data(#"{"discard_indices":[0,"2"]}"#.utf8)) else { return XCTFail() }
        XCTAssertEqual(indices, ["0", "2"])
        guard case .complete = try ServerEvent.parse(Data(#"{"socket_intention":"close"}"#.utf8)) else { return XCTFail() }
    }
    func testPayloadUsesRealModelAndNativeVideoPair() throws {
        let models = try JSONDecoder().decode([SwarmModel].self, from: Data(#"[{"name":"base"},{"name":"high"},{"name":"low"}]"#.utf8))
        let keys = ["videomodel","videoswapmodel","videoswappercent","videoframes","videofps","videosteps","videocfg","videoresolution","videoformat","initimage","initimagecreativity"]
        let specs = try JSONDecoder().decode([ParameterSpec].self, from: JSONSerialization.data(withJSONObject: keys.map { ["id": $0] }))
        var request = GenerationRequest(); request.prompt = "Test"; request.model = "invented"
        XCTAssertThrowsError(try request.payload(session: "s", models: models, specs: specs))
        request.model = "base"; request.video = true; request.videoModel = "high"; request.swapModel = "low"
        XCTAssertThrowsError(try request.payload(session: "s", models: models, specs: specs))
        request.initImage = "data:image/png;base64,AA=="
        let payload = try request.payload(session: "s", models: models, specs: specs)
        XCTAssertEqual(payload["initimagecreativity"] as? Double, 0)
        XCTAssertEqual(payload["videoswapmodel"] as? String, "low")
        XCTAssertEqual(payload["videoformat"] as? String, "h264-mp4")
        request.fps = 60
        XCTAssertEqual(try request.payload(session:"s",models:models,specs:specs)["videofps"] as? Int,60)
        let fpsLimit = try JSONDecoder().decode(ParameterSpec.self,from:Data(#"{"id":"videofps","min":1,"max":30}"#.utf8))
        XCTAssertThrowsError(try request.payload(session:"s",models:models,specs:specs + [fpsLimit]))
        request.fps = 121
        XCTAssertThrowsError(try request.payload(session:"s",models:models,specs:specs))
        request.fps = 16
        request.frames = 181; request.fps = 30
        XCTAssertThrowsError(try request.payload(session:"s",models:models,specs:specs))
        let extendKeys=["videoextendmodel","videoextendswapmodel","videoextendswappercent","videoextendframeoverlap","videoextendformat"]
        let extendSpecs=try JSONDecoder().decode([ParameterSpec].self,from:JSONSerialization.data(withJSONObject:extendKeys.map{["id":$0]}))
        let extended=try request.payload(session:"s",models:models,specs:specs+extendSpecs)
        XCTAssertEqual(extended["videoframes"] as? Int,61)
        XCTAssertEqual(extended["videoextendframeoverlap"] as? Int,1)
        XCTAssertEqual(extended["videoextendswapmodel"] as? String,"low")
        XCTAssertEqual((extended["prompt"] as? String)?.components(separatedBy:"<extend:61>").count,3)
        XCTAssertNil(request.withoutImage.initImage)
        XCTAssertThrowsError(try request.payload(session: "s", models: models, specs: []))
        request.frames = 10
        XCTAssertThrowsError(try request.payload(session: "s", models: models, specs: specs))
    }
    func testGalleryCommitFavoriteReloadAndRejectInvalidMedia() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try GalleryStore(directory: directory)
        let temporary = directory.appendingPathComponent("incoming")
        try Data("<html>Not an image</html>".utf8).write(to: temporary)
        let result = GenerationResult(path: "View/test.png", batch: "0", metadata: nil)
        XCTAssertThrowsError(try store.save(temporary: temporary, result: result, request: GenerationRequest()))
        XCTAssertTrue(try store.load().isEmpty)
        try Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aFE8AAAAASUVORK5CYII=")!.write(to: temporary)
        var entry = try store.save(temporary: temporary, result: result, request: GenerationRequest())
        entry.favorite = true; try store.update(entry)
        let reopened = try GalleryStore(directory: directory).load()
        XCTAssertEqual(reopened.count, 1); XCTAssertTrue(reopened[0].favorite)
        XCTAssertNil(reopened[0].seed)
        _ = try store.save(temporary: temporary, result: result, request: GenerationRequest())
        XCTAssertEqual(try store.load().count, 2)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasSuffix(".download") })
    }
    func testVideoPlanPreservesDurationAndUsesBoundedWanWindows() throws {
        for fps in [8,16,24,25,30,48,50,60,120] {
            for seconds in [1.0,3,5,10,15,30,60] {
                let frames=VideoPlan.frameCount(seconds:seconds,fps:fps)
                let plan=try VideoPlan(frames:frames,fps:fps)
                XCTAssertTrue(plan.segments.allSatisfy{(9...81).contains($0) && $0%4 == 1})
                XCTAssertEqual(plan.segments.reduce(0,+)-(plan.segments.count-1),frames)
                XCTAssertEqual(plan.duration,seconds,accuracy:3.0/Double(fps) + 1e-9)
            }
        }
        XCTAssertEqual(try VideoPlan(frames:85,fps:16).segments,[45,41])
        XCTAssertThrowsError(try VideoPlan(frames:80,fps:16))
        XCTAssertThrowsError(try VideoPlan(frames:7205,fps:120))
        XCTAssertThrowsError(try VideoPlan(frames:49,fps:0))
    }
}
