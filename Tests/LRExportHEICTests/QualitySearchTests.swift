import Testing

@testable import LRExportHEIC

@Suite("Quality search")
struct QualitySearchTests {
  @Test("Finds the closest quality below the target")
  func basicSearch() {
    let quality = qualitySearch(
      byTargetFileSize: 3_100,
      withAccuracy: 0.8,
      withinRange: 0.1...0.9,
      getFileSizeByQualityFn: { Int64(($0 * 10_000).rounded()) }
    )
    #expect(quality == 0.3)
  }

  @Test("Honors a fixed quality")
  func fixedQuality() {
    var calls = 0
    let quality = qualitySearch(
      byTargetFileSize: 10,
      withAccuracy: 1,
      withinRange: 0.5...0.5,
      getFileSizeByQualityFn: { _ in calls += 1; return 1 }
    )
    #expect(quality == 0.5)
    #expect(calls == 0)
  }

  @Test("Never goes below minimum quality")
  func minimumQuality() {
    let quality = qualitySearch(
      byTargetFileSize: 10,
      withAccuracy: 1,
      withinRange: 0.1...0.9,
      getFileSizeByQualityFn: { Int64(($0 * 10_000).rounded()) }
    )
    #expect(quality == 0.1)
  }
}
