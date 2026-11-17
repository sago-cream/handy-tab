import Testing
@testable import TrackpadSupport

private func finger(
    _ id: Int32, x: Float = 0.4, y: Float = 0.5, state: Int32 = 4,
    total: Float = 0.5, major: Float = 5, minor: Float = 3
) -> TouchContact {
    TouchContact(id: id, state: state, position: ContactPoint(x: x, y: y),
                 total: total, majorAxis: major, minorAxis: minor)
}

private let three = [finger(1, x: 0.3), finger(2), finger(3, x: 0.5)]

struct TapGestureTests {
    @Test func firesOnlyAfterFinalFingerLifts() {
        var gesture = TapGesture()
        #expect(gesture.process(three, timestamp: 0) == false)
        #expect(gesture.process(Array(three.prefix(2)), timestamp: 0.05) == false)
        #expect(gesture.process(Array(three.prefix(1)), timestamp: 0.1) == false)
        #expect(gesture.process([], timestamp: 0.15) == true)
        #expect(gesture.process([], timestamp: 0.16) == false)
    }

    @Test func acceptsStaggeredArrivalAndDeparture() {
        var gesture = TapGesture()
        #expect(gesture.process([three[0]], timestamp: 0) == false)
        #expect(gesture.process(Array(three.prefix(2)), timestamp: 0.03) == false)
        #expect(gesture.process(three, timestamp: 0.06) == false)
        #expect(gesture.process(Array(three.suffix(2)), timestamp: 0.09) == false)
        #expect(gesture.process([], timestamp: 0.12) == true)
    }

    @Test func timeoutStartsAtFirstFinger() {
        var gesture = TapGesture()
        #expect(gesture.process([three[0]], timestamp: 0) == false)
        #expect(gesture.process(three, timestamp: 0.25) == false)
        #expect(gesture.process([], timestamp: 0.35) == false)
    }

    @Test(arguments: [0.299, 0.301]) func enforcesThe300MillisecondWindow(releaseTime: Double) {
        var gesture = TapGesture()
        #expect(gesture.process(three, timestamp: 0) == false)
        let fired = gesture.process([], timestamp: releaseTime)
        #expect(fired == (releaseTime <= 0.3))
    }

    @Test func longHoldCannotRearmUntilRelease() {
        var gesture = TapGesture()
        for time in [0.0, 0.31, 1.01, 1.1, 2.02, 2.1] {
            #expect(gesture.process(three, timestamp: time) == false)
        }
        #expect(gesture.process([], timestamp: 2.11) == false)
        #expect(gesture.process(three, timestamp: 2.2) == false)
        #expect(gesture.process([], timestamp: 2.3) == true)
    }

