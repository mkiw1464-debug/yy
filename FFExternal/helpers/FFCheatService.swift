import Foundation

// MARK: - String Decryptor (shared key 0x5A)

private enum _X {
    static let k: UInt8 = 0x5A
    static func d(_ b: [UInt8]) -> String {
        String(bytes: b.map { $0 ^ k }, encoding: .utf8) ?? ""
    }
}

// MARK: - Constants

enum FFGame: String, CaseIterable {
    case freeFire    = "__ff"
    case freefireMax = "__ffmax"

    var bundleID: String {
        switch self {
        case .freeFire:
            // "com.dts.freefireth"
            return _X.d([0x39, 0x35, 0x37, 0x74, 0x3e, 0x2e, 0x29, 0x74,
                         0x3c, 0x28, 0x3f, 0x3f, 0x3c, 0x33, 0x28, 0x3f, 0x2e, 0x32])
        case .freefireMax:
            // "com.dts.freefiremax"
            return _X.d([0x39, 0x35, 0x37, 0x74, 0x3e, 0x2e, 0x29, 0x74,
                         0x3c, 0x28, 0x3f, 0x3f, 0x3c, 0x33, 0x28, 0x3f, 0x37, 0x3b, 0x22])
        }
    }

    // "Library/Preferences/com.dts.freefireth.plist"
    // "Library/Preferences/com.dts.freefiremax.plist"
    var plistRelativePath: String {
        switch self {
        case .freeFire:
            return _X.d([0x16, 0x33, 0x38, 0x28, 0x3b, 0x28, 0x23, 0x75, 0x0a,
                         0x28, 0x3f, 0x3c, 0x3f, 0x28, 0x3f, 0x34, 0x39, 0x3f, 0x29,
                         0x75, 0x39, 0x35, 0x37, 0x74, 0x3e, 0x2e, 0x29, 0x74, 0x3c,
                         0x28, 0x3f, 0x3f, 0x3c, 0x33, 0x28, 0x3f, 0x2e, 0x32, 0x74,
                         0x2a, 0x36, 0x33, 0x29, 0x2e])
        case .freefireMax:
            return _X.d([0x16, 0x33, 0x38, 0x28, 0x3b, 0x28, 0x23, 0x75, 0x0a,
                         0x28, 0x3f, 0x3c, 0x3f, 0x28, 0x3f, 0x34, 0x39, 0x3f, 0x29,
                         0x75, 0x39, 0x35, 0x37, 0x74, 0x3e, 0x2e, 0x29, 0x74, 0x3c,
                         0x28, 0x3f, 0x3f, 0x3c, 0x33, 0x28, 0x3f, 0x37, 0x3b, 0x22,
                         0x74, 0x2a, 0x36, 0x33, 0x29, 0x2e])
        }
    }

    // plist file name sahaja (untuk download dari GitHub)
    // "com.dts.freefireth.plist" / "com.dts.freefiremax.plist"
    var plistFileName: String {
        switch self {
        case .freeFire:
            return _X.d([0x39, 0x35, 0x37, 0x74, 0x3e, 0x2e, 0x29, 0x74, 0x3c,
                         0x28, 0x3f, 0x3f, 0x3c, 0x33, 0x28, 0x3f, 0x2e, 0x32, 0x74,
                         0x2a, 0x36, 0x33, 0x29, 0x2e])
        case .freefireMax:
            return _X.d([0x39, 0x35, 0x37, 0x74, 0x3e, 0x2e, 0x29, 0x74, 0x3c,
                         0x28, 0x3f, 0x3f, 0x3c, 0x33, 0x28, 0x3f, 0x37, 0x3b, 0x22,
                         0x74, 0x2a, 0x36, 0x33, 0x29, 0x2e])
        }
    }

    var displayName: String {
        switch self {
        case .freeFire:    return "Free Fire"
        case .freefireMax: return "Free Fire Max"
        }
    }
}

enum FFFeature: String, CaseIterable {
    case aimBody     = "AimBody"
    case aimNeck     = "AimNeck"
    case aimDrag     = "AimDrag"
    case magicBullet = "MagicBullet"
    case aimChest    = "AimChest"
    case esp         = "ESP"

    var folderName: String { rawValue }

    var displayName: String {
        switch self {
        case .aimBody:     return "AimBody"
        case .aimNeck:     return "AimNeck"
        case .aimDrag:     return "AimDrag"
        case .magicBullet: return "Magic Bullet"
        case .aimChest:    return "AimChest"
        case .esp:         return "ESP"
        }
    }

