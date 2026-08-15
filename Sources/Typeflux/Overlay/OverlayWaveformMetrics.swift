import CoreGraphics
import Foundation

enum OverlayWaveformMetrics {
    static let sampleCount = 32

    private static let minimumAmplitude: CGFloat = 0.45
    private static let dynamicAmplitude: CGFloat = 5.55
    private static let cycleCount: CGFloat = 1.55

    static func amplitude(for level: Float) -> CGFloat {
        let clampedLevel = max(0, min(1.0, CGFloat(level)))
        return minimumAmplitude + dynamicAmplitude * clampedLevel
    }

    static func envelope(at progress: CGFloat) -> CGFloat {
        let clampedProgress = max(0, min(1, progress))
        return sqrt(max(0, sin(.pi * clampedProgress)))
    }

    static func normalizedDisplacement(at progress: CGFloat, phase: CGFloat) -> CGFloat {
        let clampedProgress = max(0, min(1, progress))
        let angle = clampedProgress * cycleCount * 2 * .pi + phase
        return sin(angle) * envelope(at: clampedProgress)
    }
}
