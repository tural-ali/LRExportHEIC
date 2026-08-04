import Foundation
import ImageIO
import UniformTypeIdentifiers

struct MetadataReport: Sendable {
  let sourceTagCount: Int
  let destinationTagCount: Int
  let namespaces: [String]
}

enum MetadataCopier {
  static func copyLosslessly(from metadataSourceURL: URL, encodedURL: URL, to outputURL: URL) throws -> MetadataReport {
    guard let input = CGImageSourceCreateWithURL(metadataSourceURL as CFURL, nil) else {
      throw ExportError.invalidImage(metadataSourceURL.path)
    }
    guard let encoded = CGImageSourceCreateWithURL(encodedURL as CFURL, nil) else {
      throw ExportError.invalidEncodedImage(encodedURL.path)
    }
    guard let metadata = CGImageSourceCopyMetadataAtIndex(input, 0, nil) else {
      throw ExportError.metadataUnavailable(metadataSourceURL.path)
    }
    guard let destination = CGImageDestinationCreateWithURL(
      outputURL as CFURL, UTType.heic.identifier as CFString, 1, nil)
    else { throw ExportError.cannotCreateDestination(outputURL.path) }

    let options: [CFString: Any] = [
      kCGImageDestinationMetadata: metadata,
      kCGImageDestinationMergeMetadata: true,
    ]
    var copyError: Unmanaged<CFError>?
    guard CGImageDestinationCopyImageSource(destination, encoded, options as CFDictionary, &copyError) else {
      let detail = copyError?.takeRetainedValue().localizedDescription ?? "unknown ImageIO error"
      throw ExportError.metadataCopyFailed(detail)
    }

    guard let result = CGImageSourceCreateWithURL(outputURL as CFURL, nil),
      let resultMetadata = CGImageSourceCopyMetadataAtIndex(result, 0, nil)
    else { throw ExportError.metadataVerificationFailed("output metadata cannot be read") }

    let sourceTags = tags(in: metadata)
    let destinationTags = tags(in: resultMetadata)
    let missing = sourceTags.filter(isSemanticTag).subtracting(destinationTags)
    guard missing.isEmpty else {
      throw ExportError.metadataVerificationFailed("missing tags: \(missing.sorted().joined(separator: ", "))")
    }
    let namespaces = Set(sourceTags.compactMap { $0.split(separator: ":").first.map(String.init) }).sorted()
    return MetadataReport(
      sourceTagCount: sourceTags.count,
      destinationTagCount: destinationTags.count,
      namespaces: namespaces
    )
  }

  static func tags(at url: URL) throws -> Set<String> {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil)
    else { throw ExportError.metadataUnavailable(url.path) }
    return tags(in: metadata)
  }

  private static func tags(in metadata: CGImageMetadata) -> Set<String> {
    guard let tags = CGImageMetadataCopyTags(metadata) as? [CGImageMetadataTag] else { return [] }
    var paths = Set<String>()
    for tag in tags {
      if let prefix = CGImageMetadataTagCopyPrefix(tag) as String?,
        let name = CGImageMetadataTagCopyName(tag) as String?
      {
        paths.insert("\(prefix):\(name)")
      }
    }
    return paths
  }

  private static func isSemanticTag(_ path: String) -> Bool {
    let formatSpecificTags: Set<String> = [
      "tiff:BitsPerSample", "tiff:Compression", "tiff:ImageLength", "tiff:ImageWidth",
      "tiff:PhotometricInterpretation", "tiff:PlanarConfiguration", "tiff:ResolutionUnit",
      "tiff:RowsPerStrip", "tiff:SamplesPerPixel", "tiff:StripByteCounts",
      "tiff:StripOffsets", "tiff:XResolution", "tiff:YResolution",
    ]
    return !formatSpecificTags.contains(path)
  }
}
