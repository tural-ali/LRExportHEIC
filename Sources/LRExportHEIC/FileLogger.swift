import Foundation
import os

final class FileLogger: @unchecked Sendable {
  private let fileHandle: FileHandle?
  private let level: LogLevel
  private let verbose: Bool
  private let lock = NSLock()
  private let systemLogger = Logger(subsystem: "at.mwallner.LRExportHEIC", category: "export")

  init(directory: URL?, level: LogLevel, verbose: Bool) throws {
    self.level = level
    self.verbose = verbose
    let base = directory ?? FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Logs/LRExportHEIC", isDirectory: true)
    var openedHandle: FileHandle?
    do {
      try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      let url = base.appendingPathComponent("LRExportHEIC-\(formatter.string(from: Date())).jsonl")
      if !FileManager.default.fileExists(atPath: url.path) {
        FileManager.default.createFile(atPath: url.path, contents: nil)
      }
      openedHandle = try FileHandle(forWritingTo: url)
      try openedHandle?.seekToEnd()
    } catch {
      openedHandle = nil
      systemLogger.error("Unable to open file log: \(error.localizedDescription, privacy: .public)")
    }
    fileHandle = openedHandle
  }

  deinit { try? fileHandle?.close() }

  func error(_ message: String, fields: [String: String] = [:]) { write(.error, message, fields) }
  func info(_ message: String, fields: [String: String] = [:]) { write(.info, message, fields) }
  func debug(_ message: String, fields: [String: String] = [:]) { write(.debug, message, fields) }

  private func write(_ messageLevel: LogLevel, _ message: String, _ fields: [String: String]) {
    guard permits(messageLevel) else { return }
    var record = fields
    record["timestamp"] = ISO8601DateFormatter().string(from: Date())
    record["level"] = messageLevel.rawValue
    record["message"] = message
    if let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
      var line = String(data: data, encoding: .utf8)
    {
      line.append("\n")
      lock.lock()
      defer { lock.unlock() }
      try? fileHandle?.write(contentsOf: Data(line.utf8))
      try? fileHandle?.synchronize()
      if verbose { FileHandle.standardError.write(Data(line.utf8)) }
    }
  }

  private func permits(_ candidate: LogLevel) -> Bool {
    let rank: [LogLevel: Int] = [.error: 0, .info: 1, .debug: 2]
    return rank[candidate, default: 0] <= rank[level, default: 1]
  }
}