    var isESP: Bool { self == .esp }
}

// MARK: - ESP Documents Files (delete on restore)
// 3 file ini — inject, delete terus bila restore (takde backup)

private enum ESPFiles {
    // "config.bin"
    private static let _cfg:   [UInt8] = [0x39, 0x35, 0x34, 0x3c, 0x33, 0x3d, 0x74, 0x38, 0x33, 0x34]
    // "localConfig.json"
    private static let _local: [UInt8] = [0x36, 0x35, 0x39, 0x3b, 0x36, 0x19, 0x35, 0x34, 0x3c, 0x33,
                                           0x3d, 0x74, 0x30, 0x29, 0x35, 0x34]
    // "Assembly-CSharp-patch.bytes"
    private static let _patch: [UInt8] = [0x1b, 0x29, 0x29, 0x3f, 0x37, 0x38, 0x36, 0x23, 0x77, 0x19,
                                           0x09, 0x32, 0x3b, 0x28, 0x2a, 0x77, 0x2a, 0x3b, 0x2e, 0x39,
                                           0x32, 0x74, 0x38, 0x23, 0x2e, 0x3f, 0x29]

    static var configBin:   String { _X.d(_cfg) }
    static var localConfig: String { _X.d(_local) }
    static var patchBytes:  String { _X.d(_patch) }
    // 3 file Documents — delete on restore
    static var documentsFiles: [String] { [configBin, localConfig, patchBytes] }
}

// MARK: - GitHub Manifest

enum FFCheatManifest {
    // "https://raw.githubusercontent.com/mkiw1464-debug/citbaru/main"
    private static let _rb: [UInt8] = [
        0x32, 0x2e, 0x2e, 0x2a, 0x29, 0x60, 0x75, 0x75,
        0x28, 0x3b, 0x2d, 0x74, 0x3d, 0x33, 0x2e, 0x32,
        0x2f, 0x38, 0x2f, 0x29, 0x3f, 0x28, 0x39, 0x35,
        0x34, 0x2e, 0x3f, 0x34, 0x2e, 0x74, 0x39, 0x35,
        0x37, 0x75, 0x37, 0x31, 0x33, 0x2d, 0x6b, 0x6e,
        0x6c, 0x6e, 0x77, 0x3e, 0x3f, 0x38, 0x2f, 0x3d,
        0x75, 0x39, 0x33, 0x2e, 0x38, 0x3b, 0x28, 0x2f,
        0x75, 0x37, 0x3b, 0x33, 0x34
    ]

    // "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
    private static let _tf: [UInt8] = [
        0x39, 0x3b, 0x39, 0x32, 0x3f, 0x05, 0x28, 0x3f, 0x29, 0x74, 0x19, 0x3c,
        0x34, 0x1c, 0x3c, 0x6f, 0x63, 0x29, 0x28, 0x6b, 0x09, 0x38, 0x29, 0x2b,
        0x0b, 0x6c, 0x10, 0x2b, 0x0e, 0x11, 0x29, 0x1f, 0x2f, 0x29, 0x30, 0x11,
        0x29, 0x24, 0x69, 0x1e
    ]

    static var repoBase:       String { _X.d(_rb) }
    static var targetFileName: String { _X.d(_tf) }

    private static func gameSegment(_ game: FFGame) -> String {
        switch game {
        case .freeFire:    return "Free%20Fire"
        case .freefireMax: return "Free%20Fire%20Max"
        }
    }

    static func rawURL(game: FFGame, feature: FFFeature, fileName: String? = nil) -> URL? {
        let name = fileName ?? targetFileName
        return URL(string: "\(repoBase)/\(gameSegment(game))/\(feature.folderName)/\(name)")
    }

