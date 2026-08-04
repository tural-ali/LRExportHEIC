import CoreGraphics
import Foundation

enum BitDepth: String, Sendable {
  case auto
  case eight = "8"
  case ten = "10"
}

enum LogLevel: String, Sendable {
  case error
  case info
  case debug
}

struct CommandLineOptions: Sendable {
  let inputURL: URL
  let outputURL: URL
  let quality: Double?
  let sizeLimit: Int64?
  let minimumQuality: Double
  let maximumQuality: Double
  let colorSpaceName: String?
  let bitDepth: BitDepth
  let importIntoPhotos: Bool
  let photosLedger: URL?
  let overwrite: Bool
  let logDirectory: URL?
  let logLevel: LogLevel
  let lightroomVersion: String?
  let verbose: Bool

  var colorSpace: CGColorSpace? {
    guard let colorSpaceName else { return nil }
    let names: [String: CFString] = [
      "SRGB": CGColorSpace.sRGB,
      "DisplayP3": CGColorSpace.displayP3,
      "AdobeRGB1998": CGColorSpace.adobeRGB1998,
    ]
    return names[colorSpaceName].flatMap(CGColorSpace.init(name:))
  }

  static func parse(_ arguments: [String]) throws -> Self {
    var values: [String: String] = [:]
    var flags = Set<String>()
    var positional: [String] = []
    let valueOptions = Set([
      "--input-file", "--quality", "--size-limit", "--min-quality", "--max-quality",
      "--color-space", "--bit-depth", "--photos-ledger", "--log-directory",
      "--log-level", "--lightroom-version",
    ])
    let flagOptions = Set(["--photos-import", "--overwrite", "--verbose", "--help"])

    var index = 0
    while index < arguments.count {
      let argument = arguments[index]
      if valueOptions.contains(argument) {
        guard index + 1 < arguments.count else { throw CLIError.missingValue(argument) }
        values[argument] = arguments[index + 1]
        index += 2
      } else if flagOptions.contains(argument) {
        flags.insert(argument)
        index += 1
      } else if argument.hasPrefix("-") {
        throw CLIError.unknownOption(argument)
      } else {
        positional.append(argument)
        index += 1
      }
    }

    if flags.contains("--help") {
      print(usage)
      exit(0)
    }
    guard let input = values["--input-file"] else { throw CLIError.missingOption("--input-file") }
    guard positional.count == 1 else { throw CLIError.invalidOutputCount }

    let quality = try parseDouble(values["--quality"], name: "--quality")
    let sizeLimit = try parseInt64(values["--size-limit"], name: "--size-limit")
    if (quality == nil) == (sizeLimit == nil) { throw CLIError.qualityMode }
    let minimumQuality = try parseDouble(values["--min-quality"], name: "--min-quality") ?? 0
    let maximumQuality = try parseDouble(values["--max-quality"], name: "--max-quality") ?? 1
    guard (0...1).contains(quality ?? 0), (0...1).contains(minimumQuality),
      (0...1).contains(maximumQuality), minimumQuality <= maximumQuality
    else { throw CLIError.invalidQuality }
    guard sizeLimit.map({ $0 > 0 }) ?? true else { throw CLIError.invalidSizeLimit }
    if quality != nil && (values["--min-quality"] != nil || values["--max-quality"] != nil) {
      throw CLIError.qualityMode
    }

    let validColorSpaces = ["SRGB", "DisplayP3", "AdobeRGB1998"]
    if let colorSpace = values["--color-space"], !validColorSpaces.contains(colorSpace) {
      throw CLIError.invalidColorSpace(colorSpace)
    }
    guard let depth = BitDepth(rawValue: values["--bit-depth"] ?? "auto") else {
      throw CLIError.invalidBitDepth
    }
    guard let level = LogLevel(rawValue: values["--log-level"] ?? "info") else {
      throw CLIError.invalidLogLevel
    }

    return Self(
      inputURL: URL(fileURLWithPath: input),
      outputURL: URL(fileURLWithPath: positional[0]),
      quality: quality,
      sizeLimit: sizeLimit,
      minimumQuality: minimumQuality,
      maximumQuality: maximumQuality,
      colorSpaceName: values["--color-space"],
      bitDepth: depth,
      importIntoPhotos: flags.contains("--photos-import"),
      photosLedger: values["--photos-ledger"].map(URL.init(fileURLWithPath:)),
      overwrite: flags.contains("--overwrite"),
      logDirectory: values["--log-directory"].map(URL.init(fileURLWithPath:)),
      logLevel: level,
      lightroomVersion: values["--lightroom-version"],
      verbose: flags.contains("--verbose")
    )
  }

  private static func parseDouble(_ value: String?, name: String) throws -> Double? {
    guard let value else { return nil }
    guard let parsed = Double(value) else { throw CLIError.invalidNumber(name, value) }
    return parsed
  }

  private static func parseInt64(_ value: String?, name: String) throws -> Int64? {
    guard let value else { return nil }
    guard let parsed = Int64(value) else { throw CLIError.invalidNumber(name, value) }
    return parsed
  }

  static let usage = """
    Usage: LRExportHEIC --input-file INPUT (--quality 0...1 | --size-limit BYTES) [options] OUTPUT

      --bit-depth auto|8|10       Output bit depth (default: auto)
      --color-space NAME          SRGB, DisplayP3, or AdobeRGB1998
      --photos-import             Import the completed file into Apple Photos
      --overwrite                 Replace an existing destination atomically
      --log-directory PATH        Log directory (default: ~/Library/Logs/LRExportHEIC)
      --log-level error|info|debug
    """
}

enum CLIError: LocalizedError {
  case missingValue(String), missingOption(String), unknownOption(String), invalidOutputCount
  case qualityMode, invalidQuality, invalidSizeLimit, invalidNumber(String, String)
  case invalidColorSpace(String), invalidBitDepth, invalidLogLevel

  var errorDescription: String? {
    switch self {
    case .missingValue(let option): "Missing value for \(option)"
    case .missingOption(let option): "Missing required option \(option)"
    case .unknownOption(let option): "Unknown option \(option)"
    case .invalidOutputCount: "Exactly one output path is required"
    case .qualityMode: "Specify exactly one of --quality or --size-limit"
    case .invalidQuality: "Quality values must be between 0 and 1, with min <= max"
    case .invalidSizeLimit: "--size-limit must be greater than zero"
    case .invalidNumber(let option, let value): "Invalid number '\(value)' for \(option)"
    case .invalidColorSpace(let name): "Unsupported color space \(name)"
    case .invalidBitDepth: "--bit-depth must be auto, 8, or 10"
    case .invalidLogLevel: "--log-level must be error, info, or debug"
    }
  }
}
