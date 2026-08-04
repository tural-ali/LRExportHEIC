import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import LRExportHEIC

@Suite("Native HEIC pipeline", .serialized)
struct ImagePipelineTests {
  @Test("Encodes JPEG and TIFF inputs", arguments: [UTType.jpeg, UTType.tiff])
  func inputFormats(type: UTType) throws {
    let fixture = try Fixture(type: type, bitsPerComponent: 8)
    defer { fixture.remove() }
    let output = fixture.directory.appendingPathComponent("output.heic")
    _ = try exporter(in: fixture.directory).export(options(input: fixture.url, output: output, depth: .eight))
    #expect(CGImageSourceCreateWithURL(output as CFURL, nil) != nil)
    #expect(try MetadataCopier.tags(at: fixture.url).isSubset(of: MetadataCopier.tags(at: output)))
  }

  @Test("Encodes 16-bit TIFF as 10-bit HEIC")
  func tenBit() throws {
    let fixture = try Fixture(type: .tiff, bitsPerComponent: 16)
    defer { fixture.remove() }
    let output = fixture.directory.appendingPathComponent("ten-bit.heic")
    _ = try exporter(in: fixture.directory).export(options(input: fixture.url, output: output, depth: .ten))
    let properties = try imageProperties(output)
    #expect((properties[kCGImagePropertyDepth] as? Int ?? 0) >= 10)
  }

  @Test("Preserves metadata and embeds the output ICC profile")
  func metadata() throws {
    let fixture = try Fixture(type: .tiff, bitsPerComponent: 16)
    defer { fixture.remove() }
    let output = fixture.directory.appendingPathComponent("metadata.heic")
    let result = try exporter(in: fixture.directory).export(
      options(input: fixture.url, output: output, depth: .ten))
    #expect(result.metadata.sourceTagCount > 0)
    #expect(result.metadata.destinationTagCount >= result.metadata.sourceTagCount)
    let properties = try imageProperties(output)
    #expect(properties[kCGImagePropertyProfileName] != nil)
  }

  @Test("Handles spaces, emoji, Unicode, and long paths")
  func filenames() throws {
    let fixture = try Fixture(type: .tiff, bitsPerComponent: 8)
    defer { fixture.remove() }
    var directory = fixture.directory
    for index in 0..<5 {
      directory.appendPathComponent("long path segment \(index) abcdefghijklmnopqrstuvwxyz")
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let output = directory.appendingPathComponent("München 📷 export 你好.heic")
    _ = try exporter(in: fixture.directory).export(options(input: fixture.url, output: output, depth: .eight))
    #expect(FileManager.default.fileExists(atPath: output.path))
  }

  @Test("Processes a bounded large batch concurrently")
  func largeBatch() async throws {
    let fixture = try Fixture(type: .tiff, bitsPerComponent: 8)
    defer { fixture.remove() }
    let sharedExporter = exporter(in: fixture.directory)
    try await withThrowingTaskGroup(of: Void.self) { group in
      for index in 0..<12 {
        group.addTask {
          let output = fixture.directory.appendingPathComponent("batch-\(index).heic")
          _ = try sharedExporter.export(options(input: fixture.url, output: output, depth: .eight))
        }
      }
      try await group.waitForAll()
    }
    #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path)
      .filter { $0.hasPrefix("batch-") }.count == 12)
  }

  private func exporter(in directory: URL) -> HEICExporter {
    HEICExporter(logger: try! FileLogger(directory: directory.appendingPathComponent("logs"), level: .debug, verbose: false))
  }

  private func options(input: URL, output: URL, depth: BitDepth) -> CommandLineOptions {
    CommandLineOptions(
      inputURL: input, outputURL: output, quality: 0.82, sizeLimit: nil,
      minimumQuality: 0, maximumQuality: 1, colorSpaceName: "DisplayP3",
      bitDepth: depth, importIntoPhotos: false, photosLedger: nil, overwrite: false,
      logDirectory: output.deletingLastPathComponent(), logLevel: .debug,
      lightroomVersion: "test", verbose: false)
  }

  private func imageProperties(_ url: URL) throws -> [CFString: Any] {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    else { throw FixtureError.couldNotCreate }
    return properties
  }
}

private struct Fixture: @unchecked Sendable {
  let directory: URL
  let url: URL

  init(type: UTType, bitsPerComponent: Int) throws {
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("LRExportHEIC-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    url = directory.appendingPathComponent(type == .jpeg ? "source.jpg" : "source.tiff")
    guard let colorSpace = CGColorSpace(name: CGColorSpace.displayP3),
      let context = CGContext(
        data: nil, width: 96, height: 64, bitsPerComponent: bitsPerComponent,
        bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
      let image = Self.draw(in: context),
      let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)
    else { throw FixtureError.couldNotCreate }

    let properties: [CFString: Any] = [
      kCGImagePropertyOrientation: 1,
      kCGImagePropertyTIFFDictionary: [
        kCGImagePropertyTIFFArtist: "Tural Test",
        kCGImagePropertyTIFFCopyright: "Copyright 2026",
        kCGImagePropertyTIFFImageDescription: "Caption and title test",
        kCGImagePropertyTIFFDateTime: "2026:08:05 12:34:56",
      ],
      kCGImagePropertyExifDictionary: [
        kCGImagePropertyExifDateTimeOriginal: "2026:08:05 12:34:56",
        kCGImagePropertyExifLensModel: "FE 24-70mm F2.8 GM II",
        kCGImagePropertyExifBodySerialNumber: "TEST-SERIAL-123",
      ],
      kCGImagePropertyGPSDictionary: [
        kCGImagePropertyGPSLatitude: 48.1351,
        kCGImagePropertyGPSLatitudeRef: "N",
        kCGImagePropertyGPSLongitude: 11.5820,
        kCGImagePropertyGPSLongitudeRef: "E",
      ],
      kCGImagePropertyIPTCDictionary: [
        kCGImagePropertyIPTCKeywords: ["lightroom", "München", "摄影"],
        kCGImagePropertyIPTCCaptionAbstract: "Metadata preservation fixture",
        kCGImagePropertyIPTCObjectName: "Fixture title",
        kCGImagePropertyIPTCByline: "Tural Test",
        kCGImagePropertyIPTCCopyrightNotice: "Copyright 2026",
      ],
    ]
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw FixtureError.couldNotCreate }
  }

  func remove() { try? FileManager.default.removeItem(at: directory) }

  private static func draw(in context: CGContext) -> CGImage? {
    context.setFillColor(CGColor(red: 0.1, green: 0.2, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 96, height: 64))
    context.setFillColor(CGColor(red: 0.9, green: 0.4, blue: 0.1, alpha: 1))
    context.fill(CGRect(x: 20, y: 12, width: 55, height: 40))
    return context.makeImage()
  }
}

private enum FixtureError: Error { case couldNotCreate }
