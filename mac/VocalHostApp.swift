import Cocoa
import Network

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
    var statusItem: NSStatusItem?
    var netService: NetService?
    var listener: NWListener?
    var connectedConnection: NWConnection?
    var heartbeatTimer: Timer?
    var menuStatusText: String = MacI18n.starting {
        didSet { updateMenu() }
    }
    var isConnected: Bool = false {
        didSet {
            if isConnected {
                menuStatusText = MacI18n.connected
                updateIcon(connected: true)
                startHeartbeat()
            } else {
                menuStatusText = MacI18n.waitingConnection
                updateIcon(connected: false)
                stopHeartbeat()
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Vocal Host finished launching.")
        
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
    
    func updateIcon(connected: Bool) {
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: connected ? NSColor.systemGreen : NSColor.labelColor)
            let combined = config.applying(colorConfig)
            button.image = NSImage(systemSymbolName: connected ? "mic.fill" : "mic", accessibilityDescription: MacI18n.accessibilityDescription)?.withSymbolConfiguration(combined)
        }
    }
    
    func updateMenu() {
        let menu = NSMenu()
        
        let statusMenuItem = NSMenuItem(title: menuStatusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let permissionItem = NSMenuItem(title: MacI18n.checkPermissions, action: #selector(checkPermissions), keyEquivalent: "p")
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

        do {
            listener = try NWListener(using: parameters, on: 8888)
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("WebSocket Server ready on port 8888")
                    self.menuStatusText = MacI18n.advertising
                    self.startAdvertising()
                case .failed(let error):
                    print("Server failed: \(error)")
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { connection in
                print("New connection attempt received.")
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        print("WebSocket connection established and ready.")
                        self.connectedConnection = connection
                        self.receive(on: connection)
                        DispatchQueue.main.async {
                            self.isConnected = true
                        }
                    case .failed(let error):
                        print("Connection failed: \(error)")
                        DispatchQueue.main.async {
                            self.isConnected = false
                        }
                    case .cancelled:
                        print("Connection cancelled.")
                        DispatchQueue.main.async {
                            self.isConnected = false
                        }
                    default:
                        break
                    }
                }
                connection.start(queue: .main)
            }
            
            listener?.start(queue: .main)
        } catch {
            print("Failed to start listener: \(error)")
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
                } else {
                    // Try parsing as structured JSON first
                    var didHandleJson = false
                    if let jsonData = message.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let type = json["type"] as? String, type == "text" {
                        let text = json["text"] as? String ?? ""
                        let pressEnter = json["pressEnter"] as? Bool ?? false
                        if !text.isEmpty {
                            print("Injecting text from JSON: \(text), pressEnter: \(pressEnter)")
                            fflush(stdout)
                            self.injectText(text)
                            if pressEnter {
                                self.pressReturnKey()
                            }
                        }
                        didHandleJson = true
                    }
                    
                    // Fallback to plain text if not handled as JSON
                    if !didHandleJson && !message.isEmpty {
                        print("Injecting fallback plain text: \(message)")
                        fflush(stdout)
                        self.injectText(message)
                    }
                }
            }
            
            if error == nil {
                self.receive(on: connection)
            } else {
                print("Receive error or closure: \(String(describing: error))")
                fflush(stdout)
                DispatchQueue.main.async {
                    self.isConnected = false
                }
            }
        }
    }
    
    func injectText(_ text: String) {
        if !AXIsProcessTrusted() {
            print("⚠️ WARNING: Accessibility permission is NOT trusted! Text injection may fail.")
            fflush(stdout)
        }
        print("Injecting text: \(text)")
        fflush(stdout)
        let source = CGEventSource(stateID: .combinedSessionState)
        
        for char in text.utf16 {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            keyDown?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [char])
            keyDown?.post(tap: .cgAnnotatedSessionEventTap)
            
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            keyUp?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [char])
            keyUp?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    func pressReturnKey() {
        print("Simulating Return key...")
        let source = CGEventSource(stateID: .combinedSessionState)
        let returnKeyCode: CGKeyCode = 0x24 // kVK_Return
        
        // Wait briefly for unicode text injection to settle in active app
        usleep(30000) // 30ms
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: true)
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        
        usleep(10000) // 10ms
        
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: false)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
    
    func startAdvertising() {
        print("Starting mDNS advertising...")
        let hostName = Host.current().localizedName ?? "VocalHost"
        netService = NetService(domain: "local.", type: "_vocal._tcp", name: hostName, port: 8888)
        netService?.delegate = self
        netService?.publish()
    }
    
    func netServiceDidPublish(_ sender: NetService) {
        print("Service published successfully: \(sender.name).\(sender.type).\(sender.domain)")
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        print("Service failed to publish. Error: \(errorDict)")
    }
    
    @objc func checkPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        print("Accessibility permission trusted: \(trusted)")
        fflush(stdout)
        if !trusted {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Heartbeat
    
    func startHeartbeat() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.heartbeatTimer?.invalidate()
            self.heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.sendPing()
            }
            print("Heartbeat started.")
        }
    }
    
    func stopHeartbeat() {
        DispatchQueue.main.async {
            self.heartbeatTimer?.invalidate()
            self.heartbeatTimer = nil
            print("Heartbeat stopped.")
        }
    }
    
    func sendPing() {
        guard let connection = connectedConnection, isConnected else { return }
        let ping = "{\"type\": \"ping\"}"
        if let data = ping.data(using: .utf8) {
            let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
            let context = NWConnection.ContentContext(identifier: "ping", metadata: [metadata])
            connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed({ error in
                if let error = error {
                    print("Ping failed: \(error). Disconnecting.")
                    DispatchQueue.main.async {
                        self.isConnected = false
                        connection.cancel()
                    }
                }
            }))
        }
    }
}

@main
struct Launcher {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
