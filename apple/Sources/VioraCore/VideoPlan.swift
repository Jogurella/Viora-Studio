import Foundation

/// Bounded Wan windows, joined by SwarmUI's native extension workflow with one shared frame.
public struct VideoPlan: Sendable {
    public let frames: Int
    public let fps: Int
    public let segments: [Int]
    public var duration: Double { Double(frames) / Double(fps) }
    public init(frames: Int, fps: Int) throws {
        guard (1...120).contains(fps), frames >= 9, frames % 4 == 1, frames <= fps * 60 + 1 else {
            throw StudioError.message("Video: 1–120 FPS, höchstens 60 Sekunden und eine gültige Framezahl wählen.")
        }
        self.frames=frames; self.fps=fps
        let units=(frames-1)/4
        let count=(units+19)/20
        segments=(0..<count).map { (units/count + ($0 < units%count ? 1 : 0))*4+1 }
    }
    public static func frameCount(seconds: Double, fps: Int) -> Int {
        let finiteSeconds = seconds.isFinite ? seconds : 3
        let bounded = min(60,max(0.1,finiteSeconds)) * Double(min(120,max(1,fps)))
        return max(9,Int((bounded/4).rounded())*4+1)
    }
}
