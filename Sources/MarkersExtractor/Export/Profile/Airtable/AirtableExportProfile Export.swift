//
//  AirtableExportProfile Export.swift
//  MarkersExtractor • https://github.com/TheAcharya/MarkersExtractor
//  Licensed under MIT License
//

import AVFoundation
import CodableCSV
import Foundation
import Logging
import OrderedCollections
import TimecodeKit

extension AirtableExportProfile {
    public func prepareMarkers(
        markers: [Marker],
        idMode: MarkerIDMode,
        payload: Payload,
        mediaInfo: ExportMarkerMediaInfo?
    ) -> [PreparedMarker] {
        markers.map {
            PreparedMarker(
                $0,
                idMode: idMode,
                mediaInfo: mediaInfo
            )
        }
    }
    
    public func writeManifest(
        _ preparedMarkers: [PreparedMarker],
        payload: Payload,
        noMedia: Bool
    ) throws {
        try csvWriteManifest(
            csvPath: payload.csvPayload.csvPath,
            noMedia: noMedia,
            preparedMarkers
        )
        try jsonWriteManifest(
            jsonPath: payload.jsonPayload.jsonPath,
            noMedia: noMedia,
            preparedMarkers
        )
    }
    
    public func doneFileContent(payload: Payload) throws -> Data {
        let csv = csvDoneFileContent(csvPath: payload.csvPayload.csvPath)
        let json = jsonDoneFileContent(jsonPath: payload.jsonPayload.jsonPath)
        
        let dict = csv.merging(json) { a, b in a }
        let data = try dictToJSON(dict)
        return data
    }
    
    public func manifestFields(
        for marker: PreparedMarker,
        noMedia: Bool
    ) -> OrderedDictionary<ExportField, String> {
        var dict: OrderedDictionary<ExportField, String> = [
            .id: marker.id,
            .name: marker.name,
            .type: marker.type,
            .checked: marker.checked,
            .status: marker.status,
            .notes: marker.notes,
            .position: marker.position,
            .clipName: marker.clipName,
            .clipFilename: marker.clipFilename,
            .clipDuration: marker.clipDuration,
            .videoRole: marker.videoRole,
            .audioRole: marker.audioRole,
            .eventName: marker.eventName,
            .projectName: marker.projectName,
            .libraryName: marker.libraryName
        ]
        
        if !noMedia {
            dict[.imageFileName] = marker.imageFileName
        }
        
        return dict
    }
}
