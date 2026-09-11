// Draws the disk image's window background.
//
// A user opened Keeper and met "Apple could not verify that Keeper is free of malware", with
// Move to Trash as the first button. The way through exists — System Settings, Privacy &
// Security, Open Anyway — but it was only written in a text file beside the icon, and nobody
// opens a text file when there is an app right there to double-click. It goes on the window
// itself now, where it cannot be walked past.
//
// Each language gets its whole path in its own words rather than a translated blurb, because the
// thing a reader is actually hunting for is the label on the button, and a Russian speaker
// scanning System Settings needs to have seen "Всё равно открыть", not "Open Anyway".
//
// The background is light on purpose. Finder draws icon labels in the system's appearance, not
// the image's, so dark artwork leaves black filenames unreadable on a Mac in light mode.

import AppKit
import Foundation

// The height is the window's *content* area, not the whole window: Finder anchors the background
// under the title bar, so artwork as tall as the frame gets its last inch cut off and the window
// grows a scrollbar. make-dmg.sh sets bounds 28 points taller than this.
let width: CGFloat = 640, height: CGFloat = 590

let paper = NSColor(calibratedRed: 0.957, green: 0.953, blue: 0.941, alpha: 1)
let ink = NSColor(calibratedWhite: 0.11, alpha: 1)
let muted = NSColor(calibratedWhite: 0.48, alpha: 1)
let rule = NSColor(calibratedWhite: 0.84, alpha: 1)
let arrowColor = NSColor(calibratedWhite: 0.72, alpha: 1)

/// Language tag, then the whole route in that language. The separator is the one Apple uses in
/// its own breadcrumbs, so it reads as a path rather than a sentence.
let routes: [(String, String)] = [
    ("EN", "System Settings › Privacy & Security › Open Anyway"),
    ("UK", "Системні параметри › Конфіденційність і безпека › Усе одно відкрити"),
    ("RU", "Системные настройки › Конфиденциальность и безопасность › Всё равно открыть"),
    ("DE", "Systemeinstellungen › Datenschutz & Sicherheit › Trotzdem öffnen"),
    ("FR", "Réglages Système › Confidentialité et sécurité › Ouvrir quand même"),
    ("IT", "Impostazioni di Sistema › Privacy e sicurezza › Apri comunque"),
    ("PL", "Ustawienia systemowe › Prywatność i ochrona › Otwórz mimo to"),
]

func draw(scale: CGFloat) -> Data {
    let pixels = NSSize(width: width * scale, height: height * scale)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .calibratedRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    // Draw in the same top-left coordinates the Finder window positions use, so the artwork and
    // the icon placements in make-dmg.sh are written in one system rather than two.
    context.cgContext.translateBy(x: 0, y: pixels.height / scale)
    context.cgContext.scaleBy(x: 1, y: -1)

    paper.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()

    func text(_ string: String, _ font: NSFont, _ colour: NSColor, at point: NSPoint,
              centred: Bool = false) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colour]
        let size = (string as NSString).size(withAttributes: attributes)
        var origin = point
        if centred { origin.x -= size.width / 2 }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.translateBy(x: 0, y: origin.y + size.height)
        NSGraphicsContext.current?.cgContext.scaleBy(x: 1, y: -1)
        (string as NSString).draw(at: NSPoint(x: origin.x, y: 0), withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
    }

    // The drag: a long shallow arrow between where the two icons sit.
    let arrow = NSBezierPath()
    let y: CGFloat = 112
    arrow.move(to: NSPoint(x: 258, y: y))
    arrow.line(to: NSPoint(x: 366, y: y))
    arrow.lineWidth = 3
    arrow.lineCapStyle = .round
    arrowColor.setStroke()
    arrow.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 382, y: y))
    head.line(to: NSPoint(x: 362, y: y - 9))
    head.line(to: NSPoint(x: 362, y: y + 9))
    head.close()
    arrowColor.setFill()
    head.fill()

    text("Drag Keeper onto Applications", NSFont.systemFont(ofSize: 12), muted,
         at: NSPoint(x: width / 2, y: 178), centred: true)

    rule.setFill()
    NSRect(x: 44, y: 204, width: width - 88, height: 1).fill()

    text("⚠︎  The first time you open Keeper, macOS blocks it. That is because it is not sold",
         NSFont.systemFont(ofSize: 12.5, weight: .semibold), ink, at: NSPoint(x: 44, y: 232))
    text("through the App Store. Go here, and it opens — once, and never again:",
         NSFont.systemFont(ofSize: 12.5, weight: .semibold), ink, at: NSPoint(x: 63, y: 251))

    for (index, route) in routes.enumerated() {
        let lineY = 282 + CGFloat(index) * 19
        text(route.0, NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold), muted,
             at: NSPoint(x: 44, y: lineY + 1))
        text(route.1, NSFont.systemFont(ofSize: 12), ink, at: NSPoint(x: 76, y: lineY))
    }

    // Sits directly above where make-dmg.sh places the note, so the sentence and the icon it
    // refers to are one thing.
    text("Every step, in every language, including this one:", NSFont.systemFont(ofSize: 11),
         muted, at: NSPoint(x: width / 2, y: 424), centred: true)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/dmg-background"
try draw(scale: 1).write(to: URL(fileURLWithPath: "\(output).png"))
try draw(scale: 2).write(to: URL(fileURLWithPath: "\(output)@2x.png"))
print("wrote \(output).png and \(output)@2x.png")
