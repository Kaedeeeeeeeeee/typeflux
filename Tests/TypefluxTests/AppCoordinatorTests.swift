@testable import Typeflux
import XCTest

final class AppCoordinatorTests: XCTestCase {
    @MainActor
    func testStartupOpensStudioHomeRegardlessOfOnboardingState() {
        let firstLaunchSection = AppCoordinator.initialStudioSection(isOnboardingCompleted: false)
        let returningLaunchSection = AppCoordinator.initialStudioSection(isOnboardingCompleted: true)

        XCTAssertEqual(firstLaunchSection.rawValue, StudioSection.home.rawValue)
        XCTAssertEqual(returningLaunchSection.rawValue, StudioSection.home.rawValue)
    }
}
