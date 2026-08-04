import Foundation
import Testing

@testable import LRExportHEIC

@Suite("Apple Photos import")
struct PhotosImporterTests {
  @Test("Content hash prevents duplicate imports")
  func duplicateDetection() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("LRExportHEIC-photos-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let image = directory.appendingPathComponent("photo.heic")
    try Data("stable HEIC fixture bytes".utf8).write(to: image)
    let library = FakePhotosLibrary()
    let logger = try FileLogger(directory: directory, level: .debug, verbose: false)
    let importer = PhotosImporter(
      logger: logger,
      ledgerURL: directory.appendingPathComponent("ledger.json"),
      library: library)

    #expect(try importer.importIfNeeded(image) == .imported)
    #expect(try importer.importIfNeeded(image) == .duplicateSkipped)
    #expect(library.importCount == 1)
  }
}

private final class FakePhotosLibrary: PhotosLibrary, @unchecked Sendable {
  private let lock = NSLock()
  private var identifiers = Set<String>()
  private var count = 0

  var importCount: Int { lock.withLock { count } }
  func authorize() throws {}
  func assetExists(_ localIdentifier: String) -> Bool { lock.withLock { identifiers.contains(localIdentifier) } }
  func importAsset(at fileURL: URL) throws -> String {
    lock.withLock {
      count += 1
      let identifier = "asset-\(count)"
      identifiers.insert(identifier)
      return identifier
    }
  }
}
