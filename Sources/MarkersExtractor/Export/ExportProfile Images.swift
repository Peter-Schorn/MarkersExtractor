//
//  ExportProfile Images.swift
//  MarkersExtractor • https://github.com/TheAcharya/MarkersExtractor
//  Licensed under MIT License
//

import AVFoundation
import Foundation
import OrderedCollections
import TimecodeKit

extension ExportProfile {
    /// Generate animated images on disk.
    /// For the time being, the only format supported is Animated GIF.
    static func writeAnimatedImages(
        timecodes: OrderedDictionary<String, Timecode>,
        video videoPath: URL,
        outputPath: URL,
        gifFPS: Double,
        gifSpan: TimeInterval,
        gifDimensions: CGSize?,
        imageFormat: MarkerImageFormat.Animated,
        imageLabelText: [String],
        imageLabelProperties: MarkerLabelProperties
    ) throws {
        var imageLabeler: ImageLabeler?
        
        if !imageLabelText.isEmpty {
            imageLabeler = ImageLabeler(
                labelText: imageLabelText,
                labelProperties: imageLabelProperties
            )
        }
        
        for (imageName, timecode) in timecodes {
            let gifPath = outputPath.appendingPathComponent(imageName)
            
            let timePoint = timecode.realTimeValue
            let gifSpan = gifSpan / 2
            let timeRange = (timePoint - gifSpan) ... (timePoint + gifSpan)
            
            imageLabeler?.nextText()
            
            let conversion = AnimatedImageExtractor.ConversionSettings(
                sourceURL: videoPath,
                outputURL: gifPath,
                timeRange: timeRange,
                dimensions: gifDimensions,
                fps: gifFPS,
                imageFilter: imageLabeler?.labelImage,
                imageFormat: imageFormat
            )
            
            do {
                try AnimatedImageExtractor.convert(conversion)
            } catch {
                throw MarkersExtractorError.runtimeError(
                    "Error while generating gif \(gifPath.lastPathComponent.quoted):"
                        + " \(error.localizedDescription)"
                )
            }
        }
    }
    
    static func writeStillImages(
        timecodes: OrderedDictionary<String, Timecode>,
        video videoPath: URL,
        outputPath: URL,
        imageFormat: MarkerImageFormat.Still,
        imageJPGQuality: Double,
        imageDimensions: CGSize?,
        imageLabelText: [String],
        imageLabelProperties: MarkerLabelProperties
    ) throws {
        var imageLabeler: ImageLabeler?
        
        if !imageLabelText.isEmpty {
            imageLabeler = ImageLabeler(
                labelText: imageLabelText,
                labelProperties: imageLabelProperties
            )
        }
        
        let conversion = ImageExtractor.ConversionSettings(
            sourceURL: videoPath,
            outputURL: outputPath,
            timecodes: timecodes,
            frameFormat: imageFormat,
            frameJPGQuality: imageJPGQuality,
            dimensions: imageDimensions,
            imageFilter: imageLabeler?.labelImageNextText
        )
        
        do {
            try ImageExtractor.convert(conversion)
        } catch {
            throw MarkersExtractorError.runtimeError(
                "Error while generating images: \(error.localizedDescription)"
            )
        }
    }
}
