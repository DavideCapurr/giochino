import AppKit

struct OverlaySpec {
    let fileName: String
    let headline: String
    let subline: String?
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outDir = root.appendingPathComponent("marketing/overlays", isDirectory: true)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let size = NSSize(width: 1080, height: 1920)
let scale: CGFloat = 1

func paragraph(_ alignment: NSTextAlignment = .center) -> NSMutableParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.lineBreakMode = .byWordWrapping
    return style
}

func drawRoundedPanel(rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    stroke.setStroke()
    path.lineWidth = 2
    path.stroke()
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "Overlay", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG"])
    }
    try png.write(to: url)
}

func makeTransparentOverlay(_ spec: OverlaySpec) throws {
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()

    let panel = NSRect(x: 76, y: 1514, width: 928, height: spec.subline == nil ? 156 : 204)
    drawRoundedPanel(
        rect: panel,
        radius: 38,
        fill: NSColor.black.withAlphaComponent(0.62),
        stroke: NSColor.white.withAlphaComponent(0.20)
    )

    let titleFont = NSFont.systemFont(ofSize: 60, weight: .black)
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph()
    ]
    NSString(string: spec.headline).draw(
        in: NSRect(x: 118, y: panel.origin.y + panel.height - 94, width: 844, height: 76),
        withAttributes: titleAttrs
    )

    if let subline = spec.subline {
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 31, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.78),
            .paragraphStyle: paragraph()
        ]
        NSString(string: subline).draw(
            in: NSRect(x: 130, y: panel.origin.y + 36, width: 820, height: 48),
            withAttributes: subAttrs
        )
    }

    image.unlockFocus()
    try writePNG(image, to: outDir.appendingPathComponent(spec.fileName))
}

func makeEndCard() throws {
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.black.setFill()
    NSRect(origin: .zero, size: size).fill()

    let glowColors = [
        NSColor(calibratedRed: 0.0, green: 0.95, blue: 1.0, alpha: 0.22),
        NSColor(calibratedRed: 1.0, green: 0.08, blue: 0.58, alpha: 0.18),
        NSColor(calibratedRed: 0.4, green: 1.0, blue: 0.15, alpha: 0.16)
    ]
    let glowRects = [
        NSRect(x: -120, y: 1380, width: 460, height: 460),
        NSRect(x: 760, y: 1120, width: 520, height: 520),
        NSRect(x: 210, y: -120, width: 620, height: 620)
    ]
    for (color, rect) in zip(glowColors, glowRects) {
        color.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 96, weight: .black),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph()
    ]
    NSString(string: "ShiftBlast").draw(in: NSRect(x: 80, y: 1030, width: 920, height: 120), withAttributes: titleAttrs)

    let bodyAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 42, weight: .bold),
        .foregroundColor: NSColor.white.withAlphaComponent(0.82),
        .paragraphStyle: paragraph()
    ]
    NSString(string: "A quick puzzle instead of random scrolling.").draw(
        in: NSRect(x: 96, y: 930, width: 888, height: 70),
        withAttributes: bodyAttrs
    )

    drawRoundedPanel(
        rect: NSRect(x: 184, y: 760, width: 712, height: 104),
        radius: 34,
        fill: NSColor(calibratedRed: 0.4, green: 1.0, blue: 0.15, alpha: 0.16),
        stroke: NSColor(calibratedRed: 0.4, green: 1.0, blue: 0.15, alpha: 0.72)
    )
    let ctaAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 40, weight: .black),
        .foregroundColor: NSColor(calibratedRed: 0.55, green: 1.0, blue: 0.28, alpha: 1),
        .paragraphStyle: paragraph()
    ]
    NSString(string: "Free on iPhone").draw(in: NSRect(x: 220, y: 786, width: 640, height: 54), withAttributes: ctaAttrs)

    let urlAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 24, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.54),
        .paragraphStyle: paragraph()
    ]
    NSString(string: "apps.apple.com/app/id6767577147").draw(
        in: NSRect(x: 120, y: 680, width: 840, height: 42),
        withAttributes: urlAttrs
    )

    image.unlockFocus()
    try writePNG(image, to: outDir.appendingPathComponent("end-card.png"))
}

func makeTitleCard(fileName: String, headline: String, subline: String, accent: NSColor) throws {
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.black.setFill()
    NSRect(origin: .zero, size: size).fill()

    accent.withAlphaComponent(0.28).setFill()
    NSBezierPath(ovalIn: NSRect(x: -180, y: 1220, width: 620, height: 620)).fill()
    NSColor(calibratedRed: 1.0, green: 0.08, blue: 0.58, alpha: 0.18).setFill()
    NSBezierPath(ovalIn: NSRect(x: 760, y: 1040, width: 540, height: 540)).fill()

    let badgeRect = NSRect(x: 156, y: 1166, width: 768, height: 96)
    drawRoundedPanel(
        rect: badgeRect,
        radius: 36,
        fill: NSColor.white.withAlphaComponent(0.08),
        stroke: accent.withAlphaComponent(0.65)
    )
    let badgeAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 35, weight: .black),
        .foregroundColor: accent,
        .paragraphStyle: paragraph()
    ]
    NSString(string: "SHIFTBLAST").draw(in: NSRect(x: 190, y: 1192, width: 700, height: 44), withAttributes: badgeAttrs)

    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 82, weight: .black),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph()
    ]
    NSString(string: headline).draw(in: NSRect(x: 72, y: 906, width: 936, height: 220), withAttributes: titleAttrs)

    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 42, weight: .bold),
        .foregroundColor: NSColor.white.withAlphaComponent(0.78),
        .paragraphStyle: paragraph()
    ]
    NSString(string: subline).draw(in: NSRect(x: 96, y: 806, width: 888, height: 78), withAttributes: subAttrs)

    image.unlockFocus()
    try writePNG(image, to: outDir.appendingPathComponent(fileName))
}

let overlays = [
    OverlaySpec(fileName: "overlay-instead-of-scrolling.png", headline: "Instead of scrolling.", subline: "A quick puzzle for idle hands."),
    OverlaySpec(fileName: "overlay-while-show-is-on.png", headline: "While the show is on.", subline: "Simple moves. Satisfying clears."),
    OverlaySpec(fileName: "overlay-combo-overdrive.png", headline: "Swipe. Clear. Combo.", subline: "One more low-pressure run."),
    OverlaySpec(fileName: "overlay-stop-scrolling.png", headline: "Stop scrolling.", subline: "One quick run instead."),
    OverlaySpec(fileName: "overlay-one-more-run.png", headline: "One more run.", subline: "Fast clears. Tiny dopamine.")
]

for overlay in overlays {
    try makeTransparentOverlay(overlay)
}
try makeEndCard()
try makeTitleCard(
    fileName: "title-pov-tv.png",
    headline: "POV: TV is on.",
    subline: "Your thumb wants to scroll.",
    accent: NSColor(calibratedRed: 0.0, green: 0.97, blue: 1.0, alpha: 1)
)
try makeTitleCard(
    fileName: "title-stop-scroll.png",
    headline: "Stop the scroll.",
    subline: "One quick run instead.",
    accent: NSColor(calibratedRed: 0.4, green: 1.0, blue: 0.15, alpha: 1)
)
try makeTitleCard(
    fileName: "title-wait-for-it.png",
    headline: "Wait for it...",
    subline: "Swipe. Clear. Combo.",
    accent: NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.1, alpha: 1)
)
