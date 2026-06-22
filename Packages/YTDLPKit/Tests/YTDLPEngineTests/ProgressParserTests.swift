import Testing
import Foundation
@testable import YTDLPEngine

@Suite struct ProgressParserTests {
    let parser = ProgressParser()

    @Test func parsesDownloadingLine() throws {
        let line = "DLP|downloading|1048576|10485760|10485760|524288.0|18"
        let p = try #require(parser.parse(line: line))
        #expect(p.phase == .downloading)
        #expect(p.downloadedBytes == 1_048_576)
        #expect(p.totalBytes == 10_485_760)
        #expect(p.speedBytesPerSecond == 524_288.0)
        #expect(p.etaSeconds == 18)
        #expect(p.fractionCompleted == 0.1)
    }

    @Test func fallsBackToEstimateWhenTotalUnknown() throws {
        let line = "DLP|downloading|500|NA|2000|NA|NA"
        let p = try #require(parser.parse(line: line))
        #expect(p.totalBytes == 2000)
        #expect(p.speedBytesPerSecond == nil)
        #expect(p.etaSeconds == nil)
        #expect(p.fractionCompleted == 0.25)
    }

    @Test func finishedLineIsComplete() throws {
        let line = "DLP|finished|10485760|10485760|10485760|NA|0"
        let p = try #require(parser.parse(line: line))
        #expect(p.phase == .finished)
        #expect(p.fractionCompleted == 1.0)
    }

    @Test func detectsPostProcessing() throws {
        let p = try #require(parser.parse(line: "[ExtractAudio] Destination: song.mp3"))
        if case .postProcessing = p.phase {} else { Issue.record("erwartete postProcessing-Phase") }
    }

    @Test func ignoresUnrelatedLines() {
        #expect(parser.parse(line: "[youtube] Extracting URL: ...") == nil)
        #expect(parser.parse(line: "some random output") == nil)
    }
}
