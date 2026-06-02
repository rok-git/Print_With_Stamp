import AppKit
import Foundation
import PDFKit

enum StampPosition: String {
    case center
    case topLeft = "top-left"
    case topRight = "top-right"
    case bottomLeft = "bottom-left"
    case bottomRight = "bottom-right"
}

enum PageSelection {
    case all
    case first
    case list(String)
}

struct Options {
    var inputPDF: URL?
    var stampText = "STAMP"
    var printer: String?
    var outputPDF: URL?
    var position = StampPosition.topRight
    var pages = PageSelection.all
    var stampSize: CGFloat?
    var opacity: CGFloat = 0.55
    var rotation: CGFloat = -18
    var margin: CGFloat = 48
    var shouldPrint = false
    var dryRun = false
}

enum AppError: Error, CustomStringConvertible {
    case usage(String)
    case missingInput
    case unreadablePDF(String)
    case invalidPages(String)
    case cannotCreatePDF
    case cannotWriteOutput(String)
    case printFailed(Int32, String)

    var description: String {
        switch self {
        case .usage(let message):
            return message
        case .missingInput:
            return "Input PDF is required."
        case .unreadablePDF(let path):
            return "Could not read PDF: \(path)"
        case .invalidPages(let message):
            return message
        case .cannotCreatePDF:
            return "Could not create stamped PDF."
        case .cannotWriteOutput(let path):
            return "Could not write stamped PDF: \(path)"
        case .printFailed(let status, let output):
            return "Print command failed with status \(status).\n\(output)"
        }
    }
}

func printUsage() {
    let text = """
    Usage:
      print-with-stamp INPUT.pdf [options]

    Options:
      --stamp TEXT              Stamp text. Default: STAMP
      --print                   Send the stamped PDF to lp
      --printer NAME            Printer name passed to lp -d
      --output PATH             Keep the stamped PDF at PATH
      --position NAME           center, top-left, top-right, bottom-left, bottom-right
      --pages PAGES             all, first, or page ranges like 1,3,5-7. Default: all
      --stamp-size POINTS       Stamp font size. Default: auto
      --opacity VALUE           0.0-1.0. Default: 0.55
      --rotation DEGREES        Default: -18
      --margin POINTS           Default: 48
      --dry-run                 Create the stamped PDF but do not print
      --help                    Show this help
    """
    FileHandle.standardOutput.write(Data(text.utf8))
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func parseOptions(_ arguments: [String]) throws -> Options {
    var options = Options()
    var index = 1

    while index < arguments.count {
        let argument = arguments[index]

        if argument == "--help" || argument == "-h" {
            printUsage()
            exit(0)
        } else if argument == "--dry-run" {
            options.dryRun = true
        } else if argument == "--print" {
            options.shouldPrint = true
        } else if argument.hasPrefix("--") {
            guard index + 1 < arguments.count else {
                throw AppError.usage("Missing value for \(argument).")
            }
            let value = arguments[index + 1]
            index += 1

            switch argument {
            case "--stamp":
                options.stampText = value
            case "--printer":
                options.printer = value
            case "--output":
                options.outputPDF = URL(fileURLWithPath: value)
            case "--position":
                guard let position = StampPosition(rawValue: value) else {
                    throw AppError.usage("Unknown position: \(value)")
                }
                options.position = position
            case "--pages":
                switch value {
                case "all":
                    options.pages = .all
                case "first":
                    options.pages = .first
                default:
                    options.pages = .list(value)
                }
            case "--stamp-size":
                guard let stampSize = Double(value), stampSize > 0 else {
                    throw AppError.usage("Stamp size must be greater than zero.")
                }
                options.stampSize = CGFloat(stampSize)
            case "--opacity":
                guard let opacity = Double(value), opacity >= 0, opacity <= 1 else {
                    throw AppError.usage("Opacity must be between 0.0 and 1.0.")
                }
                options.opacity = CGFloat(opacity)
            case "--rotation":
                guard let rotation = Double(value) else {
                    throw AppError.usage("Rotation must be a number.")
                }
                options.rotation = CGFloat(rotation)
            case "--margin":
                guard let margin = Double(value), margin >= 0 else {
                    throw AppError.usage("Margin must be zero or greater.")
                }
                options.margin = CGFloat(margin)
            default:
                throw AppError.usage("Unknown option: \(argument)")
            }
        } else if options.inputPDF == nil {
            options.inputPDF = URL(fileURLWithPath: argument)
        } else {
            throw AppError.usage("Unexpected argument: \(argument)")
        }

        index += 1
    }

    return options
}

func selectedPageIndexes(from selection: PageSelection, pageCount: Int) throws -> Set<Int> {
    switch selection {
    case .all:
        return Set(0..<pageCount)
    case .first:
        return [0]
    case .list(let value):
        var selected = Set<Int>()
        let parts = value.split(separator: ",", omittingEmptySubsequences: false)

        guard !parts.isEmpty else {
            throw AppError.invalidPages("Pages must not be empty.")
        }

        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw AppError.invalidPages("Pages contain an empty item.")
            }

            let bounds = trimmed.split(separator: "-", omittingEmptySubsequences: false)
            if bounds.count == 1 {
                guard let pageNumber = Int(bounds[0]), pageNumber >= 1, pageNumber <= pageCount else {
                    throw AppError.invalidPages("Page \(trimmed) is outside the document range 1-\(pageCount).")
                }
                selected.insert(pageNumber - 1)
            } else if bounds.count == 2 {
                guard
                    let start = Int(bounds[0]),
                    let end = Int(bounds[1]),
                    start >= 1,
                    end >= start,
                    end <= pageCount
                else {
                    throw AppError.invalidPages("Page range \(trimmed) is invalid for document range 1-\(pageCount).")
                }
                for pageNumber in start...end {
                    selected.insert(pageNumber - 1)
                }
            } else {
                throw AppError.invalidPages("Page item \(trimmed) is invalid.")
            }
        }

        return selected
    }
}

