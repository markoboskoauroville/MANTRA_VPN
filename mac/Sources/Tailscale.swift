// Tailscale.swift: the whole VPN is Tailscale's exit node. This app holds no key, no address, no secret: it asks the
// Tailscale already signed in on this Mac which of Marko's machines offers itself as an exit node (chromium-vm in
// Frankfurt), and switches the Mac's traffic to it (FRANKFURT) or back (DIRECT). A stranger who downloads the app is not
// in Marko's tailnet, sees no exit node, and can do nothing.
//
//   FRANKFURT  tailscale set --exit-node=<the exit node's 100.x address> --exit-node-allow-lan-access=true
//   DIRECT     tailscale set --exit-node=
//
// LAN access stays allowed, so the home network (Sound Link to the Pixel, adb over Wi-Fi, the printer) keeps working
// while the internet goes out through Frankfurt.
import AppKit
import Foundation

struct ExitPeer: Equatable {
    let name: String      // HostName, e.g. chromium-vm
    let ip: String        // its first Tailscale address, used for --exit-node
    let online: Bool
    let active: Bool      // this Mac's traffic goes through it now
}

struct PublicIP: Equatable {
    var ip = "", city = "", region = "", country = "", org = ""
    var countryName: String {
        guard !country.isEmpty else { return "" }
        return Locale(identifier: "en_US").localizedString(forRegionCode: country) ?? country
    }
}

final class VPN: ObservableObject {
    static let preferred = "chromium-vm"      // the Frankfurt VM; any other exit node of the tailnet is used if it is missing

    @Published var cliFound = false
    @Published var backend = ""               // Running, NeedsLogin, Stopped, Starting, NoState
    @Published var exitNode: ExitPeer? = nil  // the exit node FRANKFURT uses
    @Published var activeExit: ExitPeer? = nil
    @Published var pub = PublicIP()
    @Published var ipState = "…"              // "", "…", or why the lookup failed
    @Published var busy = ""                  // "FRANKFURT" or "DIRECT" while switching
    @Published var message = ""

    private var timer: Timer?
    private var ipTimer: Timer?
    private var lastActive: String? = "-"
    private let q = DispatchQueue(label: "vpn.cli")

    static let cliPaths = ["/Applications/Tailscale.app/Contents/MacOS/Tailscale", "/usr/local/bin/tailscale",
                           "/opt/homebrew/bin/tailscale"]
    var cli: String? { VPN.cliPaths.first { FileManager.default.isExecutableFile(atPath: $0) } }

    var running: Bool { backend == "Running" }
    /// Honest lit word: the exit node is in use, or the world already sees the Frankfurt VM (Oracle / Germany).
    var isFrankfurt: Bool {
        if activeExit != nil { return true }
        let o = pub.org.lowercased()
        return o.contains("oracle") || pub.country == "DE"
    }