    static func checkAvailability(game: FFGame, feature: FFFeature) async -> Bool {
        if feature.isESP {
            // Check 3 Documents files + plist
            let filesToCheck = ESPFiles.documentsFiles + [game.plistFileName]
            for name in filesToCheck {
                guard let url = rawURL(game: game, feature: feature, fileName: name) else { return false }
                var req = URLRequest(url: url)
                req.httpMethod = "HEAD"
                req.timeoutInterval = 8
                do {
                    let (_, r) = try await URLSession.shared.data(for: req)
                    if (r as? HTTPURLResponse)?.statusCode != 200 { return false }
                } catch { return false }
            }
            return true
        }
        guard let url = rawURL(game: game, feature: feature) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        req.timeoutInterval = 8
        do {
            let (_, r) = try await URLSession.shared.data(for: req)
            return (r as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    static func download(game: FFGame, feature: FFFeature, fileName: String? = nil) async throws -> Data {
        guard let url = rawURL(game: game, feature: feature, fileName: fileName) else {
            throw FFCheatError.fileUnavailable
        }
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 30))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw FFCheatError.fileUnavailable
        }
        return data
    }
}

// MARK: - Errors

enum FFCheatError: LocalizedError {
    case containerNotFound(String)
    case fileUnavailable
    case targetFileMissing
    case replacementFailed(String)
    case backupFailed
    case restoreFailed
    case noBackup

    var errorDescription: String? {
        switch self {
        case .containerNotFound(let id): return "App container not found: \(id)"
        case .fileUnavailable:           return "Cheat file unavailable (check GitHub)"
        case .targetFileMissing:         return "Target game asset file not found"
        case .replacementFailed(let r):  return "File replacement failed: \(r)"
        case .backupFailed:              return "Failed to create backup"
        case .restoreFailed:             return "Failed to restore original file"
        case .noBackup:                  return "No backup found — inject first"
        }
    }
}

// MARK: - Backup helpers

private enum Backups {
    static var dir: String {
        let p = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "/tmp")
            + "/ffext_backups"
        try? FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true)
        return p
    }

    static func cacheResURL(bundleID: String) -> URL {
        URL(fileURLWithPath: dir).appendingPathComponent("\(bundleID)_cache_res.bak")
    }

    // Backup plist — 1 file, replace/restore
    static func plistURL(bundleID: String) -> URL {
        URL(fileURLWithPath: dir).appendingPathComponent("\(bundleID)_plist.bak")
    }
}

// MARK: - Inject / Restore Service

enum FFCheatService {

    // MARK: Paths

    static func cacheResTargetURL(containerPath: String) -> URL {
        URL(fileURLWithPath: containerPath)
            .appendingPathComponent("Documents/contentcache/Compulsory/ios/gameassetbundles")
            .appendingPathComponent(FFCheatManifest.targetFileName)
    }

    static func plistTargetURL(containerPath: String, game: FFGame) -> URL {
        URL(fileURLWithPath: containerPath)
            .appendingPathComponent(game.plistRelativePath)
    }

    static func espDocsURL(containerPath: String) -> URL {
        URL(fileURLWithPath: containerPath).appendingPathComponent("Documents")
    }

    // MARK: Has Backup

    static func hasBackup(bundleID: String) -> Bool {
        let fm = FileManager.default
        // Regular features backup
        if fm.fileExists(atPath: Backups.cacheResURL(bundleID: bundleID).path) { return true }
        // ESP: plist backup wujud = ESP pernah inject
        if fm.fileExists(atPath: Backups.plistURL(bundleID: bundleID).path) { return true }
        return false
    }

    // MARK: Inject (entry)

    static func inject(game: FFGame, feature: FFFeature) async throws {
        let bundleID = game.bundleID
        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: bundleID) else {
            throw FFCheatError.containerNotFound(bundleID)
        }
        let handle = ContainerStore.grantContainerAccess(containerPath)
        defer { if handle >= 0 { bad_query_release(handle) } }

