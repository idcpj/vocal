import Cocoa
import Network

/// Supported update distribution channels
enum UpdateChannel: String, Codable {
    case github
    case mas
}

/// Structured update release information
struct UpdateInfo {
    let currentVersion: String
    let latestVersion: String
    let releaseNotes: String?
    let downloadUrl: URL?
    let channel: UpdateChannel
    let hasUpdate: Bool
    var isIgnored: Bool
}

/// CLI configuration parsed from launch arguments
struct HostConfig {
    var isTestMode: Bool = false
    var port: UInt16 = 8888
    var mockInject: Bool = false
    var pingInterval: TimeInterval = 5.0
    var requirePin: Bool = false
    var pinCode: String? = nil
    var updateChannel: UpdateChannel = .github
    var updateUrl: String? = nil
    var checkUpdateOnLaunch: Bool = false
    
    static func parse(arguments: [String]) -> HostConfig {
        var config = HostConfig()
        var i = 1
        while i < arguments.count {
            let arg = arguments[i]
            if arg == "--test-mode" {
                config.isTestMode = true
            } else if arg == "--no-cg-inject" || arg == "--mock-inject" {
                config.mockInject = true
            } else if arg == "--require-pin" {
                config.requirePin = true
            } else if arg == "--pin" {
                i += 1
                if i < arguments.count {
                    config.pinCode = arguments[i]
                    config.requirePin = true
                }
            } else if arg.starts(with: "--pin=") {
                let val = String(arg.dropFirst("--pin=".count))
                config.pinCode = val
                config.requirePin = true
            } else if arg == "--port" {
                i += 1
                if i < arguments.count, let p = UInt16(arguments[i]), p > 0 {
                    config.port = p
                }
            } else if arg.starts(with: "--port=") {
                let val = String(arg.dropFirst("--port=".count))
                if let p = UInt16(val), p > 0 {
                    config.port = p
                }
            } else if arg == "--ping-interval" {
                i += 1
                if i < arguments.count, let interval = Double(arguments[i]), interval > 0 {
                    config.pingInterval = interval
                }
            } else if arg.starts(with: "--ping-interval=") {
                let val = String(arg.dropFirst("--ping-interval=".count))
                if let interval = Double(val), interval > 0 {
                    config.pingInterval = interval
                }
            } else if arg == "--update-channel" {
                i += 1
                if i < arguments.count {
                    if let channel = UpdateChannel(rawValue: arguments[i].lowercased()) {
                        config.updateChannel = channel
                    }
                }
            } else if arg.starts(with: "--update-channel=") {
                let val = String(arg.dropFirst("--update-channel=".count)).lowercased()
                if let channel = UpdateChannel(rawValue: val) {
                    config.updateChannel = channel
                }
            } else if arg == "--update-url" {
                i += 1
                if i < arguments.count {
                    config.updateUrl = arguments[i]
                }
            } else if arg.starts(with: "--update-url=") {
                let val = String(arg.dropFirst("--update-url=".count))
                config.updateUrl = val
            } else if arg == "--check-update-on-launch" {
                config.checkUpdateOnLaunch = true
            } else if arg == "-h" || arg == "--help" {
                printUsage()
                exit(0)
            }
            i += 1
        }
        return config
    }
    
    static func printUsage() {
        print("""
        Usage: VocalHost [options]
        Options:
          --test-mode                    Enable test mode with structured NDJSON event logs on stdout
          --port <PORT>                  Specify listening WebSocket port (default: 8888)
          --no-cg-inject                 Mock key injection without system CGEvent/Accessibility calls
          --ping-interval <SEC>          Heartbeat ping interval in seconds (default: 5.0)
          --require-pin                  Enforce PIN code authentication for connections
          --pin <PIN>                    Specify fixed 4-digit PIN for testing (enables PIN protection)
          --update-channel <github|mas>  Distribution channel for updates (default: github)
          --update-url <URL>             Custom endpoint URL for update checks (testing/mock)
          --check-update-on-launch       Trigger update check immediately upon launch
          -h, --help                     Show help information
        """)
    }
}

/// Lightweight i18n helper for Mac Host
struct MacI18n {
    static var isChinese: Bool {
        let lang = Locale.preferredLanguages.first?.lowercased() ?? Locale.current.identifier.lowercased()
        return lang.starts(with: "zh")
    }
    
    static var starting: String { isChinese ? "正在启动..." : "Starting..." }
    static var connected: String { isChinese ? "✅ 已连接" : "✅ Connected" }
    static var waitingConnection: String { isChinese ? "⏳ 等待连接..." : "⏳ Waiting for connection..." }
    static var advertising: String { isChinese ? "📡 广播中..." : "📡 Advertising..." }
    static var checkPermissions: String { isChinese ? "检查辅助功能权限" : "Check Permissions" }
    static var quitVocal: String { isChinese ? "退出 Vocal" : "Quit Vocal" }
    static var accessibilityDescription: String { isChinese ? "Vocal 语音输入宿主" : "Vocal Host" }
    static var pinProtection: String { isChinese ? "启用 PIN 码保护" : "Enable PIN Protection" }
    static var currentPin: String { isChinese ? "PIN 码: " : "PIN Code: " }
    static var refreshPin: String { isChinese ? "刷新 PIN 码" : "Refresh PIN" }
    static var clearTrustedDevices: String { isChinese ? "清除所有已配对设备" : "Clear All Paired Devices" }
    
