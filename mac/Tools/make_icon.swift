// make_icon.swift: the icon by the six-letter rule (MANTRA_MANIFEST modules/six-letter-icon.md): VPN over FRA (Frankfurt),
// one symbol behind them (a globe), the Mac tools category colour. Run by build.sh on GitHub's runner:
//   swift make_icon.swift <dir.iconset>
// The drawing is the one of STAR_SWIFT/icons6/six_icon.swift (the sf: branch), kept here so the build needs nothing else.
import AppKit
let top = "VPN", bottom = "FRA", symbols = ["globe.europe.africa", "globe"]
let color = NSColor(srgbRed: 0x9A / 255, green: 0x64 / 255, blue: 0x00 / 255, alpha: 1)
func font(_ size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: .black)
    return NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: size) ?? base
}
func draw(_ px: Int) -> NSBitmapImageRep {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.imageInterpolation = .high
    let m = s * 100 / 1024, box = NSRect(x: m, y: m, width: s - 2 * m, height: s - 2 * m)
    let tile = NSBezierPath(roundedRect: box, xRadius: s * 185 / 1024, yRadius: s * 185 / 1024)
    NSGradient(starting: color.blended(withFraction: 0.18, of: .white)!, ending: color.blended(withFraction: 0.35, of: .black)!)!
        .draw(in: tile, angle: -90)
    tile.addClip()
    let white = NSColor(white: 1, alpha: 0.46)
    let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.62, weight: .bold)
    if let img = symbols.lazy.compactMap({ NSImage(systemSymbolName: $0, accessibilityDescription: nil) }).first?.withSymbolConfiguration(cfg) {
        let tinted = NSImage(size: img.size, flipped: false) { r in img.draw(in: r); white.set(); r.fill(using: .sourceAtop); return true }
        let k = min(box.width * 0.98 / tinted.size.width, box.height * 0.98 / tinted.size.height)
        let w = tinted.size.width * k, h = tinted.size.height * k
        tinted.draw(in: NSRect(x: (s - w) / 2, y: (s - h) / 2, width: w, height: h))
    }
    var fs = s * 0.40
    let shadow = NSShadow(); shadow.shadowColor = NSColor(white: 0, alpha: 0.75)
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.008); shadow.shadowBlurRadius = s * 0.025
    func attrs(_ f: CGFloat) -> [NSAttributedString.Key: Any] { [.font: font(f), .foregroundColor: NSColor.white, .shadow: shadow, .kern: f * 0.02] }
    let wmax = max((top as NSString).size(withAttributes: attrs(fs)).width, (bottom as NSString).size(withAttributes: attrs(fs)).width)
    fs *= box.width * 0.68 / wmax
    fs = min(fs, s * 0.34)
    let f = font(fs), cap = f.capHeight, gap = cap * 0.42
    let y0 = s / 2 - (2 * cap + gap) / 2
    for (str, base) in [(bottom, y0), (top, y0 + cap + gap)] {
        let w = (str as NSString).size(withAttributes: attrs(fs)).width
        (str as NSString).draw(at: NSPoint(x: (s - w) / 2 + fs * 0.01, y: base + f.descender), withAttributes: attrs(fs))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}
let set = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)
for (n, p) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
               ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! draw(p).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(set)/icon_\(n).png"))
}