    func start() {
        refreshStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refreshStatus() }
        // one small lookup every ten minutes (the Mac's uplink is a SIM), and one after every switch
        ipTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in self?.refreshIP() }
    }

    // MARK: status

    func refreshStatus() {
        q.async { [weak self] in
            guard let self else { return }
            guard let cli = self.cli else {
                DispatchQueue.main.async { self.cliFound = false; self.backend = ""; self.exitNode = nil; self.activeExit = nil }
                return
            }
            let (code, out) = VPN.run(cli, ["status", "--json"])
            var backend = "", best: ExitPeer? = nil, active: ExitPeer? = nil
            if let j = try? JSONSerialization.jsonObject(with: Data(out.utf8)) as? [String: Any] {
                backend = j["BackendState"] as? String ?? ""
                // Tailscale 1.104: the exit node in use is named in ExitNodeStatus.ID (peer "ID"), not only Peer.ExitNode
                let usedID = (j["ExitNodeStatus"] as? [String: Any])?["ID"] as? String
                var options: [ExitPeer] = []
                for (_, v) in (j["Peer"] as? [String: Any]) ?? [:] {
                    guard let p = v as? [String: Any] else { continue }
                    let offers = p["ExitNodeOption"] as? Bool ?? false
                    let using = (p["ExitNode"] as? Bool ?? false) || (usedID != nil && p["ID"] as? String == usedID)
                    guard offers || using else { continue }
                    let ips = p["TailscaleIPs"] as? [String] ?? []
                    let peer = ExitPeer(name: p["HostName"] as? String ?? "?",
                                        ip: ips.first { !$0.contains(":") } ?? ips.first ?? "",
                                        online: p["Online"] as? Bool ?? false, active: using)
                    options.append(peer)
                    if using { active = peer }
                }
                best = active ?? options.first(where: { $0.name == VPN.preferred }) ?? options.sorted(by: { $0.name < $1.name }).first
            } else {
                VPN.log("status unreadable (exit \(code)): \(out.prefix(300))")
                backend = out.lowercased().contains("not running") || out.lowercased().contains("failed to connect") ? "Stopped" : ""
            }
            DispatchQueue.main.async {
                self.cliFound = true
                if self.backend != backend { VPN.log("backend \(self.backend) -> \(backend), exit node \(active?.name ?? "none")") }
                self.backend = backend
                self.exitNode = best
                self.activeExit = active
                let key = active?.name ?? ""
                if self.lastActive != key { self.lastActive = key; self.refreshIP(after: 1.5) }
            }
        }
    }

    // MARK: switching

    func frankfurt() {
        guard busy.isEmpty, let cli else { return }
        guard running else { message = "Tailscale is not connected. Press CONNECT."; return }
        guard let node = exitNode else {
            message = "No exit node in your tailnet yet: approve chromium-vm as exit node in the Tailscale admin."
            return
        }
        busy = "FRANKFURT"; message = ""
        q.async { [weak self] in
            let (code, out) = VPN.run(cli, ["set", "--exit-node=\(node.ip)", "--exit-node-allow-lan-access=true"])
            VPN.log("FRANKFURT set exit \(code): \(out.prefix(200))")
            DispatchQueue.main.async {
                self?.busy = ""
                self?.message = code == 0 ? "" : VPN.short(out)
                self?.refreshStatus()
            }
        }
    }

    func direct() {
        guard busy.isEmpty, let cli else { return }
        busy = "DIRECT"; message = ""
        q.async { [weak self] in
            let (code, out) = VPN.run(cli, ["set", "--exit-node="])
            VPN.log("DIRECT set exit \(code): \(out.prefix(200))")
            DispatchQueue.main.async {
                self?.busy = ""
                self?.message = code == 0 ? "" : VPN.short(out)
                self?.refreshStatus()
            }
        }
    }

    /// CONNECT (amber, top right): opens Tailscale so he can sign in or switch it on.
    func openTailscale() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Tailscale.app"))
    }

    // MARK: the public address

    func refreshIP(after delay: Double = 0) {
        DispatchQueue.main.async { self.ipState = "…" }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) { [weak self] in
            let cfg = URLSessionConfiguration.ephemeral
            cfg.timeoutIntervalForRequest = 8
            cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
            var req = URLRequest(url: URL(string: "https://ipinfo.io/json")!)
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            URLSession(configuration: cfg).dataTask(with: req) { data, _, err in
                var p = PublicIP(), state = ""
                if let data, let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let ip = j["ip"] as? String {
                    p.ip = ip
                    p.city = j["city"] as? String ?? ""
                    p.region = j["region"] as? String ?? ""
                    p.country = j["country"] as? String ?? ""
                    p.org = j["org"] as? String ?? ""
                } else {
                    state = err.map { "no answer (\($0.localizedDescription))" } ?? "no answer"
                }
                DispatchQueue.main.async {
                    guard let self else { return }
                    if state.isEmpty { self.pub = p }
                    self.ipState = state
                }
            }.resume()
        }
    }

    // MARK: helpers

    /// ~/Library/Logs/VPN (Mantra).log
    static func log(_ s: String) {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/VPN (Mantra).log")
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let line = "\(f.string(from: Date())) v\(VERSION) \(s)\n"
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close() }
        else { try? line.write(to: url, atomically: true, encoding: .utf8) }
    }

    static func short(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Tailscale refused the change." : String(t.prefix(300))
    }

    /// Runs the Tailscale CLI; stdout and stderr together, at most 15 s.
    static func run(_ exe: String, _ args: [String]) -> (Int32, String) {
        let p = Process(), out = Pipe()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        // The cause of "always DIRECT" (v1): Tailscale.app's one binary is the GUI unless TAILSCALE_BE_CLI is set or a
        // terminal environment is present; launched from a GUI app it answered "The Tailscale GUI failed to start".
        var env = ProcessInfo.processInfo.environment
        env["TAILSCALE_BE_CLI"] = "1"
        env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
        p.environment = env
        p.standardInput = FileHandle.nullDevice
        p.standardOutput = out
        p.standardError = out
        do { try p.run() } catch { return (-1, "\(error)") }
        let killer = DispatchWorkItem { if p.isRunning { p.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 15, execute: killer)
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        killer.cancel()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