    // Version Updates
    static var checkForUpdates: String { isChinese ? "检查新版本..." : "Check for Updates..." }
    static var checkingForUpdates: String { isChinese ? "正在检查更新..." : "Checking for Updates..." }
    static var autoCheckUpdates: String { isChinese ? "自动检查更新" : "Automatically Check for Updates" }
    static var resetIgnoredVersion: String { isChinese ? "重置已忽略的版本" : "Reset Ignored Version" }
    static var newVersionAvailable: String { isChinese ? "发现新版本" : "New Version Available" }
    static var upToDateTitle: String { isChinese ? "已是最新版本" : "You're Up to Date" }
    static var upToDateMessage: String { isChinese ? "当前 Vocal 版本已是最新版本。" : "Vocal is up to date." }
    static var updateAvailableTitle: String { isChinese ? "发现新版本" : "Update Available" }
    static var downloadNow: String { isChinese ? "立即下载" : "Download Now" }
    static var updateInAppStore: String { isChinese ? "前往 App Store 更新" : "Update in App Store" }
    static var remindLater: String { isChinese ? "稍后提醒" : "Remind Me Later" }
    static var skipThisVersion: String { isChinese ? "忽略此版本" : "Skip This Version" }
    static var updateCheckFailedTitle: String { isChinese ? "检查更新失败" : "Update Check Failed" }
    static var updateCheckFailedMessage: String { isChinese ? "无法获取版本信息，请检查网络连接。" : "Failed to retrieve update information. Please check your network." }
    static var releaseNotes: String { isChinese ? "更新内容：" : "Release Notes:" }
    static var currentVersionLabel: String { isChinese ? "当前版本：" : "Current Version:" }
    static var latestVersionLabel: String { isChinese ? "最新版本：" : "Latest Version:" }
    static var ok: String { isChinese ? "好" : "OK" }
}

/// Manages multi-channel version update checks (GitHub Releases & Mac App Store)
class UpdateManager: NSObject {
    weak var appDelegate: AppDelegate?
    let config: HostConfig
    
    private(set) var isChecking: Bool = false
    private(set) var availableUpdate: UpdateInfo?
    
    var currentVersion: String {
        if let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !ver.isEmpty {
            return ver
        }
        return "1.0.0"
    }
    