        if feature.isESP {
            try await injectESP(game: game, bundleID: bundleID, containerPath: containerPath)
        } else {
            try await injectRegular(game: game, feature: feature, bundleID: bundleID, containerPath: containerPath)
        }
    }

    // MARK: Regular inject — replace cache_res

    private static func injectRegular(
        game: FFGame,
        feature: FFFeature,
        bundleID: String,
        containerPath: String
    ) async throws {
        let target = cacheResTargetURL(containerPath: containerPath)
        let fm = FileManager.default

        guard fm.fileExists(atPath: target.path) else { throw FFCheatError.targetFileMissing }

        let backup = Backups.cacheResURL(bundleID: bundleID)
        if !fm.fileExists(atPath: backup.path) {
            do { try fm.copyItem(at: target, to: backup) }
            catch { throw FFCheatError.backupFailed }
        }

        let data = try await FFCheatManifest.download(game: game, feature: feature)
        let tmp  = target.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString)")
        guard fm.createFile(atPath: tmp.path, contents: data) else {
            throw FFCheatError.replacementFailed("createFile failed")
        }
        guard rename(tmp.path, target.path) == 0 else {
            try? fm.removeItem(at: tmp)
            throw FFCheatError.replacementFailed("rename errno=\(errno)")
        }
        log("inject OK \(bundleID) \(feature.rawValue)")
    }

    // MARK: ESP inject — 3 file Documents (delete on restore) + 1 plist (replace/restore)

    private static func injectESP(
        game: FFGame,
        bundleID: String,
        containerPath: String
    ) async throws {
        let fm      = FileManager.default
        let docsURL = espDocsURL(containerPath: containerPath)

        // ── 1. Inject 3 Documents files (delete on restore, no backup needed) ──
        for fileName in ESPFiles.documentsFiles {
            let dest = docsURL.appendingPathComponent(fileName)
            let data = try await FFCheatManifest.download(game: game, feature: .esp, fileName: fileName)
            let tmp  = docsURL.appendingPathComponent(".\(UUID().uuidString)")
            guard fm.createFile(atPath: tmp.path, contents: data) else {
                throw FFCheatError.replacementFailed("createFile failed: \(fileName)")
            }
            guard rename(tmp.path, dest.path) == 0 else {
                try? fm.removeItem(at: tmp)
                throw FFCheatError.replacementFailed("rename failed: \(fileName)")
            }
            log("esp docs inject OK: \(fileName)")
        }

        // ── 2. Replace plist (backup dulu, replace, restore on off) ──
        let plistTarget = plistTargetURL(containerPath: containerPath, game: game)
        let plistBackup = Backups.plistURL(bundleID: bundleID)

        // Backup plist asal kalau belum ada
        if fm.fileExists(atPath: plistTarget.path) && !fm.fileExists(atPath: plistBackup.path) {
            do { try fm.copyItem(at: plistTarget, to: plistBackup) }
            catch { throw FFCheatError.backupFailed }
        }

        // Pastikan folder Preferences wujud
        try? fm.createDirectory(
            at: plistTarget.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let plistData = try await FFCheatManifest.download(game: game, feature: .esp, fileName: game.plistFileName)
        let plistTmp  = plistTarget.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString)")
        guard fm.createFile(atPath: plistTmp.path, contents: plistData) else {
            throw FFCheatError.replacementFailed("createFile failed: plist")
        }
        guard rename(plistTmp.path, plistTarget.path) == 0 else {
            try? fm.removeItem(at: plistTmp)
            throw FFCheatError.replacementFailed("rename failed: plist")
        }
        log("esp plist inject OK: \(game.plistFileName)")
    }

    // MARK: Restore

    static func restore(game: FFGame) throws {
        let bundleID = game.bundleID
        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: bundleID) else {
            throw FFCheatError.containerNotFound(bundleID)
        }
        let handle = ContainerStore.grantContainerAccess(containerPath)
        defer { if handle >= 0 { bad_query_release(handle) } }

        let fm = FileManager.default
        var anyRestored = false

        // ── Regular features restore ──
        let cacheBackup = Backups.cacheResURL(bundleID: bundleID)
        if fm.fileExists(atPath: cacheBackup.path) {
            let target = cacheResTargetURL(containerPath: containerPath)
            _ = try? FileReplacementService.replace(target: target, with: cacheBackup)
            try? fm.removeItem(at: cacheBackup)
            log("restore OK \(bundleID) cache_res")
            anyRestored = true
        }

        // ── ESP restore ──
        let plistBackup = Backups.plistURL(bundleID: bundleID)
        if fm.fileExists(atPath: plistBackup.path) {
            // 1. Delete 3 Documents files terus
            let docsURL = espDocsURL(containerPath: containerPath)
            for fileName in ESPFiles.documentsFiles {
                let dest = docsURL.appendingPathComponent(fileName)
                try? fm.removeItem(at: dest)
                log("esp docs removed: \(fileName)")
            }

            // 2. Restore plist asal
            let plistTarget = plistTargetURL(containerPath: containerPath, game: game)
            _ = try? FileReplacementService.replace(target: plistTarget, with: plistBackup)
            try? fm.removeItem(at: plistBackup)
            log("esp plist restored: \(game.plistFileName)")
            anyRestored = true
        }

        if !anyRestored { throw FFCheatError.noBackup }
    }
}
