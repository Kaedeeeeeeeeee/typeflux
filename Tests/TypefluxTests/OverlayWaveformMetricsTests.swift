@testable import Typeflux
import XCTest

final class OverlayWaveformMetricsTests: XCTestCase {
    func testAmplitudePreservesVisibleDifferencesAcrossLevelRange() {
        let quietAmplitude = OverlayWaveformMetrics.amplitude(for: 0.05)
        let conversationalAmplitude = OverlayWaveformMetrics.amplitude(for: 0.5)
        let loudAmplitude = OverlayWaveformMetrics.amplitude(for: 0.95)

        XCTAssertGreaterThan(conversationalAmplitude, quietAmplitude)
        XCTAssertGreaterThan(loudAmplitude, conversationalAmplitude)
    }

    func testLevelsClampToWaveLineBounds() {
        let minimumAmplitude = OverlayWaveformMetrics.amplitude(for: -1)
        let zeroAmplitude = OverlayWaveformMetrics.amplitude(for: 0)
        let maximumAmplitude = OverlayWaveformMetrics.amplitude(for: 2)

        XCTAssertEqual(minimumAmplitude, zeroAmplitude, accuracy: 0.001)
        XCTAssertEqual(maximumAmplitude, 6.0, accuracy: 0.001)
    }

    func testEnvelopeTapersWaveLineAtBothEdges() {
        XCTAssertEqual(OverlayWaveformMetrics.envelope(at: 0), 0, accuracy: 0.001)
        XCTAssertEqual(OverlayWaveformMetrics.envelope(at: 1), 0, accuracy: 0.001)
        XCTAssertEqual(OverlayWaveformMetrics.envelope(at: 0.5), 1, accuracy: 0.001)
    }

    func testNormalizedDisplacementStaysWithinUnitBounds() {
        for index in 0 ... OverlayWaveformMetrics.sampleCount {
            let progress = CGFloat(index) / CGFloat(OverlayWaveformMetrics.sampleCount)
            let displacement = OverlayWaveformMetrics.normalizedDisplacement(
                at: progress,
                phase: 1.25
            )

            XCTAssertLessThanOrEqual(abs(displacement), 1.0)
        }
    }
}
