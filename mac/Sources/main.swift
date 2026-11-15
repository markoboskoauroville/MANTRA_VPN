// VPN (Mantra): the whole Mac goes out to the internet through Marko's Frankfurt VM (FRANKFURT), or straight (DIRECT).
// One window, CAMERA language (green on, grey off, amber warning): the house top row, the one switch, and a table of
// what the internet sees (public IP, country, city, provider) and what Tailscale says. Every control is an
// Accessibility button named by its word.
import AppKit
import SwiftUI

enum C {
    static let bg = Color(red: 0x15 / 255, green: 0x18 / 255, blue: 0x1B / 255)
    static let green = Color(red: 0x33 / 255, green: 0xD1 / 255, blue: 0x7A / 255)
    static let grey = Color(red: 0x7A / 255, green: 0x80 / 255, blue: 0x87 / 255)
    static let amber = Color(red: 0xE8 / 255, green: 0xA3 / 255, blue: 0x3D / 255)
    static let dark = Color(red: 0x33 / 255, green: 0x38 / 255, blue: 0x3E / 255)
    static let text = Color(red: 0xE6 / 255, green: 0xE8 / 255, blue: 0xEA / 255)
    static let line = Color(white: 1, opacity: 0.12)
}

struct Word: View {
    let word: String
    let color: Color
    var size: CGFloat = 13
    let action: () -> Void
    @State var hover = false
    var body: some View {
        Button(action: action) {
            Text(word)
                .font(.system(size: size, weight: .bold, design: .monospaced))
                .tracking(size * 0.04)
                .foregroundColor(color)
                .underline(hover)
                .fixedSize()
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in hover = h; if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        .accessibilityLabel(word)
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(C.line).frame(height: 1).padding(.vertical, 10) }
}

struct Cell: View {
    let label: String
    let value: String
    var color: Color = C.text
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(C.grey)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Rectangle().fill(C.line).frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MainView: View {
    @ObservedObject var vpn: VPN
    @State var onTop = false

    var tailscaleWord: String {
        if !vpn.cliFound { return "NOT INSTALLED" }
        switch vpn.backend {
        case "Running": return "CONNECTED"
        case "NeedsLogin": return "SIGNED OUT"
        case "Stopped": return "OFF"
        case "": return "NOT RUNNING"
        default: return vpn.backend.uppercased()
        }
    }

    var exitWord: String {
        guard let n = vpn.exitNode else { return "none offered" }
        return n.name + (n.online ? "" : " (offline)") + (n.active ? " · IN USE" : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // the house top row: name · ON · OFF · TOP ............ CONNECT · v1 · ✕
            HStack(spacing: 12) {
                Text(APP_NAME).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(C.text).fixedSize()
                Word(word: "ON", color: C.green) {}
                Word(word: "OFF", color: C.grey) { NSApp.terminate(nil) }
                Word(word: "TOP", color: onTop ? C.green : C.grey) {
                    onTop.toggle()
                    NSApp.windows.forEach { $0.level = onTop ? .floating : .normal }
                }
                Spacer(minLength: 8)
                if !vpn.running {
                    Word(word: "CONNECT", color: C.amber) { vpn.openTailscale() }
                }
                Word(word: "v\(VERSION)", color: C.grey) {
                    NSWorkspace.shared.open(URL(string: REPO_URL + "/releases/latest")!)
                }
                Button { NSApp.keyWindow?.performClose(nil) } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).foregroundColor(C.grey)
                        .frame(width: 28, height: 28).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("CLOSE")
            }
            Hairline()

            // the one switch: the lit word is where the Mac's internet goes now
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Word(word: "FRANKFURT",
                     color: vpn.busy == "FRANKFURT" ? C.amber : vpn.isFrankfurt ? C.green : (vpn.exitNode == nil || !vpn.running ? C.dark : C.grey),
                     size: 30) { vpn.frankfurt() }
                Text("|").font(.system(size: 30, weight: .light, design: .monospaced)).foregroundColor(C.line)
                Word(word: "DIRECT",
                     color: vpn.busy == "DIRECT" ? C.amber : vpn.isFrankfurt ? C.grey : C.green,
                     size: 30) { vpn.direct() }
            }
            if !vpn.message.isEmpty {
                Text(vpn.message)
                    .font(.system(size: 12, design: .monospaced)).foregroundColor(C.amber)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            Hairline()

            // what the internet sees, and what Tailscale says
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 16) {
                    Cell(label: "PUBLIC IP", value: vpn.ipState.isEmpty ? vpn.pub.ip : vpn.ipState,
                         color: vpn.ipState.isEmpty ? C.text : C.grey)
                    Cell(label: "COUNTRY", value: vpn.pub.countryName)
                }
                HStack(alignment: .top, spacing: 16) {
                    Cell(label: "CITY", value: vpn.pub.city)
                    Cell(label: "PROVIDER", value: vpn.pub.org)
                }
                HStack(alignment: .top, spacing: 16) {
                    Cell(label: "EXIT NODE", value: exitWord, color: vpn.exitNode == nil ? C.amber : C.text)
                    Cell(label: "TAILSCALE", value: tailscaleWord, color: vpn.running ? C.green : C.amber)
                }
            }
            HStack {
                Spacer()
                Word(word: "CHECK IP", color: C.grey, size: 11) { vpn.refreshIP() }
            }
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 360, maxWidth: .infinity, minHeight: 330, maxHeight: .infinity, alignment: .topLeading)
        .background(C.bg)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let vpn = VPN()
    var window: NSWindow!

    func applicationDidFinishLaunching(_ note: Notification) {
        buildMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 380),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = APP_NAME
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 360, height: 330)
        window.backgroundColor = NSColor(red: 0x15 / 255, green: 0x18 / 255, blue: 0x1B / 255, alpha: 1)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = NSHostingView(rootView: MainView(vpn: vpn))
        window.setFrameAutosaveName("VPNMantraMain")
        if !window.setFrameUsingName("VPNMantraMain") { window.center() }
        if !CommandLine.arguments.contains("--login") { window.makeKeyAndOrderFront(nil) }
        NSApp.activate(ignoringOtherApps: true)
        vpn.start()
        Updater.checkAtStart()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window.makeKeyAndOrderFront(nil)
        return true
    }

    func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Check for Updates", action: #selector(checkUpdates), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(APP_NAME)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        let winItem = NSMenuItem(); main.addItem(winItem)
        let win = NSMenu(title: "Window")
        win.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        winItem.submenu = win
        NSApp.mainMenu = main
    }

    @objc func checkUpdates() { Updater.checkAtStart(delay: 0, manual: true) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
