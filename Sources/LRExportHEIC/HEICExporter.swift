import CoreImage
import Foundation
import ImageIO

struct ExportResult: Sendable {
  let outputURL: URL
  let duration: TimeInterval
  let fileSize: Int64
  let metadata: MetadataReport
}

enum ExportError: LocalizedError {
  case inputMissing(String), invalidImage(String), invalidEncodedImage(String)
  case destinationExists(String), cannotCreateDestination(String), encodingFailed(String)
  case metadataUnavailable(String), metadataCopyFailed(String), metadataVerificationFailed(String)
  case fileOperationFailed(String), unsupportedTenBit

  var errorDescription: String? {
    switch self {
    case .inputMissing(let path): "Input does not exist: \(path)"
    case .invalidImage(let path): "ImageIO cannot read input: \(path)"
    case .invalidEncodedImage(let path): "ImageIO cannot read encoded HEIC: \(path)"
    case .destinationExists(let path): "Destination already exists: \(path)"
    case .cannotCreateDestination(let path): "Cannot create destination: \(path)"
    case .encodingFailed(let detail): "Apple HEIC encoding failed: \(detail)"
    case .metadataUnavailable(let path): "No readable metadata in source: \(path)"
    case .metadataCopyFailed(let detail): "Metadata copy failed: \(detail)"
    case .metadataVerificationFailed(let detail): "Metadata verification failed: \(detail)"
    case .fileOperationFailed(let detail): "File operation failed: \(detail)"
    case .unsupportedTenBit: "10-bit HEIC requires macOS 12 or later"
    }
  }
}

struct HEICExporter {
  let logger: FileLogger

  func export(_ options: CommandLineOptions) throws -> ExportResult {
    let started = Date()
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: options.inputURL.path) else {
      throw ExportError.inputMissing(options.inputURL.path)
    }
    if fileManager.fileExists(atPath: options.outputURL.path), !options.overwrite {
      throw ExportError.destinationExists(options.outputURL.path)
    }
    try fileManager.createDirectory(
      at: options.outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    let inputProperties = try sourceProperties(options.inputURL)
    let detectedDepth = inputProperties[kCGImagePropertyDepth] as? Int ?? 8
    let tenBit = switch options.bitDepth {
    case .auto: detectedDepth > 8
    case .eight: false
    case .ten: true
    }
    guard let image = CIImage(contentsOf: options.inputURL, options: [.applyOrientationProperty: false]) else {
      throw ExportError.invalidImage(options.inputURL.path)
    }
    let colorSpace = options.colorSpace ?? image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!

    logger.info("start", fields: [
      "input": options.inputURL.path,
      "output": options.outputURL.path,
      "bitDepth": tenBit ? "10" : "8",
      "colorSpace": options.colorSpaceName ?? "source",
      "lightroomVersion": options.lightroomVersion ?? "unknown",
      "macOSVersion": ProcessInfo.processInfo.operatingSystemVersionString,
    ])

    let encoded = temporaryURL(beside: options.outputURL, suffix: "encoded")
    let metadataOutput = temporaryURL(beside: options.outputURL, suffix: "metadata")
    defer {
      try? fileManager.removeItem(at: encoded)
      try? fileManager.removeItem(at: metadataOutput)
    }

    let quality: Double
    if let directQuality = options.quality {
      quality = directQuality
      try encode(image, to: encoded, colorSpace: colorSpace, quality: quality, tenBit: tenBit)
    } else {
      quality = try encodeToSizeLimit(
        image, destination: encoded, colorSpace: colorSpace, limit: options.sizeLimit!,
        range: options.minimumQuality...options.maximumQuality, tenBit: tenBit)
    }
    logger.info("encoding complete", fields: ["quality": "\(quality)"])

    let report = try MetadataCopier.copyLosslessly(
      from: options.inputURL, encodedURL: encoded, to: metadataOutput)
    logger.info("metadata copy", fields: [
      "sourceTags": "\(report.sourceTagCount)",
      "destinationTags": "\(report.destinationTagCount)",
      "namespaces": report.namespaces.joined(separator: ","),
    ])
    try install(metadataOutput, at: options.outputURL, overwrite: options.overwrite)
    let size = try options.outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    return ExportResult(
      outputURL: options.outputURL,
      duration: Date().timeIntervalSince(started),
      fileSize: Int64(size),
      metadata: report
    )
  }

  private func encode(
    _ image: CIImage, to url: URL, colorSpace: CGColorSpace, quality: Double, tenBit: Bool
  ) throws {
    let options = [kCGImageDestinationLossyCompressionQuality: quality]
      as [CIImageRepresentationOption: Any]
    do {
      let context = CIContext(options: [.cacheIntermediates: false])
      if tenBit {
        try context.writeHEIF10Representation(of: image, to: url, colorSpace: colorSpace, options: options)
      } else {
        try context.writeHEIFRepresentation(
          of: image, to: url, format: .RGBA8, colorSpace: colorSpace, options: options)
      }
    } catch {
      throw ExportError.encodingFailed(error.localizedDescription)
    }
  }

  private func encodeToSizeLimit(
    _ image: CIImage, destination: URL, colorSpace: CGColorSpace, limit: Int64,
    range: ClosedRange<Double>, tenBit: Bool
  ) throws -> Double {
    var files: [Double: URL] = [:]
    defer { for url in files.values { try? FileManager.default.removeItem(at: url) } }
    var capturedError: Error?
    let chosen = qualitySearch(
      byTargetFileSize: limit, withAccuracy: 0.8, withinRange: range
    ) { candidate in
      let url = temporaryURL(beside: destination, suffix: "q\(candidate)")
      do {
        try encode(image, to: url, colorSpace: colorSpace, quality: candidate, tenBit: tenBit)
        files[candidate] = url
        return Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max)
      } catch {
        capturedError = error
        return Int64.max
      }
    }
    if let capturedError { throw capturedError }
    if let selected = files[chosen] {
      try FileManager.default.moveItem(at: selected, to: destination)
    } else {
      try encode(image, to: destination, colorSpace: colorSpace, quality: chosen, tenBit: tenBit)
    }
    return chosen
  }

  private func sourceProperties(_ url: URL) throws -> [CFString: Any] {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    else { throw ExportError.invalidImage(url.path) }
    return properties
  }

  private func temporaryURL(beside output: URL, suffix: String) -> URL {
    output.deletingLastPathComponent().appendingPathComponent(
      ".\(output.lastPathComponent).\(UUID().uuidString).\(suffix).heic")
  }

  private func install(_ source: URL, at destination: URL, overwrite: Bool) throws {
    do {
      if FileManager.default.fileExists(atPath: destination.path) {
        guard overwrite else { throw ExportError.destinationExists(destination.path) }
        _ = try FileManager.default.replaceItemAt(destination, withItemAt: source)
      } else {
        try FileManager.default.moveItem(at: source, to: destination)
      }
    } catch let error as ExportError { throw error }
    catch { throw ExportError.fileOperationFailed(error.localizedDescription) }
  }
}
