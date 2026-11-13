import Cocoa
import Network

/// CLI configuration parsed from launch arguments
struct HostConfig {
    var isTestMode: Bool = false
    var port: UInt16 = 8888
    var mockInject: Bool = false
    var pingInterval: TimeInterval = 5.0
    
    static func parse(arguments: [String]) -> HostConfig {
        var config = HostConfig()
        var i = 1
        while i < arguments.count {
            let arg = arguments[i]
            if arg == "--test-mode" {
                config.isTestMode = true
            } else if arg == "--no-cg-inject" || arg == "--mock-inject" {
                config.mockInject = true
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
          --test-mode              Enable test mode with structured NDJSON event logs on stdout
          --port <PORT>            Specify listening WebSocket port (default: 8888)
          --no-cg-inject           Mock key injection without system CGEvent/Accessibility calls
          --ping-interval <SEC>    Heartbeat ping interval in seconds (default: 5.0)
          -h, --help               Show help information
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
    
    private(set) var currentState: String = "DISCONNECTED"
    var isConnected: Bool {
        return currentState == "CONNECTED"
    }
    
    init(config: HostConfig = HostConfig()) {
        self.config = config
        super.init()
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
            button.toolTip = connected
                ? (MacI18n.isChinese ? "Vocal: ✅ 已连接" : "Vocal: ✅ Connected")
                : (MacI18n.isChinese ? "Vocal: ⏳ 等待连接..." : "Vocal: ⏳ Waiting for connection...")
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
        
        let quitItem = NSMenuItem(title: MacI18n.quitVocal, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
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
                        // Cancel old connection if existing and different
                        if let old = self.connectedConnection, old !== connection {
                            print("Closing previous connection.")
                            old.cancel()
                        }
                        self.connectedConnection = connection
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
                       let type = json["type"] as? String, type == "text" {
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
                    
                    // Fallback to plain text if not handled as JSON
                    if !didHandleJson && !message.isEmpty {
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
