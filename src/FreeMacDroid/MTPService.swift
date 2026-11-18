import AppKit
import Foundation

struct EnvironmentCheck: Sendable {
    let macFUSEInstalled: Bool
    let libfuse3Installed: Bool
    let extensionsRegistered: Bool
    let mountPoint: String
    let isMounted: Bool
}

enum MountResult: Sendable {
    case success
    case failure(title: String, message: String, needsSetup: Bool)
}

final class MTPService: @unchecked Sendable {
    static let shared = MTPService()

    let mountPoint: String
    let logPath: String

    private init() {
        self.mountPoint = ProcessInfo.processInfo.environment["ANDROID_MOUNT_DIR"]
            ?? (NSHomeDirectory() + "/Android")
        self.logPath = ProcessInfo.processInfo.environment["ANDROID_MOUNT_LOG"]
            ?? "/tmp/aft-mtp-mount.log"
    }

    private func helperPath(_ name: String) -> String {
        let bundleHelper = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/\(name)").path
        if FileManager.default.isExecutableFile(atPath: bundleHelper) {
            return bundleHelper
        }
        let localBin = NSHomeDirectory() + "/.local/bin/\(name)"
        if FileManager.default.isExecutableFile(atPath: localBin) {
            return localBin
        }
        return "/opt/homebrew/bin/\(name)"
    }

    func checkEnvironment() -> EnvironmentCheck {
        let fm = FileManager.default
        let macFUSEInstalled = fm.fileExists(atPath: "/Library/Filesystems/macfuse.fs")
        let libfuse3Installed = fm.fileExists(atPath: "/usr/local/lib/libfuse3.4.dylib")
            || fm.fileExists(atPath: "/usr/local/lib/libfuse3.dylib")
        let pluginkitOut = runSync("/usr/bin/pluginkit", args: ["-m", "-p", "com.apple.fskit.fsmodule"]).output
        let extensionsRegistered = pluginkitOut.contains("io.macfuse.app.fsmodule.macfuse")
            && pluginkitOut.contains("io.macfuse.app.fsmodule.macfuse-local")
        let mounted = isCurrentlyMounted()

        return EnvironmentCheck(
            macFUSEInstalled: macFUSEInstalled,
            libfuse3Installed: libfuse3Installed,
            extensionsRegistered: extensionsRegistered,
            mountPoint: mountPoint,
            isMounted: mounted
        )
    }

    func hasMountEntry() -> Bool {
        let out = runSync("/sbin/mount", args: []).output
        return out.contains(" on \(mountPoint) (")
    }

    func isCurrentlyMounted() -> Bool {
        guard hasMountEntry() else { return false }
        let proc = runSync("/usr/bin/pgrep", args: ["-x", "aft-mtp-mount"])
        return proc.exitCode == 0
    }

    func registerFSKitExtensions() -> (ok: Bool, output: String) {
        let bin = "/Library/Filesystems/macfuse.fs/Contents/Resources/macfuse.app/Contents/MacOS/macfuse"
        guard FileManager.default.isExecutableFile(atPath: bin) else {
            return (false, "macfuse binary not found at \(bin)")
        }
        let res = runSync(bin, args: ["install", "--components", "file-system-extensions"])
        return (res.exitCode == 0, res.output)
    }

    func openFileSystemExtensionsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    func openMountInFinder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: mountPoint))
    }

    func readLogTail(lines: Int = 40) -> String {
        guard let data = try? String(contentsOfFile: logPath, encoding: .utf8) else {
            return "(No log file yet at \(logPath))"
        }
        let parts = data.split(separator: "\n", omittingEmptySubsequences: false)
        return parts.suffix(lines).joined(separator: "\n")
    }

    func mount(readOnly: Bool, openFinder: Bool = true, completion: @escaping @Sendable (MountResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = self.helperPath("android-mount")
            var args: [String] = []
            if !openFinder { args.append("--no-open") }
            if readOnly { args.append("--read-only") }

            var env = ProcessInfo.processInfo.environment
            env["ANDROID_MOUNT_DIR"] = self.mountPoint
            env["ANDROID_MOUNT_LOG"] = self.logPath
            let bundledMount = self.helperPath("aft-mtp-mount")
            if FileManager.default.isExecutableFile(atPath: bundledMount) {
                env["AFT_MTP_MOUNT_BIN"] = bundledMount
            }

            let res = self.runSync(script, args: args, env: env)
            if res.exitCode == 0 {
                completion(.success)
                return
            }

            let text = res.output + "\n" + self.readLogTail(lines: 20)
            if text.localizedCaseInsensitiveContains("File system extension") {
                completion(.failure(
                    title: "Enable macFUSE in System Settings",
                    message: "Go to System Settings → General → Login Items & Extensions → By Category → File System Extensions (i), and turn ON both macFUSE and macFUSE (local).",
                    needsSetup: true
                ))
            } else if text.localizedCaseInsensitiveContains("device may be locked") || text.localizedCaseInsensitiveContains("appears locked") {
                completion(.failure(
                    title: "Phone Is Locked",
                    message: "Unlock your Android phone, keep the screen on, tap the USB notification, and choose File transfer / MTP.",
                    needsSetup: false
                ))
            } else if text.localizedCaseInsensitiveContains("no MTP device found") || text.localizedCaseInsensitiveContains("device not found") {
                completion(.failure(
                    title: "No Android Phone Detected",
                    message: "Connect your phone with a USB data cable, unlock it, and select File transfer / MTP in the USB notification. (USB debugging can stay OFF.)",
                    needsSetup: false
                ))
            } else {
                completion(.failure(
                    title: "Mount Failed",
                    message: res.output.isEmpty ? self.readLogTail(lines: 15) : res.output,
                    needsSetup: false
                ))
            }
        }
    }

    func unmount(completion: @escaping @Sendable (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = self.helperPath("android-unmount")
            var env = ProcessInfo.processInfo.environment
            env["ANDROID_MOUNT_DIR"] = self.mountPoint
            let res = self.runSync(script, args: [], env: env)
            completion(res.exitCode == 0, res.output)
        }
    }

    private func runSync(_ executable: String, args: [String], env: [String: String]? = nil) -> (exitCode: Int32, output: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = args
        if let env = env {
            proc.environment = env
        }
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        do {
            try proc.run()
        } catch {
            return (-1, error.localizedDescription)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (proc.terminationStatus, out)
    }
}
