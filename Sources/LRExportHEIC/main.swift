import Foundation

var activeLogger: FileLogger?

do {
  let options = try CommandLineOptions.parse(Array(CommandLine.arguments.dropFirst()))
  let logger = try FileLogger(
    directory: options.logDirectory,
    level: options.logLevel,
    verbose: options.verbose
  )
  activeLogger = logger
  let result = try HEICExporter(logger: logger).export(options)
  if options.importIntoPhotos {
    do {
      let importer = PhotosImporter(logger: logger, ledgerURL: options.photosLedger)
      let outcome = try importer.importIfNeeded(result.outputURL)
      logger.info("Photos import \(outcome.rawValue)", fields: ["file": result.outputURL.path])
    } catch {
      logger.error("Photos import failed", fields: [
        "file": result.outputURL.path,
        "error": error.localizedDescription,
      ])
      FileHandle.standardError.write(Data("LRExportHEIC Photos warning: \(error.localizedDescription)\n".utf8))
    }
  }
  logger.info("finish", fields: [
    "output": result.outputURL.path,
    "seconds": String(format: "%.3f", result.duration),
    "bytes": "\(result.fileSize)",
  ])
} catch {
  activeLogger?.error("export failed", fields: ["error": error.localizedDescription])
  FileHandle.standardError.write(Data("LRExportHEIC: \(error)\n".utf8))
  exit(1)
}