    var isAutoCheckEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "vocal_auto_check_update") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "vocal_auto_check_update")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "vocal_auto_check_update")
            appDelegate?.emitTestEvent([
                "vocal_event": "UPDATE_AUTO_CHECK_TOGGLED",
                "enabled": newValue
            ])
            appDelegate?.updateMenu()
        }
    }
    
    var ignoredVersion: String? {
        get {
            return UserDefaults.standard.string(forKey: "vocal_ignored_version")
        }
        set {
            let previous = UserDefaults.standard.string(forKey: "vocal_ignored_version")
            if let val = newValue {
                UserDefaults.standard.set(val, forKey: "vocal_ignored_version")
                appDelegate?.emitTestEvent([
                    "vocal_event": "UPDATE_ACTION_IGNORED",
                    "version": val
                ])
            } else {
                UserDefaults.standard.removeObject(forKey: "vocal_ignored_version")
                appDelegate?.emitTestEvent([
                    "vocal_event": "UPDATE_ACTION_RESET_IGNORED",
                    "previousVersion": previous ?? ""
                ])
            }
            if var update = availableUpdate {
                update.isIgnored = (newValue != nil && update.latestVersion == newValue)
                availableUpdate = update
            }
            appDelegate?.updateMenu()
        }
    }
    
    init(config: HostConfig, appDelegate: AppDelegate? = nil) {
        self.config = config
        self.appDelegate = appDelegate
        super.init()
    }
    
    /// Compares two semver-like version strings (e.g. "1.0.0" vs "1.1.0" or "v1.2.0")
    static func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let clean1 = v1.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\r\n"))
        let clean2 = v2.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\r\n"))
        
        let parts1 = clean1.split(separator: "-").first?.split(separator: ".").compactMap { Int($0) } ?? []
        let parts2 = clean2.split(separator: "-").first?.split(separator: ".").compactMap { Int($0) } ?? []
        
        let maxLen = max(parts1.count, parts2.count)
        for i in 0..<maxLen {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 < p2 { return .orderedAscending }
            if p1 > p2 { return .orderedDescending }
        }
        return .orderedSame
    }
    
    func defaultCheckUrl(for channel: UpdateChannel) -> String {
        switch channel {
        case .github:
            return "https://api.github.com/repos/idcpj/vocal/releases/latest"
        case .mas:
            return "https://itunes.apple.com/lookup?bundleId=com.idcpj.vocalhost"
        }
    }
    
    func checkForUpdates(isManual: Bool = false) {
        guard !isChecking else { return }
        isChecking = true
        appDelegate?.updateMenu()
        
        let channel = config.updateChannel
        let urlString = (config.updateUrl != nil && !config.updateUrl!.isEmpty)
            ? config.updateUrl!
            : defaultCheckUrl(for: channel)
        
        appDelegate?.emitTestEvent([
            "vocal_event": "UPDATE_CHECK_STARTED",
            "channel": channel.rawValue,
            "url": urlString,
            "isManual": isManual
        ])
        
        guard let url = URL(string: urlString) else {
            handleError("Invalid update URL: \(urlString)", isManual: isManual, channel: channel)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("VocalHost/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        if channel == .github {
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        }
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.handleError(error.localizedDescription, isManual: isManual, channel: channel)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode), let data = data else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                DispatchQueue.main.async {
                    self.handleError("HTTP request failed with status code \(code)", isManual: isManual, channel: channel)
                }
                return
            }
            
            do {
                let updateInfo = try self.parseUpdateResponse(data: data, channel: channel)
                DispatchQueue.main.async {
                    self.handleSuccess(updateInfo: updateInfo, isManual: isManual)
                }
            } catch {
                DispatchQueue.main.async {
                    self.handleError("Failed to parse update data: \(error.localizedDescription)", isManual: isManual, channel: channel)
                }
            }
        }
        task.resume()
    }
    
    private func parseUpdateResponse(data: Data, channel: UpdateChannel) throws -> UpdateInfo {
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        let curVer = currentVersion
        
        switch channel {
        case .github:
            guard let dict = jsonObject as? [String: Any] else {
                throw NSError(domain: "UpdateManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid GitHub Release JSON format"])
            }
            let rawTag = (dict["tag_name"] as? String) ?? (dict["name"] as? String) ?? ""
            let latestVersion = rawTag.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\r\n"))
            let releaseNotes = dict["body"] as? String
            let htmlUrl = (dict["html_url"] as? String).flatMap { URL(string: $0) }
            
            var dmgUrl: URL? = nil
            if let assets = dict["assets"] as? [[String: Any]] {
                for asset in assets {
                    if let assetName = asset["name"] as? String, assetName.hasSuffix(".dmg"),
                       let downloadStr = asset["browser_download_url"] as? String,
                       let url = URL(string: downloadStr) {
                        dmgUrl = url
                        break
                    }
                }
            }
            let finalDownloadUrl = dmgUrl ?? htmlUrl
            let hasUpdate = Self.compareVersions(curVer, latestVersion) == .orderedAscending
            let isIgnored = (self.ignoredVersion == latestVersion)
            
            return UpdateInfo(
                currentVersion: curVer,
                latestVersion: latestVersion,
                releaseNotes: releaseNotes,
                downloadUrl: finalDownloadUrl,
                channel: .github,
                hasUpdate: hasUpdate,
                isIgnored: isIgnored
            )
            
        case .mas:
            guard let dict = jsonObject as? [String: Any],
                  let results = dict["results"] as? [[String: Any]],
                  let first = results.first else {
                return UpdateInfo(
                    currentVersion: curVer,
                    latestVersion: curVer,
                    releaseNotes: nil,
                    downloadUrl: nil,
                    channel: .mas,
                    hasUpdate: false,
                    isIgnored: false
                )
            }
            
            let rawVersion = first["version"] as? String ?? ""
            let latestVersion = rawVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\r\n"))
            let releaseNotes = first["releaseNotes"] as? String
            let trackViewUrlStr = first["trackViewUrl"] as? String
            let downloadUrl = trackViewUrlStr.flatMap { URL(string: $0) }
            let hasUpdate = Self.compareVersions(curVer, latestVersion) == .orderedAscending
            let isIgnored = (self.ignoredVersion == latestVersion)
            
            return UpdateInfo(
                currentVersion: curVer,
                latestVersion: latestVersion,
                releaseNotes: releaseNotes,
                downloadUrl: downloadUrl,
                channel: .mas,
                hasUpdate: hasUpdate,
                isIgnored: isIgnored
            )
        }
    }
    
    private func handleSuccess(updateInfo: UpdateInfo, isManual: Bool) {
        self.isChecking = false
        self.availableUpdate = updateInfo
        
        var eventDict: [String: Any] = [
            "vocal_event": "UPDATE_CHECK_RESULT",
            "channel": updateInfo.channel.rawValue,
            "currentVersion": updateInfo.currentVersion,
            "latestVersion": updateInfo.latestVersion,
            "hasUpdate": updateInfo.hasUpdate,
            "isIgnored": updateInfo.isIgnored
        ]
        if let downloadUrl = updateInfo.downloadUrl {
            eventDict["downloadUrl"] = downloadUrl.absoluteString
        }
        if let notes = updateInfo.releaseNotes {
            eventDict["releaseNotes"] = notes
        }
        appDelegate?.emitTestEvent(eventDict)
        
        appDelegate?.updateMenu()
        appDelegate?.updateIcon(connected: appDelegate?.isConnected ?? false)
        
        // Present modal alert only in non-test interactive runs
        if !config.isTestMode {
            if updateInfo.hasUpdate {
                if !updateInfo.isIgnored || isManual {
                    showAlertForUpdate(updateInfo)
                }
            } else if isManual {
                showUpToDateAlert(updateInfo)
            }
        }
    }
    
    private func handleError(_ errorMsg: String, isManual: Bool, channel: UpdateChannel) {
        self.isChecking = false
        appDelegate?.emitTestEvent([
            "vocal_event": "UPDATE_CHECK_ERROR",
            "channel": channel.rawValue,
            "error": errorMsg
        ])
        appDelegate?.updateMenu()
        
        if isManual && !config.isTestMode {
            let alert = NSAlert()
            alert.messageText = MacI18n.updateCheckFailedTitle
            alert.informativeText = "\(MacI18n.updateCheckFailedMessage)\n(\(errorMsg))"
            alert.alertStyle = .warning
            alert.addButton(withTitle: MacI18n.ok)
            alert.runModal()
        }
    }
    
    func showAlertForUpdate(_ update: UpdateInfo) {
        let alert = NSAlert()
        alert.messageText = "\(MacI18n.updateAvailableTitle): v\(update.latestVersion)"
        var message = "\(MacI18n.currentVersionLabel) v\(update.currentVersion)\n\(MacI18n.latestVersionLabel) v\(update.latestVersion)"
        if let notes = update.releaseNotes, !notes.isEmpty {
            message += "\n\n\(MacI18n.releaseNotes)\n\(notes)"
        }
        alert.informativeText = message
        alert.alertStyle = .informational
        
        let primaryBtn = (update.channel == .mas) ? MacI18n.updateInAppStore : MacI18n.downloadNow
        alert.addButton(withTitle: primaryBtn)
        alert.addButton(withTitle: MacI18n.remindLater)
        alert.addButton(withTitle: MacI18n.skipThisVersion)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = update.downloadUrl {
                NSWorkspace.shared.open(url)
            }
        } else if response == .alertThirdButtonReturn {
            self.ignoredVersion = update.latestVersion
        }
    }
    
    func showUpToDateAlert(_ update: UpdateInfo) {
        let alert = NSAlert()
        alert.messageText = MacI18n.upToDateTitle
        alert.informativeText = "\(MacI18n.upToDateMessage) (\(MacI18n.currentVersionLabel) v\(update.currentVersion))"
        alert.alertStyle = .informational
        alert.addButton(withTitle: MacI18n.ok)
        alert.runModal()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NetServiceDelegate {
    let config: HostConfig
    var originalStdoutFile: UnsafeMutablePointer<FILE>?
    
    var statusItem: NSStatusItem?
    var netService: NetService?
    var listener: NWListener?
    var connectedConnection: NWConnection?
    var heartbeatTimer: Timer?
    var menuStatusText: String = MacI18n.starting {
        didSet { updateMenu() }
    }
    
    // MARK: - Update Manager
    lazy var updateManager: UpdateManager = {
        return UpdateManager(config: self.config, appDelegate: self)
    }()
    
    // MARK: - PIN Protection & Auth State
    var isPinProtectionEnabled: Bool = false
    var currentPin: String = "8492"
    var trustedTokens: Set<String> = []
    var isConnectionAuthenticated: Bool = false
    var failedPinAttempts: Int = 0
    
    private(set) var currentState: String = "DISCONNECTED"
    var isConnected: Bool {
        return currentState == "CONNECTED"
    }
    
    init(config: HostConfig = HostConfig()) {
        self.config = config
        super.init()
        
        // Initialize PIN protection state from config or UserDefaults
        let defaults = UserDefaults.standard
        if config.requirePin {
            self.isPinProtectionEnabled = true
        } else {
            self.isPinProtectionEnabled = defaults.bool(forKey: "vocal_pin_enabled")
        }
        
        if let pin = config.pinCode, !pin.isEmpty {
            self.currentPin = pin
        } else if let savedPin = defaults.string(forKey: "vocal_current_pin"), !savedPin.isEmpty {
            self.currentPin = savedPin
        } else {
            self.currentPin = String(format: "%04d", Int.random(in: 1000...9999))
            defaults.set(self.currentPin, forKey: "vocal_current_pin")
        }
        
        if let tokens = defaults.stringArray(forKey: "vocal_trusted_tokens") {
            self.trustedTokens = Set(tokens)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupLogging()
        print("\n=== Vocal Host Starting at \(Date()) ===")
        if config.isTestMode {
            print("Mode: TEST MODE (port: \(config.port), mockInject: \(config.mockInject), pingInterval: \(config.pingInterval)s)")
        }
        fflush(stdout)
        
        // Ensure the app shows in the status bar even without a bundle
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if statusItem?.button != nil {
            // Default to disconnected icon state
            updateIcon(connected: false)
        }
        
        updateMenu()
        checkPermissions()
        startWebSocketServer()
        
        // Check for updates on launch if configured or auto-check is enabled in normal mode
        if config.checkUpdateOnLaunch || (updateManager.isAutoCheckEnabled && !config.isTestMode) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.updateManager.checkForUpdates(isManual: false)
            }
        }
        
        // Bring to front if needed, but since it's an accessory app, it stays in the menu bar
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func setupLogging() {
        // Preserve original stdout descriptor before redirecting to log file
        // so that test harnesses can capture unbuffered NDJSON events via stdout.
        let origFd = dup(STDOUT_FILENO)
        if origFd != -1 {
            originalStdoutFile = fdopen(origFd, "w")
            if let originalStdoutFile = originalStdoutFile {
                setvbuf(originalStdoutFile, nil, _IONBF, 0)
            }
        }
        
        let logPath = NSHomeDirectory() + "/.vocalhost.log"
        freopen(logPath.cString(using: .utf8), "a+", stdout)
        freopen(logPath.cString(using: .utf8), "a+", stderr)
        setvbuf(stdout, nil, _IONBF, 0)
        setvbuf(stderr, nil, _IONBF, 0)
    }

    /// Emits structured NDJSON event to stdout if in test mode
    func emitTestEvent(_ jsonObject: [String: Any]) {
        guard config.isTestMode else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys]),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        let line = jsonString + "\n"
        let target = originalStdoutFile ?? stdout
        fputs(line, target)
        fflush(target)
        
        // Also mirror to log file if stdout was redirected
        if originalStdoutFile != nil {
            fputs("[NDJSON] " + line, stdout)
            fflush(stdout)
        }
    }
    
    /// State machine transition helper with guaranteed NDJSON emission and thread safety
    func transitionState(to newState: String, reason: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.transitionState(to: newState, reason: reason)
            }
            return
        }
        
        let oldState = currentState
        guard newState != oldState else { return }
        currentState = newState
        
        emitTestEvent([
            "vocal_event": "STATE_CHANGE",
            "from": oldState,
            "to": newState,
            "reason": reason
        ])
        
        if newState == "CONNECTED" {
            menuStatusText = MacI18n.connected
            updateIcon(connected: true)
            startHeartbeat()
        } else {
            menuStatusText = MacI18n.waitingConnection
            updateIcon(connected: false)
            stopHeartbeat()
        }
    }

    func updateIcon(connected: Bool) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateIcon(connected: connected)
            }
            return
        }
        
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: connected ? NSColor.systemGreen : NSColor.labelColor)
            let combined = config.applying(colorConfig)
            let image = NSImage(systemSymbolName: connected ? "mic.fill" : "mic", accessibilityDescription: MacI18n.accessibilityDescription)?.withSymbolConfiguration(combined)
            // CRITICAL: When connected, isTemplate MUST be false so systemGreen hierarchical tint is not stripped by NSStatusBar
            image?.isTemplate = !connected
            button.image = image
            
            let baseTooltip = connected
                ? (MacI18n.isChinese ? "Vocal: ✅ 已连接" : "Vocal: ✅ Connected")
                : (MacI18n.isChinese ? "Vocal: ⏳ 等待连接..." : "Vocal: ⏳ Waiting for connection...")
            
            let hasNewVersion = (updateManager.availableUpdate?.hasUpdate == true) && (updateManager.availableUpdate?.isIgnored == false)
            if hasNewVersion, let newVer = updateManager.availableUpdate?.latestVersion {
                button.toolTip = "\(baseTooltip)\n🎉 \(MacI18n.newVersionAvailable): v\(newVer)"
            } else {
                button.toolTip = baseTooltip
            }
        }
    }
    
    func updateMenu() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateMenu()
            }
            return
        }
        
        let menu = NSMenu()
        
        let statusMenuItem = NSMenuItem(title: menuStatusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        
        let isTrusted = AXIsProcessTrusted()
        let permTitle = isTrusted
            ? (MacI18n.isChinese ? "🟢 辅助功能权限已就绪" : "🟢 Accessibility Ready")
            : (MacI18n.isChinese ? "🔴 辅助功能未授权 (点击去授权)" : "🔴 Accessibility Required (Click)")
        let permissionItem = NSMenuItem(title: permTitle, action: #selector(checkPermissions), keyEquivalent: "p")
        menu.addItem(permissionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // PIN Protection Toggle
        let pinToggleItem = NSMenuItem(title: MacI18n.pinProtection, action: #selector(togglePinProtection), keyEquivalent: "")
        pinToggleItem.state = isPinProtectionEnabled ? .on : .off
        menu.addItem(pinToggleItem)
        
        if isPinProtectionEnabled {
            let pinItem = NSMenuItem(title: "\(MacI18n.currentPin)\(currentPin) (\(MacI18n.refreshPin))", action: #selector(refreshCurrentPin), keyEquivalent: "")
            menu.addItem(pinItem)
            
            let clearItem = NSMenuItem(title: MacI18n.clearTrustedDevices, action: #selector(clearAllTrustedDevices), keyEquivalent: "")
            menu.addItem(clearItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Version update items
        if let update = updateManager.availableUpdate, update.hasUpdate, !update.isIgnored {
            let updateNoticeItem = NSMenuItem(title: "🎉 \(MacI18n.newVersionAvailable): v\(update.latestVersion)", action: #selector(showAvailableUpdateAlert), keyEquivalent: "")
            menu.addItem(updateNoticeItem)
        }
        
        let checkUpdateTitle = updateManager.isChecking ? MacI18n.checkingForUpdates : MacI18n.checkForUpdates
        let checkUpdateItem = NSMenuItem(title: checkUpdateTitle, action: #selector(manualCheckForUpdates), keyEquivalent: "u")
        if updateManager.isChecking {
            checkUpdateItem.isEnabled = false
        }
        menu.addItem(checkUpdateItem)
        
        let autoCheckItem = NSMenuItem(title: MacI18n.autoCheckUpdates, action: #selector(toggleAutoCheckUpdate), keyEquivalent: "")
        autoCheckItem.state = updateManager.isAutoCheckEnabled ? .on : .off
        menu.addItem(autoCheckItem)
        
        if let ignored = updateManager.ignoredVersion {
            let resetIgnoredItem = NSMenuItem(title: "\(MacI18n.resetIgnoredVersion) (v\(ignored))", action: #selector(resetIgnoredVersion), keyEquivalent: "")
            menu.addItem(resetIgnoredItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: MacI18n.quitVocal, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc func manualCheckForUpdates() {
        updateManager.checkForUpdates(isManual: true)
    }
    
    @objc func toggleAutoCheckUpdate() {
        updateManager.isAutoCheckEnabled.toggle()
    }
    
    @objc func resetIgnoredVersion() {
        updateManager.ignoredVersion = nil
    }
    
    @objc func showAvailableUpdateAlert() {
        if let update = updateManager.availableUpdate {
            updateManager.showAlertForUpdate(update)
        }
    }
    
    @objc func togglePinProtection() {
        isPinProtectionEnabled.toggle()
        UserDefaults.standard.set(isPinProtectionEnabled, forKey: "vocal_pin_enabled")
        print("PIN Protection toggled: \(isPinProtectionEnabled)")
        emitTestEvent([
            "vocal_event": "PIN_PROTECTION_TOGGLED",
            "enabled": isPinProtectionEnabled,
            "pin": currentPin
        ])
        updateMenu()
    }
    
    @objc func refreshCurrentPin() {
        currentPin = String(format: "%04d", Int.random(in: 1000...9999))
        UserDefaults.standard.set(currentPin, forKey: "vocal_current_pin")
        print("PIN refreshed to: \(currentPin)")
        emitTestEvent([
            "vocal_event": "PIN_REFRESHED",
            "pin": currentPin
        ])
        updateMenu()
    }
    
    @objc func clearAllTrustedDevices() {
        trustedTokens.removeAll()
        UserDefaults.standard.removeObject(forKey: "vocal_trusted_tokens")
        print("All trusted paired devices cleared.")
        emitTestEvent([
            "vocal_event": "TRUSTED_DEVICES_CLEARED"
        ])
        updateMenu()
    }
    
    func startWebSocketServer() {
        let parameters = NWParameters.tcp
        let options = NWProtocolWebSocket.Options()
        parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)

        guard let nwPort = NWEndpoint.Port(rawValue: config.port) else {
            print("Invalid port specified: \(config.port)")
            return
        }

        do {
            listener = try NWListener(using: parameters, on: nwPort)
            listener?.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    print("WebSocket Server ready on port \(self.config.port)")
                    self.emitTestEvent([
                        "vocal_event": "SERVER_READY",
                        "port": Int(self.config.port)
                    ])
                    DispatchQueue.main.async {
                        self.menuStatusText = MacI18n.advertising
                        self.startAdvertising()
                    }
                case .failed(let error):
                    print("Server failed: \(error)")
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                guard let self = self else { return }
                print("New connection attempt received.")
                connection.stateUpdateHandler = { [weak self, weak connection] state in
                    guard let self = self, let connection = connection else { return }
                    switch state {
                    case .ready:
                        print("WebSocket connection established and ready.")
                        // Check if host is already occupied by an active connection
                        if self.isConnected && self.connectedConnection != nil && self.connectedConnection !== connection {
                            print("⚠️ Connection rejected: Host is already occupied by an active client.")
                            self.emitTestEvent([
                                "vocal_event": "CONNECTION_REJECTED",
                                "reason": "OCCUPIED"
                            ])
                            let occupiedPayload = "{\"type\":\"error\",\"code\":\"OCCUPIED\",\"message\":\"Host is occupied by another device\"}"
                            let data = occupiedPayload.data(using: .utf8) ?? Data()
                            let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
                            let context = NWConnection.ContentContext(identifier: "occupiedError", metadata: [metadata])
                            connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed({ error in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    print("Closed rejected secondary connection.")
                                    connection.cancel()
                                }
                            }))
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                connection.cancel()
                            }
                            return
                        }

                        // Cancel old connection if existing and different
                        if let old = self.connectedConnection, old !== connection {
                            print("Closing previous connection.")
                            old.cancel()
                        }
                        self.connectedConnection = connection
                        // Reset authentication state for new connection
                        if self.isPinProtectionEnabled {
                            self.isConnectionAuthenticated = false
                            self.failedPinAttempts = 0
                            print("PIN Protection active: connection requires PIN or trusted token.")
                        } else {
                            self.isConnectionAuthenticated = true
                            self.failedPinAttempts = 0
                        }
                        self.receive(on: connection)
                        self.transitionState(to: "CONNECTED", reason: "HANDSHAKE_COMPLETED")
                    case .failed(let error):
                        print("Connection failed: \(error)")
                        if self.connectedConnection === connection {
                            self.connectedConnection = nil
                            self.transitionState(to: "DISCONNECTED", reason: "CONNECTION_FAILED")
                        } else {
                            print("Ignoring failure from secondary/stale connection.")
                        }
                    case .cancelled:
                        print("Connection cancelled.")
                        if self.connectedConnection === connection {
                            self.connectedConnection = nil
                            self.transitionState(to: "DISCONNECTED", reason: "CONNECTION_CANCELLED")
                        } else {
                            print("Ignoring cancellation from secondary/stale connection.")
                        }
                    default:
                        break
                    }
                }
                connection.start(queue: .main)
            }
            
            listener?.start(queue: .main)
        } catch {
            print("Failed to start listener on port \(config.port): \(error)")
        }
    }
    
    func sendJson(to connection: NWConnection, object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "textFrame", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed({ error in
            if let error = error {
                print("Failed to send JSON frame: \(error)")
            }
        }))
    }
    
    func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] (data, context, isComplete, error) in
            guard let self = self else { return }
            if let data = data, !data.isEmpty, let message = String(data: data, encoding: .utf8) {
                print("📩 Received message from mobile: \(message)")
                fflush(stdout)
                
                if message.contains("\"type\":\"pong\"") || message.contains("\"type\": \"pong\"") {
                    print("Heartbeat pong received.")
                    fflush(stdout)
                    self.emitTestEvent(["vocal_event": "PONG_RECEIVED"])
                } else {
                    // Try parsing as structured JSON first
                    var didHandleJson = false
                    if let jsonData = message.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let type = json["type"] as? String {
                        
                        if type == "auth_request" {
                            didHandleJson = true
                            let token = json["token"] as? String ?? ""
                            let deviceId = json["deviceId"] as? String ?? ""
                            let deviceName = json["deviceName"] as? String ?? ""
                            
                            if !self.isPinProtectionEnabled {
                                self.isConnectionAuthenticated = true
                                self.sendJson(to: connection, object: ["type": "auth_success", "mode": "open"])
                                self.emitTestEvent([
                                    "vocal_event": "AUTH_SUCCESS",
                                    "mode": "open",
                                    "deviceId": deviceId
                                ])
                            } else if !token.isEmpty && self.trustedTokens.contains(token) {
                                self.isConnectionAuthenticated = true
                                self.sendJson(to: connection, object: ["type": "auth_success", "mode": "trusted"])
                                self.emitTestEvent([
                                    "vocal_event": "AUTH_SUCCESS",
                                    "mode": "trusted",
                                    "deviceId": deviceId
                                ])
                            } else {
                                self.isConnectionAuthenticated = false
                                self.sendJson(to: connection, object: ["type": "auth_require_pin"])
                                self.emitTestEvent([
                                    "vocal_event": "AUTH_REQUIRED",
                                    "deviceId": deviceId,
                                    "deviceName": deviceName
                                ])
                            }
                        } else if type == "auth_verify_pin" {
                            didHandleJson = true
                            let submittedPin = (json["pin"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                            if self.isPinProtectionEnabled && submittedPin == self.currentPin {
                                self.isConnectionAuthenticated = true
                                self.failedPinAttempts = 0
                                let newToken = "token_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
                                self.trustedTokens.insert(newToken)
                                UserDefaults.standard.set(Array(self.trustedTokens), forKey: "vocal_trusted_tokens")
                                self.sendJson(to: connection, object: ["type": "auth_success", "token": newToken])
                                self.emitTestEvent([
                                    "vocal_event": "AUTH_SUCCESS",
                                    "mode": "pin",
                                    "token": newToken
                                ])
                            } else {
                                self.failedPinAttempts += 1
                                let remaining = max(0, 3 - self.failedPinAttempts)
                                self.emitTestEvent([
                                    "vocal_event": "AUTH_FAILED",
                                    "reason": "INVALID_PIN",
                                    "remainingAttempts": remaining
                                ])
                                if remaining > 0 {
                                    self.sendJson(to: connection, object: [
                                        "type": "auth_failed",
                                        "reason": MacI18n.isChinese ? "PIN 码错误" : "Incorrect PIN",
                                        "remainingAttempts": remaining
                                    ])
                                } else {
                                    self.sendJson(to: connection, object: [
                                        "type": "auth_failed",
                                        "reason": MacI18n.isChinese ? "输错次数过多，连接已断开" : "Too many attempts, connection terminated",
                                        "remainingAttempts": 0
                                    ])
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        connection.cancel()
                                    }
                                }
                            }
                        } else if type == "text" {
                            // Check auth gate
                            if self.isPinProtectionEnabled && !self.isConnectionAuthenticated {
                                print("🛑 BLOCKED: Unauthorized text injection attempted while PIN protection is active!")
                                fflush(stdout)
                                self.emitTestEvent([
                                    "vocal_event": "AUTH_BLOCKED",
                                    "reason": "NOT_AUTHENTICATED"
                                ])
                                self.sendJson(to: connection, object: ["type": "auth_require_pin"])
                                didHandleJson = true
                            } else {
                                self.emitTestEvent([
                                    "vocal_event": "PAYLOAD_RECEIVED",
                                    "mode": "JSON",
                                    "raw": message
                                ])
                                let text = json["text"] as? String ?? ""
                                let pressEnter = json["pressEnter"] as? Bool ?? false
                                if !text.isEmpty {
                                    print("Injecting text from JSON: \(text), pressEnter: \(pressEnter)")
                                    fflush(stdout)
                                    self.injectText(text)
                                }
                                if pressEnter {
                                    self.pressReturnKey()
                                }
                                didHandleJson = true
                            }
                        } else if type == "update_control" {
                            didHandleJson = true
                            let action = json["action"] as? String ?? ""
                            if action == "toggle_auto_check" {
                                self.toggleAutoCheckUpdate()
                            } else if action == "ignore_version" {
                                let ver = json["version"] as? String ?? ""
                                self.updateManager.ignoredVersion = ver
                            } else if action == "reset_ignored" {
                                self.resetIgnoredVersion()
                            } else if action == "check_now" {
                                self.manualCheckForUpdates()
                            }
                        }
                    }
                    
                    // Fallback to plain text if not handled as JSON
                    if !didHandleJson && !message.isEmpty {
                        if self.isPinProtectionEnabled && !self.isConnectionAuthenticated {
                            print("🛑 BLOCKED: Unauthorized plain text injection attempted while PIN protection is active!")
                            fflush(stdout)
                            self.emitTestEvent([
                                "vocal_event": "AUTH_BLOCKED",
                                "reason": "NOT_AUTHENTICATED"
                            ])
                            self.sendJson(to: connection, object: ["type": "auth_require_pin"])
                        } else {
                            print("Injecting fallback plain text: \(message)")
                            fflush(stdout)
                            self.emitTestEvent([
                                "vocal_event": "PAYLOAD_RECEIVED",
                                "mode": "PLAIN_TEXT",
                                "raw": message
                            ])
                            self.injectText(message)
                        }
                    }
                }
            }
            
            if error == nil {
                self.receive(on: connection)
            } else {
                print("Receive error or closure: \(String(describing: error))")
                fflush(stdout)
                if self.connectedConnection === connection {
                    self.connectedConnection = nil
                    self.transitionState(to: "DISCONNECTED", reason: "CONNECTION_CLOSED")
                } else {
                    print("Ignoring receive error from secondary/stale connection.")
                }
            }
        }
    }
    
    func injectText(_ text: String) {
        if config.mockInject {
            print("[Mock] Injecting text: \(text)")
            fflush(stdout)
            emitTestEvent([
                "vocal_event": "TEXT_INJECTED",
                "text": text,
                "charCount": text.count,
                "mocked": true
            ])
            return
        }
        
        if !AXIsProcessTrusted() {
            print("⚠️ WARNING: Accessibility permission is NOT trusted! Text injection will be blocked by macOS.")
            fflush(stdout)
            checkPermissions()
            return
        }
        
        print("Injecting text: \(text)")
        fflush(stdout)
        emitTestEvent([
            "vocal_event": "TEXT_INJECTED",
            "text": text,
            "charCount": text.count,
            "mocked": false
        ])
        
        let source = CGEventSource(stateID: .combinedSessionState)
        for char in text {
            let unichars = Array(char.utf16)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            keyDown?.keyboardSetUnicodeString(stringLength: unichars.count, unicodeString: unichars)
            keyDown?.post(tap: .cgAnnotatedSessionEventTap)
            
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            keyUp?.keyboardSetUnicodeString(stringLength: unichars.count, unicodeString: unichars)
            keyUp?.post(tap: .cgAnnotatedSessionEventTap)
            
            // 2ms slight delay between characters to allow focused application to process event stream
            usleep(2000)
        }
    }

    func pressReturnKey() {
        if config.mockInject {
            print("[Mock] Simulating Return key...")
            fflush(stdout)
            emitTestEvent([
                "vocal_event": "RETURN_KEY_SIMULATED",
                "mocked": true
            ])
            return
        }
        
        if !AXIsProcessTrusted() {
            print("⚠️ WARNING: Accessibility permission is NOT trusted! Return key simulation blocked.")
            fflush(stdout)
            checkPermissions()
            return
        }
        
        print("Simulating Return key...")
        fflush(stdout)
        emitTestEvent([
            "vocal_event": "RETURN_KEY_SIMULATED",
            "mocked": false
        ])
        
        let source = CGEventSource(stateID: .combinedSessionState)
        let returnKeyCode: CGKeyCode = 0x24 // kVK_Return
        
        // Wait briefly for unicode text injection to settle in active app
        usleep(30000) // 30ms
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: true)
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        
        usleep(15000) // 15ms
        
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: false)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
    
    func startAdvertising() {
        print("Starting mDNS advertising on port \(config.port)...")
        let baseName = Host.current().localizedName ?? "VocalHost"
        let serviceName = (config.isTestMode && config.port != 8888) ? "\(baseName) (\(config.port))" : baseName
        netService = NetService(domain: "local.", type: "_vocal._tcp", name: serviceName, port: Int32(config.port))
        netService?.delegate = self
        netService?.publish()
    }
    
    func netServiceDidPublish(_ sender: NetService) {
        print("Service published successfully: \(sender.name).\(sender.type).\(sender.domain)")
        emitTestEvent([
            "vocal_event": "MDNS_PUBLISHED",
            "serviceName": sender.name,
            "type": "_vocal._tcp",
            "port": Int(config.port)
        ])
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        print("Service failed to publish. Error: \(errorDict)")
        if let errorCode = errorDict[NetService.errorCode]?.intValue, errorCode == -72001 {
            // Collision error: retry with a unique test suffix
            let fallbackName = "\(sender.name) (\(config.port))"
            print("Retrying mDNS publish with unique name: \(fallbackName)")
            sender.stop()
            netService = NetService(domain: "local.", type: "_vocal._tcp", name: fallbackName, port: Int32(config.port))
            netService?.delegate = self
            netService?.publish()
        }
    }
    
    @objc func checkPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        print("Accessibility permission trusted: \(trusted)")
        fflush(stdout)
        // In mock mode (e.g. CI testing), avoid popping system settings window
        if !trusted && !config.mockInject {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        updateMenu()
    }

    // MARK: - Heartbeat
    
    func startHeartbeat() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.heartbeatTimer?.invalidate()
            let interval = self.config.pingInterval
            let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
                self?.sendPing()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.heartbeatTimer = timer
            print("Heartbeat started with interval \(interval)s.")
        }
    }
    
    func stopHeartbeat() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.heartbeatTimer?.invalidate()
            self.heartbeatTimer = nil
            print("Heartbeat stopped.")
        }
    }
    
    func sendPing() {
        guard let connection = connectedConnection, currentState == "CONNECTED" else { return }
        let ping = "{\"type\": \"ping\"}"
        if let data = ping.data(using: .utf8) {
            let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
            let context = NWConnection.ContentContext(identifier: "ping", metadata: [metadata])
            connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed({ [weak self, weak connection] error in
                guard let self = self else { return }
                if let error = error {
                    print("Ping failed: \(error). Disconnecting.")
                    if self.connectedConnection === connection {
                        self.connectedConnection = nil
                        self.transitionState(to: "DISCONNECTED", reason: "PING_FAILED")
                        connection?.cancel()
                    } else {
                        print("Ignoring ping error from secondary/stale connection.")
                    }
                } else {
                    self.emitTestEvent(["vocal_event": "PING_SENT"])
                }
            }))
        }
    }
}

@main
struct Launcher {
    static func main() {
        let config = HostConfig.parse(arguments: CommandLine.arguments)
        let app = NSApplication.shared
        let delegate = AppDelegate(config: config)
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
