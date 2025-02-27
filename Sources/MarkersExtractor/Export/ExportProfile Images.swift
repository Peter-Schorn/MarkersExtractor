//
//  ExportProfile Images.swift
//  MarkersExtractor • https://github.com/TheAcharya/MarkersExtractor
//  Licensed under MIT License
//

import AVFoundation
import Foundation
import Logging
import OrderedCollections
import TimecodeKit

extension ExportProfile {
    /// Generate animated images on disk.
    /// For the time being, the only format supported is Animated GIF.
    static func writeAnimatedImages(
        timecodes: OrderedDictionary<String, Timecode>,
        video videoPath: URL,
        outputURL: URL,
        gifFPS: Double,
        gifSpan: TimeInterval,
        gifDimensions: CGSize?,
        imageFormat: MarkerImageFormat.Animated,
        imageLabelText: [String],
        imageLabelProperties: MarkerLabelProperties,
        logger: Logger? = nil
    ) throws {
        let logger = logger ?? Logger(label: "\(Self.self)")
        
        var imageLabeler: ImageLabeler?
        
        if !imageLabelText.isEmpty {
            imageLabeler = ImageLabeler(
                labelText: imageLabelText,
                labelProperties: imageLabelProperties,
                logger: logger
            )
        }
        
        for (imageName, timecode) in timecodes {
            let outputURL = outputURL.appendingPathComponent(imageName)
            
            var delta = timecode
            delta.setTimecode(clampingRealTime: gifSpan / 2)
            
            let timeIn = timecode - delta
            let timeOut = timecode + delta
            let timeRange = timeIn ... timeOut
            
            imageLabeler?.nextText()
            
            let conversion = AnimatedImageExtractor.ConversionSettings(
                sourceMediaFile: videoPath,
                outputFolder: outputURL,
                timecodeRange: timeRange,
                dimensions: gifDimensions,
                outputFPS: gifFPS,
                imageFilter: imageLabeler?.labelImage,
                imageFormat: imageFormat
            )
            
            do {
                try AnimatedImageExtractor(conversion, logger: logger).convert()
            } catch {
                throw MarkersExtractorError.runtimeError(
                    "Error while generating animated thumbnail \(outputURL.lastPathComponent.quoted):"
                        + " \(error.localizedDescription)"
                )
            }
        }
    }
    
    static func writeStillImages(
        timecodes: OrderedDictionary<String, Timecode>,
        video videoPath: URL,
        outputURL: URL,
        imageFormat: MarkerImageFormat.Still,
        imageJPGQuality: Double,
        imageDimensions: CGSize?,
        imageLabelText: [String],
        imageLabelProperties: MarkerLabelProperties,
        logger: Logger? = nil
    ) throws {
        let logger = logger ?? Logger(label: "\(Self.self)")
        
        var imageLabeler: ImageLabeler?
        
        if !imageLabelText.isEmpty {
            imageLabeler = ImageLabeler(
                labelText: imageLabelText,
                labelProperties: imageLabelProperties,
                logger: logger
            )
        }
        
        let conversion = ImagesExtractor.ConversionSettings(
            sourceMediaFile: videoPath,
            outputFolder: outputURL,
            timecodes: timecodes,
            frameFormat: imageFormat,
            jpgQuality: imageJPGQuality,
            dimensions: imageDimensions,
            imageFilter: imageLabeler?.labelImageNextText
        )
        
        do {
            try ImagesExtractor(conversion, logger: logger).convert()
        } catch {
            throw MarkersExtractorError.runtimeError(
                "Error while generating images: \(error.localizedDescription)"
            )
        }
    }
}
