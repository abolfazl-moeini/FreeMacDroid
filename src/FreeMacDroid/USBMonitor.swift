import Foundation
import IOKit
import IOKit.usb

final class USBMonitor: @unchecked Sendable {
    var onNonAppleUSBConnected: (@Sendable () -> Void)?

    private var notifyPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var lastTrigger: Date = .distantPast
    private let lock = NSLock()

    func start() {
        guard notifyPort == nil else { return }
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notifyPort = port
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)

        let matchDict = IOServiceMatching("IOUSBHostDevice")
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let kr = IOServiceAddMatchingNotification(
            port,
            kIOMatchedNotification,
            matchDict,
            { refcon, iterator in
                guard let refcon else { return }
                let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.drainIterator(iterator, notify: true)
            },
            selfPtr,
            &addedIterator
        )
        if kr == KERN_SUCCESS {
            // Drain initial already-connected devices without triggering auto-mount on launch.
            drainIterator(addedIterator, notify: false)
        }
    }

    func stop() {
        if addedIterator != 0 {
            IOObjectRelease(addedIterator)
            addedIterator = 0
        }
        if let port = notifyPort {
            IONotificationPortDestroy(port)
            notifyPort = nil
        }
    }

    private func drainIterator(_ iterator: io_iterator_t, notify: Bool) {
        var foundNonApple = false
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let vendorProp = IORegistryEntryCreateCFProperty(service, "idVendor" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber {
                if vendorProp.intValue != 0x05ac {
                    foundNonApple = true
                }
            }
        }
        guard notify && foundNonApple else { return }

        lock.lock()
        let now = Date()
        let shouldFire = now.timeIntervalSince(lastTrigger) > 4.0
        if shouldFire {
            lastTrigger = now
        }
        lock.unlock()

        if shouldFire {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.onNonAppleUSBConnected?()
            }
        }
    }

    deinit {
        stop()
    }
}
