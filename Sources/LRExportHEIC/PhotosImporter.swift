import CryptoKit
import Foundation
import Photos

enum PhotosImportOutcome: String, Sendable {
  case imported
  case duplicateSkipped
}

enum PhotosImportError: LocalizedError {
  case permissionDenied, importFailed(String), fingerprintFailed(String), ledgerFailed(String)

  var errorDescription: String? {
    switch self {
    case .permissionDenied: "Apple Photos permission was denied. Allow Photos access in System Settings > Privacy & Security > Photos."
    case .importFailed(let detail): "Apple Photos import failed: \(detail)"
    case .fingerprintFailed(let detail): "Could not fingerprint export for duplicate detection: \(detail)"
    case .ledgerFailed(let detail): "Could not update Photos import ledger: \(detail)"
    }
  }
}

final class PhotosImporter: @unchecked Sendable {
  private let logger: FileLogger
  private let ledgerURL: URL
  private let library: any PhotosLibrary

  init(logger: FileLogger, ledgerURL: URL?, library: (any PhotosLibrary)? = nil) {
    self.logger = logger
    self.library = library ?? SystemPhotosLibrary()
    self.ledgerURL = ledgerURL ?? FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/LRExportHEIC/photos-imports.json")
  }

  func importIfNeeded(_ fileURL: URL) throws -> PhotosImportOutcome {
    let digest = try fingerprint(fileURL)
    var ledger = try readLedger()
    if let localIdentifier = ledger[digest], library.assetExists(localIdentifier) {
      logger.info("Photos duplicate skipped", fields: ["fingerprint": digest])
      return .duplicateSkipped
    }

    try library.authorize()
    let localIdentifier = try library.importAsset(at: fileURL)
    ledger[digest] = localIdentifier
    try writeLedger(ledger)
    logger.info("Photos import complete", fields: [
      "asset": localIdentifier,
      "fingerprint": digest,
    ])
    return .imported
  }

}

protocol PhotosLibrary: Sendable {
  func authorize() throws
  func assetExists(_ localIdentifier: String) -> Bool
  func importAsset(at fileURL: URL) throws -> String
}

struct SystemPhotosLibrary: PhotosLibrary {
  func assetExists(_ localIdentifier: String) -> Bool {
    PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).count > 0
  }

  func authorize() throws {
    var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    if status == .notDetermined {
      let semaphore = DispatchSemaphore(value: 0)
      let box = AuthorizationBox()
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
        box.status = newStatus
        semaphore.signal()
      }
      semaphore.wait()
      status = box.status
    }
    guard status == .authorized || status == .limited else {
      throw PhotosImportError.permissionDenied
    }
  }

  func importAsset(at fileURL: URL) throws -> String {
    let box = PlaceholderBox()
    do {
      try PHPhotoLibrary.shared().performChangesAndWait {
        let request = PHAssetCreationRequest.forAsset()
        request.addResource(with: .photo, fileURL: fileURL, options: nil)
        box.placeholder = request.placeholderForCreatedAsset
      }
    } catch {
      throw PhotosImportError.importFailed(error.localizedDescription)
    }
    guard let localIdentifier = box.placeholder?.localIdentifier else {
      throw PhotosImportError.importFailed("Photos returned no asset identifier")
    }
    return localIdentifier
  }
}

extension PhotosImporter {
  private func fingerprint(_ url: URL) throws -> String {
    do {
      let handle = try FileHandle(forReadingFrom: url)
      defer { try? handle.close() }
      var hasher = SHA256()
      while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty {
        hasher.update(data: data)
      }
      return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    } catch {
      throw PhotosImportError.fingerprintFailed(error.localizedDescription)
    }
  }

  private func readLedger() throws -> [String: String] {
    guard FileManager.default.fileExists(atPath: ledgerURL.path) else { return [:] }
    do {
      let data = try Data(contentsOf: ledgerURL)
      return try JSONDecoder().decode([String: String].self, from: data)
    } catch {
      throw PhotosImportError.ledgerFailed(error.localizedDescription)
    }
  }

  private func writeLedger(_ ledger: [String: String]) throws {
    do {
      try FileManager.default.createDirectory(
        at: ledgerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      let data = try JSONEncoder().encode(ledger)
      try data.write(to: ledgerURL, options: .atomic)
    } catch {
      throw PhotosImportError.ledgerFailed(error.localizedDescription)
    }
  }
}

private final class AuthorizationBox: @unchecked Sendable {
  private let lock = NSLock()
  private var value: PHAuthorizationStatus = .notDetermined

  var status: PHAuthorizationStatus {
    get { lock.withLock { value } }
    set { lock.withLock { value = newValue } }
  }
}

private final class PlaceholderBox: @unchecked Sendable {
  private let lock = NSLock()
  private var value: PHObjectPlaceholder?

  var placeholder: PHObjectPlaceholder? {
    get { lock.withLock { value } }
    set { lock.withLock { value = newValue } }
  }
}
