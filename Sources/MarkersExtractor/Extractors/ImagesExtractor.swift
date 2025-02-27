//
//  ImagesExtractor.swift
//  MarkersExtractor • https://github.com/TheAcharya/MarkersExtractor
//  Licensed under MIT License
//

import AVFoundation
import Foundation
import CoreImage
import Logging
import OrderedCollections
import TimecodeKit

/// Extract one or more images from a video asset.
final class ImagesExtractor {
    // MARK: - Properties
    
    private let logger: Logger
    private let conversion: ConversionSettings
    
    // MARK: - Init
    
    init(_ conversion: ConversionSettings, logger: Logger? = nil) {
        self.logger = logger ?? Logger(label: "\(Self.self)")
        self.conversion = conversion
    }
}

// MARK: - Convert

extension ImagesExtractor {
    func convert() throws {
        try generateImages()
    }
    
    // MARK: - Helpers
    
    private func generateImages() throws {
        let generator = try imageGenerator()
        let times = conversion.timecodes.values.map { $0.cmTime }
        var frameNamesIterator = conversion.timecodes.keys.makeIterator()

        var result: Result<Void, Error> = .failure(.invalidSettings)

        let group = DispatchGroup()
        group.enter()

        generator.generateCGImagesAsynchronously(forTimePoints: times) { [weak self] imageResult in
            guard let self = self else {
                result = .failure(.invalidSettings)
                group.leave()
                return
            }

            guard let frameName = frameNamesIterator.next() else {
                result = .failure(.labelsDepleted)
                group.leave()
                return
            }

            let frameResult = self.processAndWriteFrameToDisk(
                for: imageResult,
                frameName: frameName
            )

            switch frameResult {
            case let .success(finished):
                if finished {
                    result = .success(())
                    group.leave()
                }
            case let .failure(error):
                result = .failure(error)
                group.leave()
            }
        }

        group.wait()

        switch result {
        case let .failure(error):
            throw error
        case .success:
            return
        }
    }

    private func imageGenerator() throws -> AVAssetImageGenerator {
        let asset = AVAsset(url: conversion.sourceMediaFile)
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        // This improves the performance a little bit.
        if let dimensions = conversion.dimensions {
            generator.maximumSize = CGSize(square: dimensions.longestSide)
        }

        return generator
    }

    private func processAndWriteFrameToDisk(
        for result: Result<AVAssetImageGenerator.CompletionHandlerResult, Swift.Error>,
        frameName: String
    ) -> Result<Bool, Error> {
        switch result {
        case let .success(result):
            let image = conversion.imageFilter?(result.image) ?? result.image

            let ciContext = CIContext()
            let ciImage = CIImage(cgImage: image)

            let url = conversion.outputFolder.appendingPathComponent(frameName)

            do {
                switch conversion.frameFormat {
                case .png:
                    // PNG does not offer 'compression' or 'quality' options
                    try ciContext.writePNGRepresentation(
                        of: ciImage,
                        to: url,
                        format: .RGBA8,
                        colorSpace: ciImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
                    )
                case .jpg:
                    var options = [:] as [CIImageRepresentationOption: Any]
                    
                    if let jpgQuality = conversion.jpgQuality {
                        options = [
                            kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption:
                                jpgQuality
                        ]
                    }
                    
                    try ciContext.writeJPEGRepresentation(
                        of: ciImage,
                        to: url,
                        colorSpace: ciImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                        options: options
                    )
                }
            } catch {
                return .failure(.addFrameFailed(error))
            }

            return .success(result.isFinished)
        case let .failure(error):
            return .failure(.generateFrameFailed(error))
        }
    }
}

// MARK: - Types

extension ImagesExtractor {
    struct ConversionSettings {
        let sourceMediaFile: URL
        let outputFolder: URL
        let timecodes: OrderedDictionary<String, Timecode>
        let frameFormat: MarkerImageFormat.Still
        
        /// JPG quality: percentage as a unit interval between `0.0 ... 1.0`
        let jpgQuality: Double?
        
        let dimensions: CGSize?
        let imageFilter: ((CGImage) -> CGImage)?
    }
    
    enum Error: LocalizedError {
        case invalidSettings
        case unreadableFile
        case unsupportedType
        case labelsDepleted
        case generateFrameFailed(Swift.Error)
        case addFrameFailed(Swift.Error)
        case writeFailed(Swift.Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidSettings:
                return "Invalid settings."
            case .unreadableFile:
                return "The selected file is no longer readable."
            case .unsupportedType:
                return "Image type is not supported."
            case .labelsDepleted:
                return "Image labels depleted before images."
            case let .generateFrameFailed(error):
                return "Failed to generate frame: \(error.localizedDescription)"
            case let .addFrameFailed(error):
                return "Failed to add frame, with underlying error: \(error.localizedDescription)"
            case let .writeFailed(error):
                return "Failed to write, with underlying error: \(error.localizedDescription)"
            }
        }
    }
}
