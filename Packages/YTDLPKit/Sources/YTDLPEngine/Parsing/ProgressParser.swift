import Foundation

/// Reads the progress lines produced by `--progress-template` as well as yt-dlp status messages.
public struct ProgressParser: Sendable {
    /// Must match exactly the template that the `ArgumentBuilder` passes to yt-dlp.
    /// Order: status | downloaded | total | total_estimate | speed | eta
    public static let downloadTemplate =
        "DLP|%(progress.status)s|%(progress.downloaded_bytes)s|%(progress.total_bytes)s|%(progress.total_bytes_estimate)s|%(progress.speed)s|%(progress.eta)s"

    private static let sentinel = "DLP|"

    private static let postProcessingMarkers: [(String, String)] = [
        ("[ExtractAudio]", "Audio extrahieren"),
        ("[Merger]", "Zusammenführen"),
        ("[EmbedSubtitle]", "Untertitel einbetten"),
        ("[Metadata]", "Metadaten"),
        ("[ThumbnailsConvertor]", "Thumbnail"),
        ("[EmbedThumbnail]", "Thumbnail einbetten"),
        ("[VideoConvertor]", "Konvertieren"),
    ]

    public init() {}

    public func parse(line: String) -> DownloadProgress? {
        if line.hasPrefix(Self.sentinel) {
            return parseProgressLine(line)
        }
        for (marker, label) in Self.postProcessingMarkers where line.contains(marker) {
            return DownloadProgress(phase: .postProcessing(label), rawLine: line)
        }
        return nil
    }

    /// Detects the destination path from yt-dlp lines (full path).
    public func parseDestination(line: String) -> String? {
        if let range = line.range(of: "Destination: ") {
            let path = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return path.isEmpty ? nil : path
        }
        if line.contains("Merging formats into ") {
            // [Merger] Merging formats into "/path/file.mkv"
            let parts = line.components(separatedBy: "\"")
            if parts.count >= 2 { return parts[1] }
        }
        return nil
    }

    private func parseProgressLine(_ line: String) -> DownloadProgress? {
        let fields = line.components(separatedBy: "|")
        // [0]=DLP [1]=status [2]=downloaded [3]=total [4]=estimate [5]=speed [6]=eta
        guard fields.count >= 7 else { return nil }

        let status = fields[1]
        let downloaded = Self.int64(fields[2])
        let total = Self.int64(fields[3]) ?? Self.int64(fields[4])
        let speed = Self.double(fields[5])
        let eta = Self.int(fields[6])

        var fraction: Double?
        if let downloaded, let total, total > 0 {
            fraction = min(1.0, Double(downloaded) / Double(total))
        }

        let phase: DownloadProgress.Phase = (status == "finished") ? .finished : .downloading
        if status == "finished" { fraction = 1.0 }

        return DownloadProgress(
            phase: phase,
            fractionCompleted: fraction,
            downloadedBytes: downloaded,
            totalBytes: total,
            speedBytesPerSecond: speed,
            etaSeconds: eta,
            rawLine: line
        )
    }

    // For `%s`, yt-dlp prints "NA" for unknown fields; numbers may come as floats ("1234.0").
    private static func double(_ field: String) -> Double? {
        let t = field.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, t != "NA", t != "None" else { return nil }
        return Double(t)
    }
    private static func int64(_ field: String) -> Int64? {
        guard let d = double(field) else { return nil }
        return Int64(d)
    }
    private static func int(_ field: String) -> Int? {
        guard let d = double(field) else { return nil }
        return Int(d)
    }
}
