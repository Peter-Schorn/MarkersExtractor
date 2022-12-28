import AVFoundation
import AppKit
import Foundation
import Logging
import OrderedCollections
import TimecodeKit

public final class MarkersExtractor {
    private let logger = Logger(label: "\(MarkersExtractor.self)")
    private let s: Settings

    init(_ settings: Settings) {
        s = settings
    }

    public static func extract(_ settings: Settings) throws {
        try self.init(settings).run()
    }

    func run() throws {
        let imageQuality = Double(s.imageQuality) / 100
        let imageLabelFontAlpha = Double(s.imageLabelFontOpacity) / 100
        let imageLabels = OrderedSet(s.imageLabels).map { $0 }
        let imageFormatEXT = s.imageFormat.rawValue.uppercased()

        logger.info("Extracting markers from \(s.fcpxml).")

        let markers = try extractMarkers()
        
        guard !markers.isEmpty else {
            logger.info("No markers found.")
            return
        }

        if !Resource.validateAll() {
            logger.warning("Could not validate internal resource files. Export may not work correctly.")
        }
        
        let projectName = markers[0].parentInfo.projectName

        let destPath = try makeDestPath(for: projectName)

        let videoPath = try findMedia(name: projectName, paths: s.mediaSearchPaths)

        logger.info("Found project media file \(videoPath.path.quoted).")
        logger.info("Generating CSV with \(imageFormatEXT) images into \(destPath.path.quoted).")

        let labelProperties = MarkerLabelProperties(
            fontName: s.imageLabelFont,
            fontMaxSize: s.imageLabelFontMaxSize,
            fontColor: NSColor(hexString: s.imageLabelFontColor, alpha: imageLabelFontAlpha),
            fontStrokeColor: NSColor(
                hexString: s.imageLabelFontStrokeColor,
                alpha: imageLabelFontAlpha
            ),
            fontStrokeWidth: s.imageLabelFontStrokeWidth,
            alignHorizontal: s.imageLabelAlignHorizontal,
            alignVertical: s.imageLabelAlignVertical
        )

        let csvName = "\(projectName).csv"
        let csvPath = destPath.appendingPathComponent(csvName)
        
        do {
            try CSVExportModel.export(
                markers: markers,
                idMode: s.idNamingMode,
                csvPath: csvPath,
                videoPath: videoPath,
                outputPath: destPath,
                imageSettings: .init(
                    gifFPS: s.gifFPS,
                    gifSpan: s.gifSpan,
                    format: s.imageFormat,
                    quality: imageQuality,
                    dimensions: calcVideoDimensions(for: videoPath),
                    labelFields: imageLabels,
                    labelCopyright: s.imageLabelCopyright,
                    labelProperties: labelProperties,
                    imageLabelHideNames: s.imageLabelHideNames
                )
            )
        } catch {
            throw MarkersExtractorError.runtimeError(
                "Failed to export CSV: \(error.localizedDescription)"
            )
        }

        if s.createDoneFile {
            logger.info("Creating \(s.doneFilename.quoted) done file at \(destPath.path.quoted).")
            try saveDoneFile(at: destPath, fileName: s.doneFilename, content: csvPath.path)
        }

        logger.info("Done!")
    }

    internal func extractMarkers(sort: Bool = true) throws -> [Marker] {
        var markers: [Marker]

        do {
            markers = try FCPXMLMarkerExtractor.extractMarkers(
                from: s.fcpxml,
                idNamingMode: s.idNamingMode
            )
        } catch {
            throw MarkersExtractorError.runtimeError(
                "Failed to parse \(s.fcpxml): \(error.localizedDescription)"
            )
        }

        if !isAllUniqueIDs(in: markers) {
            throw MarkersExtractorError.runtimeError("Every marker must have non-empty ID.")
        }

        // TODO: duplicate markers shouldn't be an error condition, we should append filename uniquing string to the ID instead
        let duplicates = findDuplicateIDs(in: markers)
        if !duplicates.isEmpty {
            throw MarkersExtractorError.runtimeError("Duplicate marker IDs found: \(duplicates)")
        }
        
        if sort {
            markers.sort()
        }

        return markers
    }

    internal func findDuplicateIDs(in markers: [Marker]) -> [String] {
        Dictionary(grouping: markers, by: { $0.id(s.idNamingMode) })
            .filter { $1.count > 1 }
            .compactMap { $0.1.first }
            .map { $0.id(s.idNamingMode) }
            .sorted()
    }

    internal func isAllUniqueIDs(in markers: [Marker]) -> Bool {
        markers
            .map { $0.id(s.idNamingMode) }
            .allSatisfy { !$0.isEmpty }
    }

    private func makeDestPath(for projectName: String) throws -> URL {
        let destPath = s.outputDir.appendingPathComponent(
            "\(projectName) \(nowTimestamp())"
        )

        do {
            // TODO: this should throw an error if the folder already exists; this folder should be created new every time
            try FileManager.default.mkdirWithParent(destPath.path)
        } catch {
            throw MarkersExtractorError.runtimeError(
                "Failed to create destination dir \(destPath.path.quoted): \(error.localizedDescription)"
            )
        }

        return destPath
    }

    private func saveDoneFile(at destPath: URL, fileName: String, content: String) throws {
        let doneFile = destPath.appendingPathComponent(fileName)

        do {
            try content.write(to: doneFile, atomically: true, encoding: .utf8)
        } catch {
            throw MarkersExtractorError.runtimeError(
                "Failed to create done file \(doneFile.path.quoted): \(error.localizedDescription)"
            )
        }
    }

    private func findMedia(name: String, paths: [URL]) throws -> URL {
        let mediaFormats = ["mov", "mp4", "m4v", "mxf", "avi", "mts", "m2ts", "3gp"]
        
        let files: [URL] = try paths.reduce(into: []) { base, path in
            do {
                let matches = try matchFiles(at: path, name: name, exts: mediaFormats)
                base.append(contentsOf: matches)
            } catch {
                throw MarkersExtractorError.runtimeError(
                    "Error finding media for \(name.quoted): \(error.localizedDescription)"
                )
            }
        }
        
        if files.isEmpty {
            throw MarkersExtractorError.runtimeError("No media found for \(name.quoted).")
        }

        let selection = files[0]
        
        if files.count > 1 {
            logger.info("Found more than one media candidate for \(name.quoted). Using first match: \(selection.path.quoted)")
        }

        return selection
    }

    private func matchFiles(at path: URL, name: String, exts: [String]) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
            .filter {
                $0.lastPathComponent.starts(with: name)
                    && exts.contains($0.fileExtension)
            }
    }

    private func nowTimestamp() -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd hh-mm-ss"
        return formatter.string(from: now)
    }

    private func calcVideoDimensions(for videoPath: URL) -> CGSize? {
        if s.imageWidth != nil || s.imageHeight != nil {
            return CGSize(width: s.imageWidth ?? 0, height: s.imageHeight ?? 0)
        } else if let imageSizePercent = s.imageSizePercent {
            return calcVideosSizePercent(at: videoPath, for: imageSizePercent)
        }

        return nil
    }

    private func calcVideosSizePercent(at path: URL, for percent: Int) -> CGSize? {
        let asset = AVAsset(url: path)
        let ratio = Double(percent) / 100

        guard let origDimensions = asset.firstVideoTrack?.dimensions else {
            return nil
        }

        return origDimensions * ratio
    }
}
