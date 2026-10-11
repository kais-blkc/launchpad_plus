// Накладывает на картинку стандартную форму иконки macOS (отступы + скруглённый квадрат + тень).
// Использование: swift scripts/make_icon.swift исходник.png результат.png
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let source = NSImage(contentsOfFile: args[1]) else {
    FileHandle.standardError.write(Data("usage: make_icon.swift in.png out.png\n".utf8)); exit(1)
}

let canvas = 1024
let body = NSRect(x: 100, y: 100, width: 824, height: 824)   // шаблон иконок Apple: тело 824 pt в холсте 1024
let radius: CGFloat = 185

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: canvas, height: canvas)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let shape = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

// мягкая тень под иконкой
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
NSColor.white.setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()

shape.addClip()
source.draw(in: body, from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
