import Foundation
import Testing
@testable import TrackpadSupport

struct DeviceLifecycleTests {
    // Opt in on a Mac with a trackpad. No action handler is installed, so this cannot open a URL.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["HANDYTAB_TEST_TRACKPAD"] == "1"))
    @MainActor func realDeviceRegistration() async {
        let recognizer = TrackpadTapRecognizer()
        defer { recognizer.stop() }
        #expect(recognizer.start())
        #expect(recognizer.isRunning)
        try? await Task.sleep(for: .milliseconds(50))
        recognizer.stop()
        #expect(!recognizer.isRunning)
    }
}
