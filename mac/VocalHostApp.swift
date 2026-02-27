import Cocoa
import Network

class AppDelegate: NSObject, NSApplicationDelegate, NetServiceDelegate {
    var statusItem: NSStatusItem?
    var netService: NetService?
    var listener: NWListener?
    var connectedConnection: NWConnection?
    var heartbeatTimer: Timer?
    var menuStatusText: String = "Starting..." {
        didSet { updateMenu() }
    }
    var isConnected: Bool = false {
        didSet {
            if isConnected {
                menuStatusText = "✅ Connected"
                updateIcon(connected: true)
                startHeartbeat()
            } else {
                menuStatusText = "⏳ Waiting for connection..."
                updateIcon(connected: false)
                stopHeartbeat()
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Vocal Host finished launching.")
        
        // Ensure the app shows in the status bar even without a bundle
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Default to disconnected icon state
            updateIcon(connected: false)
        }
        
        updateMenu()
        startWebSocketServer()
        
        // Bring to front if needed, but since it's an accessory app, it stays in the menu bar
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func updateIcon(connected: Bool) {
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: connected ? NSColor.systemGreen : NSColor.labelColor)
            let combined = config.applying(colorConfig)
            button.image = NSImage(systemSymbolName: connected ? "mic.fill" : "mic", accessibilityDescription: "Vocal Host")?.withSymbolConfiguration(combined)
        }
    }
    
    func updateMenu() {
        let menu = NSMenu()
        
        let statusMenuItem = NSMenuItem(title: menuStatusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let permissionItem = NSMenuItem(title: "Check Permissions", action: #selector(checkPermissions), keyEquivalent: "p")
        menu.addItem(permissionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Vocal", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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
                    self.menuStatusText = "📡 Advertising..."
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
            if let data = data, !data.isEmpty {
                if let message = String(data: data, encoding: .utf8) {
                    if message.contains("\"type\":\"pong\"") || message.contains("\"type\": \"pong\"") {
                        print("Heartbeat pong received.")
                    } else if !message.contains("\"type\":") {
                        // message = full recognized string from mobile (one whole sentence sent at once)
                        let fullText = message
                        if !fullText.isEmpty {
                            print("Injecting: \(fullText)")
                            self.injectText(fullText)
                        }
                    }
                }
            }
            
            if error == nil {
                self.receive(on: connection)
            } else {
                print("Receive error or closure: \(String(describing: error))")
                DispatchQueue.main.async {
                    self.isConnected = false
                }
            }
        }
    }
    
    func injectText(_ text: String) {
        print("Injecting text: \(text)")
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
        let _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - Heartbeat
    
    func startHeartbeat() {
        DispatchQueue.main.async {
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
