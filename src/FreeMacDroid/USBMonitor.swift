import Foundation
import IOKit
import IOKit.usb

final class USBMonitor: @unchecked Sendable {
    var onNonAppleUSBConnected: (@Sendable () -> Void)?
    var onNonAppleUSBDisconnected: (@Sendable () -> Void)?

    private var notifyPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private var lastTrigger: Date = .distantPast
    private let lock = NSLock()

    func start() {
        guard notifyPort == nil else { return }
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notifyPort = port
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let matchDict = IOServiceMatching("IOUSBHostDevice")
        let kr = IOServiceAddMatchingNotification(
            port,
            kIOMatchedNotification,
            matchDict,
            { refcon, iterator in
                guard let refcon else { return }
                let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.drainIterator(iterator, notify: true, isRemoval: false)
            },
            selfPtr,
            &addedIterator
        )
        if kr == KERN_SUCCESS {
            drainIterator(addedIterator, notify: false, isRemoval: false)
        }

        let matchDictRemove = IOServiceMatching("IOUSBHostDevice")
        let krRemove = IOServiceAddMatchingNotification(
            port,
            kIOTerminatedNotification,
            matchDictRemove,
            { refcon, iterator in
                guard let refcon else { return }
                let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.drainIterator(iterator, notify: true, isRemoval: true)
            },
            selfPtr,
            &removedIterator
        )
        if krRemove == KERN_SUCCESS {
            drainIterator(removedIterator, notify: false, isRemoval: true)
        }
    }

    func stop() {
        if addedIterator != 0 {
            IOObjectRelease(addedIterator)
            addedIterator = 0
        }
        if removedIterator != 0 {
            IOObjectRelease(removedIterator)
            removedIterator = 0
        }
        if let port = notifyPort {
            IONotificationPortDestroy(port)
            notifyPort = nil
        }
    }

    static func hasConnectedMTPDevice() -> Bool {
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostInterface"), &iterator)
        guard kr == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let ifaceClass = IORegistryEntryCreateCFProperty(service, "bInterfaceClass" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber,
               ifaceClass.intValue == 6 {
                return true
            }
            if let ifaceName = IORegistryEntryCreateCFProperty(service, "USB Interface Name" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String,
               ifaceName.localizedCaseInsensitiveContains("MTP") {
                return true
            }
        }
        return false
    }

    static func hasConnectedAndroidCandidate() -> Bool {
        if hasConnectedMTPDevice() {
            return true
        }
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &iterator)
        guard kr == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let devClass = IORegistryEntryCreateCFProperty(service, "bDeviceClass" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber,
               devClass.intValue == 9 {
                continue
            }
            if let vendorProp = IORegistryEntryCreateCFProperty(service, "idVendor" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber,
               vendorProp.intValue != 0x05ac {
                return true
            }
        }
        return false
    }

    private func drainIterator(_ iterator: io_iterator_t, notify: Bool, isRemoval: Bool) {
        var foundNonApple = false
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let devClass = IORegistryEntryCreateCFProperty(service, "bDeviceClass" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber,
               devClass.intValue == 9 {
                continue
            }
            if let vendorProp = IORegistryEntryCreateCFProperty(service, "idVendor" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber {
                if vendorProp.intValue != 0x05ac {
                    foundNonApple = true
                }
            }
        }
        guard notify && foundNonApple else { return }

        if isRemoval {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.onNonAppleUSBDisconnected?()
            }
        } else {
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
    }

    deinit {
        stop()
    }
}
