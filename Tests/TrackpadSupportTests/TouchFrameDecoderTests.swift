import CMultitouch
import Testing
@testable import TrackpadSupport

struct TouchFrameDecoderTests {
    @Test func nilPointerWithZeroContactsCompletesATap() throws {
        var gesture = TapGesture()
        let three = (1...3).map { id in
            TouchContact(id: Int32(id), state: 4, position: ContactPoint(x: Float(id) * 0.2, y: 0.5))
        }
        #expect(gesture.process(three, timestamp: 0) == false)
        let decoded = try #require(TouchFrameDecoder.decode(nil, count: 0))
        #expect(gesture.process(decoded, timestamp: 0.1) == true)
    }

    @Test func malformedBuffersAreRejected() {
        #expect(TouchFrameDecoder.decode(nil, count: 1) == nil)
        #expect(TouchFrameDecoder.decode(nil, count: -1) == nil)
        #expect(TouchFrameDecoder.decode(nil, count: 33) == nil)
    }

    @Test func copiesContactDataWhileFrameworkBufferIsAlive() throws {
        var touch = MTTouch()
        touch.identifier = 7
        touch.state = 3
        touch.normalizedVector.position = MTPoint(x: 0.05, y: 0.8)
        touch.total = 0.7
        touch.majorAxis = 6
        touch.minorAxis = 4
        let decoded = withUnsafeMutablePointer(to: &touch) { TouchFrameDecoder.decode($0, count: 1) }
        touch.normalizedVector.position.x = 0.9
        let contact = try #require(decoded?.first)
        #expect(contact.id == 7)
        #expect(contact.isActive)
        #expect(contact.position.x == 0.05)
        #expect(contact.total == 0.7)
        #expect(contact.majorAxis == 6)
        #expect(contact.minorAxis == 4)
    }

    @Test func rejectsUnrecognizedStateOrNonfiniteSize() {
        var touch = MTTouch()
        touch.state = 99
        #expect(withUnsafeMutablePointer(to: &touch) { TouchFrameDecoder.decode($0, count: 1) } == nil)
        touch.state = 4
        touch.total = .nan
        #expect(withUnsafeMutablePointer(to: &touch) { TouchFrameDecoder.decode($0, count: 1) } == nil)
    }

    @Test func importedCLayoutMatchesExpectedTouchABI() {
        #expect(MemoryLayout<MTTouch>.stride == 96)
        #expect(MemoryLayout<MTTouch>.offset(of: \MTTouch.timestamp) == 8)
        #expect(MemoryLayout<MTTouch>.offset(of: \MTTouch.state) == 20)
        #expect(MemoryLayout<MTTouch>.offset(of: \MTTouch.normalizedVector) == 32)
        #expect(MemoryLayout<MTTouch>.offset(of: \MTTouch.total) == 48)
        #expect(MemoryLayout<MTTouch>.offset(of: \MTTouch.majorAxis) == 60)
    }
}
