//
//  PersistenceSystem.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//

import SwiftUI
import RealityKit
import UIKit
import ARKit
import Foundation


class PersistenceSystem {
    private var worldTracking: WorldTrackingProvider
    private var rootEntity: Entity
    private var anchoredObjects: [UUID: PlacedObjectEntity] = [:]
    private var objectsBeingAnchored: [UUID: PlacedObjectEntity] = [:]
    private var movingObjects: [PlacedObjectEntity] = []
    private let objectAtRestThreshold: Float = 0.001
    private var worldAnchors: [UUID: WorldAnchor] = [:]
    private var persistedObjectFileNamePerAnchor: [UUID: String] = [:]
    static let objectsDatabaseFileName = "persistentObjects.json"
    var placeableObjectsByFileName: [String: PlaceableObjectEntity] = [:]

    init(worldTracking: WorldTrackingProvider, rootEntity: Entity) {
        self.worldTracking = worldTracking
        self.rootEntity = rootEntity
    }

    func loadPersistedObjects() {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let filePath = docsDir?.appendingPathComponent(Self.objectsDatabaseFileName),
              FileManager.default.fileExists(atPath: filePath.path) else { return }
        do {
            let data = try Data(contentsOf: filePath)
            persistedObjectFileNamePerAnchor = try JSONDecoder().decode([UUID: String].self, from: data)
        } catch {
            print("Failed to decode persisted anchor-object map: \(error)")
        }
    }
    
    func saveWorldAnchorsObjectsMapToDisk() {
        var anchorsToFileNames: [UUID: String] = [:]
        for (anchorID, obj) in anchoredObjects {
            anchorsToFileNames[anchorID] = obj.fileName
        }
        do {
            let data = try JSONEncoder().encode(anchorsToFileNames)
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let filePath = docsDir.appendingPathComponent(Self.objectsDatabaseFileName)
            try data.write(to: filePath)
        } catch {
            print("Failed to save anchors map: \(error)")
        }
    }
    
    @MainActor
    func attachPersistedObjectToAnchor(_ modelFileName: String, anchor: WorldAnchor) {
        guard let placeableObject = placeableObjectsByFileName[modelFileName] else {
            return
        }
        let object = placeableObject.materialize()
        object.position = anchor.originFromAnchorTransform.translation
        object.orientation = anchor.originFromAnchorTransform.rotation
        object.isEnabled = anchor.isTracked
        rootEntity.addChild(object)
        anchoredObjects[anchor.id] = object
    }

    @MainActor
    func process(_ anchorUpdate: AnchorUpdate<WorldAnchor>) {
        let anchor = anchorUpdate.anchor
        if anchorUpdate.event != .removed {
            worldAnchors[anchor.id] = anchor
        } else {
            worldAnchors.removeValue(forKey: anchor.id)
        }
        switch anchorUpdate.event {
        case .added:
            if let persistedFile = persistedObjectFileNamePerAnchor[anchor.id] {
                attachPersistedObjectToAnchor(persistedFile, anchor: anchor)
            } else if let objBeingAnchored = objectsBeingAnchored[anchor.id] {
                objectsBeingAnchored.removeValue(forKey: anchor.id)
                anchoredObjects[anchor.id] = objBeingAnchored
                rootEntity.addChild(objBeingAnchored)
            } else {
                if anchoredObjects[anchor.id] == nil {
                    Task { await removeAnchorWithID(anchor.id) }
                }
            }
            fallthrough
        case .updated:
            if let obj = anchoredObjects[anchor.id] {
                obj.position = anchor.originFromAnchorTransform.translation
                obj.orientation = anchor.originFromAnchorTransform.rotation
                obj.isEnabled = anchor.isTracked
            }
        case .removed:
            anchoredObjects[anchor.id]?.removeFromParent()
            anchoredObjects.removeValue(forKey: anchor.id)
        }
    }
    
    @MainActor
    func removeAllPlacedObjects() async {
        await deleteWorldAnchorsForAnchoredObjects()
    }
    
    private func deleteWorldAnchorsForAnchoredObjects() async {
        for anchorID in anchoredObjects.keys {
            await removeAnchorWithID(anchorID)
        }
    }
    
    func removeAnchorWithID(_ uuid: UUID) async {
        do {
            try await worldTracking.removeAnchor(forID: uuid)
        } catch {
            print("Failed to remove anchor \(uuid): \(error)")
        }
    }
    
    @MainActor
    func attachObjectToWorldAnchor(_ object: PlacedObjectEntity) async {
        let anchor = WorldAnchor(originFromAnchorTransform: object.transformMatrix(relativeTo: nil))
        movingObjects.removeAll { $0 === object }
        objectsBeingAnchored[anchor.id] = object
        do {
            try await worldTracking.addAnchor(anchor)
        } catch {
            objectsBeingAnchored.removeValue(forKey: anchor.id)
            object.removeFromParent()
        }
    }
    
    @MainActor
    private func detachObjectFromWorldAnchor(_ object: PlacedObjectEntity) {
        if let anchorID = anchoredObjects.first(where: { $0.value === object })?.key {
            anchoredObjects.removeValue(forKey: anchorID)
            Task { await removeAnchorWithID(anchorID) }
        }
    }
    
    @MainActor
    func placedObject(for entity: Entity) -> PlacedObjectEntity? {
        anchoredObjects.first(where: { $0.value === entity })?.value
    }
    
    @MainActor
    func object(for entity: Entity) -> PlacedObjectEntity? {
        if let placed = placedObject(for: entity) {
            return placed
        }
        if let moving = movingObjects.first(where: { $0 === entity }) {
            return moving
        }
        if let anchoring = objectsBeingAnchored.first(where: { $0.value === entity })?.value {
            return anchoring
        }
        return nil
    }
    
    @MainActor
    func removeObject(_ object: PlacedObjectEntity) async {
        if let anchorID = anchoredObjects.first(where: { $0.value === object })?.key {
            await removeAnchorWithID(anchorID)
        }
    }
    
    @MainActor
    func checkIfAnchoredObjectsNeedToBeDetached() async {
        for (anchorID, object) in anchoredObjects {
            guard let anchor = worldAnchors[anchorID] else {
                object.positionAtLastReanchoringCheck = object.position
                movingObjects.append(object)
                anchoredObjects.removeValue(forKey: anchorID)
                continue
            }
            let distance = object.position - anchor.originFromAnchorTransform.translation
            if length(distance) >= objectAtRestThreshold {
                object.atRest = false
                object.positionAtLastReanchoringCheck = object.position
                movingObjects.append(object)
                detachObjectFromWorldAnchor(object)
            }
        }
    }
    
    @MainActor
    func checkIfMovingObjectsCanBeAnchored() async {
        for object in movingObjects {
            guard !object.isBeingDragged else { continue }
            let lastPos = object.positionAtLastReanchoringCheck ?? object.position
            let currentPos = object.position
            let movement = currentPos - lastPos
            object.positionAtLastReanchoringCheck = currentPos
            if length(movement) < objectAtRestThreshold {
                object.atRest = true
                await attachObjectToWorldAnchor(object)
            }
        }
    }
}
