import Foundation

struct ContactPoint: Sendable {
    var x: Float
    var y: Float

    func distance(to other: Self) -> Float {
        hypot(x - other.x, y - other.y)
    }

    var isValid: Bool {
        x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y)
    }
}

struct TouchContact: Sendable {
    let id: Int32
    let state: Int32
    var position: ContactPoint
    var total: Float = 0
    var majorAxis: Float = 0
    var minorAxis: Float = 0

    var isActive: Bool { state == 3 || state == 4 }
    var isEnding: Bool { state == 5 }
    var isPresent: Bool { (1...6).contains(state) }
}

struct TapConfiguration: Sendable {
    var duration = 0.3
    var movement: Float = 0.05
    var frameMovement: Float = 0.025
    var cooldown = 0.2
    var edgeMargin: Float = 0.12
    var palmTotal: Float = 1.5
    var palmMajorAxis: Float = 10
    var palmMinorAxis: Float = 8

    func isPalm(_ contact: TouchContact) -> Bool {
        let point = contact.position
        let nearEdge = point.x < edgeMargin || point.x > 1 - edgeMargin ||
            point.y < edgeMargin || point.y > 1 - edgeMargin
        // Position alone never rejects a contact. Require area and shape evidence.
        return nearEdge && contact.total > palmTotal &&
            (contact.majorAxis > palmMajorAxis || contact.minorAxis > palmMinorAxis)
    }
}

private struct FingerTrack: Sendable {
    let start: ContactPoint
    var previous: ContactPoint
}

struct TapGesture: Sendable {
    private enum Phase { case idle, possibleTap, cancelled }

    var configuration = TapConfiguration()
    private var phase = Phase.idle
    private var startTime: Double?
    private var previousTime: Double?
    private var fingers = [Int32: FingerTrack]()
    private var activeIDs = Set<Int32>()
    private var releasedIDs = Set<Int32>()
    private var rejectedIDs = Set<Int32>()
    private var sawThree = false
    private var lastTriggerTime: Double?

    mutating func cancel() {
        phase = .cancelled
    }

    /// Returns true once, on the final accepted finger's release.
    mutating func process(_ contacts: [TouchContact], timestamp: Double) -> Bool {
        guard timestamp.isFinite else {
            cancel()
            return false
        }
        if let previousTime, timestamp < previousTime {
            cancel()
        }
        previousTime = timestamp

        let presentIDs = Set(contacts.filter(\.isPresent).map(\.id))
        if !rejectedIDs.isEmpty {
            rejectedIDs.formIntersection(presentIDs)
        }
        for contact in contacts where contact.isActive && configuration.isPalm(contact) {
            if fingers[contact.id] != nil {
                cancel()
            }
            rejectedIDs.insert(contact.id)
        }

        let accepted = contacts.filter { !rejectedIDs.contains($0.id) && ($0.isActive || $0.isEnding) }
        let active = accepted.filter(\.isActive)
        let currentIDs = Set(active.map(\.id))
        if currentIDs.count != active.count || accepted.contains(where: { !$0.position.isValid }) {
            cancel()
        }

        if phase == .idle && !active.isEmpty {
            phase = .possibleTap
            startTime = timestamp
        }
        if let startTime, timestamp - startTime > configuration.duration {
            cancel()
        }

        if phase == .possibleTap {
            releasedIDs.formUnion(activeIDs.subtracting(currentIDs))
            if !currentIDs.isDisjoint(with: releasedIDs) {
                cancel()
            }

            for contact in accepted {
                if var track = fingers[contact.id] {
                    if contact.position.distance(to: track.start) > configuration.movement ||
                        contact.position.distance(to: track.previous) > configuration.frameMovement {
                        cancel()
                    }
                    track.previous = contact.position
                    fingers[contact.id] = track
                } else if contact.isActive {
                    fingers[contact.id] = FingerTrack(start: contact.position, previous: contact.position)
                }
            }
            if fingers.count > 3 {
                cancel()
            }
            if currentIDs.count == 3 {
                sawThree = true
            }
        }
        activeIDs = currentIDs

        guard active.isEmpty else { return false }
        let cooledDown = lastTriggerTime.map { timestamp - $0 >= configuration.cooldown } ?? true
        let shouldFire = phase == .possibleTap && sawThree && cooledDown
        if shouldFire {
            lastTriggerTime = timestamp
        }
        resetSession()
        return shouldFire
    }

    private mutating func resetSession() {
        phase = .idle
        startTime = nil
        fingers.removeAll(keepingCapacity: true)
        activeIDs.removeAll(keepingCapacity: true)
        releasedIDs.removeAll(keepingCapacity: true)
        sawThree = false
    }
}

struct TrackpadTapEngine: Sendable {
    private var gestures = [UInt: TapGesture]()

    mutating func process(device: UInt, contacts: [TouchContact], timestamp: Double) -> Bool {
        gestures[device, default: TapGesture()].process(contacts, timestamp: timestamp)
    }

    mutating func cancel(device: UInt) {
        gestures[device, default: TapGesture()].cancel()
    }
}