func stampCenter(in pageRect: CGRect, textSize: CGSize, position: StampPosition, margin: CGFloat) -> CGPoint {
    switch position {
    case .center:
        return CGPoint(x: pageRect.midX, y: pageRect.midY)
    case .topLeft:
        return CGPoint(x: pageRect.minX + margin + textSize.width / 2, y: pageRect.maxY - margin - textSize.height / 2)
    case .topRight:
        return CGPoint(x: pageRect.maxX - margin - textSize.width / 2, y: pageRect.maxY - margin - textSize.height / 2)
    case .bottomLeft:
        return CGPoint(x: pageRect.minX + margin + textSize.width / 2, y: pageRect.minY + margin + textSize.height / 2)
    case .bottomRight:
        return CGPoint(x: pageRect.maxX - margin - textSize.width / 2, y: pageRect.minY + margin + textSize.height / 2)
    }
}

func drawStamp(text: String, on pageRect: CGRect, options: Options, context: CGContext) {
    let shortestSide = max(min(pageRect.width, pageRect.height), 1)
    let fontSize = options.stampSize ?? max(24, shortestSide * 0.085)
    let font = NSFont.boldSystemFont(ofSize: fontSize)
    let strokeWidth = max(2, fontSize * 0.08)
    let padding = fontSize * 0.25

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.systemRed.withAlphaComponent(options.opacity),
        .strokeColor: NSColor.systemRed.withAlphaComponent(options.opacity),
        .strokeWidth: -2.0
    ]
    let attributedText = NSAttributedString(string: text, attributes: attributes)
    let textSize = attributedText.size()
    let boxSize = CGSize(width: textSize.width + padding * 2, height: textSize.height + padding * 1.5)
    let center = stampCenter(in: pageRect, textSize: boxSize, position: options.position, margin: options.margin)
    let box = CGRect(x: -boxSize.width / 2, y: -boxSize.height / 2, width: boxSize.width, height: boxSize.height)

    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: options.rotation * .pi / 180)
    context.setAlpha(options.opacity)
    context.setStrokeColor(NSColor.systemRed.cgColor)
    context.setLineWidth(strokeWidth)
    context.stroke(box)

    let textOrigin = CGPoint(x: -textSize.width / 2, y: -textSize.height / 2)
    attributedText.draw(at: textOrigin)
    context.restoreGState()
}

func createStampedPDF(inputURL: URL, outputURL: URL, options: Options) throws {
    guard let document = PDFDocument(url: inputURL), document.pageCount > 0 else {
        throw AppError.unreadablePDF(inputURL.path)
    }
    let selectedPages = try selectedPageIndexes(from: options.pages, pageCount: document.pageCount)

    let outputData = NSMutableData()
    guard let consumer = CGDataConsumer(data: outputData as CFMutableData) else {
        throw AppError.cannotCreatePDF
    }

    var mediaBox = CGRect.zero
    guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        throw AppError.cannotCreatePDF
    }

    let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext

    for pageIndex in 0..<document.pageCount {
        guard let page = document.page(at: pageIndex) else {
            continue
        }

        var pageRect = page.bounds(for: .mediaBox)
        context.beginPDFPage([kCGPDFContextMediaBox as String: NSData(bytes: &pageRect, length: MemoryLayout<CGRect>.size)] as CFDictionary)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(pageRect)
        page.draw(with: .mediaBox, to: context)
        if selectedPages.contains(pageIndex) {
            drawStamp(text: options.stampText, on: pageRect, options: options, context: context)
        }
        context.endPDFPage()
    }

    NSGraphicsContext.restoreGraphicsState()
    context.closePDF()

    guard outputData.write(to: outputURL, atomically: true) else {
        throw AppError.cannotWriteOutput(outputURL.path)
    }
}

func makeTemporaryOutputURL() -> URL {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    return directory.appendingPathComponent("print-with-stamp-\(UUID().uuidString).pdf")
}

func printPDF(_ pdfURL: URL, printer: String?) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/lp")
    var arguments: [String] = []
    if let printer {
        arguments.append(contentsOf: ["-d", printer])
    }
    arguments.append(pdfURL.path)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    if process.terminationStatus != 0 {
        throw AppError.printFailed(process.terminationStatus, output)
    }

    FileHandle.standardOutput.write(Data(output.utf8))
}

func run() throws {
    let options = try parseOptions(CommandLine.arguments)
    guard let inputURL = options.inputPDF else {
        throw AppError.missingInput
    }

    if options.outputPDF == nil && !options.shouldPrint && !options.dryRun {
        throw AppError.usage("Specify --output to save the stamped PDF, or --print to print it.")
    }

    let outputURL = options.outputPDF ?? makeTemporaryOutputURL()
    try createStampedPDF(inputURL: inputURL, outputURL: outputURL, options: options)

    if options.dryRun || !options.shouldPrint {
        print("Stamped PDF created: \(outputURL.path)")
        return
    }

    try printPDF(outputURL, printer: options.printer)

    if options.outputPDF == nil {
        try? FileManager.default.removeItem(at: outputURL)
    }
}

do {
    try run()
} catch let error as AppError {
    FileHandle.standardError.write(Data("Error: \(error.description)\n".utf8))
    FileHandle.standardError.write(Data("Run with --help for usage.\n".utf8))
    exit(1)
} catch {
    FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
    exit(1)
}
