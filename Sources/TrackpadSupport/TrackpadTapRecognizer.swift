import CMultitouch
import Foundation

enum TouchFrameDecoder {
    // The framework owns this buffer. Copy values before leaving the callback.
    static func decode(_ touches: UnsafeMutablePointer<MTTouch>?, count: Int) -> [TouchContact]? {
        guard (0...32).contains(count) else { return nil }
        guard count > 0 else { return [] }
        guard let touches else { return nil }
        var contacts = [TouchContact]()
        contacts.reserveCapacity(count)
        for touch in UnsafeBufferPointer(start: touches, count: count) {
            guard (0...7).contains(touch.state),
                  touch.total.isFinite, touch.majorAxis.isFinite, touch.minorAxis.isFinite
            else { return nil }
            contacts.append(TouchContact(
                id: touch.identifier,
                state: touch.state,
                position: ContactPoint(x: touch.normalizedVector.position.x, y: touch.normalizedVector.position.y),
                total: touch.total,
                majorAxis: touch.majorAxis,
                minorAxis: touch.minorAxis
            ))
        }
        return contacts
    }
}

private final class CallbackRouter: @unchecked Sendable {
    private let lock = NSLock()
    private weak var recognizer: TrackpadTapRecognizer?

    func attach(_ recognizer: TrackpadTapRecognizer?) {
        lock.withLock { self.recognizer = recognizer }
    }

    func process(device: MTDeviceRef?, touches: UnsafeMutablePointer<MTTouch>?, count: Int, timestamp: Double) {
        let target = lock.withLock { recognizer }
        target?.process(device: device, touches: touches, count: count, timestamp: timestamp)
    }
}

private let callbackRouter = CallbackRouter()
private let contactFrameCallback: MTContactCallback = { device, touches, count, timestamp, _ in
    callbackRouter.process(device: device, touches: touches, count: Int(count), timestamp: timestamp)
}

public final class TrackpadTapRecognizer: @unchecked Sendable {
    @MainActor public var onTap: (() -> Void)?
    @MainActor private var devices = [MTDeviceRef]()
    // Retain the device references for the full registration lifetime.
    @MainActor private var deviceList: CFArray?

    private let lock = NSLock()
    private var engine = TrackpadTapEngine()
    private var registeredDevices = Set<UInt>()
    private var generation: UInt = 0

    public init() {}

    @MainActor public var isRunning: Bool { !devices.isEmpty }

    @MainActor public func start() -> Bool {
        if isRunning { return true }
        guard let list = MTDeviceCreateList() else { return false }
        let foundDevices = (0..<CFArrayGetCount(list)).compactMap { index -> MTDeviceRef? in
            guard let value = CFArrayGetValueAtIndex(list, index) else { return nil }
            return UnsafeMutableRawPointer(mutating: value)
        }
        guard !foundDevices.isEmpty else { return false }
        deviceList = list
        devices = foundDevices
        lock.withLock {
            engine = TrackpadTapEngine()
            registeredDevices = Set(foundDevices.map { UInt(bitPattern: $0) })
            generation &+= 1
        }
        callbackRouter.attach(self)
        for device in devices {
            MTRegisterContactFrameCallback(device, contactFrameCallback)
            MTDeviceStart(device, 0)
        }
        return true
    }

    @MainActor public func stop() {
        // Invalidate callbacks before touching the framework; stop may wait for a callback.
        lock.withLock {
            registeredDevices.removeAll()
            engine = TrackpadTapEngine()
            generation &+= 1
        }
        callbackRouter.attach(nil)
        for device in devices {
            MTUnregisterContactFrameCallback(device, contactFrameCallback)
            MTDeviceStop(device)
        }
        devices.removeAll()
        deviceList = nil
    }

    fileprivate func process(
        device: MTDeviceRef?, touches: UnsafeMutablePointer<MTTouch>?, count: Int, timestamp: Double
    ) {
        guard let device else { return }
        let deviceID = UInt(bitPattern: device)
        let triggerGeneration: UInt? = lock.withLock {
            guard registeredDevices.contains(deviceID) else { return nil }
            guard let contacts = TouchFrameDecoder.decode(touches, count: count) else {
                engine.cancel(device: deviceID)
                return nil
            }
            return engine.process(device: deviceID, contacts: contacts, timestamp: timestamp) ? generation : nil
        }
        guard let triggerGeneration else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.lock.withLock({ self.generation == triggerGeneration && !self.registeredDevices.isEmpty })
            else { return }
            self.onTap?()
        }
    }
}
