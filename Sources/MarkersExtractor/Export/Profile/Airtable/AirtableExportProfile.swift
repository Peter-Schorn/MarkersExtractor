//
//  AirtableExportProfile.swift
//  MarkersExtractor • https://github.com/TheAcharya/MarkersExtractor
//  Licensed under MIT License
//

import Foundation
import Logging

public struct AirtableExportProfile: ExportProfile {
    public typealias Payload = CSVJSONExportPayload
    public typealias Icon = EmptyExportIcon
    public typealias PreparedMarker = StandardExportMarker
    
    public static let isMediaCapable: Bool = true
    
    public var logger: Logger?
    
    public init(logger: Logger? = nil) {
        self.logger = logger
    }
}
