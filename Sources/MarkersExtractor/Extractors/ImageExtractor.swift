//
//  ImageExtractor.swift
//  MarkersExtractor • https://github.com/TheAcharya/MarkersExtractor
//  Licensed under MIT License
//

import AVFoundation
import Foundation
import CoreImage
import Logging
import OrderedCollections
import TimecodeKit

final class ImageExtractor {
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

    struct ConversionSettings {
        let sourceURL: URL
        let outputURL: URL
        let timecodes: OrderedDictionary<String, Timecode>
        let frameFormat: MarkerImageFormat.Still
        let frameJPGQuality: Double?
        let dimensions: CGSize?
        let imageFilter: ((CGImage) -> CGImage)?
    }

    private let logger = Logger(label: "\(ImageExtractor.self)")

    private let conversion: ConversionSettings

    init(_ conversion: ConversionSettings) {
        self.conversion = conversion
    }

    static func convert(_ conversion: ConversionSettings) throws {
        let conv = self.init(conversion)
        try conv.generateImages()
    }

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

            let frameResult = self.processFrame(for: imageResult, frameName: frameName)

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
        let asset = AVAsset(url: conversion.sourceURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        // This improves the performance a little bit.
        if let dimensions = conversion.dimensions {
            generator.maximumSize = CGSize(widthHeight: dimensions.longestSide)
        }

        return generator
    }

    private func processFrame(
        for result: Result<AVAssetImageGenerator.CompletionHandlerResult, Swift.Error>,
        frameName: String
    ) -> Result<Bool, Error> {
        switch result {
        case let .success(result):
            let image = conversion.imageFilter?(result.image) ?? result.image

            let cicontext = CIContext()
            let ciimage = CIImage(cgImage: image)

            let url = conversion.outputURL.appendingPathComponent(frameName)

            var options = [:] as [CIImageRepresentationOption: Any]

            if let jpgQuality = conversion.frameJPGQuality {
                options = [
                    kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption:
                        jpgQuality
                ]
            }

            do {
                switch conversion.frameFormat {
                case .png:
                    try cicontext.writePNGRepresentation(
                        of: ciimage,
                        to: url,
                        format: .RGBA8,
                        colorSpace: ciimage.colorSpace!
                    )
                case .jpg:
                    try cicontext.writeJPEGRepresentation(
                        of: ciimage,
                        to: url,
                        colorSpace: ciimage.colorSpace!,
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