    @Test(arguments: [true, false]) func fourthFingerCancelsUntilRelease(addedLater: Bool) {
        var gesture = TapGesture()
        if addedLater { #expect(gesture.process(three, timestamp: 0) == false) }
        #expect(gesture.process(three + [finger(4, x: 0.6)], timestamp: 0.02) == false)
        #expect(gesture.process(three, timestamp: 0.04) == false)
        #expect(gesture.process([], timestamp: 0.06) == false)
        #expect(gesture.process(three, timestamp: 0.4) == false)
        #expect(gesture.process([], timestamp: 0.5) == true)
    }

    @Test func replacingAFingerCannotPreserveTheTap() {
        var gesture = TapGesture()
        #expect(gesture.process(three, timestamp: 0) == false)
        #expect(gesture.process([three[0], three[1], finger(4)], timestamp: 0.03) == false)
        #expect(gesture.process([], timestamp: 0.06) == false)
    }

    @Test func puttingAReleasedFingerBackDownCancels() {
        var gesture = TapGesture()
        #expect(gesture.process(three, timestamp: 0) == false)
        #expect(gesture.process(Array(three.prefix(2)), timestamp: 0.03) == false)
        #expect(gesture.process(three, timestamp: 0.04) == false)
        #expect(gesture.process([], timestamp: 0.06) == false)
    }

    @Test func oppositeFingerMovementsCannotCancelEachOtherOut() {
        var gesture = TapGesture()
        #expect(gesture.process(three, timestamp: 0) == false)
        let moved = [finger(1, x: 0.23), three[1], finger(3, x: 0.57)]
        #expect(gesture.process(moved, timestamp: 0.03) == false)
        #expect(gesture.process(three, timestamp: 0.06) == false)
        #expect(gesture.process([], timestamp: 0.09) == false)
    }

    @Test func gradualSwipeExceedsTotalMovementLimit() {
        var gesture = TapGesture()
        #expect(gesture.process(three, timestamp: 0) == false)
        for step in 1...4 {
            let moved = three.map { contact in
                var result = contact
                result.position.x += Float(step) * 0.02
                return result
            }
            #expect(gesture.process(moved, timestamp: Double(step) * 0.03) == false)
        }
        #expect(gesture.process([], timestamp: 0.15) == false)
    }

    @Test func fastMovementBelowTotalLimitStillCancels() {
        var gesture = TapGesture()
        #expect(gesture.process(three, timestamp: 0) == false)
        #expect(gesture.process([finger(1, x: 0.33), three[1], three[2]], timestamp: 0.02) == false)
        #expect(gesture.process([], timestamp: 0.04) == false)
    }

    @Test func movementBeforeThirdFingerAndDuringLiftingIsChecked() {
        var before = TapGesture()
        #expect(before.process([three[0]], timestamp: 0) == false)
        #expect(before.process([finger(1, x: 0.4)], timestamp: 0.02) == false)
        #expect(before.process(three, timestamp: 0.04) == false)
        #expect(before.process([], timestamp: 0.06) == false)

        var after = TapGesture()
        #expect(after.process(three, timestamp: 0) == false)
        #expect(after.process([finger(1, x: 0.4), three[1]], timestamp: 0.02) == false)
        #expect(after.process([], timestamp: 0.04) == false)
    }

    @Test func breakTouchPositionIsChecked() {
        var gesture = TapGesture()
        #expect(gesture.process(three, timestamp: 0) == false)
        let released = [finger(1, x: 0.4, state: 5), finger(2, state: 5), finger(3, state: 5)]
        #expect(gesture.process(released, timestamp: 0.04) == false)
    }

    @Test func smallIndividualJitterIsAllowed() {
        var gesture = TapGesture()
        #expect(gesture.process(three, timestamp: 0) == false)
        #expect(gesture.process([finger(1, x: 0.31), three[1], finger(3, x: 0.49)], timestamp: 0.03) == false)
        #expect(gesture.process([], timestamp: 0.1) == true)
    }

    @Test(arguments: [ContactPoint(x: 0.01, y: 0.5), ContactPoint(x: 0.99, y: 0.5),
                      ContactPoint(x: 0.5, y: 0.01), ContactPoint(x: 0.5, y: 0.99),
                      ContactPoint(x: 0, y: 0), ContactPoint(x: 1, y: 1)])
    func ordinaryEdgeAndCornerContactsAreAccepted(point: ContactPoint) {
        var gesture = TapGesture()
        let contacts = [finger(1, x: point.x, y: point.y), three[1], three[2]]
        #expect(gesture.process(contacts, timestamp: 0) == false)
        #expect(gesture.process([], timestamp: 0.1) == true)
    }

    @Test func allThreeFingersMayBeNearAnEdge() {
        var gesture = TapGesture()
        let contacts = [finger(1, x: 0.2, y: 0.05), finger(2, x: 0.4, y: 0.05), finger(3, x: 0.6, y: 0.05)]
        #expect(gesture.process(contacts, timestamp: 0) == false)
        #expect(gesture.process([], timestamp: 0.1) == true)
    }

    @Test(arguments: [finger(1, x: 0.01, total: 2), finger(1, x: 0.01, major: 12, minor: 9)])
    func singleSizeSignalDoesNotRejectAnEdgeFinger(contact: TouchContact) {
        var gesture = TapGesture()
        #expect(gesture.process([contact, three[1], three[2]], timestamp: 0) == false)
        #expect(gesture.process([], timestamp: 0.1) == true)
    }

    @Test func broadEdgeContactCannotSubstituteForThirdFinger() {
        var gesture = TapGesture()
        let palm = finger(3, x: 0.02, total: 2, major: 12, minor: 9)
        #expect(gesture.process([three[0], three[1], palm], timestamp: 0) == false)
        // Once rejected, a palm cannot become a finger by shrinking or moving inward.
        #expect(gesture.process(three, timestamp: 0.03) == false)
        #expect(gesture.process([], timestamp: 0.1) == false)
        #expect(gesture.process(three, timestamp: 0.4) == false)
        #expect(gesture.process([], timestamp: 0.5) == true)
    }

    @Test func restingPalmDoesNotPreventThreeRealFingersFromTapping() {
        var gesture = TapGesture()
        let palm = finger(9, x: 0.02, total: 2, major: 12, minor: 9)
        #expect(gesture.process([palm], timestamp: 0) == false)
        #expect(gesture.process(three + [palm], timestamp: 1) == false)
        #expect(gesture.process([palm], timestamp: 1.1) == true)
        #expect(gesture.process([palm], timestamp: 1.2) == false)
    }

    @Test func reclassifyingAFingerAsPalmCancelsInsteadOfFiring() {
        var gesture = TapGesture()
        let edge = finger(1, x: 0.01)
        #expect(gesture.process([edge, three[1], three[2]], timestamp: 0) == false)
        let palm = finger(1, x: 0.01, total: 2, major: 12, minor: 9)
        #expect(gesture.process([palm, three[1], three[2]], timestamp: 0.02) == false)
        #expect(gesture.process([palm], timestamp: 0.04) == false)
    }

    @Test func hoverAndLingeringContactsAreNotFingers() {
        var gesture = TapGesture()
        #expect(gesture.process([finger(4, state: 2)], timestamp: 0) == false)
        #expect(gesture.process(three + [finger(4, state: 2)], timestamp: 1) == false)
        #expect(gesture.process([finger(1, state: 6), finger(4, state: 2)], timestamp: 1.1) == true)
    }

    @Test func cooldownSurvivesGestureReset() {
        var gesture = TapGesture()
        #expect(gesture.process(three, timestamp: 0) == false)
        #expect(gesture.process([], timestamp: 0.1) == true)
        #expect(gesture.process(three, timestamp: 0.15) == false)
        #expect(gesture.process([], timestamp: 0.2) == false)
        #expect(gesture.process(three, timestamp: 0.4) == false)
        #expect(gesture.process([], timestamp: 0.5) == true)
    }

    @Test func malformedInputCancelsUntilRelease() {
        var engine = TrackpadTapEngine()
        #expect(engine.process(device: 1, contacts: three, timestamp: 0) == false)
        engine.cancel(device: 1)
        #expect(engine.process(device: 1, contacts: three, timestamp: 0.03) == false)
        #expect(engine.process(device: 1, contacts: [], timestamp: 0.06) == false)
    }

    @Test func invalidPositionAndBackwardsTimeCannotTrigger() {
        var invalid = TapGesture()
        #expect(invalid.process([finger(1, x: .nan), three[1], three[2]], timestamp: 0) == false)
        #expect(invalid.process([], timestamp: 0.1) == false)
        var backwards = TapGesture()
        #expect(backwards.process(three, timestamp: 1) == false)
        #expect(backwards.process([], timestamp: 0.9) == false)
    }

    @Test func devicesCannotCompleteOrCancelEachOthersGestures() {
        var engine = TrackpadTapEngine()
        #expect(engine.process(device: 1, contacts: three, timestamp: 0) == false)
        #expect(engine.process(device: 2, contacts: [], timestamp: 0.02) == false)
        #expect(engine.process(device: 2, contacts: three + [finger(4)], timestamp: 0.03) == false)
        #expect(engine.process(device: 1, contacts: [], timestamp: 0.1) == true)
        #expect(engine.process(device: 2, contacts: [], timestamp: 0.12) == false)
    }

    @Test func countsAndRejectedIDsAreSeparatePerDevice() {
        var engine = TrackpadTapEngine()
        let palm = finger(1, x: 0.01, total: 2, major: 12, minor: 9)
        #expect(engine.process(device: 1, contacts: [palm, three[1]], timestamp: 0) == false)
        #expect(engine.process(device: 2, contacts: Array(three.prefix(2)), timestamp: 0.02) == false)
        #expect(engine.process(device: 2, contacts: three, timestamp: 0.04) == false)
        #expect(engine.process(device: 2, contacts: [], timestamp: 0.1) == true)
        #expect(engine.process(device: 1, contacts: [], timestamp: 0.12) == false)
    }
}
