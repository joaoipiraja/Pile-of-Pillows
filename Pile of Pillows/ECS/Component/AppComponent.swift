//
//  AppComponent.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//

import SwiftUI
import RealityKit
import UIKit
import ARKit
import Foundation

@Observable
class AppComponent: ECSComponent {
    var immersiveSpaceOpened: Bool { placementSystem != nil }
    private(set) weak var placementSystem: PlacementSystem? = nil

    private(set) var placeableObjectsByFileName: [String: PlaceableObjectEntity] = [:]
    private(set) var modelDescriptors: [ModelDescriptorComponent] = []
    var selectedFileName: String?

    func immersiveSpaceOpened(with manager: PlacementSystem) {
        placementSystem = manager
    }

    func didLeaveImmersiveSpace() {
        if let placementSystem {
            placementSystem.saveWorldAnchorsObjectsMapToDisk()
            arkitSession.stop()
        }
        placementSystem = nil
    }

    func setPlaceableObjects(_ objects: [PlaceableObjectEntity]) {
        placeableObjectsByFileName = objects.reduce(into: [:]) { map, obj in
            map[obj.descriptor.fileName] = obj
        }
        modelDescriptors = objects.map { $0.descriptor }.sorted { $0.displayName < $1.displayName }
    }

    var arkitSession = ARKitSession()
    var providersStoppedWithError = false
    var worldSensingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined
    
    var allRequiredAuthorizationsAreGranted: Bool {
        worldSensingAuthorizationStatus == .allowed
    }
    var allRequiredProvidersAreSupported: Bool {
        WorldTrackingProvider.isSupported && PlaneDetectionProvider.isSupported
    }
    var canEnterImmersiveSpace: Bool {
        allRequiredAuthorizationsAreGranted && allRequiredProvidersAreSupported
    }

    func requestWorldSensingAuthorization() async {
        let result = await arkitSession.requestAuthorization(for: [.worldSensing])
        worldSensingAuthorizationStatus = result[.worldSensing]!
    }
    
    func queryWorldSensingAuthorization() async {
        let result = await arkitSession.queryAuthorization(for: [.worldSensing])
        worldSensingAuthorizationStatus = result[.worldSensing]!
    }

    func monitorSessionEvents() async {
        for await event in arkitSession.events {
            switch event {
            case .dataProviderStateChanged(_, let newState, let error):
                if newState == .stopped, let error{
                    providersStoppedWithError = true
                }
            case .authorizationChanged(let type, let status):
                if type == .worldSensing {
                    worldSensingAuthorizationStatus = status
                }
            default:
                break
            }
        }
    }

    fileprivate var previewPlacementSystem: PlacementSystem? = nil

    @MainActor
    static func previewAppState(immersiveSpaceOpened: Bool = false, selectedIndex: Int? = nil) -> AppComponent {
        let app = AppComponent()
        app.setPlaceableObjects([
            previewObject(named: "Pillow")
        ])
        if let selectedIndex, selectedIndex < app.modelDescriptors.count {
            app.selectedFileName = app.modelDescriptors[selectedIndex].fileName
        }
        if immersiveSpaceOpened {
            app.previewPlacementSystem = PlacementSystem()
            app.placementSystem = app.previewPlacementSystem
        }
        return app
    }
    
    @MainActor
    private static func previewObject(named fileName: String) -> PlaceableObjectEntity {
        let descriptor = ModelDescriptorComponent(fileName: fileName)
        let render = ModelEntity()
        let preview = ModelEntity()
        return PlaceableObjectEntity(descriptor: descriptor, renderContent: render, previewEntity: preview)
    }
}
